## Bastion

Template for creating a bastion instance.

```hcl
provider "aws" {
  profile = "default"
  region  = "eu-west-1"
}

module "bastion" {
  source      = "github.com/itsdalmo/tf-modules//bastion"
  prefix      = "example"
  environment = "stage"
  pem_bucket  = "your-key-bucket"
  pem_path    = "example-key.pem"

  authorized_keys = [
    "ssh-rsa <your-public>",
  ]

  authorized_cidr = [
    "0.0.0.0/0",
  ]

  vpc_id = "vpc-f123456d"

  subnet_ids = [
    "subnet-12345678",
    "subnet-23456789",
    "subnet-34567890",
  ]
}

output "bastion_ip" {
  value = "${module.bastion.ip}"
}
```
