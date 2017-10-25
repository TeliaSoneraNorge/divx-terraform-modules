# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
variable "prefix" {
  description = "A prefix used for naming resources."
}

variable "cluster_id" {
  description = "ID of an ECS cluster which the service will be deployed to."
}

variable "cluster_role" {
  description = "ID of the clusters IAM role (used for the instance profiles)."
}

variable "task_definition" {
  description = "ARN of a ECS task definition."
}

variable "task_log_group_arn" {
  description = "ARN of the tasks log group."
}

variable "container_count" {
  description = "Number of containers to run for the task."
  default     = "2"
}

variable "load_balancer" {
  description = "Configuration for the Service load balancer."
  type        = "map"
  default     = {}
}

variable "load_balanced" {
  description = "HACK: This exists purely to calculate count in Terraform. Set to false if you don't want a load balancer."
  default     = "true"
}

variable "tags" {
  description = "A map of tags (key-value pairs) passed to resources."
  type        = "map"
  default     = {}
}

# ------------------------------------------------------------------------------
# Resources
# ------------------------------------------------------------------------------
data "aws_caller_identity" "current" {}

data "aws_region" "current" {
  current = true
}

resource "aws_ecs_service" "lb" {
  count = "${var.load_balanced == "true" ? 1 : 0}"
  depends_on      = ["aws_iam_role.service"]
  name            = "${var.prefix}"
  cluster         = "${var.cluster_id}"
  task_definition = "${var.task_definition}"
  desired_count   = "${var.container_count}"
  iam_role        = "${aws_iam_role.service.arn}"

  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200

  # NOTE: load_balancer variable could not be passed directly to the service.
  # (Tried and got errors about container_name and port not being defined)
  load_balancer {
    target_group_arn = "${var.load_balancer["target_group_arn"]}"
    container_name   = "${var.load_balancer["container_name"]}"
    container_port   = "${var.load_balancer["container_port"]}"
  }

  placement_strategy {
    type  = "spread"
    field = "instanceId"
  }
}

resource "aws_ecs_service" "no_lb" {
  count = "${var.load_balanced == "true" ? 0 : 1}"
  name            = "${var.prefix}"
  cluster         = "${var.cluster_id}"
  task_definition = "${var.task_definition}"
  desired_count   = "${var.container_count}"

  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200

  placement_strategy {
    type  = "spread"
    field = "instanceId"
  }
}

resource "aws_iam_role" "service" {
  count = "${var.load_balanced == "true" ? 1 : 0}"
  name               = "${var.prefix}-service-role"
  assume_role_policy = "${data.aws_iam_policy_document.service_assume.json}"
}

resource "aws_iam_role_policy" "service_permissions" {
  count = "${var.load_balanced == "true" ? 1 : 0}"
  name   = "${var.prefix}-service-permissions"
  role   = "${aws_iam_role.service.id}"
  policy = "${data.aws_iam_policy_document.service_permissions.json}"
}

resource "aws_iam_role_policy" "log_agent" {
  name   = "${var.prefix}-log-permissions"
  role   = "${var.cluster_role}"
  policy = "${data.aws_iam_policy_document.task_log.json}"
}

# ------------------------------------------------------------------------------
# Output
# ------------------------------------------------------------------------------
output "arn" {
  value = "${lookup(var.load_balancer, "container_name", "") == "" ? aws_ecs_service.no_lb.arn : aws_ecs_service.lb.arn}"
}

output "role_arn" {
  value = "${aws_iam_role.service.arn}"
}

output "role_id" {
  value = "${aws_iam_role.service.id}"
}
