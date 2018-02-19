# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
variable "prefix" {
  description = "Prefix used for resource names."
}

variable "zip_file" {
  description = "Path to an archive file containing the Lambda handler."
}

variable "runtime" {
  description = "Lambda runtime. Defaults to Node.js."
  default     = "go1.x"
}

variable "variables" {
  description = "Map of environment variables."
  type        = "map"

  default = {
    DUMMY = "VARIABLE"
  }
}

variable "policy" {
  description = "A policy document for the lambda execution role."
}

variable "tags" {
  description = "A map of tags (key-value pairs) passed to resources."
  type        = "map"
  default     = {}
}
