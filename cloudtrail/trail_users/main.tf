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

  # lifecycle {
  #   prevent_destroy = true
  # }

  tags {
    Name        = "${var.prefix}-cloudtrail-logs"
    terraform   = "true"
    environment = "${var.environment}"
  }
}

resource "aws_cloudwatch_log_group" "main" {
  name = "${var.prefix}-cloudtrail-logs"

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

resource "aws_dynamodb_table" "mapping" {
  name           = "${var.prefix}-cloudtrail-mapping"
  read_capacity  = 20
  write_capacity = 20
  hash_key       = "AccessKeyId"

  attribute {
    name = "AccessKeyId"
    type = "S"
  }

  # lifecycle {
  #   prevent_destroy = true
  # }

  tags {
    Name        = "${var.prefix}-user-key-mapping"
    terraform   = "true"
    environment = "${var.environment}"
  }
}

module "lambda" {
  source = "../../lambda/function"

  prefix      = "${var.prefix}-cloudtrail"
  policy      = "${data.aws_iam_policy_document.lambda.json}"
  source_code = "${path.module}/src/"
  runtime     = "nodejs6.10"
  variables   = {
    DYNAMODB_TABLE_NAME = "${aws_dynamodb_table.mapping.id}"
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
  filter_pattern  = "${chomp(file("${path.module}/filter.tpl"))}"
}

# ------------------------------------------------------------------------------
# Output
# ------------------------------------------------------------------------------
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
