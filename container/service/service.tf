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

variable "target_group" {
  description = "Optional: Create a target group for use with an application load balancer. (Does not create listener rules)."
  default     = "true"
}

variable "image_repository" {
  description = "Docker image repository."
}

variable "image_version" {
  description = "Optional: ECS image version."
  default     = "latest"
}

variable "container_count" {
  description = "Number of containers to run for the task."
  default     = "2"
}

variable "container_cpu" {
  description = "CPU reservation for the container."
}

variable "container_memory" {
  description = "Memory reservation for the container."
}

variable "container_ports" {
  description = "A map of instance to container port mappings (host port = container port)."
  default     = {}
}

variable "container_policy" {
  description = "Optional: IAM inline policy added to the container (task) role."
  default     = ""
}

# ------------------------------------------------------------------------------
# Resources
# ------------------------------------------------------------------------------
data "aws_caller_identity" "current" {}

data "aws_region" "current" {
  current = true
}

resource "aws_alb_target_group" "main" {
  count       = "${var.target_group == "true" ? 1 : 0}"
  vpc_id      = "${var.vpc_id}"
  port        = "${element(values(var.container_ports), count.index)}"
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

resource "aws_ecs_service" "main" {
  depends_on      = ["aws_iam_role.service"]
  name            = "${var.prefix}"
  cluster         = "${var.cluster_id}"
  task_definition = "${aws_ecs_task_definition.main.arn}"
  desired_count   = "${var.container_count}"
  iam_role        = "${aws_iam_role.service.arn}"

  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200

  load_balancer {
    // Don't set load_balancer if we want a target_group. (But load_balancer is still required for scoping privileges).
    elb_name         = "${var.target_group == "true" ? "" : var.load_balancer_name}"
    target_group_arn = "${var.target_group != "true" ? "" : aws_alb_target_group.main.arn}"
    container_name   = "${var.prefix}"
    container_port   = "${element(values(var.container_ports), 0)}"
  }

  placement_strategy {
    type  = "spread"
    field = "instanceId"
  }
}

resource "aws_ecs_task_definition" "main" {
  depends_on            = ["data.template_file.main"]
  family                = "${var.prefix}"
  container_definitions = "${data.template_file.main.rendered}"
  task_role_arn         = "${aws_iam_role.task.arn}"
}

data "template_file" "main" {
  depends_on = ["data.template_file.ports"]
  template   = "${file("${path.module}/task.json")}"

  vars {
    name          = "${var.prefix}"
    repository    = "${var.image_repository}"
    version       = "${var.image_version}"
    cpu           = "${var.container_cpu}"
    memory        = "${var.container_memory}"
    port_mappings = "${join(",", data.template_file.ports.*.rendered)}"
    log_group     = "${aws_cloudwatch_log_group.main.name}"
    region        = "${data.aws_region.current.name}"
  }
}

data "template_file" "ports" {
  count = "${length(var.container_ports)}"

  vars {
    container_port = "${element(values(var.container_ports), count.index)}"
    host_port      = "${var.target_group == "true" ? 0 : element(keys(var.container_ports), count.index)}" // Use dynamic port mapping when we have a target group.
    protocol       = "tcp"                                                                                 // AWS load balancers do not support UDP.
  }

  template = <<EOF
{
  "containerPort": $${container_port},
  "hostPort": $${host_port},
  "protocol": "$${protocol}"
}
EOF
}

resource "aws_iam_role_policy" "log_agent" {
  name   = "${var.prefix}-log-permissions"
  role   = "${var.cluster_role}"
  policy = "${data.aws_iam_policy_document.task_log.json}"
}

resource "aws_cloudwatch_log_group" "main" {
  name = "${var.prefix}"
}

resource "aws_iam_role" "task" {
  name               = "${var.prefix}-task-role"
  assume_role_policy = "${data.aws_iam_policy_document.task_assume.json}"
}

resource "aws_iam_role_policy" "task_permissions" {
  count  = "${var.container_policy == "" ? 0 : 1}"
  name   = "${var.prefix}-task-permissions"
  role   = "${aws_iam_role.task.id}"
  policy = "${var.container_policy}"
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

// Open dynamic port mapping range if using an ALB
resource "aws_security_group_rule" "dynamic_port_mapping" {
  count                    = "${var.target_group == "true" ? 1 : 0}"
  type                     = "ingress"
  security_group_id        = "${var.cluster_sg}"
  protocol                 = "tcp"
  from_port                = 32768
  to_port                  = 65535
  source_security_group_id = "${var.load_balancer_sg}"
}

// Open individual ports if using a classic ELB
resource "aws_security_group_rule" "static_port_mapping" {
  count                    = "${var.target_group == "true" ? 0 : length(var.container_ports)}"
  type                     = "ingress"
  security_group_id        = "${var.cluster_sg}"
  protocol                 = "tcp"
  from_port                = "${element(keys(var.container_ports), count.index)}"
  to_port                  = "${element(keys(var.container_ports), count.index)}"
  source_security_group_id = "${var.load_balancer_sg}"
}

# ------------------------------------------------------------------------------
# Output
# ------------------------------------------------------------------------------
output "task_arn" {
  value = "${aws_ecs_task_definition.main.arn}"
}

output "task_role_arn" {
  value = "${aws_iam_role.task.arn}"
}

output "task_role_id" {
  value = "${aws_iam_role.task.id}"
}

output "service_arn" {
  value = "${aws_ecs_service.main.id}"
}

output "service_role_arn" {
  value = "${aws_iam_role.service.arn}"
}

output "service_role_id" {
  value = "${aws_iam_role.service.id}"
}

output "target_group_arn" {
  value = "${var.target_group == "true" ? aws_alb_target_group.main.arn : "NONE"}"
}
