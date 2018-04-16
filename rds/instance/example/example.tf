provider "aws" {
  region = "eu-west-1"
}

module "vpc" {
  source          = "../../../ec2/vpc"
  prefix          = "your-project"
  cidr_block      = "10.8.0.0/16"
  private_subnets = "2"
  dns_hostnames   = "true"

  tags {
    environment = "example"
    terraform   = "True"
  }
}

module "rds" {
  source        = "../../../rds/instance"
  multi_az      = "false"
  prefix        = "your-project"
  username      = "someuser"
  password      = "somepassword"
  port          = "5000"
  engine        = "postgres"
  instance_type = "db.t2.small"
  storage_size  = "5"
  vpc_id        = "${module.vpc.vpc_id}"
  subnet_ids    = "${module.vpc.private_subnet_ids}"

  tags {
    environment = "example"
    terraform   = "True"
  }
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
