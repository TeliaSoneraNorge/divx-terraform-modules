# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
variable "prefix" {
  description = "A prefix used for naming resources."
}

variable "user_data" {
  description = "User data script for the launch configuration."
  default     = ""
}

variable "vpc_id" {
  description = "ID of the VPC for the subnets."
}

variable "subnet_ids" {
  description = "ID of subnets where instances can be provisioned."
  type        = "list"
}

variable "instance_type" {
  description = "Type of instance to provision."
  default     = "t2.micro"
}

variable "instance_count" {
  description = "Desired (and minimum) number of instances."
  default     = "1"
}

variable "instance_ami" {
  description = "AMI id for the launch configuration."
  default     = "ami-d7b9a2b1"
}

variable "instance_key" {
  description = "Name of an EC2 key-pair for SSH access."
  default     = ""
}

// HACK: Count issues, but we want this to be optional.
variable "instance_policy" {
  description = "Optional: A policy document which is applied to the instance profile."
  default     = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "deny-all",
            "Effect": "Deny",
            "Action": "*",
            "Resource": "*"
        }
    ]
}
EOF
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

locals {
  asg_tags = "${merge(var.tags, map("Name", "${var.prefix}"))}"
}

data "null_data_source" "autoscaling" {
  count = "${length(local.asg_tags)}"

  inputs = {
    Key               = "${element(keys(local.asg_tags), count.index)}"
    Value             = "${element(values(local.asg_tags), count.index)}"
    PropagateAtLaunch = "TRUE"
  }
}

resource "aws_cloudformation_stack" "main" {
  depends_on    = ["aws_launch_configuration.main"]
  name          = "${var.prefix}-asg"
  template_body = "${data.template_file.main.rendered}"
}

data "template_file" "main" {
  template = "${file("${path.module}/cloudformation.yml")}"

  vars {
    prefix               = "${var.prefix}"
    launch_configuration = "${aws_launch_configuration.main.name}"
    min_size             = "${var.instance_count}"
    max_size             = "${var.instance_count + 2}"
    subnets              = "${jsonencode(var.subnet_ids)}"
    tags                 = "${jsonencode(data.null_data_source.autoscaling.*.outputs)}"
  }
}

# ------------------------------------------------------------------------------
# Output
# ------------------------------------------------------------------------------
output "id" {
  value = "${aws_cloudformation_stack.main.outputs["AsgName"]}"
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
