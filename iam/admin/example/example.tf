provider "aws" {
  region = "eu-west-1"
}

module "admin" {
  source          = "github.com/TeliaSoneraNorge/divx-terraform-modules//iam/admin"
  prefix          = "account-name"
  trusted_account = "<user-account>"

  users = [
    "first.last",
  ]
}

output "arn" {
  value = "${module.admin.arn}"
}

output "url" {
  value = "${module.admin.url}"
}
