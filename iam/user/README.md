## iam\_user

```hcl
provider "aws" {
  profile = "default"
  region  = "eu-west-1"
}

module "user" {
  source   = "github.com/itsdalmo/tf-modules//iam/user"

  username = "firstname.lastname"
  keybase  = "itsdalmo"
}

output "info" {
  value = "${module.user.info}"
}
```
