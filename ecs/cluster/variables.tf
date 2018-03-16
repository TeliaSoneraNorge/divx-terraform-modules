# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
variable "prefix" {
  description = "A prefix used for naming resources."
}

variable "vpc_id" {
  description = "ID of the VPC for the subnets."
}

variable "subnet_ids" {
  description = "ID of subnets where bastion can be provisioned."
  type        = "list"
}

variable "instance_ami" {
  description = "ID of a Amazon Linux ECS optimized AMI for the instances."
  default     = "ami-1d46df64"
}

variable "instance_type" {
  description = "Type of instance to provision."
  default     = "t2.micro"
}

variable "instance_count" {
  description = "Desired (and minimum) number of instances."
  default     = "2"
}

variable "instance_key" {
  description = "Name of an EC2 key-pair for SSH access."
  default     = ""
}

variable "ecs_log_level" {
  description = "Log level for the ECS agent."
  default     = "info"
}

variable "load_balancers" {
  description = "List of load balancer security groups that can ingress on the dynamic port range."
  type        = "list"
  default     = []
}

variable "load_balancer_count" {
  description = "HACK: This exists purely to calculate count in Terraform. Should equal the length of your ingress map."
  default     = 0
}

variable "tags" {
  description = "A map of tags (key/value)."
  type        = "map"
  default     = {}
}
