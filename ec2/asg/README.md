## ec2/asg

Easy way of setting up an autoscaling group, which also takes care of creating:

- Launch configuration.
- Security group (including public egress).
- IAM role with instance profile.

```hcl
provider "aws" {
  profile = "default"
  region  = "eu-west-1"
}

module "vpc" {
  source        = "github.com/TeliaSoneraNorge/divx-terraform-modules//ec2/vpc"
  prefix        = "your-project"
  cidr_block    = "10.8.0.0/16"
  dns_hostnames = "true"

  tags {
    environment = "prod"
    terraform   = "True"
  }
}

module "asg" {
  source        = "github.com/TeliaSoneraNorge/divx-terraform-modules//ec2/asg"
  prefix          = "your-project"
  user_data       = "#!bin/bash\necho hello world"
  vpc_id          = "${module.vpc.vpc_id}"
  subnet_ids      = "${module.vpc.subnet_ids}"
  instance_policy = "${data.aws_iam_policy_document.permissions.json}"

  tags {
    environment = "prod"
    terraform   = "True"
  }
}

resource "aws_security_group_rule" "ingress" {
  security_group_id = "${module.asg.security_group_id}"
  type              = "ingress"
  protocol          = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_blocks       = ["0.0.0.0/0"]
}

data "aws_iam_policy_document" "permissions" {
  statement {
    effect = "Allow"

    actions = [
      "ec2:AssociateAddress",
    ]

    resources = ["*"]
  }
}

output "vpc_id" {
  value = "${module.vpc.vpc_id}"
}

output "subnet_ids" {
  value = "${module.vpc.subnet_ids}"
}

output "security_group_id" {
  value = "${module.asg.security_group_id}"
}

output "role_arn" {
  value = "${module.asg.role_arn}"
}
```
