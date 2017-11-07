## Concourse CI

A Terraform module for deploying Concourse CI.

## Prerequisites

1. Route53 hosted zone, domain and ACM certificate.

2. Github Oauth application, with an encrypted password:

```bash
aws kms encrypt \
  --key-id <aws-kms-key-id> \
  --plaintext <github-client-secret> \
  --output text \
  --query CiphertextBlob \
  --profile default
```

3. You must generate the necessary keys for Concourse:

```bash
# Create folder
mkdir -p keys

ssh-keygen -t rsa -f ./keys/tsa_host_key -N ''
ssh-keygen -t rsa -f ./keys/worker_key -N ''
ssh-keygen -t rsa -f ./keys/session_signing_key -N ''

# Authorized workers
cp ./keys/worker_key.pub ./keys/authorized_worker_keys
```

4. Set up Vault for Concourse:

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
vault token-create --policy=concourse-policy -period="1h" -format=json
```

## Deploy

```hcl
provider "aws" {
  profile = "default"
  region  = "eu-west-1"
}

module "vpc" {
  source        = "github.com/itsdalmo/tf-modules//ec2/vpc"

  prefix        = "concourse-ci"
  cidr_block    = "10.0.0.0/16"
  dns_hostnames = "true"
  public_ips    = "true"

  tags {
    terraform   = "True"
    environment = "dev"
  }
}

module "bastion" {
  source      = "github.com/itsdalmo/tf-modules//bastion"

  prefix      = "concourse-ci"
  vpc_id      = "${module.vpc.vpc_id}"
  subnet_ids  = "${module.vpc.subnet_ids}"
  pem_bucket  = "your-key-bucket"
  pem_path    = "example-key.pem"

  authorized_keys = [
    "ssh-rsa <your-public-key>",
  ]

  authorized_cidr = [
    "0.0.0.0/0",
  ]

  tags {
    terraform   = "True"
    environment = "dev"
  }
}

module "concourse" {
  source = "github.com/itsdalmo/tf-modules//concourse/"

  prefix               = "concourse-ci"
  domain               = "ci.example.com"
  zone_id              = "<zone-id>"
  concourse_keys       = "${path.root}/keys"
  vpc_id               = "${module.vpc.vpc_id}"
  subnet_ids           = "${module.vpc.subnet_ids}"
  authorized_cidr      = ["0.0.0.0/0"]
  postgres_username    = "someuser"
  postgres_password    = "<kms-encrypted-password>"
  instance_key         = "<instance-key-pair>"
  github_client_id     = "<github-client-id>"
  github_client_secret = "<kms-encrypted-github-client-secret>"
  vault_url            = "https://vault.example.com"
  vault_client_token   = "<temporary-vault-token>"

  github_users = [
    "itsdalmo",
  ]

  tags {
    terraform   = "True"
    environment = "dev"
  }
}

# Open ATC and workers to Bastion SSH
resource "aws_security_group_rule" "bastion_ingress_atc" {
  security_group_id        = "${module.concourse.atc_sg}"
  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = "22"
  to_port                  = "22"
  source_security_group_id = "${module.bastion.security_group_id}"
}

resource "aws_security_group_rule" "bastion_ingress_worker" {
  security_group_id        = "${module.concourse.worker_sg}"
  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = "22"
  to_port                  = "22"
  source_security_group_id = "${module.bastion.security_group_id}"
}

# Allow workers to fetch ECR images
resource "aws_iam_role_policy" "main" {
  name   = "concourse-ci-worker-ecr-policy"
  role   = "${module.concourse.worker_role_id}"
  policy = "${data.aws_iam_policy_document.worker.json}"
}

data "aws_iam_policy_document" "worker" {
  statement {
    effect    = "Allow"
    actions = [
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:GetRepositoryPolicy",
      "ecr:DescribeRepositories",
      "ecr:ListImages",
      "ecr:DescribeImages",
      "ecr:BatchGetImage",
    ]
    resources = ["*"]
  }
}

output "endpoint" {
  value = "${module.concourse.endpoint}"
}
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

## Example

Install the `fly` cli and run the following:

```bash
fly -t example login -c https://ci.example.com
fly -t example set-pipeline -p hello-world -c ./example/hello_world.yml
fly -t example unpause-pipeline -p hello-world
```

Log on the concourse web front end and manually trigger the job afterward.
