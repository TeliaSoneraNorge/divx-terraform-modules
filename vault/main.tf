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

variable "bastion_sg" {
  description = "Bastion security group ID. Opens SSH access."
}

variable "authorized_cidr" {
  description = "List of authorized CIDR blocks which can reach the ELB."
  type        = "list"
}

variable "instance_ami" {
  description = "ID of a Ubuntu AMI to use for Vault."
  default     = "ami-eab74493"
}

variable "instance_key" {
  description = "EC2 key-pair to use for ingress from bastion."
  default     = ""
}

variable "config" {
  description = "Optional: Vault configuration in HCL or JSON format."
  default = ""
}

variable "extra_install" {
  description = "Optional: Extra install steps to take after installing Vault."
  default     = ""
}

# -------------------------------------------------------------------------------
# Resources
# -------------------------------------------------------------------------------
data "aws_region" "current" {
  current = true
}

data "aws_caller_identity" "current" {}

module "asg" {
  source          = "../ec2/asg"
  prefix          = "${var.prefix}-vault"
  environment     = "${var.environment}"
  user_data       = "${data.template_file.main.rendered}"
  vpc_id          = "${var.vpc_id}"
  subnet_ids      = "${var.subnet_ids}"
  load_balancers  = ["${aws_elb.main.name}"]
  instance_policy = "${data.aws_iam_policy_document.permissions.json}"
  instance_count  = "3"
  instance_type   = "m3.medium"
  instance_ami    = "${var.instance_ami}"
  instance_key    = "${var.instance_key}"
}

data "aws_iam_policy_document" "permissions" {
  statement {
    effect = "Allow"

    actions = [
      "dynamodb:*",
    ]

    resources = [
      "arn:aws:dynamodb:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:table/${var.prefix}-vault*"
    ]
  }
}

data "template_file" "main" {
  depends_on = ["data.template_file.config"]
  template = "${file("${path.module}/cloud-config.yml")}"

  vars {
    download_url  = "https://releases.hashicorp.com/vault/0.8.2/vault_0.8.2_linux_amd64.zip"
    config        = "${data.template_file.config.rendered}"
    extra_install = "${var.extra_install}"
  }
}

data "template_file" "config" {
  template = "${file("${path.module}/config.hcl")}"

  vars {
    table    = "${var.prefix}-vault"
    region   = "${data.aws_region.current.name}"
    redirect = "http://${aws_elb.main.dns_name}:8200"
  }
}

resource "aws_elb" "main" {
  name            = "${var.prefix}-vault-elb"
  subnets         = ["${var.subnet_ids}"]
  security_groups = ["${aws_security_group.main.id}"]

  listener {
    instance_port     = 8200
    instance_protocol = "tcp"
    lb_port           = 80
    lb_protocol       = "tcp"
  }

  listener {
    instance_port     = 8200
    instance_protocol = "tcp"
    lb_port           = 443
    lb_protocol       = "tcp"
  }

  health_check {
    target              = "HTTP:8200/v1/sys/health"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 3
    interval            = 15
  }

  tags {
    Name        = "${var.prefix}-vault-elb"
    terraform   = "true"
    environment = "${var.environment}"
  }
}

resource "aws_security_group" "main" {
  name        = "${var.prefix}-sg"
  description = "Security group for the web-facing ELB for Vault."
  vpc_id      = "${var.vpc_id}"

  lifecycle {
    create_before_destroy = true
  }

  tags {
    Name        = "${var.prefix}-sg"
    terraform   = "true"
    environment = "${var.environment}"
  }
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

resource "aws_security_group_rule" "bastion_ingress" {
  security_group_id        = "${module.asg.security_group_id}"
  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = "22"
  to_port                  = "22"
  source_security_group_id = "${var.bastion_sg}"
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
