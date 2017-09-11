# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
variable "prefix" {
  description = "A prefix used for naming resources."
}

variable "environment" {
  description = "Environment tag which is applied to resources."
  default     = ""
}

variable "vpc_id" {
  description = "ID of the VPC for the subnets."
}

variable "subnet_ids" {
  description = "ID of subnets where bastion can be provisioned."
  type        = "list"
}

variable "instance_type" {
  description = "Type of instance to provision."
  default     = "m3.medium"
}

variable "instance_count" {
  description = "Desired (and minimum) number of instances."
  default     = "2"
}

variable "instance_key" {
  description = "Name of an EC2 key-pair for SSH access."
  default     = ""
}

variable "drone_secret" {
  description = "Shared secret used to authenticate agents with the Drone server."
  default     = "12345"
}

variable "drone_github_org" {
  description = "Drone Github organization which is allowed to create users."
  default     = ""
}

variable "drone_github_admins" {
  description = "Github usernames which are allowed to administrate Drone."
  type        = "list"
}

variable "drone_github_client" {
  description = "Drone Github client."
}

variable "drone_github_secret" {
  description = "Drone Github secret."
}

variable "drone_remote_driver" {
  description = "Remote driver for Drone."
  default     = "sqlite3"
}

variable "drone_remote_config" {
  description = "Remote config for Drone."
  default     = "/var/lib/drone/drone.sqlite"
}

# ------------------------------------------------------------------------------
# Resources
# ------------------------------------------------------------------------------
data "aws_region" "current" {
  current = true
}

module "alb" {
  source = "../ec2/alb"

  prefix      = "${var.prefix}"
  environment = "dev"
  internal    = "false"
  vpc_id      = "${var.vpc_id}"
  subnet_ids  = ["${var.subnet_ids}"]
}

module "cluster" {
  source = "../container/cluster"

  prefix         = "${var.prefix}"
  environment    = "${var.environment}"
  vpc_id         = "${var.vpc_id}"
  subnet_ids     = ["${var.subnet_ids}"]
  instance_type  = "${var.instance_type}"
  instance_count = "${var.instance_count}"
  instance_key   = "${var.instance_key}"
}

module "service" {
  source = "../container/service"

  prefix               = "${var.prefix}"
  environment          = "${var.environment}"
  vpc_id               = "${var.vpc_id}"
  cluster_id           = "${module.cluster.id}"
  cluster_sg           = "${module.cluster.security_group_id}"
  cluster_role         = "${module.cluster.role_id}"
  load_balancer_name   = "${module.alb.name}"
  load_balancer_sg     = "${module.alb.security_group_id}"
  task_definition      = "${aws_ecs_task_definition.main.arn}"
  task_log_group_arn   = "${aws_cloudwatch_log_group.main.arn}"
  container_count      = "${var.instance_count}"
  port_mapping         = {
    "0" = "8000"
  }
}

resource "aws_cloudwatch_log_group" "main" {
  name = "${var.prefix}"
}

data "template_file" "main" {
  template = "${file("${path.module}/task.json")}"

  vars {
    name          = "${var.prefix}"
    version       = "latest"
    log_group     = "${aws_cloudwatch_log_group.main.name}"
    region        = "${data.aws_region.current.name}"
    drone_secret  = "${var.drone_secret}"
    drone_host    = "${module.alb.dns_name}"
    remote_driver = "${var.drone_remote_driver}"
    remote_config = "${var.drone_remote_config}"
    github_org    = "${var.drone_github_org}"
    github_admins = "${join(",", var.drone_github_admins)}"
    github_client = "${var.drone_github_client}"
    github_secret = "${var.drone_github_secret}"
  }
}

resource "aws_ecs_task_definition" "main" {
  family                = "${var.prefix}"
  container_definitions = "${data.template_file.main.rendered}"
  task_role_arn         = "${aws_iam_role.main.arn}"

  volume {
    name      = "drone-volume"
    host_path = "/var/lib/drone"
  }

  volume {
    name      = "docker-socket"
    host_path = "/var/run/docker.sock"
  }
}

resource "aws_iam_role" "main" {
  name               = "${var.prefix}-task-role"
  assume_role_policy = "${data.aws_iam_policy_document.assume.json}"
}

data "aws_iam_policy_document" "assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_alb_listener" "main" {
  load_balancer_arn = "${module.alb.arn}"
  port              = 80
  protocol          = "HTTP"

  default_action {
    target_group_arn = "${module.service.target_group_arn}"
    type             = "forward"
  }
}

resource "aws_security_group_rule" "ingress" {
  security_group_id = "${module.alb.security_group_id}"
  type              = "ingress"
  protocol          = "tcp"
  from_port         = "80"
  to_port           = "80"
  cidr_blocks       = ["0.0.0.0/0"]
}

# ------------------------------------------------------------------------------
# Output
# ------------------------------------------------------------------------------
output "security_group_id" {
  value = "${module.cluster.security_group_id}"
}
output "endpoint" {
  value = "${module.alb.dns_name}"
}
