variable "prefix" {}
variable "domain" {}
variable "zone_id" {}
variable "web_protocol" {}
variable "web_port" {}
variable "certificate_arn" {}
variable "concourse_keys" {}
variable "postgres_password" {}
variable "encryption_key" {}
variable "basic_auth_username" {}
variable "basic_auth_password" {}
variable "github_client" {}
variable "github_secret" {}

variable "github_users" {
  type = "list"
}

variable "github_teams" {
  type = "list"
}

variable "instance_key" {}
variable "pem_bucket" {}
variable "pem_path" {}

variable "authorized_keys" {
  type = "list"
}

variable "tags" {
  type = "map"
}
