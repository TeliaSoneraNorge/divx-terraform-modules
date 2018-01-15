# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
variable "prefix" {
  description = "Prefix used for resource names."
}

variable "domain" {
  description = "Optional: The domain name to associate with the Concourse ELB. (Must have an ACM certificate)."
  default     = ""
}

variable "zone_id" {
  description = "Optional: Zone ID for the domains route53 alias record."
  default     = ""
}

variable "certificate_arn" {
  description = "Optional: ACM certificate ARN for the domain."
  default     = ""
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

variable "concourse_keys" {
  description = "Path to a directory containing the Concourse SSH keys. (See README.md)."
}

variable "postgres_connection" {
  description = "A connection string for the Postgresql database. Format: postgres://<username>:<password>@<address>:<port>/<database>"
}

variable "authorized_cidr" {
  description = "List of authorized CIDR blocks which can reach the Concourse web interface."
  type        = "list"
}

variable "basic_auth_username" {
  description = "Optional: Username to use for basic auth."
  default     = ""
}

variable "basic_auth_password" {
  description = "Optional: Password to use for basic auth."
  default     = ""
}

variable "github_client_id" {
  description = "Client ID of the Github Oauth application."
}

variable "github_client_secret" {
  description = "Client secret for the Github Oauth application."
}

variable "github_users" {
  description = "List of Github users that can log into the main Concourse team."
  type        = "list"
}

variable "github_teams" {
  description = "List of Github teams that can log into the main Concourse team."
  type        = "list"
}

variable "instance_key" {
  description = "EC2 key-pair for Concourse instances."
  default     = ""
}

variable "concourse_version" {
  description = "Version of Concourse to download/run."
  default     = "3.8.0"
}

variable "instance_ami" {
  description = "Amazon AMI 2 (id) for Concourse instances."
  default     = "ami-db51c2a2"
}

variable "atc_count" {
  description = "Number of ATC instances to provision."
  default     = "2"
}

variable "atc_type" {
  description = "Instance type to provision for the Concourse ATC."
  default     = "t2.small"
}

variable "worker_count" {
  description = "Number of concourse workers to provision."
  default     = "3"
}

variable "worker_type" {
  description = "Instance type to provision for the Concourse workers."
  default     = "t2.medium"
}

variable "web_port" {
  description = "Port specification for the Concourse web interface."
  default     = "443"
}

variable "atc_port" {
  description = "Port specification for the Concourse ATC."
  default     = "8080"
}

variable "tsa_port" {
  description = "Port specification for the Concourse TSA."
  default     = "2222"
}

variable "log_level" {
  description = "Concourse log level (debug|info|error|fatal) for ATC, TSA and Baggageclaim."
  default     = "info"
}

variable "vault_url" {
  description = "Optional: DNS name for the vault backend."
  default     = ""
}

variable "vault_client_token" {
  description = "Optional: Vault client token."
  default     = ""
}

variable "encryption_key" {
  description = "Optional: Key used for encrypting database entries."
}

variable "old_encryption_key" {
  description = "Optional: When changing the encryption key you must use this variable to set the old encryption key."
  default     = ""
}

variable "tags" {
  description = "A map of tags (key-value pairs) passed to resources."
  type        = "map"
  default     = {}
}

# -------------------------------------------------------------------------------
# Resources
# -------------------------------------------------------------------------------
data "aws_region" "current" {
  current = true
}

data "aws_vpc" "concourse" {
  id = "${var.vpc_id}"
}

# -------------------------------------------------------------------------------
# Output
# -------------------------------------------------------------------------------
output "worker_role_arn" {
  value = "${module.worker.role_arn}"
}

output "worker_role_id" {
  value = "${module.worker.role_id}"
}

output "atc_role_arn" {
  value = "${module.atc.role_arn}"
}

output "atc_role_id" {
  value = "${module.atc.role_id}"
}

output "worker_sg" {
  value = "${module.worker.security_group_id}"
}

output "atc_sg" {
  value = "${module.atc.security_group_id}"
}

output "external_elb_sg" {
  value = "${module.external_lb.security_group_id}"
}

output "internal_elb_sg" {
  value = "${module.internal_lb.security_group_id}"
}

# TODO: Figure out how to fix http/https.
output "endpoint" {
  value = "https://${var.domain == "" ? module.external_lb.dns : var.domain}:${var.web_port}"
}
