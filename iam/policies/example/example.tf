provider "aws" {
  region = "eu-west-1"
}

variable "prefix" {
  default = "example-project"
}

data "aws_caller_identity" "current" {}

module "developer" {
  source          = "github.com/TeliaSoneraNorge/divx-terraform-modules//iam/developer"
  prefix          = "${var.prefix}"
  trusted_account = "<user-account>"

  users = [
    "first.last",
  ]
}

module "policies" {
  source        = "github.com/TeliaSoneraNorge/divx-terraform-modules//iam/policies"
  prefix        = "${var.prefix}"
  region        = "eu-west-1"
  account_id    = "${data.aws_caller_identity.current.account_id}"
  iam_role_name = "${var.prefix}-developer-role"

  services = [
    "autoscaling",
    "cloudformation",
    "cloudwatch",
    "codedeploy",
    "dynamodb",
    "ec2",
    "ecs",
    "elasticsearch",
    "emr",
    "iam",
    "kinesis",
    "lambda",
    "s3",
    "sns",
    "sqs",
  ]
}

module "terraform_state_policy" {
  source        = "github.com/TeliaSoneraNorge/divx-terraform-modules//terraform/policy"
  prefix        = "${var.prefix}"
  state_bucket  = "some-state-bucket"
  region        = "eu-west-1"
  account_id    = "${data.aws_caller_identity.current.account_id}"
  iam_role_name = "${var.prefix}-developer-role"
}

output "arn" {
  value = "${module.developer.arn}"
}

output "url" {
  value = "${module.developer.url}"
}
