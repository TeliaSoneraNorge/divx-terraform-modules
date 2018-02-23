provider "aws" {
  region = "eu-west-1"
}

module "developer" {
  source           = "github.com/TeliaSoneraNorge/divx-terraform-modules//iam/role"
  prefix           = "example-project-developer"
  trusted_account  = "<user-account>"
  role_description = "example role created to show iam/role module in use"

  users = [
    "first.last",
  ]
}

resource "aws_iam_role_policy_attachment" "power_user_policy" {
  role       = "${module.developer.name}"
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}

output "url" {
  value = "${module.developer.url}"
}
