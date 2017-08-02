## iam\_developer\_role

Opinionated way for setting up developer roles for projects, which allows one to grant users registered in another
account access to assume the role. The basic role includes the managed `ViewOnlyAccess` policy, and further privileges
should be restricted to the project using the [iam\_policies](../iam_policies/readme.md) module. In addition,
we attach a policy which restricts users from making changes to the role itself (irrespective of other IAM policies).

```hcl
provider "aws" {
  profile = "default"
  region  = "eu-west-1"
}

module "developer" {
  source = "../iam_developer_role"

  #source     = "github.com/itsdalmo/tf-modules//iam_developer_role"
  prefix     = "example-project"
  account_id = "123456789101"

  users = [
    "user.name",
    "first.last",
    "ola.nordmann",
  ]
}

module "s3_access" {
  source = "../iam_policies/s3"

  #source        = "github.com/itsdalmo/tf-modules//iam_policies/s3"
  prefix      = "example-project"
  region      = "eu-west-1"
  account_id  = "123456789101"
  iam_role_id = "${module.developer.role_name}"
}

output "arn" {
  value = "${module.developer.role_arn}"
}

output "url" {
  value = "${module.developer.role_url}"
}
```
