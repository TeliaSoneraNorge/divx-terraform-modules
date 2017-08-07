## terraform/init

A template for setting up a state bucket and lock table on AWS. These
resources should never be deleted, so storing the state for this 
deployment is not necessary.

```hcl
provider "aws" {
  profile = "default"
  region  = "eu-west-1"
}

module "terraform_init" {
  source      = "github.com/itsdalmo/tf-modules//terraform/init"
  prefix      = "example-staging"
  environment = "stage"
}

output "state_bucket" {
  value = "${module.terraform_init.state_bucket}"
}

output "lock_table" {
  value = "${module.terraform_init.lock_table}"
}

output "encryption_key" {
  value = "${module.terraform_init.kms_key_arn}"
}
```
