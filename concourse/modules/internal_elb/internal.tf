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
  description = "ID of subnets for the ELB."
  type        = "list"
}

variable "tsa_port" {
  description = "Port specification for the Concourse TSA."
  default     = "2222"
}

variable "atc_port" {
  description = "Port specification for the Concourse ATC."
  default     = "8080"
}

variable "tags" {
  description = "A map of tags (key-value pairs) passed to resources."
  type        = "map"
  default     = {}
}

# -------------------------------------------------------------------------------
# Resources
# -------------------------------------------------------------------------------
resource "aws_elb" "main" {
  name            = "${var.prefix}"
  subnets         = ["${var.subnet_ids}"]
  security_groups = ["${aws_security_group.main.id}"]
  internal        = "true"

  listener {
    instance_port     = "${var.atc_port}"
    instance_protocol = "http"
    lb_port           = "80"
    lb_protocol       = "http"
  }

  listener {
    instance_port     = "${var.tsa_port}"
    instance_protocol = "tcp"
    lb_port           = "${var.tsa_port}"
    lb_protocol       = "tcp"
  }

  health_check {
    target              = "TCP:${var.tsa_port}"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    interval            = 30
  }

  tags = "${merge(var.tags, map("Name", "${var.prefix}"))}"
}

resource "aws_security_group" "main" {
  name        = "${var.prefix}-sg"
  description = "Security group for the internal ELB for the Concourse TSA."
  vpc_id      = "${var.vpc_id}"

  lifecycle {
    create_before_destroy = true
  }

  tags = "${merge(var.tags, map("Name", "${var.prefix}-sg"))}"
}

resource "aws_security_group_rule" "outbound" {
  security_group_id = "${aws_security_group.main.id}"
  type              = "egress"
  protocol          = "-1"
  from_port         = 0
  to_port           = 0
  cidr_blocks       = ["0.0.0.0/0"]
}

# -------------------------------------------------------------------------------
# Output
# -------------------------------------------------------------------------------
output "name" {
  value = "${aws_elb.main.name}"
}

output "dns_name" {
  value = "${aws_elb.main.dns_name}"
}

output "security_group_id" {
  value = "${aws_security_group.main.id}"
}
