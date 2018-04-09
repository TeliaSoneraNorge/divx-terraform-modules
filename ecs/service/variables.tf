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

variable "task_definition_image" {
  description = "Image for the task definition (repo:tag or repo@digest)."
}

variable "task_definition_cpu" {
  description = "Optional: Amount of CPU to reserve for the task."
  default     = "256"
}

variable "task_definition_ram" {
  description = "Optional: Amount of RAM to reserve for the task."
  default     = "512"
}

variable "task_definition_command" {
  description = "Optional: List of command arguments that are passed when invoking the command."
  default     = []
}

variable "task_definition_environment" {
  description = "Optional: Map of key = value pairs for the environment."
  default     = {}
}

variable "task_definition_environment_count" {
  description = "Required if task_definition_environment is used : Number of environment variables in task_definition_environment."
  default     = "0"
}

variable "task_definition_health_check_grace_period" {
  description = "Optional: Grace period health checks on initial start-up - to stop slow tasks from being killed too early"
  default = "0"
}

variable "tags" {
  description = "A map of tags (key-value pairs) passed to resources."
  type        = "map"
  default     = {}
}
