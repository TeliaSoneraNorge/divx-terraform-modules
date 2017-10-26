## ec2/vpc

This is a module which simplifies setting up a new VPC and getting it into a useful state:

- Creates one public subnet per availability zone (with a shared route table and internet gateway).
- Creates the desired number of private subnets (with one NAT gateway and route table per subnet).
- Evenly splits the specified CIDR block between public/private subnets.

Note that each private subnet has a route table which targets an individual NAT gateway when accessing
the internet, which means that instances in a given private subnet will have a static IP.

```hcl
provider "aws" {
  profile = "default"
  region  = "eu-west-1"
}

module "vpc" {
  source          = "github.com/TeliaSoneraNorge/divx-terraform-modules//ec2/vpc"
  prefix          = "your-project"
  cidr_block      = "10.8.0.0/16"
  private_subnets = "2"
  dns_hostnames = "true"

  tags {
    environment = "prod"
    terraform   = "True"
  }
}

output "vpc_id" {
  value = "${module.vpc.vpc_id}"
}

output "subnet_ids" {
  value = "${module.vpc.subnet_ids}"
}
```
