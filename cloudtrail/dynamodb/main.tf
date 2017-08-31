# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
variable "prefix" {
  description = "A prefix used for naming resources."
}

variable "environment" {
  description = "Environment tag which is applied to resources."
  default     = ""
}

# ------------------------------------------------------------------------------
# Resources
# ------------------------------------------------------------------------------
resource "aws_dynamodb_table" "mapping" {
  name           = "${var.prefix}-mapping"
  read_capacity  = 40
  write_capacity = 40
  hash_key       = "eventID"
  range_key      = "eventTime"

  attribute {
    name = "eventID"
    type = "S"
  }

  attribute {
    name = "eventTime"
    type = "S"
  }

  ttl {
    attribute_name = "ttl"
    enabled        = "true"
  }

  tags {
    Name        = "${var.prefix}-mapping"
    terraform   = "true"
    environment = "${var.environment}"
  }
}

# ------------------------------------------------------------------------------
# Output
# ------------------------------------------------------------------------------
output "dynamodb_arn" {
  value = "${aws_dynamodb_table.mapping.arn}"
}

output "dynamodb_name" {
  value = "${aws_dynamodb_table.mapping.id}"
}
