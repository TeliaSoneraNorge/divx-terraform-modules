# ------------------------------------------------------------------------------
# Resources
# ------------------------------------------------------------------------------
variable "prefix" {
  description = "Prefix used for resource names."
}

variable "lambda_policy" {
  description = "A policy document for the lambda execution role."
}

variable "lambda_source" {
  description = "Absolute path to the source code for the lambda handler."
}

variable "lambda_runtime" {
  description = "Lambda runtime. Defaults to Node.js."
  default = "nodejs6.10"
}

# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
resource "aws_lambda_function" "main" {
  function_name    = "${var.prefix}-function"
  description      = "Lambda function."
  handler          = "index.handler"
  filename         = "${var.lambda_source}.zip"
  source_code_hash = "${data.archive_file.main.output_base64sha256}"
  runtime          = "${var.lambda_runtime}"
  memory_size      = 128
  timeout          = 300
  role             = "${aws_iam_role.main.arn}"
}

data "archive_file" "main" {
  type        = "zip"
  source_dir  = "${var.lambda_source}"
  output_path = "${var.lambda_source}.zip"
}

resource "aws_iam_role" "main" {
  name               = "${var.prefix}-lambda-role"
  assume_role_policy = "${data.aws_iam_policy_document.assume.json}"
}

data "aws_iam_policy_document" "assume" {
  statement {
    effect = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type = "Service"
      identifiers = [ "lambda.amazonaws.com" ]
    }
  }
}

resource "aws_iam_role_policy" "main" {
  name   = "${var.prefix}-lambda-privileges"
  role   = "${aws_iam_role.main.name}"
  policy = "${var.lambda_policy}"
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
