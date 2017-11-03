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
  source          = "github.com/TeliaSoneraNorge/divx-terraform-modules//iam/developer"
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

Use [iam/policies](../policies/README.md) to attach additional privileges to the role. The
below example would grant the role access to manage `ec2`, `ecs` and `iam` resources that have
the prefix (`example-project-*`) in their name (and write to the terraform state bucket under 
`/example-project/*`).

```hcl
provider "aws" {
  profile = "default"
  region  = "eu-west-1"

  assume_role {
    role_arn = "arn:aws:iam::<dev-account>:role/admin-role"
  }
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
    "ec2",
    "ecs",
    "iam",
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
```
