# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
variable "prefix" {
  description = "A prefix used for naming resources."
}

variable "type" {
  description = "Type of load balancer to provision (network or application)."
}

variable "internal" {
  description = "Provision an internal load balancer. Defaults to false."
  default     = "false"
}

variable "vpc_id" {
  description = "ID of the VPC for the subnets."
}

variable "subnet_ids" {
  description = "ID of subnets which will be attached to the load balancer."
  type        = "list"
}

variable "tags" {
  description = "A map of tags (key-value pairs) passed to resources."
  type        = "map"
  default     = {}
}
