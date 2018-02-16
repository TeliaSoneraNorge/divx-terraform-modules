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

variable "authorized_cidr" {
  description = "List of authorized CIDR blocks which can reach the Concourse web interface."
  type        = "list"
}

variable "concourse_keys" {
  description = "Path to a directory containing the Concourse SSH keys. (See README.md)."
}

variable "postgres_connection" {
  description = "A connection string for the Postgresql database. Format: postgres://<username>:<password>@<address>:<port>/<database>"
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
  description = "Optional: Client ID of the Github Oauth application."
  default     = ""
}

variable "github_client_secret" {
  description = "Optional: Client secret for the Github Oauth application."
  default     = ""
}

variable "github_users" {
  description = "Optional: List of Github users that can log into the main Concourse team."
  type        = "list"
  default     = []
}

variable "github_teams" {
  description = "Optional: List of Github teams that can log into the main Concourse team."
  type        = "list"
  default     = []
}

variable "instance_count" {
  description = "Number of ATC instances to provision."
  default     = "2"
}

variable "instance_type" {
  description = "Instance type to provision for the Concourse ATC."
  default     = "t2.small"
}

variable "instance_ami" {
  description = "Amazon AMI 2 (id) for Concourse instances."
}

variable "instance_key" {
  description = "EC2 key-pair for Concourse instances."
  default     = ""
}

variable "domain" {
  description = "Optional: The domain name to associate with the external load balancer for Concourse."
  default     = ""
}

variable "zone_id" {
  description = "Optional: Zone ID of the parent domain where the alias record should be created."
  default     = ""
}

variable "web_protocol" {
  description = "Protocol specification for the Concourse web interface."
  default     = "HTTP"
}

variable "web_port" {
  description = "Port specification for the Concourse web interface."
  default     = "80"
}

variable "web_certificate_arn" {
  description = "Optional: If using HTTPS ingress you can supply a certificate ARN for the load balancer."
  default     = ""
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
