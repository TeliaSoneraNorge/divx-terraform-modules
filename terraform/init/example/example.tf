provider "aws" {
  region = "eu-west-1"
}

module "terraform_init" {
  source      = "github.com/TeliaSoneraNorge/divx-terraform-modules//terraform/init"
  prefix      = "example-staging"
  environment = "stage"
}

output "state_bucket" {
  value = "${module.terraform_init.state_bucket}"
}

output "lock_table" {
  value = "${module.terraform_init.lock_table}"
}

output "encryption_key" {
  value = "${module.terraform_init.kms_key_arn}"
}
