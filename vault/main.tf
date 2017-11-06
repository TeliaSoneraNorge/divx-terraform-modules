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

variable "instance_ami" {
  description = "ID of a Ubuntu AMI to use for Vault."
  default     = "ami-47d6723e"
}

variable "instance_key" {
  description = "EC2 key-pair to use for ingress from bastion."
  default     = ""
}

variable "config" {
  description = "Optional: Vault configuration in HCL or JSON format."
  default     = ""
}

variable "extra_install" {
  description = "Optional: Extra install steps to take after installing Vault."
  default     = ""
}

variable "tags" {
  description = "A map of tags (key-value pairs) passed to resources."
  type        = "map"
  default     = {}
}

# -------------------------------------------------------------------------------
# Resources
# -------------------------------------------------------------------------------
data "aws_region" "current" {
  current = true
}

data "aws_caller_identity" "current" {}

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

module "asg" {
  source          = "../ec2/asg"
  prefix          = "${var.prefix}"
  user_data       = "${data.template_file.main.rendered}"
  vpc_id          = "${var.vpc_id}"
  subnet_ids      = "${var.subnet_ids}"
  instance_policy = "${data.aws_iam_policy_document.permissions.json}"
  instance_count  = "1"
  instance_type   = "m3.medium"
  instance_ami    = "${var.instance_ami}"
  instance_key    = "${var.instance_key}"
  tags            = "${var.tags}"
}

resource "aws_autoscaling_attachment" "main" {
  autoscaling_group_name = "${module.asg.id}"
  elb                    = "${aws_elb.main.name}"
}

data "aws_iam_policy_document" "permissions" {
  statement {
    effect = "Allow"

    actions = [
      "dynamodb:*",
    ]

    resources = [
      "arn:aws:dynamodb:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:table/${var.prefix}*"
    ]
  }
}

data "template_file" "main" {
  depends_on = ["data.template_file.config"]
  template = "${file("${path.module}/cloud-config.yml")}"

  vars {
    download_url  = "https://releases.hashicorp.com/vault/0.8.3/vault_0.8.3_linux_amd64.zip"
    config        = "${var.config != "" ? var.config : data.template_file.config.rendered}"
    extra_install = "${var.extra_install}"
  }
}

data "template_file" "config" {
  template = "${file("${path.module}/config.hcl")}"

  vars {
    table    = "${var.prefix}"
    region   = "${data.aws_region.current.name}"
    redirect = "http://${aws_elb.main.dns_name}:8200"
  }
}

resource "aws_elb" "main" {
  name            = "${var.prefix}-elb"
  subnets         = ["${var.subnet_ids}"]
  security_groups = ["${aws_security_group.main.id}"]

  listener {
    instance_port     = 8200
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  listener {
    instance_port      = 8200
    instance_protocol  = "http"
    lb_port            = 443
    lb_protocol        = "https"
    ssl_certificate_id = "${var.certificate_arn}"
  }

  health_check {
    target              = "HTTP:8200/v1/sys/health"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 3
    interval            = 15
  }

  tags = "${merge(var.tags, map("Name", "${var.prefix}-elb"))}"
}

resource "aws_security_group" "main" {
  name        = "${var.prefix}-elb-sg"
  description = "Security group for the web-facing ELB for Vault."
  vpc_id      = "${var.vpc_id}"

  lifecycle {
    create_before_destroy = true
  }

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

resource "aws_security_group_rule" "https_ingress" {
  security_group_id = "${aws_security_group.main.id}"
  type              = "ingress"
  protocol          = "tcp"
  from_port         = "443"
  to_port           = "443"
  cidr_blocks       = ["${var.authorized_cidr}"]
}

resource "aws_security_group_rule" "http_ingress" {
  security_group_id = "${aws_security_group.main.id}"
  type              = "ingress"
  protocol          = "tcp"
  from_port         = "80"
  to_port           = "80"
  cidr_blocks       = ["${var.authorized_cidr}"]
}

resource "aws_security_group_rule" "elb_ingress" {
  security_group_id        = "${module.asg.security_group_id}"
  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = "8200"
  to_port                  = "8200"
  source_security_group_id = "${aws_security_group.main.id}"
}

# ------------------------------------------------------------------------------
# Output
# ------------------------------------------------------------------------------
output "vault_role_arn" {
  value = "${module.asg.role_arn}"
}

output "vault_sg" {
  value = "${module.asg.security_group_id}"
}

output "elb_name" {
  value = "${aws_elb.main.name}"
}

output "elb_sg" {
  value = "${aws_security_group.main.id}"
}

output "elb_dns" {
  value = "${aws_elb.main.dns_name}"
}
