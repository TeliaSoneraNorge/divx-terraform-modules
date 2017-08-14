# ------------------------------------------------------------------------------
# Resources
# ------------------------------------------------------------------------------
variable "prefix" {
  description = "Prefix used for resource names."
}

variable "environment" {
  description = "Environment tag which is applied to resources."
  default     = ""
}

variable "source_code" {
  description = "Absolute path of the source code for the lambda handler. (Path with trailing slash)."
}

variable "runtime" {
  description = "Lambda runtime. Defaults to Node.js."
  default     = "nodejs6.10"
}

variable "variables" {
  description = "Map of environment variables."
  type        = "map"
  default     = {}
}

variable "policy" {
  description = "A policy document for the lambda execution role."
}

# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
resource "aws_lambda_function" "main" {
  function_name    = "${var.prefix}-function"
  description      = "Lambda function."
  handler          = "index.handler"
  filename         = "${var.source_code}${basename(var.source_code)}.zip"
  source_code_hash = "${data.archive_file.main.output_base64sha256}"
  runtime          = "${var.runtime}"
  memory_size      = 128
  timeout          = 300
  role             = "${aws_iam_role.main.arn}"

  environment {
    variables = "${var.variables}"
  }

  tags {
    Name        = "${var.prefix}-function"
    terraform   = "true"
    environment = "${var.environment}"
  }
}

data "archive_file" "main" {
  type        = "zip"
  source_dir  = "${var.source_code}"
  output_path = "${var.source_code}${basename(var.source_code)}.zip"
}

resource "aws_iam_role" "main" {
  name               = "${var.prefix}-lambda-role"
  assume_role_policy = "${data.aws_iam_policy_document.assume.json}"
}

data "aws_iam_policy_document" "assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "main" {
  name   = "${var.prefix}-lambda-privileges"
  role   = "${aws_iam_role.main.name}"
  policy = "${var.policy}"
}

# ------------------------------------------------------------------------------
# Output
# ------------------------------------------------------------------------------
output "role_arn" {
  value = "${aws_iam_role.main.arn}"
}

output "function_arn" {
  value = "${aws_lambda_function.main.arn}"
}

output "function_name" {
  value = "${aws_lambda_function.main.name}"
}
