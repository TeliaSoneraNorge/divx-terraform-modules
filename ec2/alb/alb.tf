# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
variable "prefix" {
  description = "A prefix used for naming resources."
}

variable "vpc_id" {
  description = "ID of the VPC for the subnets."
}

variable "subnet_ids" {
  description = "ID of subnets where instances can be provisioned."
  type        = "list"
}

variable "internal" {
  description = "Provision an internal ALB. Defaults to false."
  default     = "false"
}

variable "tags" {
  description = "A map of tags (key-value pairs) passed to resources."
  type        = "map"
  default     = {}
}

# ------------------------------------------------------------------------------
# Resources
# ------------------------------------------------------------------------------
resource "aws_alb" "main" {
  name            = "${var.prefix}-alb"
  internal        = "${var.internal}"
  subnets         = ["${var.subnet_ids}"]
  security_groups = ["${aws_security_group.main.id}"]

  tags = "${merge(var.tags, map("Name", "${var.prefix}"))}"
}

resource "aws_security_group" "main" {
  name        = "${var.prefix}-sg"
  description = "Terraformed security group."
  vpc_id      = "${var.vpc_id}"

  tags = "${merge(var.tags, map("Name", "${var.prefix}-sg"))}"
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
  value = "${aws_alb.main.arn}"
}

output "name" {
  // arn:aws:elasticloadbalancing:<region>:<account-id>:loadbalancer/app/<name>/<uuid>
  value = "${element(split("/", aws_alb.main.name), 2)}"
}

output "dns_name" {
  value = "${aws_alb.main.dns_name}"
}

output "zone_id" {
  value = "${aws_alb.main.zone_id}"
}

output "origin_id" {
  value = "${element(split(".", aws_alb.main.dns_name), 0)}"
}

output "security_group_id" {
  value = "${aws_security_group.main.id}"
}
