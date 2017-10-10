# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
variable "prefix" {
  description = "A prefix used for naming resources."
}

variable "vpc_id" {
  description = "ID of the VPC for the subnet."
}

variable "subnet_id" {
  description = "ID of a subnet where cluster will be provisioned."
}

variable "applications" {
  description = "List of applications for the EMR cluster."
  type        = "list"
}

variable "configurations" {
  description = "Optional: JSON configuration for the EMR cluster."
  default     = ""
}

variable "master_instance_type" {
  description = "Optional: Type of master instance to provision."
  default     = "m3.xlarge"
}

variable "core_instance_type" {
  description = "Optional: Type of core instance to provision."
  default     = "m3.xlarge"
}

variable "core_instance_count" {
  description = "Number of core instances."
  default     = "2"
}

variable "instance_key" {
  description = "Name of an EC2 key-pair for SSH access."
  default     = ""
}

variable "instance_policy" {
  description = "A policy document which is applied to the instance profile."
  default     = ""
}

variable "keep_alive" {
  description = "Keep cluster alive after job flows finish running."
  default     = "false"
}

variable "tags" {
  description = "A map of tags (key-value pairs) passed to resources."
  type        = "map"
  default     = {}
}

# ------------------------------------------------------------------------------
# Resources
# ------------------------------------------------------------------------------
resource "aws_iam_role" "service" {
  name               = "${var.prefix}-emr-service-role"
  assume_role_policy = "${data.aws_iam_policy_document.service.json}"
}

data "aws_iam_policy_document" "service" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["elasticmapreduce.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "service" {
  role       = "${aws_iam_role.service.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonElasticMapReduceRole"
}

resource "aws_iam_role" "instance" {
  name               = "${var.prefix}-emr-instance-role"
  assume_role_policy = "${data.aws_iam_policy_document.instance.json}"
}

data "aws_iam_policy_document" "instance" {
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
  name = "${var.prefix}-emr-instance-profile"
  role = "${aws_iam_role.instance.name}"
}

resource "aws_iam_role_policy" "main" {
  count  = "${var.instance_policy == "" ? 0 : 1}"
  name   = "${var.prefix}-emr-permissions"
  role   = "${aws_iam_role.instance.id}"
  policy = "${var.instance_policy}"
}

resource "aws_security_group" "master" {
  name        = "${var.prefix}-emr-master-sg"
  description = "Terraformed security group."
  vpc_id      = "${var.vpc_id}"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    ignore_changes = ["ingress", "egress"]
  }

  tags = "${merge(var.tags, map("Name", "${var.prefix}-emr-master-sg"))}"
}

resource "aws_security_group" "core" {
  name        = "${var.prefix}-emr-core-sg"
  description = "Terraformed security group."
  vpc_id      = "${var.vpc_id}"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    ignore_changes = ["ingress", "egress"]
  }

  tags = "${merge(var.tags, map("Name", "${var.prefix}-emr-core-sg"))}"
}

resource "aws_emr_cluster" "main" {
  name                              = "${var.prefix}-emr"
  release_label                     = "emr-4.6.0"
  applications                      = ["${var.applications}"]
  configurations                    = "${var.configurations}"
  service_role                      = "${aws_iam_role.service.arn}"
  master_instance_type              = "${var.master_instance_type}"
  core_instance_type                = "${var.core_instance_type}"
  core_instance_count               = "${var.core_instance_count}"
  termination_protection            = "false"
  keep_job_flow_alive_when_no_steps = "${var.keep_alive}"

  ec2_attributes {
    key_name                          = "${var.instance_key}"
    emr_managed_master_security_group = "${aws_security_group.master.id}"
    emr_managed_slave_security_group  = "${aws_security_group.core.id}"
    subnet_id                         = "${var.subnet_id}"
    instance_profile                  = "${aws_iam_instance_profile.main.arn}"
  }

  tags = "${merge(var.tags, map("Name", "${var.prefix}-emr"))}"
}

# ------------------------------------------------------------------------------
# Output
# ------------------------------------------------------------------------------
output "service_role_name" {
  value = "${aws_iam_role.service.name}"
}

output "service_role_arn" {
  value = "${aws_iam_role.service.arn}"
}

output "service_role_id" {
  value = "${aws_iam_role.service.id}"
}

output "instance_role_name" {
  value = "${aws_iam_role.instance.name}"
}

output "instance_role_arn" {
  value = "${aws_iam_role.instance.arn}"
}

output "instance_role_id" {
  value = "${aws_iam_role.instance.id}"
}

output "master_security_group_id" {
  value = "${aws_security_group.master.id}"
}

output "core_security_group_id" {
  value = "${aws_security_group.core.id}"
}

output "dns_name" {
  value = "${aws_emr_cluster.main.master_public_dns}"
}
