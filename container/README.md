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

// Create the external ALB (or NLB)
module "lb" {
  source = "github.com/itsdalmo/tf-modules//ec2/lb"

  prefix     = "${var.prefix}"
  type       = "application"
  internal   = "false"
  vpc_id     = "${var.vpc_id}"
  subnet_ids = ["${var.subnets}"]

  tags {
    terraform   = "True"
    environment = "dev"
  }
}

// Create cluster and open ingress from the LB on the dynamic port range.
module "cluster" {
  source = "github.com/itsdalmo/tf-modules//container/cluster"

  prefix           = "${var.prefix}"
  vpc_id           = "${var.vpc_id}"
  subnet_ids       = ["${var.subnets}"]
  ingress_length   = 1

  ingress {
    "0" = "${module.lb.security_group_id}"
  }

  tags {
    terraform   = "True"
    environment = "dev"
  }
}

// Create a target group with listeners.
module "target" {
  source = "github.com/itsdalmo/tf-modules//container/target"

  prefix            = "${var.prefix}"
  vpc_id            = "${var.vpc_id}"
  load_balancer_arn = "${module.lb.arn}"

  target {
    protocol        = "HTTP"
    port            = "8000"
    health          = "HTTP:traffic-port/"
  }

  listeners = [{
    protocol = "HTTP"
    port     = "80"
  }]

  tags {
    terraform   = "True"
    environment = "dev"
  }
}

// Create a task definition for the service.
// NOTE: HostPort must be 0 to use dynamic port mapping.
resource "aws_cloudwatch_log_group" "main" {
  name = "${var.prefix}"
}

resource "aws_ecs_task_definition" "main" {
  family = "${var.prefix}"

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

// Finally, create the service with the given task definition and target group.
module "service" {
  source = "github.com/itsdalmo/tf-modules//container/service"

  prefix             = "${var.prefix}"
  cluster_id         = "${module.cluster.id}"
  cluster_role       = "${module.cluster.role_id}"
  task_definition    = "${aws_ecs_task_definition.main.arn}"
  task_log_group_arn = "${aws_cloudwatch_log_group.main.arn}"
  container_count    = "2"

  load_balancer {
    target_group_arn = "${module.target.target_group_arn}"
    container_name   = "${var.prefix}"
    container_port   = "${module.target.container_port}"
  }

  tags {
    terraform   = "True"
    environment = "dev"
  }
}

// SG rules for ingress to the LB is created manually.
resource "aws_security_group_rule" "ingress_80" {
  security_group_id = "${module.lb.security_group_id}"
  type              = "ingress"
  protocol          = "tcp"
  from_port         = "80"
  to_port           = "80"
  cidr_blocks       = ["0.0.0.0/0"]
}
```
