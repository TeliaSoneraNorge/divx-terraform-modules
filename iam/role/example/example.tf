provider "aws" {
  region = "eu-west-1"
}

module "developer" {
  source          = "github.com/TeliaSoneraNorge/divx-terraform-modules//iam/role"
  prefix          = "example-project-developer"
  trusted_account = "<user-account>"

  users = [
    "first.last",
  ]
}

resource "aws_iam_role_policy_attachment" "view_only_policy" {
  role       = "${module.developer.name}"
  policy_arn = "arn:aws:iam::aws:policy/job-function/ViewOnlyAccess"
}

output "url" {
  value = "${module.developer.url}"
}
