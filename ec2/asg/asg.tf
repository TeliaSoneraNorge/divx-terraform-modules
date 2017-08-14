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

variable "load_balancers" {
  description = "List of load balancers to add to the ASG."
  type        = "list"
  default     = []
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

variable "rolling_updates" {
  description = "Flag for rolling updates. Requires that the Autoscaling group is set up in Cloudformation."
  default     = "false"
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

resource "aws_launch_configuration" "main" {
  name_prefix          = "${var.prefix}-config-"
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
  count                = "${var.rolling_updates == "false" ? 1 : 0}"
  name                 = "${aws_launch_configuration.main.name}"
  desired_capacity     = "${var.instance_count}"
  min_size             = "${var.instance_count}"
  max_size             = "${var.instance_count + 1}"
  launch_configuration = "${aws_launch_configuration.main.name}"
  load_balancers       = ["${var.load_balancers}"]
  vpc_zone_identifier  = ["${var.subnet_ids}"]


  tag {
    key                 = "Name"
    value               = "${var.prefix}"
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

# Rolling updates
resource "aws_cloudformation_stack" "main" {
  count         = "${var.rolling_updates == "true" ? 1 : 0}"
  depends_on    = ["aws_launch_configuration.main"]
  name          = "${var.prefix}-asg"
  template_body = "${data.template_file.main.rendered}"
}

data "template_file" "main" {
  template = "${file("${path.module}/cloudformation.yml")}"

  vars {
    prefix               = "${var.prefix}"
    environment          = "${var.environment}"
    launch_configuration = "${aws_launch_configuration.main.name}"
    min_size             = "${var.instance_count}"
    max_size             = "${var.instance_count + 2}"
    subnets              = "${jsonencode(var.subnet_ids)}"
    load_balancers       = "${join("", var.load_balancers) == "" ? "" : "LoadBalancerNames: ${jsonencode(var.load_balancers)}"}"
  }
}

# ------------------------------------------------------------------------------
# Output
# ------------------------------------------------------------------------------
output "role_arn" {
  value = "${aws_iam_role.main.arn}"
}

output "role_id" {
  value = "${aws_iam_role.main.id}"
}

output "security_group_id" {
  value = "${aws_security_group.main.id}"
}
