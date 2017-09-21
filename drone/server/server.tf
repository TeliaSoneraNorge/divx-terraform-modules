# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
variable "prefix" {
  description = "A prefix used for naming resources."
}

variable "environment" {
  description = "Environment tag which is applied to resources."
}

variable "domain" {
  description = "The domain name to associate with the Drone ELB. (Must have an ACM certificate)."
}

variable "cluster_id" {
  description = "ID of an ECS cluster which the service will be deployed to."
}

variable "cluster_sg" {
  description = "Optional: ID of the security group associated with the cluster."
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

variable "postgres_connection" {
  description = "Connection string for the postgres backend."
}

variable "drone_secret" {
  description = "Shared secret used to authenticate agents with the Drone server. (KMS Encrypted)."
}

variable "drone_github_org" {
  description = "Drone Github organization which is allowed to create users."
}

variable "drone_github_admins" {
  description = "Github usernames which are allowed to administrate Drone."
  type        = "list"
}

variable "drone_github_client" {
  description = "Drone Github client."
}

variable "drone_github_secret" {
  description = "Drone Github secret."
}

# ------------------------------------------------------------------------------
# Resources
# ------------------------------------------------------------------------------
data "aws_region" "current" {
  current = true
}

module "server" {
  source = "../../container/service"

  prefix             = "${var.prefix}-server"
  environment        = "${var.environment}"
  cluster_id         = "${var.cluster_id}"
  cluster_sg         = "${var.cluster_sg}"
  cluster_role       = "${var.cluster_role}"
  load_balancer_name = "${var.load_balancer_name}"
  load_balancer_sg   = "${var.load_balancer_sg}"
  task_definition    = "${aws_ecs_task_definition.server.arn}"
  task_log_group_arn = "${aws_cloudwatch_log_group.server.arn}"
  container_count    = "1"

  port_mapping = {
    "8000" = "8000",
  }
}

resource "aws_ecs_task_definition" "server" {
  family                = "${var.prefix}-server"
  container_definitions = "${data.template_file.server.rendered}"
  task_role_arn         = "${aws_iam_role.server.arn}"

  volume {
    name      = "drone-volume"
    host_path = "/var/lib/drone"
  }
}

data "template_file" "server" {
  template   = "${file("${path.module}/server.json")}"

  vars {
    name                = "${var.prefix}-server"
    version             = "latest"
    log_group           = "${aws_cloudwatch_log_group.server.name}"
    region              = "${data.aws_region.current.name}"
    drone_secret        = "${var.drone_secret}"
    drone_host          = "https://${var.domain}"
    database_driver     = "postgres"
    database_datasource = "${var.postgres_connection}?sslmode=disable"
    github_org          = "${var.drone_github_org}"
    github_admins       = "${join(",", var.drone_github_admins)}"
    github_client       = "${var.drone_github_client}"
    github_secret       = "${var.drone_github_secret}"
  }
}

resource "aws_cloudwatch_log_group" "server" {
  name = "${var.prefix}-server"
}

resource "aws_iam_role" "server" {
  name               = "${var.prefix}-server-task-role"
  assume_role_policy = "${data.aws_iam_policy_document.assume.json}"
}

data "aws_iam_policy_document" "assume" {
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
