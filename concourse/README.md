## Concourse CI

A Terraform module for deploying Concourse CI.

## Prerequisites

1. You must generate the necessary keys for Concourse:

```bash
# Create folder
mkdir -p keys

ssh-keygen -t rsa -f ./keys/tsa_host_key -N ''
ssh-keygen -t rsa -f ./keys/worker_key -N ''
ssh-keygen -t rsa -f ./keys/session_signing_key -N ''

# Authorized workers
cp ./keys/worker_key.pub ./keys/authorized_worker_keys
```

2. Use Packer to make a concourse AMI:

```bash
packer validate template.json

packer build \
  -var="source_ami=<amazon-linux-2>" \
  -var="concourse_version=v3.8.0" \
  template.json
```

NOTE: You can use [bin/ami.sh](../bin/ami.sh) to figure out the latest version Amazon Linux 2. Later, the 
baking can be automated by Concourse - see example in [concourse/packer/pipeline.yml](packer/pipeline.yml).

### Required for HTTPS

Route53 hosted zone, domain and ACM certificate.

### Required for Vault backend

Concourse needs a token (which it automatically renews) on deployment. The token will
be used to read secrets from the `concourse/` secrets mount, but will restrict itself to
`concourse/<team>/<pipeline>` (first) and `concourse/<team>` (second).

First we mount a new secret backend:

```bash
vault mount -path=/concourse -description="Secrets for concourse pipelines" generic
```

`concourse-policy.hcl`:

```hcl
path "concourse/*" {
  policy = "read"
  capabilities =  ["read", "list"]
}
```

Then we write the policy (above) and privileges for concourse:

```bash
vault policy-write concourse-policy concourse-policy.hcl
```

Then we create a temporary token (which concourse renews automatically),
this token is passed along as a variable to our concourse deployment:

```bash
vault token-create --policy=concourse-policy -period="1h" -format=json -orphan
```

NOTE: We use `-orphan` so we can revoke the root token without revoking
concourses token in the process.

### Required for Github authentication 

Github Oauth application, with an encrypted password:

```bash
aws kms encrypt \
  --key-id <aws-kms-key-id> \
  --plaintext <github-client-secret> \
  --output text \
  --query CiphertextBlob \
  --profile default
```

## New teams

### Concourse

To create a new team in Concourse, an admin first logs into the `main` team:

```bash
fly --target admin login --team-name main --concourse-url https://ci.example.com
## Same command with short flags:
fly -t admin login -n main -c https://ci.example.com
```

Then we set up the new team:

```bash
fly -t admin set-team -n demo-team \
    --github-auth-client-id <client> \
    --github-auth-client-secret <secret> \
    --github-auth-team TeliaSoneraNorge/demo-team
```

And then we can log into the new team:

```bash
fly --target demo login --team-name demo-team --concourse-url https://ci.example.com
```

### Vault

The team now has access to create and manage pipelines in Concourse, but also need somewhere
to securely store their secrets. Concourse integrates with Vault, but we need to onboard our team.

First we create a policy (`policy.hcl`):

```hcl
path "concourse/demo-team/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
```

And then write it to Vault:

```bash
export VAULT_ADDR=https://vault.example.com
vault policy-write demo-policy policy.hcl
```

After we have written the policy, we specify who is allowed to use the role. This is done using 
the AWS Auth backend for Vault, which lets us restrict access on a per-role basis:

```bash
vault write auth/aws/role/demo auth_type=iam bound_iam_principal_arn=arn:aws:iam::<account-id>:role/demo-team-developer policies=demo-policy ttl=10m max_ttl=15m
```

The above basically states that anyone who can assume the `demo-team-developer` role should be allowed to
retrieve a token from Vault, which allows them to CRUD the `concourse/demo-team/*` path of Vault. To
authenticate to Vault, a user using vaulted (not to be confused with Vault) then simply runs:

```bash
vaulted -n demo-team-developer -- vault auth -method=aws role=demo
```

### Example

In addition to the deployment example, you'll also find a sample `pipeline.yml` for testing the installation.
It can be added to concourse by running:

```bash
fly -t ci-test login -n main -c <url>
fly -t ci-test set-pipeline -p ci-test -c pipeline.yml
fly -t ci-test unpause-pipeline -p ci-test
```
