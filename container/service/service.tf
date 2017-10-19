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

variable "load_balancer_name" {
  description = "Optional: The name of a load balancer used with the service (classic or application)."
  default     = ""
}

variable "load_balancer_arn" {
  description = "Optional: The ARN of a load balancer used with the service (network or application)."
  default     = ""
}

variable "vpc_id" {
  description = "Optional: ID of a VPC where the target group (optional) will be registered."
  default     = ""
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

variable "target" {
  description = "Configuration for the target group attached to the cluster."
  default     = {}
}

variable "health" {
  description = "Configuration for the health check for the target group."
  default     = {}
}

variable "listeners" {
  description = "Configuration of listeners for the load balancer which are forwarded to the target group."
  default     = {}
}

variable "tags" {
  description = "A map of tags (key-value pairs) passed to resources."
  type        = "map"
  default     = {}
}

# ------------------------------------------------------------------------------
# Resources
# ------------------------------------------------------------------------------
locals {
  default_target = {
    port              = ""
    protocol          = "TCP"
  }
  target = "${merge(local.default_target, var.target)}"

  default_health = {
    port              = "${local.target["port"]}"
    path              = "/"
    protocol          = "${local.target["protocol"]}"
  }
  health = "${merge(local.default_health, var.health)}"

  default_listeners = {
    http            = "false"
    https           = "false"
    tcp             = ""
    certificate_arn = ""
  }
  listeners = "${merge(local.default_listeners, var.listeners)}"
  tcp_ports = "${split(",", local.listeners["tcp"])}"
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {
  current = true
}

resource "aws_lb_target_group" "main" {
  depends_on = ["aws_iam_role_policy.service_permissions"]
  count      = "${local.target["port"] == "" ? 0 : 1}"
  vpc_id     = "${var.vpc_id}"
  port       = "${local.target["port"]}"
  protocol   = "${local.target["protocol"]}"

  health_check {
    path                = "${local.health["path"]}"
    port                = "${local.health["port"]}"
    protocol            = "${local.health["protocol"]}"
    interval            = "30"
    timeout             = "5"
    healthy_threshold   = "5"
    unhealthy_threshold = "2"
    matcher             = "200"
  }

  /**
  * NOTE: TF is unable to destroy a target group while a listener is attached,
  * therefor we have to create a new one before destroying the old. This also means
  * we have to let it have a random name, and then tag it with the desired name.
  */
  lifecycle {
    create_before_destroy = true
  }

  tags = "${merge(var.tags, map("Name", "${var.prefix}-target-${local.target["port"]}"))}"
}


resource "aws_lb_listener" "http" {
  depends_on        = ["aws_lb_target_group.main"]
  count             = "${local.listeners["http"] == "true" ? 1 : 0}"
  load_balancer_arn = "${var.load_balancer_arn}"
  port              = "80"
  protocol          = "http"

  default_action {
    target_group_arn = "${aws_lb_target_group.main.arn}"
    type             = "forward"
  }
}

resource "aws_lb_listener" "https" {
  depends_on        = ["aws_lb_target_group.main"]
  count             = "${local.listeners["https"] == "true" ? 1 : 0}"
  load_balancer_arn = "${var.load_balancer_arn}"
  port              = "80"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2015-05"
  certificate_arn   = "${local.targets["certificate_arn"]}"

  default_action {
    target_group_arn = "${aws_lb_target_group.main.arn}"
    type             = "forward"
  }
}

resource "aws_lb_listener" "tcp" {
  depends_on        = ["aws_lb_target_group.main"]
  count             = "${length(local.tcp_ports)}"
  load_balancer_arn = "${var.load_balancer_arn}"
  port              = "${element(local.tcp_ports, count.index)}"
  protocol          = "tcp"

  default_action {
    target_group_arn = "${aws_lb_target_group.main.arn}"
    type             = "forward"
  }
}

resource "aws_ecs_service" "lb" {
  depends_on      = ["aws_iam_role.service", "aws_lb_target_group.main"]
  count           = "${local.target["port"] == "" ? 0 : 1}"
  name            = "${var.prefix}"
  cluster         = "${var.cluster_id}"
  task_definition = "${var.task_definition}"
  desired_count   = "${var.container_count}"
  iam_role        = "${aws_iam_role.service.arn}"

  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200

  load_balancer {
    target_group_arn = "${aws_lb_target_group.main.arn}"
    container_name   = "${var.prefix}"
    container_port   = "${var.target["port"]}"
  }

  placement_strategy {
    type  = "spread"
    field = "instanceId"
  }
}

resource "aws_ecs_service" "no_lb" {
  count           = "${local.target["port"] == "" ? 1 : 0}"
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
  count              = "${var.target["port"] == "" ? 0 : 1}"
  name               = "${var.prefix}-service-role"
  assume_role_policy = "${data.aws_iam_policy_document.service_assume.json}"
}

resource "aws_iam_role_policy" "service_permissions" {
  count  = "${var.target["port"] == "" ? 0 : 1}"
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
  value = "${local.target["port"] == "" ? aws_ecs_service.no_lb.arn : aws_ecs_service.lb.arn}"
}

output "role_arn" {
  value = "${aws_iam_role.service.arn}"
}

output "role_id" {
  value = "${aws_iam_role.service.id}"
}
