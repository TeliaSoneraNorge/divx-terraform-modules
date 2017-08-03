## iam\_developer\_role

An opinionated way of setting up developer roles for projects:

- Allows users in another (management) account to assume the role.
- Grants `ViewOnlyAccess` by default.
- Explicit Deny for all IAM actions on the role itself.

Use [iam\_developer\_policies](../iam_developer_policies/README.md) to attach
additional (project specific) privileges to the role after creation.

```hcl
provider "aws" {
  profile = "default"
  region  = "eu-west-1"
}

data "aws_caller_identity" "current" {}

module "developer" {
  source = "github.com/itsdalmo/tf-modules//iam_developer_role"

  prefix          = "example-project"
  user_account_id = "123456789101"

  users = [
    "user.name",
    "first.last",
    "ola.nordmann",
  ]
}

module "s3_access" {
  source = "github.com/itsdalmo/tf-modules//iam_developer_policies/s3"

  prefix        = "example-project"
  region        = "eu-west-1"
  account_id    = "${data.aws_caller_identity.current.account_id}"
  iam_role_name = "${module.developer.role_name}"
}

module "cloudformation_access" {
  source = "github.com/itsdalmo/tf-modules//iam_developer_policies/cloudformation"

  prefix        = "example-project"
  region        = "eu-west-1"
  account_id    = "${data.aws_caller_identity.current.account_id}"
  iam_role_name = "${module.developer.role_name}"
}

module "codedeploy_access" {
  source = "github.com/itsdalmo/tf-modules//iam_developer_policies/codedeploy"

  prefix        = "example-project"
  region        = "eu-west-1"
  account_id    = "${data.aws_caller_identity.current.account_id}"
  iam_role_name = "${module.developer.role_name}"
}

module "ec2_access" {
  source = "github.com/itsdalmo/tf-modules//iam_developer_policies/ec2"

  prefix        = "example-project"
  region        = "eu-west-1"
  account_id    = "${data.aws_caller_identity.current.account_id}"
  iam_role_name = "${module.developer.role_name}"
}

module "iam_access" {
  source = "github.com/itsdalmo/tf-modules//iam_developer_policies/iam"

  prefix        = "example-project"
  account_id    = "${data.aws_caller_identity.current.account_id}"
  iam_role_name = "${module.developer.role_name}"
}

module "kinesis_access" {
  source = "github.com/itsdalmo/tf-modules//iam_developer_policies/kinesis"

  prefix        = "example-project"
  region        = "eu-west-1"
  account_id    = "${data.aws_caller_identity.current.account_id}"
  iam_role_name = "${module.developer.role_name}"
}

output "arn" {
  value = "${module.developer.role_arn}"
}

output "url" {
  value = "${module.developer.role_url}"
}
```
