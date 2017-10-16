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
module "base" {
  source = "../"

  prefix          = "${var.prefix}"
  instance_policy = "${var.instance_policy}"
  instance_type   = "${var.instance_type}"
  instance_ami    = "${var.instance_ami}"
  instance_key    = "${var.instance_key}"
  user_data       = "${var.user_data}"
  tags            = "${var.tags}"
}

locals {
  asg_tags = "${merge(var.tags, map("Name", "${var.prefix}"))}"
}

data "null_data_source" "autoscaling" {
  count = "${length(local.asg_tags)}"

  inputs = {
    Key               = "${element(keys(local.asg_tags), count.index)}"
    Value             = "${element(values(local.asg_tags), count.index)}"
    PropagateAtLaunch = "true"
  }
}

data "template_file" "main" {
  template = "${file("${path.module}/cloudformation.yml")}"

  vars {
    prefix               = "${var.prefix}"
    launch_configuration = "${module.base.launch_configuration}"
    min_size             = "${var.instance_count}"
    max_size             = "${var.instance_count + 2}"
    subnets              = "${jsonencode(var.subnet_ids)}"
    tags                 = "${jsonencode(data.null_data_source.autoscaling.*.outputs)}"
  }
}

resource "aws_cloudformation_stack" "main" {
  depends_on    = ["module.base"]
  name          = "${var.prefix}-asg"
  template_body = "${data.template_file.main.rendered}"
}

# ------------------------------------------------------------------------------
# Output
# ------------------------------------------------------------------------------
output "id" {
  value = "${aws_cloudformation_stack.main.outputs["AsgId"]}"
}

output "role_name" {
  value = "${module.base.role_name}"
}

output "role_arn" {
  value = "${module.base.role_arn}"
}

output "role_id" {
  value = "${module.base.role_id}"
}

output "security_group_id" {
  value = "${module.base.security_group_id}"
}
