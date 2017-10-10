# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
variable "prefix" {
  description = "A prefix used for naming resources."
}

variable "domain" {
  description = "The domain name to associate with the Concourse ELB. (Must have an ACM certificate)."
}

variable "zone_id" {
  description = "Zone ID for the domains route53 alias record."
}

variable "certificate_arn" {
  description = "ACM certificate ARN for the domain."
}

variable "vpc_id" {
  description = "ID of the VPC for the subnets."
}

variable "subnet_ids" {
  description = "ID of subnets for the ELB."
  type        = "list"
}

variable "authorized_cidr" {
  description = "List of authorized CIDR blocks which can reach the ELB."
  type        = "list"
}

variable "web_port" {
  description = "Port specification for the Concourse web interface."
  default     = "443"
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
resource "aws_route53_record" "main" {
  zone_id = "${var.zone_id}"
  name    = "${var.domain}"
  type    = "A"

  alias {
    name                   = "${aws_elb.main.dns_name}"
    zone_id                = "${aws_elb.main.zone_id}"
    evaluate_target_health = false
  }
}

resource "aws_elb" "main" {
  name            = "${var.prefix}"
  subnets         = ["${var.subnet_ids}"]
  security_groups = ["${aws_security_group.main.id}"]

  listener {
    instance_port      = "${var.atc_port}"
    instance_protocol  = "http"
    lb_port            = "${var.web_port}"
    lb_protocol        = "https"
    ssl_certificate_id = "${var.certificate_arn}"
  }

  health_check {
    target              = "HTTP:${var.atc_port}/"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    interval            = 30
  }

  tags = "${merge(var.tags, map("Name", "${var.prefix}"))}"
}

resource "aws_security_group" "main" {
  name        = "${var.prefix}-sg"
  description = "Security group for the web-facing ELB for Concourse."
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

resource "aws_security_group_rule" "ingress" {
  security_group_id = "${aws_security_group.main.id}"
  type              = "ingress"
  protocol          = "tcp"
  from_port         = "${var.web_port}"
  to_port           = "${var.web_port}"
  cidr_blocks       = ["${var.authorized_cidr}"]
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
