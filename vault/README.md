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
  environment     = "dev"
  vpc_id          = "vpc-12345678"
  subnet_ids      = ["subnet-12345678","subnet-23456789","subnet-34567890"]
  bastion_sg      = "sg-12345678"
  authorized_cidr = ["0.0.0.0/0"]
  instance_key    = ""
}

output "vault_addr" {
  value = "https://${module.vault.elb_dns}"
}
```

### Manual steps

In order to get Vault up and running we also need to `init` and `unseal` the vault. This can be
done from your local machine.

```bash
export VAULT_ADDR=$(terraform output vault_addr)
vault init \
  -pgp-keys=keybase:itsdalmo \
  -root-token-pgp-key=keybase:itsdalmo \
  -key-shares=1 \
  -key-threshold=1

vault unseal <decrypted-unseal-keys>
vault auth <decrypted-root-token>
```
