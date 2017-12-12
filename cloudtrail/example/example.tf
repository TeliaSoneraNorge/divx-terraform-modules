provider "aws" {
  region = "eu-west-1"
}

module "cloudtrail" {
  source = "github.com/TeliaSoneraNorge/divx-terraform-modules//cloudtrail"

  prefix         = "company-cloudtrail"
  read_capacity  = "30"
  write_capacity = "30"

  source_accounts = [
    "<jump-account-id>",
    "<dev-account-id>",
  ]

  tags {
    environment = "prod"
    terraform   = "True"
  }
}

resource "aws_cloudtrail" "users" {
  name                          = "jump-user-assume-role-trail"
  s3_bucket_name                = "${module.cloudtrail.bucket_name}"
  include_global_service_events = "true"
  is_multi_region_trail         = "true"
  enable_logging                = "true"

  tags {
    environment = "prod"
    terraform   = "True"
  }
}
