provider "aws" {
  region = "eu-west-1"
}

module "bastion" {
  source     = "github.com/TeliaSoneraNorge/divx-terraform-modules//bastion"
  prefix     = "example"
  pem_bucket = "your-key-bucket"
  pem_path   = "example-key.pem"

  authorized_keys = [
    "ssh-rsa <your-public-key>",
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

  tags {
    environment = "dev"
    terraform   = "True"
  }
}

output "bastion_ip" {
  value = "${module.bastion.ip}"
}
