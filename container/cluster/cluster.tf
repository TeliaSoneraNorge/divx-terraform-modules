# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
variable "prefix" {
  description = "A prefix used for naming resources."
}

variable "vpc_id" {
  description = "ID of the VPC for the subnets."
}

variable "subnet_ids" {
  description = "ID of subnets where bastion can be provisioned."
  type        = "list"
}

variable "ingress" {
  description = "Map of security groups which will be granted ingress on the specified ports (port = sg id). If a port of 0 is specified, the dynamic range used by ECS is opened instead."
  default     = {}
}

variable "image_version" {
  description = "Docker image version."
  default     = "latest"
}

variable "instance_ami" {
  description = "ID of a CoreOS AMI for the instances."
  default     = "ami-417abe38"
}

variable "instance_type" {
  description = "Type of instance to provision."
  default     = "t2.micro"
}

variable "instance_count" {
  description = "Desired (and minimum) number of instances."
  default     = "2"
}

variable "instance_key" {
  description = "Name of an EC2 key-pair for SSH access."
  default     = ""
}

variable "ecs_log_level" {
  description = "Log level for the ECS agent."
  default     = "info"
}

variable "tags" {
  description = "A map of tags (key/value)."
  type        = "map"
  default     = {}
}

# ------------------------------------------------------------------------------
# Resources
# ------------------------------------------------------------------------------
data "aws_region" "current" {
  current = true
}

resource "aws_ecs_cluster" "main" {
  name = "${var.prefix}-cluster"
}

resource "aws_cloudwatch_log_group" "main" {
  name = "${var.prefix}-cluster-agent"
}

data "template_file" "main" {
  template = "${file("${path.module}/cloud-config.yml")}"

  vars {
    aws_region         = "${data.aws_region.current.name}"
    ecs_cluster_name   = "${aws_ecs_cluster.main.name}"
    ecs_log_level      = "${var.ecs_log_level}"
    ecs_agent_version  = "${var.image_version}"
    ecs_log_group_name = "${aws_cloudwatch_log_group.main.name}"
  }
}

data "aws_iam_policy_document" "permissions" {
  # TODO: Restrict privileges to specific ECS services.
  statement {
    effect    = "Allow"
    resources = ["*"]

    actions = [
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:GetRepositoryPolicy",
      "ecr:DescribeRepositories",
      "ecr:ListImages",
      "ecr:DescribeImages",
      "ecr:BatchGetImage",
      "ecs:CreateCluster",
      "ecs:DeregisterContainerInstance",
      "ecs:DiscoverPollEndpoint",
      "ecs:Poll",
      "ecs:RegisterContainerInstance",
      "ecs:StartTelemetrySession",
      "ecs:Submit*",
    ]
  }

  statement {
    effect = "Allow"

    resources = [
      "${aws_cloudwatch_log_group.main.arn}",
    ]

    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
  }
}

module "asg" {
  source          = "../../ec2/asg"
  prefix          = "${var.prefix}-cluster"
  user_data       = "${data.template_file.main.rendered}"
  vpc_id          = "${var.vpc_id}"
  subnet_ids      = "${var.subnet_ids}"
  instance_policy = "${data.aws_iam_policy_document.permissions.json}"
  instance_count  = "${var.instance_count}"
  instance_type   = "${var.instance_type}"
  instance_ami    = "${var.instance_ami}"
  instance_key    = "${var.instance_key}"
  tags            = "${var.tags}"
}

locals {
  ports = "${keys(var.ingress)}"
  sources = "${values(var.ingress)}"
}

resource "aws_security_group_rule" "ingress" {
  count                    = "${length(var.ingress)}"
  type                     = "ingress"
  security_group_id        = "${module.asg.security_group_id}"
  protocol                 = "tcp"
  from_port                = "${element(local.ports, count.index) == "0" ? "32768" : element(local.ports, count.index)}"
  to_port                  = "${element(local.ports, count.index) == "0" ? "65535" : element(local.ports, count.index)}"
  source_security_group_id = "${element(local.sources, count.index)}"
}

# ------------------------------------------------------------------------------
# Output
# ------------------------------------------------------------------------------
output "id" {
  value = "${aws_ecs_cluster.main.id}"
}

output "asg_id" {
  value = "${module.asg.id}"
}

output "role_name" {
  value = "${module.asg.role_name}"
}

output "role_arn" {
  value = "${module.asg.role_arn}"
}

output "role_id" {
  value = "${module.asg.role_id}"
}

output "security_group_id" {
  value = "${module.asg.security_group_id}"
}
