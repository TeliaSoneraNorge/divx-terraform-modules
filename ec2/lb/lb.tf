# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
variable "prefix" {
  description = "A prefix used for naming resources."
}

variable "type" {
  description = "Type of load balancer to provision (network or application)."
}

variable "internal" {
  description = "Provision an internal load balancer. Defaults to false."
  default     = "false"
}

variable "vpc_id" {
  description = "ID of the VPC for the subnets."
}

variable "subnet_ids" {
  description = "ID of subnets which will be attached to the load balancer."
  type        = "list"
}

variable "tags" {
  description = "A map of tags (key-value pairs) passed to resources."
  type        = "map"
  default     = {}
}

# ------------------------------------------------------------------------------
# Resources
# ------------------------------------------------------------------------------
locals {
  name = "${var.prefix}-${var.type == "network" ? "nlb" : "alb"}"
}

resource "aws_lb" "main" {
  name               = "${local.name}"
  load_balancer_type = "${var.type}"
  internal           = "${var.internal}"
  subnets            = ["${var.subnet_ids}"]
  security_groups    = ["${aws_security_group.main.id}"]

  tags = "${merge(var.tags, map("Name", "${local.name}"))}"
}

resource "aws_security_group" "main" {
  name        = "${local.name}-sg"
  description = "Terraformed security group."
  vpc_id      = "${var.vpc_id}"

  tags = "${merge(var.tags, map("Name", "${local.name}-sg"))}"
}

resource "aws_security_group_rule" "egress" {
  security_group_id = "${aws_security_group.main.id}"
  type              = "egress"
  protocol          = "-1"
  from_port         = 0
  to_port           = 0
  cidr_blocks       = ["0.0.0.0/0"]
}

# ------------------------------------------------------------------------------
# Output
# ------------------------------------------------------------------------------
output "arn" {
  value = "${aws_lb.main.arn}"
}

output "name" {
  // arn:aws:elasticloadbalancing:<region>:<account-id>:loadbalancer/app/<name>/<uuid>
  value = "${element(split("/", aws_lb.main.name), 2)}"
}

output "dns_name" {
  value = "${aws_lb.main.dns_name}"
}

output "zone_id" {
  value = "${aws_lb.main.zone_id}"
}

output "origin_id" {
  value = "${element(split(".", aws_lb.main.dns_name), 0)}"
}

output "security_group_id" {
  value = "${aws_security_group.main.id}"
}
