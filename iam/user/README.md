## iam\_user

```hcl
provider "aws" {
  profile = "default"
  region  = "eu-west-1"
}

module "firstname_lastname" {
  source   = "github.com/TeliaSoneraNorge/divx-terraform-modules//iam/user"

  username = "firstname.lastname"
  keybase  = "itsdalmo"
}

output "firstname_lastname" {
  value = "${module.user.instructions}"
}
```
