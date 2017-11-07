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
    name                   = "${module.lb.dns_name}"
    zone_id                = "${module.lb.zone_id}"
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
  depends_on             = ["aws_lb_target_group.main"]
  autoscaling_group_name = "${module.asg.id}"
  alb_target_group_arn   = "${aws_lb_target_group.main.arn}"
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
  template = "${file("${path.module}/cloud-config.yml")}"

  vars {
    download_url  = "https://releases.hashicorp.com/vault/0.8.3/vault_0.8.3_linux_amd64.zip"
    extra_install = "${var.extra_install}"
    address       = "https://${var.domain}"
    region        = "${data.aws_region.current.name}"
    table         = "${var.prefix}"
  }
}

module "lb" {
  source = "../ec2/lb"

  prefix     = "${var.prefix}"
  type       = "application"
  internal   = "false"
  vpc_id     = "${var.vpc_id}"
  subnet_ids = "${var.subnet_ids}"
  tags       = "${var.tags}"
}

resource "aws_lb_target_group" "main" {
  vpc_id     = "${var.vpc_id}"
  port       = "8200"
  protocol   = "HTTP"

  health_check {
    path                = "/v1/sys/seal-status"
    port                = "8200"
    protocol            = "HTTP"
    interval            = "30"
    timeout             = "5"
    healthy_threshold   = "5"
    unhealthy_threshold = "2"
    matcher             = "200"
  }

  /**
  * NOTE: TF is unable to destroy a target group while a listener is attached,
  * therefor we have to create a new one before destroying the old. This also means
  * we have to let it have a random name, and then tag it with the desired name.
  */
  lifecycle {
    create_before_destroy = true
  }

  tags = "${merge(var.tags, map("Name", "${var.prefix}-target"))}"
}

resource "aws_lb_listener" "main" {
  depends_on        = ["aws_lb_target_group.main"]
  load_balancer_arn = "${module.lb.arn}"
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2015-05"
  certificate_arn   = "${var.certificate_arn}"

  default_action {
    target_group_arn = "${aws_lb_target_group.main.arn}"
    type             = "forward"
  }

}

resource "aws_security_group_rule" "https_ingress" {
  security_group_id = "${module.lb.security_group_id}"
  type              = "ingress"
  protocol          = "tcp"
  from_port         = "443"
  to_port           = "443"
  cidr_blocks       = ["${var.authorized_cidr}"]
}

resource "aws_security_group_rule" "lb_ingress" {
  security_group_id        = "${module.asg.security_group_id}"
  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = "8200"
  to_port                  = "8200"
  source_security_group_id = "${module.lb.security_group_id}"
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

