# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
variable "tags" {
  description = "A map of tags (key-value pairs)."
  type        = "map"
  default     = {}
}

variable "passed" {
  description = "A map of tags supplied by the user."
  type        = "map"
  default     = {}
}

# ------------------------------------------------------------------------------
# Resources
# ------------------------------------------------------------------------------
locals {
  tags = "${merge(var.passed, var.tags)}"
}

data "null_data_source" "autoscaling" {
  count = "${length(local.tags)}"

  inputs = {
    key                 = "${element(keys(local.tags), count.index)}"
    value               = "${element(values(local.tags), count.index)}"
    propagate_at_launch = "true"
  }
}

# NOTE: Passing local directly causes terraform crashes.
data "null_data_source" "standard" {
  inputs = "${local.tags}"
}

# ------------------------------------------------------------------------------
# Output
# ------------------------------------------------------------------------------
output "autoscaling" {
  value = ["${data.null_data_source.autoscaling.*.outputs}"]
}

output "standard" {
  value = "${data.null_data_source.standard.outputs}"
}
