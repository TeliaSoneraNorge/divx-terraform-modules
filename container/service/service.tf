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

variable "cluster_id" {
  description = "ID of an ECS cluster which the service will be deployed to."
}

variable "cluster_sg" {
  description = "ID of the security group associated with the cluster."
}

variable "cluster_role" {
  description = "ID of the clusters IAM role (used for the instance profiles)."
}

variable "load_balancer_name" {
  description = "The name of a load balancer used with the service (classic or application)."
}

variable "load_balancer_sg" {
  description = "Id of the security group for the load balancer used for the service."
}

variable "vpc_id" {
  description = "Optional: ID of a VPC where the target group (optional) will be registered."
  default     = ""
}

variable "port_mapping" {
  description = "A map of instance to container port mappings (host port = container port). Supports only one mapping when using an ALB (enabled by setting host port to 0)."
  default     = {}
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

# ------------------------------------------------------------------------------
# Resources
# ------------------------------------------------------------------------------
data "aws_caller_identity" "current" {}

data "aws_region" "current" {
  current = true
}

resource "aws_alb_target_group" "main" {
  count       = "${contains(keys(var.port_mapping), "0") ? 1 : 0}"
  vpc_id      = "${var.vpc_id}"
  port        = "${element(values(var.port_mapping), 0)}"
  protocol    = "HTTP"

  /**
    * NOTE: TF is unable to destroy a target group while a listener is attached,
    * therefor we have to create a new one before destroying the old. This also means
    * we have to let it have a random name, and then tag it with the desired name.
    */
  lifecycle {
    create_before_destroy = true
  }

  tags {
    Name        = "${var.prefix}-target"
    terraform   = "true"
    environment = "${var.environment}"
  }
}

resource "aws_ecs_service" "elb" {
  count           = "${length(var.port_mapping) > 0 ? 1 : 0}"
  depends_on      = ["aws_iam_role.service"]
  name            = "${var.prefix}"
  cluster         = "${var.cluster_id}"
  task_definition = "${var.task_definition}"
  desired_count   = "${var.container_count}"
  iam_role        = "${aws_iam_role.service.arn}"

  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200

  load_balancer {
    // Don't set load_balancer if we want a target_group. (But load_balancer is still required for scoping privileges).
    elb_name         = "${contains(keys(var.port_mapping), "0") ? "" : var.load_balancer_name}"
    target_group_arn = "${contains(keys(var.port_mapping), "0") ? aws_alb_target_group.main.arn : ""}"
    container_name   = "${var.prefix}"
    container_port   = "${element(values(var.port_mapping), 0)}"
  }

  placement_strategy {
    type  = "spread"
    field = "instanceId"
  }
}

resource "aws_iam_role" "service" {
  count              = "${length(var.port_mapping) > 0 ? 1 : 0}"
  name               = "${var.prefix}-service-role"
  assume_role_policy = "${data.aws_iam_policy_document.service_assume.json}"
}

resource "aws_iam_role_policy" "service_permissions" {
  count  = "${length(var.port_mapping) > 0 ? 1 : 0}"
  name   = "${var.prefix}-service-permissions"
  role   = "${aws_iam_role.service.id}"
  policy = "${data.aws_iam_policy_document.service_permissions.json}"
}

// Open dynamic port mapping range if using an ALB
resource "aws_security_group_rule" "dynamic_port_mapping" {
  count                    = "${contains(keys(var.port_mapping), "0") ? 1 : 0}"
  type                     = "ingress"
  security_group_id        = "${var.cluster_sg}"
  protocol                 = "tcp"
  from_port                = 32768
  to_port                  = 65535
  source_security_group_id = "${var.load_balancer_sg}"
}

// Open individual ports if using a classic ELB
resource "aws_security_group_rule" "static_port_mapping" {
  count                    = "${contains(keys(var.port_mapping), "0") ? 0 : length(var.port_mapping)}"
  type                     = "ingress"
  security_group_id        = "${var.cluster_sg}"
  protocol                 = "tcp"
  from_port                = "${element(keys(var.port_mapping), count.index)}"
  to_port                  = "${element(keys(var.port_mapping), count.index)}"
  source_security_group_id = "${var.load_balancer_sg}"
}

// Support no port mapping.
resource "aws_ecs_service" "no_elb" {
  count           = "${length(var.port_mapping) > 0 ? 0 : 1}"
  depends_on      = ["aws_iam_role.service"]
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

resource "aws_iam_role_policy" "log_agent" {
  name   = "${var.prefix}-log-permissions"
  role   = "${var.cluster_role}"
  policy = "${data.aws_iam_policy_document.task_log.json}"
}

# ------------------------------------------------------------------------------
# Output
# ------------------------------------------------------------------------------
output "arn" {
  value = "${length(var.port_mapping) > 0 ? "${aws_ecs_service.elb.id}" : "${aws_ecs_service.no_elb.id}"}"
}

output "role_arn" {
  value = "${aws_iam_role.service.arn}"
}

output "role_id" {
  value = "${aws_iam_role.service.id}"
}

output "target_group_arn" {
  value = "${contains(keys(var.port_mapping), "0") ? aws_alb_target_group.main.arn : "NONE"}"
}
