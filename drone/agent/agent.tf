# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
variable "prefix" {
  description = "A prefix used for naming resources."
}

variable "domain" {
  description = "The domain name to associate with the Drone ELB. (Must have an ACM certificate)."
}

variable "cluster_id" {
  description = "ID of an ECS cluster which the service will be deployed to."
}

variable "cluster_role" {
  description = "ID of the clusters IAM role (used for the instance profiles)."
}

variable "task_count" {
  description = "Desired (and minimum) number of instances."
}

variable "drone_secret" {
  description = "Shared secret used to authenticate agents with the Drone server. (KMS Encrypted)."
}

variable "tags" {
  description = "A map of tags (key-value pairs) passed to resources."
  type        = "map"
  default     = {}
}

# ------------------------------------------------------------------------------
# Resources
# ------------------------------------------------------------------------------
data "aws_region" "current" {
  current = true
}

module "agent" {
  source = "../../container/service"

  prefix             = "${var.prefix}-agent"
  cluster_id         = "${var.cluster_id}"
  cluster_role       = "${var.cluster_role}"
  task_definition    = "${aws_ecs_task_definition.agent.arn}"
  task_log_group_arn = "${aws_cloudwatch_log_group.agent.arn}"
  container_count    = "${var.task_count}"
  tags               = "${var.tags}"
}

resource "aws_ecs_task_definition" "agent" {
  family                = "${var.prefix}-agent"
  container_definitions = "${data.template_file.agent.rendered}"
  task_role_arn         = "${aws_iam_role.agent.arn}"

  volume {
    name      = "docker-socket"
    host_path = "/var/run/docker.sock"
  }
}

data "template_file" "agent" {
  template = "${file("${path.module}/agent.json")}"

  vars {
    name           = "${var.prefix}-agent"
    version        = "latest"
    log_group      = "${aws_cloudwatch_log_group.agent.name}"
    region         = "${data.aws_region.current.name}"
    drone_server   = "${var.domain}:9000"
    drone_secret   = "${var.drone_secret}"
    docker_api_ver = "1.24"
  }
}

resource "aws_cloudwatch_log_group" "agent" {
  name = "${var.prefix}-agent"
}

resource "aws_iam_role" "agent" {
  name               = "${var.prefix}-agent-task-role"
  assume_role_policy = "${data.aws_iam_policy_document.agent_assume.json}"
}

data "aws_iam_policy_document" "agent_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# ------------------------------------------------------------------------------
# Output
# ------------------------------------------------------------------------------

