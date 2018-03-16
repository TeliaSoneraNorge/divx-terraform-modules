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
  source          = "github.com/TeliaSoneraNorge/divx-terraform-modules///ec2/vpc"
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

resource "aws_lb_listener" "main" {
  load_balancer_arn = "${module.alb.arn}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = "${module.four_o_four.target_group_arn}"
    type             = "forward"
  }
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

module "application_gw" {
  source = "../service"
  prefix                      = "hello1"
  task_definition_cpu         = "256"
  task_definition_ram         = "512"
  container_count             = "2"
  task_definition_image_id    = "crccheck/hello-world:latest"
  container_port              = "8000"

  vpc_id                      = "${module.vpc.vpc_id}"
  cluster_role_id             = "${module.cluster.role_id}"
  alb_arn                     = "${module.alb.arn}"
  cluster_id                  = "${module.cluster.id}"
  tags = "${var.tags}"

}

module "four_o_four" {
  source = "../service"
  prefix                      = "hello2"
  task_definition_cpu         = "256"
  task_definition_ram         = "512"
  container_count             = "1"
  task_definition_image_id    = "crccheck/hello-world:latest"
  container_port              = "8000"

  vpc_id                      = "${module.vpc.vpc_id}"
  cluster_id                  = "${module.cluster.id}"
  cluster_role_id             = "${module.cluster.role_id}"
  alb_arn                     = "${module.alb.arn}"
  tags = "${var.tags}"
}
