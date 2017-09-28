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

variable "source_account_id" {
  description = "ID of the account which sends the logs."
}

variable "dynamodb_name" {
  description = "Name of DynamoDB table where logs will be delivered."
}

variable "dynamodb_arn" {
  description = "ARN of DynamoDB table where logs will be delivered."
}

variable "region" {
  description = ""
}

# ------------------------------------------------------------------------------
# Resources
# ------------------------------------------------------------------------------

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "trail" {
  bucket        = "${var.prefix}-cloudtrail-logs"
  acl           = "private"
  policy        = "${data.aws_iam_policy_document.bucket.json}"
  force_destroy = "true"

  tags {
    Name        = "${var.prefix}-cloudtrail-logs"
    terraform   = "true"
    environment = "${var.environment}"
  }
}

module "lambda" {
  source = "../../lambda/function"

  prefix      = "${var.prefix}-cloudtrail"
  policy      = "${data.aws_iam_policy_document.lambda.json}"
  source_code = "${path.module}/handler/"
  runtime     = "nodejs6.10"

  variables = {
    DYNAMODB_TABLE_NAME = "${var.dynamodb_name}"
  }
}

resource "aws_lambda_permission" "cloudwatch" {
  depends_on     = ["module.lambda"]
  statement_id   = "${var.prefix}-cloudtrail-logs-lambda"
  function_name  = "${var.prefix}-cloudtrail-function"
  principal      = "logs.amazonaws.com"
  action         = "lambda:InvokeFunction"
  source_arn     = "arn:aws:logs:eu-west-1:${var.source_account_id}:log-group:*:*"
  source_account = "${var.source_account_id}"
}

# ------------------------------------------------------------------------------
# Output
# ------------------------------------------------------------------------------

output "info" {
  value = <<EOF

Bucket name: ${aws_s3_bucket.trail.id}
Lambda ARN:  ${module.lambda.function_arn}
EOF
}

output "lambda_arn" {
  value = "${module.lambda.function_arn}"
}

output "bucket_name" {
  value = "${aws_s3_bucket.trail.id}"
}
