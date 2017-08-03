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

variable "authorized_keys" {
  description = "A list of public keys which can reach bastion via SSH."
  type        = "list"
}

variable "authorized_cidr" {
  description = "List of authorized IPv4 CIDR blocks."
  type        = "list"
}

variable "vpc_id" {
  description = "ID of the vpc where bastion will be launched."
}

variable "subnet_ids" {
  description = "List of subnet ID's where bastion can be launched."
  type        = "list"
}

variable "pem_bucket" {
  description = "Name of bucket where PEM keys are stored."
}

variable "pem_path" {
  description = "Path to the specific PEM key which bastion uses to gain access to instances."
}

variable "instance_ami" {
  description = "AMI ID used for provisioning the bastion instance."
  default     = "ami-d7b9a2b1"
}

variable "instance_type" {
  description = "Type of instance to provision."
  default     = "t2.micro"
}

# ------------------------------------------------------------------------------
# Resources
# ------------------------------------------------------------------------------
data "aws_region" "current" {
  current = true
}

resource "aws_security_group" "main" {
  name        = "${var.prefix}-bastion-sg"
  description = "Security group for bastion."
  vpc_id      = "${var.vpc_id}"

  tags {
    Name        = "${var.prefix}-bastion-sg"
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

resource "aws_security_group_rule" "ingress" {
  security_group_id = "${aws_security_group.main.id}"
  type              = "ingress"
  protocol          = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_blocks       = ["${var.authorized_cidr}"]
}

resource "aws_launch_configuration" "main" {
  name_prefix          = "${var.prefix}-bastion-config-"
  instance_type        = "${var.instance_type}"
  iam_instance_profile = "${aws_iam_instance_profile.main.name}"
  security_groups      = ["${aws_security_group.main.id}"]
  image_id             = "${var.instance_ami}"

  user_data = "${data.template_file.main.rendered}"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "main" {
  name                 = "${aws_launch_configuration.main.name}"
  desired_capacity     = "1"
  min_size             = "1"
  max_size             = "1"
  launch_configuration = "${aws_launch_configuration.main.name}"
  vpc_zone_identifier  = ["${var.subnet_ids}"]

  tag {
    key                 = "Name"
    value               = "${var.prefix}-bastion"
    propagate_at_launch = true
  }

  tag {
    key                 = "terraform"
    value               = "true"
    propagate_at_launch = true
  }

  tag {
    key                 = "environment"
    value               = "${var.environment}"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_eip" "main" {}

data "template_file" "main" {
  template = "${file("${path.module}/cloud-config.yml")}"

  vars {
    authorized_keys = "${join("\n  - ", "${var.authorized_keys}")}"
    aws_region      = "${data.aws_region.current.name}"
    elastic_ip      = "${aws_eip.main.public_ip}"
    pem_bucket      = "${var.pem_bucket}"
    pem_path        = "${var.pem_path}"
  }
}

# ------------------------------------------------------------------------------
# Output
# ------------------------------------------------------------------------------

