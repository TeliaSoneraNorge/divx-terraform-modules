provider "aws" {
  region = "eu-west-1"
}

module "vpc" {
  source          = "github.com/TeliaSoneraNorge/divx-terraform-modules//ec2/vpc"
  prefix          = "your-project"
  cidr_block      = "10.8.0.0/16"
  private_subnets = "2"
  dns_hostnames   = "true"

  tags {
    environment = "prod"
    terraform   = "True"
  }
}

output "vpc_id" {
  value = "${module.vpc.vpc_id}"
}

output "subnet_ids" {
  value = "${module.vpc.public_subnet_ids}"
}
