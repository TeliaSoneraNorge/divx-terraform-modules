# ------------------------------------------------------------------------------
# Resources
# ------------------------------------------------------------------------------
resource "aws_lambda_function" "main" {
  function_name    = "${var.prefix}-function"
  description      = "Lambda function."
  handler          = "${var.handler}"
  filename         = "${var.zip_file}"
  source_code_hash = "${base64sha256(file(var.zip_file))}"
  runtime          = "${var.runtime}"
  memory_size      = "${var.memory_size}"
  timeout          = "${var.timeout}"
  role             = "${aws_iam_role.main.arn}"

  environment {
    variables = "${var.variables}"
  }

  tags = "${merge(var.tags, map("Name", "${var.prefix}-function"))}"
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
