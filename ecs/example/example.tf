variable "prefix" {
  default = "ecs-test"
}

provider "aws" {
  region = "eu-west-1"
}

data "aws_region" "current" {}

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
  source          = "github.com/TeliaSoneraNorge/divx-terraform-modules//ec2/vpc"
  prefix          = "${var.prefix}"
  cidr_block      = "10.1.0.0/16"
  tags            = "${var.tags}"
  private_subnets = "1"
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
  subnet_ids     = ["${module.vpc.private_subnet_ids}"]
  ingress_length = 1

  ingress {
    "0" = "${module.alb.security_group_id}"
  }

  tags = "${var.tags}"
}

# Default service and listener (404)
module "four_o_four" {
  source = "../service"

  prefix                   = "hello2"
  vpc_id                   = "${module.vpc.vpc_id}"
  cluster_id               = "${module.cluster.id}"
  cluster_role_id          = "${module.cluster.role_id}"
  task_container_count     = "1"
  task_definition_cpu      = "256"
  task_definition_ram      = "512"
  task_definition_image_id = "crccheck/hello-world:latest"

  target {
    protocol      = "HTTP"
    port          = "8000"
    load_balancer = "${module.alb.arn}"
  }

  health {
    port    = "traffic-port"
    path    = "/"
    matcher = "200"
  }

  tags = "${var.tags}"
}

resource "aws_lb_listener" "main" {
  load_balancer_arn = "${module.alb.arn}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = "${module.four_o_four.target_group_arn}"
    type             = "forward"
  }
}

resource "aws_security_group_rule" "ingress_80" {
  security_group_id = "${module.alb.security_group_id}"
  type              = "ingress"
  protocol          = "tcp"
  from_port         = "80"
  to_port           = "80"
  cidr_blocks       = ["0.0.0.0/0"]
}

# Application service
module "application" {
  source = "../service"

  prefix                   = "hello1"
  vpc_id                   = "${module.vpc.vpc_id}"
  cluster_id               = "${module.cluster.id}"
  cluster_role_id          = "${module.cluster.role_id}"
  task_container_count     = "2"
  task_definition_cpu      = "256"
  task_definition_ram      = "512"
  task_definition_image_id = "crccheck/hello-world:latest"

  target {
    protocol      = "HTTP"
    port          = "8000"
    load_balancer = "${module.alb.arn}"
  }

  health {
    port    = "traffic-port"
    path    = "/"
    matcher = "200"
  }

  tags = "${var.tags}"
}

resource "aws_lb_listener_rule" "application" {
  listener_arn = "${aws_lb_listener.main.arn}"
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = "${module.application.target_group_arn}"
  }

  condition {
    field  = "path-pattern"
    values = ["/application/*"]
  }
}

# Application service
module "hello" {
  source = "../microservice"

  prefix                   = "hello3"
  vpc_id                   = "${module.vpc.vpc_id}"
  cluster_id               = "${module.cluster.id}"
  cluster_role_id          = "${module.cluster.role_id}"
  task_container_count     = "2"
  task_definition_cpu      = "256"
  task_definition_ram      = "512"
  task_definition_image_id = "crccheck/hello-world:latest"

  listener_rule {
    listener_arn = "${aws_lb_listener.main.arn}"
    priority     = 90
    pattern      = "path"
    values       = "/hello/*"
  }

  target {
    protocol      = "HTTP"
    port          = "8000"
    load_balancer = "${module.alb.arn}"
  }

  health {
    port    = "traffic-port"
    path    = "/"
    matcher = "200"
  }

  tags = "${var.tags}"
}
