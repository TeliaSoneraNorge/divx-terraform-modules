## ec2/vpc

This is a module which simplifies setting up a new VPC and getting it into a useful state with a basic
internet gateway/route table and one subnet per AZ in your chosen region. 

```hcl
provider "aws" {
  profile = "default"
  region  = "eu-west-1"
}

module "vpc" {
  source        = "github.com/itsdalmo/tf-modules//ec2/vpc"
  prefix        = "your-project"
  environment   = "dev"
  cidr_block    = "10.8.0.0/16"
  dns_hostnames = "true"
}

output "vpc_id" {
  value = "${module.vpc.vpc_id}"
}

output "subnet_ids" {
  value = "${module.vpc.subnet_ids}"
}
```
