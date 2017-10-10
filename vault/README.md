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

### Manual steps

In order to get Vault up and running we also need to `init` and `unseal` the vault. This
has to be done by SSH'ing to the instance and running the following commands:

```bash
vault init \
  -pgp-keys=keybase:itsdalmo \
  -root-token-pgp-key=keybase:itsdalmo \
  -key-shares=1 \
  -key-threshold=1

vault unseal <decrypted-unseal-keys>
```

At this point the instance will pass the health checks and be available from the outside, so
you can switch to your local machine and set up remote access:

```bash
export VAULT_ADDR=$(terraform output domain)
vault auth <decrypted-root-token>
```

### Concourse

`policy.hcl`:

```hcl
path "concourse/*" {
  policy = "read"
  capabilities =  ["read", "list"]
}
```

```bash
vault mount -path=/concourse -description="Secrets for concourse pipelines" generic
vault policy-write policy-concourse policy.hcl
vault token-create --policy=policy-concourse -period="600h" -format=json

# Write some value
vault write concourse/main/repository value=ubuntu
vault read -field=value concourse/main/repository

# Write value from file
cat secret.pem | vault write concourse/main/github_deploy_key value=-
vault read -field=value concourse/main/github_deploy_key
```
