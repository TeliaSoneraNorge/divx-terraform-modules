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

variable "listener_rule" {
  description = "Listener rule block containing the listener arn, type and values."
  type        = "map"
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
