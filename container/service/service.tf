# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
variable "prefix" {
  description = "A prefix used for naming resources."
}

variable "vpc_id" {
  description = "The ID of the VPC that this container will run in, needed for the Target Group"
}

variable "cluster_role_id" {
  description = "The ID of EC2 Instance profile IAM Role for cluster instances "
}

variable "cluster_id" {
  description = "ID of an ECS cluster which the service will be deployed to."
}

variable "container_count" {
  description = "Number of containers to run for the task."
  default     = "2"
}

variable "container_port" {
  description = "The ID of the VPC that this container will run in, needed for the Target Group"
}

variable "container_health_check_grace_period" {
  description = "Number of seconds grace to give the service's health check before reporting unhealthy."
  default     = "0"
}

variable "load_balancer_arn" {
  description = "The ARN of the load balancer that will forward requests to this service "
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


# HACK: If we don't depend on this the target group is created and associated with the service before
# the LB is ready and listeners are attached. Which fails, see https://github.com/hashicorp/terraform/issues/12634.
resource "null_resource" "alb_exists" {
  triggers {
    alb_name = "${var.alb_arn}"
  }
}

# Create a target group with listeners.
module "targetgroup" {
  source = "../target"

  prefix            = "${var.prefix}"
  vpc_id            = "${var.vpc_id}"
  load_balancer_arn = "${var.load_balancer_arn}"

  target {
    protocol = "HTTP"
    port     = "${var.container_port}"
    health   = "HTTP:traffic-port/"
  }

  tags = "${var.tags}"
}

# Create a task definition for the service.
resource "aws_cloudwatch_log_group" "main" {
  name = "${var.prefix}"
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
      "ContainerPort": ${var.container_port}
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

 resource "aws_ecs_service" "lb" {
  depends_on = ["null_resource.alb_exists", "aws_iam_role.service"]
  name                              = "${var.prefix}"
  cluster                           = "${var.cluster_id}"
  task_definition                   = "${aws_ecs_task_definition.main.arn}"
  desired_count                     = "${var.container_count}"
  iam_role                          = "${aws_iam_role.service.arn}"
  health_check_grace_period_seconds = "${var.container_health_check_grace_period}"

  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200

  # NOTE: load_balancer variable could not be passed directly to the service.
  # (Tried and got errors about container_name and port not being defined)
  load_balancer {
    target_group_arn = "${module.targetgroup.target_group_arn}"
    container_name   = "${var.prefix}"
    container_port   = "${var.container_port}"
  }

  placement_strategy {
    type  = "spread"
    field = "instanceId"
  }
}

resource "aws_iam_role" "service" {
  count              = "${var.load_balanced == "true" ? 1 : 0}"
  name               = "${var.prefix}-service-role"
  assume_role_policy = "${data.aws_iam_policy_document.service_assume.json}"
}

resource "aws_iam_role_policy" "service_permissions" {
  count  = "${var.load_balanced == "true" ? 1 : 0}"
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
  value = "${element(concat(aws_ecs_service.lb.*.id, aws_ecs_service.no_lb.*.id), 0)}"
}

output "role_arn" {
  value = "${element(concat(aws_iam_role.service.*.arn, list("")), 0)}"
}

output "role_id" {
  value = "${element(concat(aws_iam_role.service.*.id, list("")), 0)}"
}

 output "target_group_arn" {
   value = "${module.targetgroup.target_group_arn}"
 }
