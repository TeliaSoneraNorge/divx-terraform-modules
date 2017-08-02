## iam\_developer\_role

An opinionated way of setting up developer roles for projects:

- Allows users in another (management) account to assume the role.
- Grants `ViewOnlyAccess` by default.
- Explicit Deny for all IAM actions on the role itself.

Use [iam\_developer\_policies](../iam_developer_policies/readme.md) to attach
additional (project specific) privileges to the role after creation.

```hcl
provider "aws" {
  profile = "default"
  region  = "eu-west-1"
}

module "developer" {
  source     = "github.com/itsdalmo/tf-modules//iam_developer_role"

  prefix     = "example-project"
  account_id = "123456789101"

  users = [
    "user.name",
    "first.last",
    "ola.nordmann",
  ]
}

module "s3_access" {
  source      = "github.com/itsdalmo/tf-modules//iam_policies/s3"

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
