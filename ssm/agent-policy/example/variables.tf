variable "prefix" {
  description = "Prefix used for resource names."
}

variable "tags" {
  description = "A map of tags (key-value pairs) passed to resources."
  type        = "map"
  default     = {}
}
