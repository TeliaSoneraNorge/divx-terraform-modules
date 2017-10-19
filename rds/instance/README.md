## rds

Module for creating an RDS database instance in a VPC, with a subnet group and
security group with public egress.

```hcl
provider "aws" {
  profile = "default"
  region  = "eu-west-1"
}

module "vpc" {
  source        = "github.com/itsdalmo/tf-modules//ec2/vpc"
  prefix        = "your-project"
  environment   = "dev"
  cidr_block    = "10.8.0.0/16"
  dns_hostnames = "true"
}

module "rds" {
  source        = "github.com/itsdalmo/tf-modules//rds/instance"

  prefix        = "your-project"
  username      = "someuser"
  password      = "<kms-encrypted-password>"
  port          = "5000"
  engine        = "postgres"
  instance_type = "db.m3.medium"
  storage_size  = "50"
  vpc_id        = "${module.vpc.vpc_id}"
  subnet_ids    = "${module.vpc.subnet_ids}"
}

resource "aws_security_group_rule" "bastion_ingress" {
  security_group_id        = "${module.rds.security_group_id}"
  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = "${module.rds.port}"
  to_port                  = "${module.rds.port}"
  source_security_group_id = "<bastion-sg-id>"
}

output "security_group_id" {
  value = "${module.rds.security_group_id}"
}

output "address" {
  value = "${module.rds.address}"
}

output "port" {
  value = "${module.rds.port}"
}
```

## source_security_group_id
Need an valid id, or 0.0.0.0./0 - allow from anywhere.
## Create KMS_KEY_ID

https://console.aws.amazon.com/iam/home?region=eu-west-1#/encryptionKeys/eu-west-1

Take note of the Id, and the Availabillity Zone

## Create <kms-encrypted-password>

``` 
aws kms encrypt \
  --key-id <KMS_KEY_ID> \
  --plaintext WowSuchTest123 \
  --output text \
  --query CiphertextBlob \
  --profile <your aws profile>
```
