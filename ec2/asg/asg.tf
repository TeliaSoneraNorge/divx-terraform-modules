# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
variable "prefix" {
  description = "A prefix used for naming resources."
}

# TODO: Remove this in favor of a tags block.
variable "environment" {
  description = "Environment tag which is applied to resources."
  default     = ""
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

variable "instance_policy" {
  description = "A policy document which is applied to the instance profile."
}

variable "tags" {
  description = "A map of tags (key-value pairs)."
  type        = "map"
  default     = {}
}

# variable "rolling_updates" {
#   description = "Flag for rolling updates. Requires that the Autoscaling group is set up in Cloudformation."
#   default     = "false"
# }

# ------------------------------------------------------------------------------
# Resources
# ------------------------------------------------------------------------------
module "tags" {
  source = "github.com/itsdalmo/tf-modules//terraform/tags"
  passed = "${var.tags}"

  tags {
    Name        = "${var.prefix}"
    terraform   = "True"
    environment = "${var.environment}"
  }
}

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

  tags = "${module.tags.standard}"
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

resource "aws_autoscaling_group" "main" {
  # count                = "${var.rolling_updates == "false" ? 1 : 0}"
  name                 = "${aws_launch_configuration.main.name}"
  desired_capacity     = "${var.instance_count}"
  min_size             = "${var.instance_count}"
  max_size             = "${var.instance_count + 1}"
  launch_configuration = "${aws_launch_configuration.main.name}"
  vpc_zone_identifier  = ["${var.subnet_ids}"]

  tags = ["${module.tags.autoscaling}"]

  lifecycle {
    create_before_destroy = true
  }
}

# # Rolling updates
# resource "aws_cloudformation_stack" "main" {
#   count         = "${var.rolling_updates == "true" ? 1 : 0}"
#   depends_on    = ["aws_launch_configuration.main"]
#   name          = "${var.prefix}-asg"
#   template_body = "${data.template_file.main.rendered}"
# }

# data "template_file" "main" {
#   template = "${file("${path.module}/cloudformation.yml")}"

#   vars {
#     prefix               = "${var.prefix}"
#     environment          = "${var.environment}"
#     launch_configuration = "${aws_launch_configuration.main.name}"
#     min_size             = "${var.instance_count}"
#     max_size             = "${var.instance_count + 2}"
#     subnets              = "${jsonencode(var.subnet_ids)}"
#   }
# }

# data "aws_autoscaling_groups" "main" {
#   # The join() hack is required because currently the ternary operator
#   # evaluates the expressions on both branches of the condition before
#   # returning a value. When providing and external VPC, the template VPC
#   # resource gets a count of zero which triggers an evaluation error.
#   #
#   # Copied from:
#   # https://github.com/coreos/tectonic-installer/blob/master/modules/aws/vpc/vpc.tf
#   #
#   # Hardcoding the ASG name for Cloudformation here because the type of ["AsgName"]
#   # cannot be inferred when the list is empty. I.e., need to update this if we change the stack name.

#   filter {
#     name = "auto-scaling-group"
#     values = [
#       "${var.rolling_updates == "true" ? join(" ", aws_cloudformation_stack.main.*.outputs.AsgName) : join(" ", aws_autoscaling_group.main.*.id)}"
#     ]
#   }
# }

# ------------------------------------------------------------------------------
# Output
# ------------------------------------------------------------------------------
# output "id" {
#   value = "${element(data.aws_autoscaling_groups.main.names, 0)}"
# }

output "id" {
  value = "${aws_autoscaling_group.main.id}"
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
