## iam/admin

Quick way of setting up an admin role which can be assumed between accounts. 

- `ViewOnlyAccess` (attached from the role module).
- `AdministratorAccess` (managed policy).

```hcl
provider "aws" {
  profile = "admin-user"
  region  = "eu-west-1"
}

module "admin" {
  source          = "github.com/TeliaSoneraNorge/divx-terraform-modules//iam/admin"
  prefix          = "account-name"
  trusted_account = "<user-account>"

  users = [
    "first.last"
  ]
}

output "arn" {
  value = "${module.admin.arn}"
}

output "url" {
  value = "${module.admin.url}"
}
```

See [iam/role](../role/README.md) for more information.
