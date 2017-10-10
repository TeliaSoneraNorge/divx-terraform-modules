## Container

Set up an ECS cluster and register services with ease. The modules set up the following:

#### container/cluster

- Autoscaling group/launch configuration.
- CoreOS instances with ECS agent running.
- A security group for the cluster (with all egress).
- CloudWatch log group.
- IAM role/instance profile with appropriate privileges.

#### container/service

- Usable with either an ALB or a classic ELB (to be tested).
- Optional: Creates the ALB target group (when used with an ALB).
- Sets up and enables logging for the service.
- Creates IAM roles for the ECS service.
- Takes care of opening ingress on the appropriate ports from the load balancer (ALB or classic ELB) to the cluster.

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

// ALB w/ingress and listener rule
module "alb" {
  source = "github.com/itsdalmo/tf-modules//ec2/alb"

  prefix      = "${var.prefix}"
  internal    = "false"
  vpc_id      = "${var.vpc_id}"
  subnet_ids  = ["${var.subnets}"]

  tags {
    terraform   = "True"
    environment = "dev"
  }
}

// Cluster
module "cluster" {
  source = "github.com/itsdalmo/tf-modules//container/cluster"

  prefix      = "${var.prefix}"
  vpc_id      = "${var.vpc_id}"
  subnet_ids  = ["${var.subnets}"]

  tags {
    terraform   = "True"
    environment = "dev"
  }
}

// Create a task definition
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

// Service
module "service" {
  source = "github.com/itsdalmo/tf-modules//container/service"

  prefix             = "${var.prefix}"
  vpc_id             = "${var.vpc_id}"
  cluster_id         = "${module.cluster.id}"
  cluster_sg         = "${module.cluster.security_group_id}"
  cluster_role       = "${module.cluster.role_id}"
  load_balancer_name = "${module.alb.name}"
  load_balancer_sg   = "${module.alb.security_group_id}"
  task_definition    = "${aws_ecs_task_definition.main.arn}"
  task_log_group_arn = "${aws_cloudwatch_log_group.main.arn}"
  container_count    = "2"

  port_mapping = {
    "0" = "8000"
  }

  tags {
    terraform   = "True"
    environment = "dev"
  }
}

// Listeners are added manually
resource "aws_alb_listener" "main" {
  load_balancer_arn = "${module.alb.arn}"
  port              = 80
  protocol          = "HTTP"

  default_action {
    target_group_arn = "${module.service.target_group_arn}"
    type             = "forward"
  }
}

// ... and SG ingress
resource "aws_security_group_rule" "ingress" {
  security_group_id = "${module.alb.security_group_id}"
  type              = "ingress"
  protocol          = "tcp"
  from_port         = "80"
  to_port           = "80"
  cidr_blocks       = ["0.0.0.0/0"]
}
```
