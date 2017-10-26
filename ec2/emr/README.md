## ec2/emr

WIP: Module to make it easier to provision an EMR cluster for ad-hoc analysis.

```hcl
provider "aws" {
  region  = "eu-west-1"
  profile = "default"
}

module "cluster" {
  source = "github.com/TeliaSoneraNorge/divx-terraform-modules//ec2/emr"

  prefix          = "my-project"
  vpc_id          = "vpc-12345678"
  subnet_id       = "subnet-f1234567"
  applications    = ["Spark"]

  tags {
    environment = "prod"
    terraform   = "True"
  }
}
```
