# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
variable "prefix" {
  description = "A prefix used for naming resources."
}

variable "vpc_id" {
  description = "The ID of the VPC that this container will run in, needed for the Target Group"
}

variable "cluster_id" {
  description = "ID of an ECS cluster which the service will be deployed to."
}

variable "cluster_role_id" {
  description = "The ID of EC2 Instance profile IAM Role for cluster instances "
}

variable "target" {
  description = "A target block containing the protocol and port exposed on the container."
  type        = "map"
}

variable "health" {
  description = "A health block containing health check settings for the target group. Overrides the defaults."
  type        = "map"
}

variable "task_container_count" {
  description = "Number of containers to run for the task."
  default     = "2"
}

variable "task_definition_image_id" {
  description = "The ID of Cluster IAM Role "
}

variable "task_definition_cpu" {
  description = "The ID of Cluster IAM Role "
}

variable "task_definition_ram" {
  description = "The ID of Cluster IAM Role "
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

data "aws_region" "current" {}

module "target" {
  source = "../target"
  prefix = "${var.prefix}"
  vpc_id = "${var.vpc_id}"
  health = "${var.health}"

  # NOTE: Terraform failed to calculate count when passing the map directly.
  target {
    protocol      = "${var.target["protocol"]}"
    port          = "${var.target["port"]}"
    load_balancer = "${var.target["load_balancer"]}"
  }

  tags = "${var.tags}"
}

resource "aws_ecs_service" "main" {
  depends_on                        = ["aws_iam_role.service"]
  name                              = "${var.prefix}"
  cluster                           = "${var.cluster_id}"
  task_definition                   = "${aws_ecs_task_definition.main.arn}"
  desired_count                     = "${var.task_container_count}"
  iam_role                          = "${aws_iam_role.service.arn}"
  health_check_grace_period_seconds = "0"

  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200

  load_balancer {
    target_group_arn = "${module.target.target_group_arn}"
    container_name   = "${var.prefix}"
    container_port   = "${var.target["port"]}"
  }

  placement_strategy {
    type  = "spread"
    field = "instanceId"
  }
}

# NOTE: HostPort must be 0 to use dynamic port mapping.
resource "aws_ecs_task_definition" "main" {
  family = "${var.prefix}"

  container_definitions = <<EOF
[{
    "name": "${var.prefix}",
    "image": "${var.task_definition_image_id}",
    "cpu": ${var.task_definition_cpu},
    "memory": ${var.task_definition_ram},
    "essential": true,
    "portMappings": [{
      "HostPort": 0,
      "ContainerPort": ${var.target["port"]}
    }],
    "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
            "awslogs-group": "${aws_cloudwatch_log_group.main.name}",
            "awslogs-region": "${data.aws_region.current.name}",
            "awslogs-stream-prefix": "container"
        }
    }
}]
EOF
}

resource "aws_cloudwatch_log_group" "main" {
  name = "${var.prefix}"
}

resource "aws_iam_role" "service" {
  name               = "${var.prefix}-service-role"
  assume_role_policy = "${data.aws_iam_policy_document.service_assume.json}"
}

resource "aws_iam_role_policy" "service_permissions" {
  name   = "${var.prefix}-service-permissions"
  role   = "${aws_iam_role.service.id}"
  policy = "${data.aws_iam_policy_document.service_permissions.json}"
}

resource "aws_iam_role_policy" "log_agent" {
  name   = "${var.prefix}-log-permissions"
  role   = "${var.cluster_role_id}"
  policy = "${data.aws_iam_policy_document.task_log.json}"
}

# ------------------------------------------------------------------------------
# Output
# ------------------------------------------------------------------------------
output "arn" {
  value = "${aws_ecs_service.main.id}"
}

output "role_arn" {
  value = "${aws_iam_role.service.arn}"
}

output "role_id" {
  value = "${aws_iam_role.service.id}"
}

output "target_group_arn" {
  value = "${module.target.target_group_arn}"
}
