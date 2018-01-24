# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
variable "prefix" {
  description = "Prefix to use when naming the state bucket and lock table."
}

variable "environment" {
  description = "Environment tag which is applied to resources."
  default     = ""
}

# ------------------------------------------------------------------------------
# Resources
# ------------------------------------------------------------------------------
resource "aws_s3_bucket" "state" {
  bucket = "${var.prefix}-terraform-state"
  acl    = "private"

  versioning {
    enabled = true
  }

  lifecycle {
    prevent_destroy = true
  }

  tags {
    terraform   = "true"
    environment = "${var.environment}"
  }
}

resource "aws_dynamodb_table" "lock" {
  name           = "${var.prefix}-terraform-state"
  read_capacity  = 20
  write_capacity = 20
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  lifecycle {
    prevent_destroy = true
  }

  tags {
    terraform   = "true"
    environment = "${var.environment}"
  }
}

resource "aws_kms_key" "encrypt" {
  description             = "Terraform state (default) encryption key."
  deletion_window_in_days = 30

  tags {
    terraform   = "true"
    environment = "${var.environment}"
  }
}

resource "aws_kms_alias" "encrypt-alias" {
  name          = "alias/terraform-state-encryption-key"
  target_key_id = "${aws_kms_key.encrypt.key_id}"
}

# ------------------------------------------------------------------------------
# Output
# ------------------------------------------------------------------------------
output "state_bucket" {
  value = "${aws_s3_bucket.state.id}"
}

output "lock_table" {
  value = "${aws_dynamodb_table.lock.id}"
}

output "kms_key_arn" {
  value = "${aws_kms_key.encrypt.arn}"
}

output "kms_key_id" {
  value = "${aws_kms_key.encrypt.key_id}"
}

output "kms_key_alias_arn" {
  value = "${aws_kms_alias.encrypt-alias.arn}"
}
