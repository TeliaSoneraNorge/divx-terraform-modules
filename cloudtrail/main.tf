# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
variable "prefix" {
  description = "A prefix used for naming resources."
}

variable "source_accounts" {
  description = "List of account ID's which will be allowed to enable CloudTrail logging in the bucket."
  type        = "list"
}

variable "read_capacity" {
  description = "Read capacity for the DynamoDB table."
  default     = 30
}

variable "write_capacity" {
  description = "Write capacity for the DynamoDB table."
  default     = 30
}

variable "tags" {
  description = "A map of tags (key-value pairs) passed to resources."
  type        = "map"
  default     = {}
}

# ------------------------------------------------------------------------------
# Resources
# ------------------------------------------------------------------------------

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

resource "aws_s3_bucket" "main" {
  bucket        = "${var.prefix}-cloudtrail-logs"
  acl           = "private"
  policy        = "${data.aws_iam_policy_document.bucket.json}"
  force_destroy = "true"

  tags = "${merge(var.tags, map("Name", "${var.prefix}-cloudtrail-logs"))}"
}

resource "aws_dynamodb_table" "main" {
  name           = "${var.prefix}-cloudtrail-logs"
  read_capacity  = "${var.read_capacity}"
  write_capacity = "${var.write_capacity}"
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

  tags = "${merge(var.tags, map("Name", "${var.prefix}-cloudtrail-logs"))}"
}

module "lambda" {
  source = "../lambda/function"

  prefix      = "${var.prefix}-cloudtrail"
  policy      = "${data.aws_iam_policy_document.lambda.json}"
  source_code = "${path.module}/handler/"
  runtime     = "nodejs6.10"
  tags        = "${var.tags}"

  variables = {
    DYNAMODB_TABLE_NAME = "${aws_dynamodb_table.main.id}"
    REGION              = "${data.aws_region.current.name}"
  }
}

resource "aws_lambda_permission" "main" {
  statement_id   = "cloudtrail-bucket-invoke"
  function_name  = "${module.lambda.function_arn}"
  principal      = "s3.amazonaws.com"
  action         = "lambda:InvokeFunction"
  source_arn     = "${aws_s3_bucket.main.arn}"
  source_account = "${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_notification" "main" {
  bucket = "${aws_s3_bucket.main.id}"

  lambda_function {
    lambda_function_arn = "${module.lambda.function_arn}"
    events              = ["s3:ObjectCreated:*"]
  }
}

# ------------------------------------------------------------------------------
# Output
# ------------------------------------------------------------------------------

output "lambda_arn" {
  value = "${module.lambda.function_arn}"
}

output "bucket_name" {
  value = "${aws_s3_bucket.main.id}"
}
