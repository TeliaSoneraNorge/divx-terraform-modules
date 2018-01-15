# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
variable "prefix" {
  description = "Prefix used for resource names."
}

variable "vpc_id" {
  description = "ID of the VPC for the subnets."
}

variable "public_subnet_ids" {
  description = "ID of subnets where Concourse will deploy public resources."
  type        = "list"
}

variable "private_subnet_ids" {
  description = "ID of subnets where Concourse will deploy private resources. (You can pass public subnets also)."
  type        = "list"
}

variable "concourse_version" {
  description = "Version of Concourse to download/run."
  default     = "3.8.0"
}

variable "concourse_keys" {
  description = "Path to a directory containing the Concourse SSH keys. (See README.md)."
}

variable "atc_sg" {
  description = "Security group ID for the ATC."
}

variable "tsa_host" {
  description = "Address of the TSA host. (Typically: Address of the internal load balancer for the ATC)."
}

variable "tsa_port" {
  description = "Port to use for reaching the TSA host."
}

variable "worker_team" {
  description = "Optional: The name of the Concourse team that these workers will be assigned to."
  default     = ""
}

variable "log_level" {
  description = "Concourse log level (debug|info|error|fatal) for ATC, TSA and Baggageclaim."
  default     = "info"
}

variable "instance_count" {
  description = "Number of ATC instances to provision."
  default     = "2"
}

variable "instance_type" {
  description = "Instance type to provision for the Concourse ATC."
  default     = "m5.large"
}

variable "instance_ami" {
  description = "Amazon AMI 2 (id) for Concourse instances."
}

variable "instance_key" {
  description = "EC2 key-pair for Concourse instances."
  default     = ""
}

variable "tags" {
  description = "A map of tags (key-value pairs) passed to resources."
  type        = "map"
  default     = {}
}
