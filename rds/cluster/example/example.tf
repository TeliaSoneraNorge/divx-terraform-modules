provider "aws" {
  region = "eu-west-1"
}

module "vpc" {
  source        = "github.com/TeliaSoneraNorge/divx-terraform-modules//ec2/vpc"
  prefix        = "your-project"
  cidr_block    = "10.8.0.0/16"
  dns_hostnames = "true"

  tags {
    environment = "prod"
    terraform   = "True"
  }
}

module "rds" {
  source = "github.com/TeliaSoneraNorge/divx-terraform-modules//rds/cluster"

  prefix     = "your-project"
  username   = "someuser"
  password   = "<kms-encrypted-password>"
  port       = "5000"
  vpc_id     = "${module.vpc.vpc_id}"
  subnet_ids = "${module.vpc.private_subnet_ids}"

  tags {
    environment = "prod"
    terraform   = "True"
  }
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

output "endpoint" {
  value = "${module.rds.endpoint}"
}

output "port" {
  value = "${module.rds.port}"
}
