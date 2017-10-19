## Container

Set up an ECS cluster and register services with ease. The modules set up the following:

#### container/cluster

- Autoscaling group/launch configuration.
- CoreOS instances with ECS agent running.
- A security group for the cluster (with all egress and ingress from the specified load balancers).
- CloudWatch log group.
- IAM role/instance profile with appropriate privileges.

#### container/service

- Can be used with or without a load balancer.
- Usable with either an ALB or a NLB.
- Creates target group and listeners when used with a load balancer (for dynamic port mapping).
- Sets up and enables logging for the service.
- Creates IAM roles for the ECS service.

Note that task definitions have to be created manually (cannot be abstracted) because of `volume` blocks.

## Usage

```hcl
variable "prefix" {
  default = "ecs-test"
}

variable "vpc_id" {
  default = "vpc-12345678"
}

variable "subnets" {
  default = ["subnet-12345678", "subnet-23456789"]
}

provider "aws" {
  profile = "default"
  region  = "eu-west-1"
}

data "aws_region" "current" {
  current = "true"
}

// NLB w/ingress and listener rule
module "lb" {
  source = "github.com/itsdalmo/tf-modules//ec2/lb"

  prefix     = "${var.prefix}"
  type       = "network"
  internal   = "false"
  vpc_id     = "${var.vpc_id}"
  subnet_ids = ["${var.subnets}"]

  tags {
    terraform   = "True"
    environment = "dev"
  }
}

resource "aws_security_group_rule" "ingress_80" {
  security_group_id = "${module.lb.security_group_id}"
  type              = "ingress"
  protocol          = "tcp"
  from_port         = "80"
  to_port           = "80"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "ingress_8000" {
  security_group_id = "${module.lb.security_group_id}"
  type              = "ingress"
  protocol          = "tcp"
  from_port         = "8000"
  to_port           = "8000"
  cidr_blocks       = ["0.0.0.0/0"]
}

// Cluster which allows ingress from the NLB
module "cluster" {
  source = "github.com/itsdalmo/tf-modules//container/cluster"

  prefix           = "${var.prefix}"
  vpc_id           = "${var.vpc_id}"
  subnet_ids       = ["${var.subnets}"]
  load_balancer_sg = ["${module.lb.security_group_id}"]

  tags {
    terraform   = "True"
    environment = "dev"
  }
}

// Service w/dynamic port mapping and two tcp listeners (port 80 and 8000)
module "service" {
  source = "github.com/itsdalmo/tf-modules//container/service"

  prefix             = "${var.prefix}"
  vpc_id             = "${var.vpc_id}"
  cluster_id         = "${module.cluster.id}"
  cluster_role       = "${module.cluster.role_id}"
  load_balancer_arn  = "${module.lb.arn}"
  load_balancer_name = "${module.lb.name}"
  task_definition    = "${aws_ecs_task_definition.main.arn}"
  task_log_group_arn = "${aws_cloudwatch_log_group.main.arn}"
  container_count    = "2"

  target {
    port     = "8000"
    protocol = "TCP"
  }

  listeners {
    tcp  = "80,8000"
  }

  tags {
    terraform   = "True"
    environment = "dev"
  }
}

// Task definition for the service
resource "aws_cloudwatch_log_group" "main" {
  name = "${var.prefix}"
}

resource "aws_ecs_task_definition" "main" {
  family = "${var.prefix}"

  // NOTE: HostPort has to be 0 when using a target group.
  container_definitions = <<EOF
[{
    "name": "${var.prefix}",
    "image": "crccheck/hello-world:latest",
    "cpu": 256,
    "memory": 512,
    "essential": true,
    "portMappings": [{
      "HostPort": 0,
      "ContainerPort": 8000
    }],
    "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
            "awslogs-group": "${aws_cloudwatch_log_group.main.name}",
            "awslogs-region": "${data.aws_region.current.name}"
        }
    }
}]
EOF
}
```
