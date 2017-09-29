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

resource "aws_iam_role" "main" {
  name               = "${var.prefix}-log-destination-role"
  assume_role_policy = "${data.aws_iam_policy_document.cloudwatch_assume.json}"
}

resource "aws_iam_role_policy" "main" {
  name   = "${var.prefix}-log-destination-permissions"
  role   = "${aws_iam_role.main.id}"
  policy = "${data.aws_iam_policy_document.cloudwatch.json}"
}

resource "aws_cloudwatch_log_destination" "main" {
  depends_on = ["module.lambda"]
  name       = "${var.prefix}-cloudtrail-destination"
  role_arn   = "${aws_iam_role.main.arn}"
  target_arn = "${module.lambda.function_arn}"
}

resource "aws_cloudwatch_log_destination_policy" "main" {
  destination_name = "${aws_cloudwatch_log_destination.main.name}"
  access_policy    = "${data.aws_iam_policy_document.destination.json}"
}

# ------------------------------------------------------------------------------
# Output
# ------------------------------------------------------------------------------

output "info" {
  value = <<EOF

Bucket name:      ${aws_s3_bucket.trail.id}
Destination ARN:  ${aws_cloudwatch_log_destination.main.arn}
EOF
}

output "lambda_arn" {
  value = "${module.lambda.function_arn}"
}

output "bucket_name" {
  value = "${aws_s3_bucket.trail.id}"
}
