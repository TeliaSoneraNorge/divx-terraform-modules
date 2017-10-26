## iam/role

Module for creating an IAM role with a trusted relationship to users in a trusted account, 
which can be used to grant cross-account access to roles: 

- By default, the role grants `ViewOnlyAccess` access.
- `sts:AssumeRole` is granted to individual users in the trusted account.

Granting access to the role on a per-user basis ensures that the `user-account` is only responsible
for authentication, while the `dev-account` (where the role is created) is responsible for authorization.

```hcl
provider "aws" {
  profile = "default"
  region  = "eu-west-1"
  assume_role {
    role_arn = "arn:aws:iam::<dev-account>:role/admin-role"
  }
}

module "developer" {
  source          = "github.com/TeliaSoneraNorge/divx-terraform-modules//iam/role"
  prefix          = "example-project-developer"
  trusted_account = "<user-account>"

  users = [
    "first.last"
  ]
}

resource "aws_iam_role_policy_attachment" "view_only_policy" {
  role       = "${module.developer.name}"
  policy_arn = "arn:aws:iam::aws:policy/job-function/ViewOnlyAccess"
}

output "url" {
  value = "${module.developer.url}"
}
```

Users will still have to be given a policy on the `user-account` which
grants them access to assume roles in remote accounts (the `dev-account`).
The [iam/user](../user/README.md) module solves this by attaching an inline
policy to all users, giving them privileges to assume any role in remote 
accounts.

