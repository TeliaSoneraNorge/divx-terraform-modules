## iam/developer

An opinionated way of setting up developer roles for projects:

- `ViewOnlyAccess` (attached from the role module).
- Safe with liberal IAM privileges, as the role explicitly denies all IAM actions on the role itself.

```hcl
provider "aws" {
  profile = "default"
  region  = "eu-west-1"

  assume_role {
    role_arn = "arn:aws:iam::<dev-account>:role/admin-role"
  }
}

module "developer" {
  source          = "github.com/itsdalmo/tf-modules//iam/developer"
  prefix          = "your-project"
  trusted_account = "<user-account>"
  
  users = [
    "first.last"
  ]
}

output "arn" {
  value = "${module.developer.arn}"
}

output "url" {
  value = "${module.developer.url}"
}
```

Use [iam/policy](../policy/README.md) to attach additional privileges to the role:

```hcl
provider "aws" {
  profile = "default"
  region  = "eu-west-1"

  assume_role {
    role_arn = "arn:aws:iam::<dev-account>:role/admin-role"
  }
}

data "aws_caller_identity" "current" {}

module "developer" {
  source          = "github.com/itsdalmo/tf-modules//iam/developer"
  prefix          = "example-project"
  trusted_account = "<user-account>"

  users = [
    "first.last",
  ]
}

module "s3_access" {
  source = "github.com/itsdalmo/tf-modules//iam/policy/s3"

  prefix        = "example-project"
  region        = "eu-west-1"
  account_id    = "${data.aws_caller_identity.current.account_id}"
  iam_role_name = "${module.developer.name}"
}

module "cloudformation_access" {
  source = "github.com/itsdalmo/tf-modules//iam/policy/cloudformation"

  prefix        = "example-project"
  region        = "eu-west-1"
  account_id    = "${data.aws_caller_identity.current.account_id}"
  iam_role_name = "${module.developer.name}"
}

module "codedeploy_access" {
  source = "github.com/itsdalmo/tf-modules//iam/policy/codedeploy"

  prefix        = "example-project"
  region        = "eu-west-1"
  account_id    = "${data.aws_caller_identity.current.account_id}"
  iam_role_name = "${module.developer.name}"
}

module "ec2_access" {
  source = "github.com/itsdalmo/tf-modules//iam/policy/ec2"

  prefix        = "example-project"
  region        = "eu-west-1"
  account_id    = "${data.aws_caller_identity.current.account_id}"
  iam_role_name = "${module.developer.name}"
}

module "iam_access" {
  source = "github.com/itsdalmo/tf-modules//iam/policy/iam"

  prefix        = "example-project"
  account_id    = "${data.aws_caller_identity.current.account_id}"
  iam_role_name = "${module.developer.name}"
}

module "kinesis_access" {
  source = "github.com/itsdalmo/tf-modules//iam/policy/kinesis"

  prefix        = "example-project"
  region        = "eu-west-1"
  account_id    = "${data.aws_caller_identity.current.account_id}"
  iam_role_name = "${module.developer.name}"
}

module "lambda_access" {
  source = "github.com/itsdalmo/tf-modules//iam/policy/lambda"

  prefix        = "example-project"
  region        = "eu-west-1"
  account_id    = "${data.aws_caller_identity.current.account_id}"
  iam_role_name = "${module.developer.name}"
}

module "apigateway_access" {
  source = "github.com/itsdalmo/tf-modules//iam/policy/apigateway"

  prefix        = "example-project"
  region        = "eu-west-1"
  api_id        = "<your-api-gateway-rest-api-id>"
  iam_role_name = "${module.developer.name}"
}

output "arn" {
  value = "${module.developer.arn}"
}

output "url" {
  value = "${module.developer.url}"
}
```
