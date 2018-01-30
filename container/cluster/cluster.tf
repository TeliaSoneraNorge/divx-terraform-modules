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

variable "instance_ami" {
  description = "ID of a Amazon Linux ECS optimized AMI for the instances."
  default     = "ami-1d46df64"
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

variable "ingress" {
  description = "Map (port = source_security_group_id) which will be allowed to ingress the cluster."
  type        = "map"
  default     = {}
}

variable "ingress_length" {
  description = "HACK: This exists purely to calculate count in Terraform. Should equal the length of your ingress map."
  default     = 0
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
    region           = "${data.aws_region.current.name}"
    stack_name       = "${var.prefix}-cluster-asg"
    log_group_name   = "${aws_cloudwatch_log_group.main.name}"
    ecs_cluster_name = "${aws_ecs_cluster.main.name}"
    ecs_log_level    = "${var.ecs_log_level}"
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
      "logs:CreateLogGroup",
      "logs:PutLogEvents",
    ]
  }
}

module "asg" {
  source            = "../../ec2/asg"
  prefix            = "${var.prefix}-cluster"
  user_data         = "${data.template_file.main.rendered}"
  vpc_id            = "${var.vpc_id}"
  subnet_ids        = "${var.subnet_ids}"
  await_signal      = "true"
  pause_time        = "PT5M"
  health_check_type = "EC2"
  instance_policy   = "${data.aws_iam_policy_document.permissions.json}"
  instance_count    = "${var.instance_count}"
  instance_type     = "${var.instance_type}"
  instance_ami      = "${var.instance_ami}"
  instance_key      = "${var.instance_key}"
  tags              = "${var.tags}"
}

resource "aws_security_group_rule" "ingress" {
  count                    = "${var.ingress_length}"
  security_group_id        = "${module.asg.security_group_id}"
  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = "${element(keys(var.ingress), count.index) == "0" ? "32768" : element(keys(var.ingress), count.index)}"
  to_port                  = "${element(keys(var.ingress), count.index) == "0" ? "65535" : element(keys(var.ingress), count.index)}"
  source_security_group_id = "${element(values(var.ingress), count.index)}"
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
