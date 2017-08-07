## iam/admin\_role

Quick way of setting up an admin role which can be assumed between accounts. Done once when setting
up the account, which is then managed from a central 'management' account. 

```hcl
provider "aws" {
  profile = "default"
  region  = "eu-west-1"
}

module "admin" {
  source     = "github.com/itsdalmo/tf-modules//iam/admin_role"
  prefix     = "account-name"
  account_id = "123456789101"
}

output "arn" {
  value = "${module.admin.role_arn}"
}
output "url" {
  value = "${module.admin.role_url}"
}
```
