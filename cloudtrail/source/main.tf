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

variable "bucket_name" {
  description = "Name of the bucket where the raw CloudTrail logs should be delivered."
}

variable "lambda_arn" {
  description = "ARN of the Lambda function which will be invoked by the CloudWatch filter."
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

resource "aws_cloudtrail" "main" {
  name                          = "${var.prefix}-cloudtrail"
  s3_bucket_name                = "${var.bucket_name}"
  cloud_watch_logs_group_arn    = "${aws_cloudwatch_log_group.main.arn}"
  cloud_watch_logs_role_arn     = "${aws_iam_role.main.arn}"
  include_global_service_events = "true"
  is_multi_region_trail         = "true"
  enable_logging                = "true"

  tags {
    environment = "prod"
    terraform   = "true"
  }
}

resource "aws_cloudwatch_log_group" "main" {
  name              = "${var.prefix}-cloudtrail-log"
  retention_in_days = 90

  tags {
    Name        = "${var.prefix}-cloudtrail-log"
    environment = "${var.environment}"
    terraform   = "true"
  }
}

resource "aws_cloudwatch_log_subscription_filter" "main" {
  # NOTE: Cannot be created if it is not allowed to invoke the Lambda function.
  name            = "${var.prefix}-filtered-cloudtrail-log"
  log_group_name  = "${aws_cloudwatch_log_group.main.name}"
  destination_arn = "${var.lambda_arn}"
  filter_pattern  = "${chomp("${var.cloudwatch_filter}")}"
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

data "aws_iam_policy_document" "cloudtrail_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "cloudtrail" {
  statement {
    effect = "Allow"

    actions = [
      "logs:DescribeLogStreams",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = ["${aws_cloudwatch_log_group.main.arn}*"]
  }
}

# ------------------------------------------------------------------------------
# Output
# ------------------------------------------------------------------------------
