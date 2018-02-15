# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
variable "prefix" {
  description = "Prefix used for resource names."
}

variable "role" {
  description = "IAM role name which will be granted the privileges."
}

variable "output_bucket" {
  description = "Optional: Name of a bucket where the SSM agent will be allowed to dump command outputs."
  default     = ""
}

variable "tags" {
  description = "A map of tags (key-value pairs) passed to resources."
  type        = "map"
  default     = {}
}
