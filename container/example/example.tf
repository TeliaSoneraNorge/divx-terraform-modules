variable "prefix" {
  default = "ecs-test"
}

provider "aws" {
  region = "eu-west-1"
}

data "aws_region" "current" {
  current = "true"
}

variable "tags" {
  type = "map"

  default = {
    terraform   = "true"
    environment = "dev"
    test        = "true"
  }
}

# Create a VPC in which to place this example / test
module "vpc" {
  source          = "github.com/TeliaSoneraNorge/divx-terraform-modules///ec2/vpc"
  prefix          = "${var.prefix}"
  cidr_block      = "10.0.0.0/16"
  tags            = "${var.tags}"
  private_subnets = "0"
}

# Create the external ALB
module "alb" {
  source = "github.com/TeliaSoneraNorge/divx-terraform-modules//ec2/lb"

  prefix     = "${var.prefix}"
  type       = "application"
  internal   = "false"
  vpc_id     = "${module.vpc.vpc_id}"
  subnet_ids = ["${module.vpc.public_subnet_ids}"]
  tags       = "${var.tags}"
}

# Create cluster and open ingress from the LB on the dynamic port range.
module "cluster" {
  source = "github.com/TeliaSoneraNorge/divx-terraform-modules//container/cluster"

  prefix         = "${var.prefix}"
  vpc_id         = "${module.vpc.vpc_id}"
  subnet_ids     = ["${module.vpc.public_subnet_ids}"]
  ingress_length = 1

  ingress {
    "0" = "${module.alb.security_group_id}"
  }

  tags = "${var.tags}"
}

# Create a target group with listeners.
module "targetHTTP" {
  source = "github.com/TeliaSoneraNorge/divx-terraform-modules//container/target"

  prefix            = "${var.prefix}"
  vpc_id            = "${module.vpc.vpc_id}"
  load_balancer_arn = "${module.alb.arn}"

  target {
    protocol = "HTTP"
    port     = "8000"
    health   = "HTTP:traffic-port/"
  }

  listeners = [{
    protocol = "HTTP"
    port     = "80"
  }]

  tags = "${var.tags}"
}

# Create a task definition for the service.
# NOTE: HostPort must be 0 to use dynamic port mapping.
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

# Finally, create the service with the given task definition and target group.
module "service" {
  source = "github.com/TeliaSoneraNorge/divx-terraform-modules//container/service"

  prefix             = "${var.prefix}"
  cluster_id         = "${module.cluster.id}"
  cluster_role       = "${module.cluster.role_id}"
  task_definition    = "${aws_ecs_task_definition.main.arn}"
  task_log_group_arn = "${aws_cloudwatch_log_group.main.arn}"
  container_count    = "2"

  load_balancer {
    target_group_arn = "${module.targetHTTP.target_group_arn}"
    container_name   = "${var.prefix}"
    container_port   = "${module.targetHTTP.container_port}"
  }

  tags = "${var.tags}"
}

# SG rules for ingress to the LB is created manually.
resource "aws_security_group_rule" "ingress_80" {
  security_group_id = "${module.alb.security_group_id}"
  type              = "ingress"
  protocol          = "tcp"
  from_port         = "80"
  to_port           = "80"
  cidr_blocks       = ["0.0.0.0/0"]
}
