# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
variable "prefix" {
  description = "A prefix used for naming resources."
}

variable "iam_role_name" {
  description = "Name of IAM role to attach the generated policy to."
}

variable "iam_user_name" {
  description = "Optional: Name of an IAM (CI/CD) user which the policy is also attached to."
  default     = ""
}

variable "resources" {
  description = "Restrict access to specific resources. Defaults to 'prefix-*'."
  default     = ""
}

variable "services" {
  description = "List of services which the role is granted access to."
  type        = "list"
}

variable "account_id" {
  description = "Restrict access to a given account ID."
}

variable "region" {
  description = "Restrict privileges to a given region."
}

# ------------------------------------------------------------------------------
# Resources
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Output
# ------------------------------------------------------------------------------
