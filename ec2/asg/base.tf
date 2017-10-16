# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
variable "prefix" {
  description = "A prefix used for naming resources."
}

variable "user_data" {
  description = "User data script for the launch configuration."
}

variable "vpc_id" {
  description = "ID of the VPC for the subnets."
}

variable "instance_type" {
  description = "Type of instance to provision."
}

variable "instance_ami" {
  description = "AMI id for the launch configuration."
}

variable "instance_key" {
  description = "Name of an EC2 key-pair for SSH access."
}

variable "instance_policy" {
  description = "Optional: A policy document which is applied to the instance profile."
  default     = ""
}

variable "tags" {
  description = "A map of tags (key-value pairs) passed to resources."
  type        = "map"
  default     = {}
}

# ------------------------------------------------------------------------------
# Resources
# ------------------------------------------------------------------------------
resource "aws_iam_role" "main" {
  name               = "${var.prefix}-role"
  assume_role_policy = "${data.aws_iam_policy_document.main.json}"
}

data "aws_iam_policy_document" "main" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_instance_profile" "main" {
  name = "${var.prefix}-profile"
  role = "${aws_iam_role.main.name}"
}

resource "aws_iam_role_policy" "main" {
  name   = "${var.prefix}-permissions"
  role   = "${aws_iam_role.main.id}"
  policy = "${var.instance_policy}"
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

resource "aws_launch_configuration" "main" {
  name_prefix          = "${var.prefix}-asg-"
  instance_type        = "${var.instance_type}"
  iam_instance_profile = "${aws_iam_instance_profile.main.name}"
  security_groups      = ["${aws_security_group.main.id}"]
  image_id             = "${var.instance_ami}"
  key_name             = "${var.instance_key}"
  user_data            = "${var.user_data}"

  lifecycle {
    create_before_destroy = true
  }
}

# ------------------------------------------------------------------------------
# Output
# ------------------------------------------------------------------------------
output "launch_configuration" {
  value = "${aws_launch_configuration.main.name}"
}

output "role_name" {
  value = "${aws_iam_role.main.name}"
}

output "role_arn" {
  value = "${aws_iam_role.main.arn}"
}

output "role_id" {
  value = "${aws_iam_role.main.id}"
}

output "security_group_id" {
  value = "${aws_security_group.main.id}"
}
