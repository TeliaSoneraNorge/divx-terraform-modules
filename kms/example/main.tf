provider "aws" {
  region = "eu-west-1"
}

module "kms-key" {
  source = "../"

  prefix      = "${var.prefix}"
  description = "example key"
  tags        = "${var.tags}"
}
