# ------------------------------------------------------------------------------
# Resources
# ------------------------------------------------------------------------------
data "aws_region" "current" {}

module "vpc" {
  source          = "../../ec2/vpc"
  prefix          = "${var.prefix}"
  cidr_block      = "10.1.0.0/16"
  tags            = "${var.tags}"
  private_subnets = "1"
}

module "alb" {
  source = "../../ec2/lb"

  prefix     = "${var.prefix}"
  type       = "application"
  internal   = "false"
  vpc_id     = "${module.vpc.vpc_id}"
  subnet_ids = ["${module.vpc.public_subnet_ids}"]
  tags       = "${var.tags}"
}

# ------------------------------------------------------------------------------
# ecs/cluster
# ------------------------------------------------------------------------------
module "cluster" {
  source = "../cluster"

  prefix         = "${var.prefix}"
  vpc_id         = "${module.vpc.vpc_id}"
  subnet_ids     = ["${module.vpc.private_subnet_ids}"]
  ingress_length = 1

  ingress {
    "0" = "${module.alb.security_group_id}"
  }

  tags = "${var.tags}"
}

# ------------------------------------------------------------------------------
# ecs/service: Create a service which responds with 404 as the default target
# ------------------------------------------------------------------------------
module "four_o_four" {
  source = "../service"

  prefix                   = "${var.prefix}-bouncer"
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

# ------------------------------------------------------------------------------
# Create a default listener and open ingress on port 80 (target group from above)
# ------------------------------------------------------------------------------
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

# ------------------------------------------------------------------------------
# ecs/microservice: Creates a listener rule, target group and ECS service
# (any request to example.com/app/* will be sent to this service)
# ------------------------------------------------------------------------------
module "application" {
  source = "../microservice"

  prefix                   = "${var.prefix}-app"
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
    values       = "/app/*"
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
