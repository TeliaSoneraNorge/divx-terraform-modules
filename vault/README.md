## Vault

Module for Vault deployment on AWS. 

### Usage

```hcl
provider "aws" {
  profile = "default"
  region  = "eu-west-1"
}

module "vault" {
  source = "../../vault"

  prefix          = "my-project"
  vpc_id          = "vpc-12345678"
  subnet_ids      = ["subnet-12345678","subnet-23456789","subnet-34567890"]
  bastion_sg      = "sg-12345678"
  authorized_cidr = ["0.0.0.0/0"]
  instance_count  = "3"
  instance_key    = ""

  tags {
    environment = "dev"
    terraform   = "True"
  }
}

output "vault_addr" {
  value = "https://${module.vault.elb_dns}"
}
```

## Setup

With Vault in HA mode, we have to use a healthcheck which only reports healthy for the
leader and not the inactive nodes. This means that we can't init or unseal via the load balancer,
so we have to use SSH.

### Vault init

Vault init is only run once on any Vault node (note that we are setting VAULT_ADDR):

```bash
export VAULT_ADDR=http://localhost:8200
vault init \
  -pgp-keys=keybase:itsdalmo,<user2>,<user3> \
  -root-token-pgp-key=keybase:itsdalmo \
  -key-shares=3 \
  -key-threshold=2
```

### Vault unseal

After initializing, we need to unseal each node in turn. This is also done locally on the instance via
SSH:

```bash
export VAULT_ADDR=http://localhost:8200
vault unseal <decrypted-key>
```

At this point the instance will pass the health checks and be available from the outside, so
you can switch to your local machine and set up remote access:

```bash
export VAULT_ADDR=$(terraform output domain)
vault auth <decrypted-root-token>
```

### AWS auth setup

Instead of using tokens to authenticate users, we want use AWS roles to give users access to manage
their secrets. For example, by showing that I'm allowed to assume the `example-developer-role` I'm
allowed to manage secrets under `concourse/example/*`.

First we need to activate the AWS auth backend:

```bash
vault auth-enable aws
```

`example-policy.hcl`:

```hcl
path "concourse/example/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
```

We then write the policy (above) which should be granted to users that are authenticated:

```bash
vault policy-write example-policy example-policy.hcl
```

We are now ready to create a role which grants a temporary token with the above policy,
if users manage to authenticate themselves by assuming the specified role:

```bash
vault write auth/aws/role/example auth_type=iam bound_iam_principal_arn=arn:aws:iam::<account-id>:role/lab-admin-role policies=example-policy ttl=30s max_ttl=30m
```

After the above is set up, we can use vaulted to assume a role and then authenticate to Vault:

```bash
vaulted -n lab-admin -- vault auth -method=aws role=example
```

To check that we can read/write (remember that the token is only valid for 30s):

```bash
vault write concourse/example/test value=test
vault read concourse/example/test
```

We can also write values from a file:

```bash
cat secret.pem | vault write concourse/example/github_deploy_key value=-
```

#### Note

For roles deployed in a different account then Vault we also need to
give Vault a role in the remote account that it can assume to authenticate users:

```bash
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeInstances",
        "iam:GetInstanceProfile",
        "iam:GetUser",
        "iam:GetRole"
      ],
      "Resource": "*"
    }
  ]
}
```

The policy above must be attached to the role in the remote account, and the
root of the account where Vault is deployed must be a trusted entity (and Vaults
instance profile must be allowed to assume the remote role). When all this is done,
we have to instruct Vault to assume the role in question for a specific account id:

```bash
vault write /auth/aws/config/sts/<account-id> sts_role=<role-arn>
```

### Revoke root token

Once you have set up Vault, the root token should be revoked. A new one can be generated on
demand using the unseal keys - which ensures that any one person cannot make changes or retrieve
secrets that should not have access to.
