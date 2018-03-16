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
  security_groups    = ["${aws_security_group.main.*.id}"]

  tags = "${merge(var.tags, map("Name", "${local.name}"))}"
}

resource "aws_security_group" "main" {
  count       = "${var.type == "network" ? 0 : 1}"
  name        = "${local.name}-sg"
  description = "Terraformed security group."
  vpc_id      = "${var.vpc_id}"

  tags = "${merge(var.tags, map("Name", "${local.name}-sg"))}"
}

resource "aws_security_group_rule" "egress" {
  count             = "${var.type == "network" ? 0 : 1}"
  security_group_id = "${aws_security_group.main.id}"
  type              = "egress"
  protocol          = "-1"
  from_port         = 0
  to_port           = 0
  cidr_blocks       = ["0.0.0.0/0"]
}
