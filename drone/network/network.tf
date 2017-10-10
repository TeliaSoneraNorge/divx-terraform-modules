# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
variable "prefix" {
  description = "A prefix used for naming resources."
}

variable "certificate_arn" {
  description = "ACM certificate ARN for the domain."
}

variable "vpc_id" {
  description = "ID of the VPC for the subnets."
}

variable "subnet_ids" {
  description = "ID of subnets where bastion can be provisioned."
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
resource "aws_elb" "external" {
  name            = "${var.prefix}-external-elb"
  subnets         = ["${var.subnet_ids}"]
  security_groups = ["${aws_security_group.external.id}"]

  listener {
    instance_port     = "8000"
    instance_protocol = "tcp"
    lb_port           = "80"
    lb_protocol       = "tcp"
  }

  listener {
    instance_port      = "8000"
    instance_protocol  = "http"
    lb_port            = "443"
    lb_protocol        = "https"
    ssl_certificate_id = "${var.certificate_arn}"
  }

  health_check {
    target              = "HTTP:8000/"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    interval            = 30
  }

  tags = "${merge(var.tags, map("Name", "${var.prefix}-external-elb"))}"
}

resource "aws_security_group" "external" {
  name        = "${var.prefix}-external-elb-sg"
  description = "Security group for the Drone.io internet facing ELB."
  vpc_id      = "${var.vpc_id}"

  lifecycle {
    create_before_destroy = true
  }

  tags = "${merge(var.tags, map("Name", "${var.prefix}-external-elb-sg"))}"
}

resource "aws_security_group_rule" "external_egress" {
  security_group_id = "${aws_security_group.external.id}"
  type              = "egress"
  protocol          = "-1"
  from_port         = 0
  to_port           = 0
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_elb" "internal" {
  name            = "${var.prefix}-internal-elb"
  subnets         = ["${var.subnet_ids}"]
  security_groups = ["${aws_security_group.internal.id}"]
  internal        = "true"

  listener {
    instance_port     = "9000"
    instance_protocol = "tcp"
    lb_port           = "9000"
    lb_protocol       = "tcp"
  }

  health_check {
    target              = "HTTP:8000/"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    interval            = 30
  }

  tags = "${merge(var.tags, map("Name", "${var.prefix}-internal-elb"))}"
}

resource "aws_security_group" "internal" {
  name        = "${var.prefix}-internal-elb-sg"
  description = "Security group for the Drone.io internal ELB."
  vpc_id      = "${var.vpc_id}"

  lifecycle {
    create_before_destroy = true
  }

  tags = "${merge(var.tags, map("Name", "${var.prefix}-internal-elb-sg"))}"
}

resource "aws_security_group_rule" "internal_egress" {
  security_group_id = "${aws_security_group.internal.id}"
  type              = "egress"
  protocol          = "-1"
  from_port         = 0
  to_port           = 0
  cidr_blocks       = ["0.0.0.0/0"]
}

# ------------------------------------------------------------------------------
# Output
# ------------------------------------------------------------------------------
output "external_elb_name" {
  value = "${aws_elb.external.name}"
}

output "external_elb_sg" {
  value = "${aws_security_group.external.id}"
}

output "external_elb_dns" {
  value = "${aws_elb.external.dns_name}"
}

output "external_elb_zone_id" {
  value = "${aws_elb.external.zone_id}"
}

output "internal_elb_id" {
  value = "${aws_elb.internal.id}"
}

output "internal_elb_sg" {
  value = "${aws_security_group.internal.id}"
}

output "internal_elb_dns" {
  value = "${aws_elb.internal.dns_name}"
}
