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

variable "trail_account" {
  description = "ID of the account which sends the logs."
}

variable "dynamodb_name" {
  description = "Name of DynamoDB table where logs will be delivered."
}

variable "dynamodb_arn" {
  description = "ARN of DynamoDB table where logs will be delivered."
}

variable "cloudwatch_filter" {
  description = "A string containing the cloudwatch filter to apply before sending logs to lambda."
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

resource "aws_cloudwatch_log_group" "main" {
  name              = "${var.prefix}-cloudtrail-logs"
  retention_in_days = 90

  tags {
    Name        = "${var.prefix}-cloudtrail-logs"
    environment = "${var.environment}"
    terraform   = "true"
  }
}

resource "aws_iam_role" "main" {
  name               = "${var.prefix}-cloudtrail-role"
  assume_role_policy = "${data.aws_iam_policy_document.cloudtrail_assume.json}"
}

resource "aws_iam_role_policy" "main" {
  name   = "${var.prefix}-cloudtrail-permissions"
  role   = "${aws_iam_role.main.id}"
  policy = "${data.aws_iam_policy_document.cloudtrail.json}"
}

module "lambda" {
  source = "../lambda/function"

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
  source_arn     = "${aws_cloudwatch_log_group.main.arn}"
  source_account = "${data.aws_caller_identity.current.account_id}"
}

resource "aws_cloudwatch_log_subscription_filter" "cloudtrail" {
  depends_on      = ["aws_lambda_permission.cloudwatch"]
  name            = "${var.prefix}-cloudtrail-logs-filter"
  log_group_name  = "${aws_cloudwatch_log_group.main.name}"
  destination_arn = "${module.lambda.function_arn}"
  filter_pattern  = "${chomp("${var.cloudwatch_filter}")}"
}

# ------------------------------------------------------------------------------
# Output
# ------------------------------------------------------------------------------
output "info" {
  value = <<EOF
Bucket name:   ${aws_s3_bucket.trail.id}
Log group ARN: ${aws_cloudwatch_log_group.main.arn}
Role ARN:      ${aws_iam_role.main.arn}
}

output "role_arn" {
  value = "${aws_iam_role.main.arn}"
}

output "log_group_arn" {
  value = "${aws_cloudwatch_log_group.main.arn}"
}

output "bucket_name" {
  value = "${aws_s3_bucket.trail.id}"
}

output "bucket_arn" {
  value = "${aws_s3_bucket.trail.arn}"
}
