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

resource "aws_alb_listener" "main" {
  load_balancer_arn = "${module.alb.arn}"
  port              = 80
  protocol          = "HTTP"

  default_action {
    target_group_arn = "${module.server.target_group_arn}"
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
