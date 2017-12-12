provider "aws" {
  region = "eu-west-1"
}

module "vpc" {
  source = "github.com/TeliaSoneraNorge/divx-terraform-modules//ec2/vpc"

  prefix          = "vault"
  cidr_block      = "10.0.0.0/16"
  dns_hostnames   = "true"
  private_subnets = "3"

  tags {
    terraform   = "True"
    environment = "dev"
  }
}

module "bastion" {
  source = "github.com/TeliaSoneraNorge/divx-terraform-modules//bastion"

  prefix     = "vault"
  vpc_id     = "${module.vpc.vpc_id}"
  subnet_ids = "${module.vpc.public_subnet_ids}"
  pem_bucket = "your-key-bucket"
  pem_path   = "example-key.pem"

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

module "vault" {
  source = "github.com/TeliaSoneraNorge/divx-terraform-modules//vault"

  prefix             = "vault"
  domain             = "vault.example.com"
  zone_id            = "<zone-id>"
  certificate_arn    = "arn:aws:acm:eu-west-1:123456789101:certificate/e234a5c6-43e4-4532-9f24-f318dcae78e5"
  vpc_id             = "${module.vpc.vpc_id}"
  public_subnet_ids  = "${module.vpc.public_subnet_ids}"
  private_subnet_ids = "${module.vpc.private_subnet_ids}"
  authorized_cidr    = ["0.0.0.0/0"]
  instance_count     = "2"
  instance_key       = "vault"

  tags {
    terraform   = "True"
    environment = "prod"
  }
}

resource "aws_security_group_rule" "bastion_ingress_vault" {
  security_group_id        = "${module.vault.vault_sg}"
  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = "22"
  to_port                  = "22"
  source_security_group_id = "${module.bastion.security_group_id}"
}

output "vault_addr" {
  value = "https://vault.example.com"
}
