# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
variable "prefix" {
  description = "A prefix used for naming resources."
}

variable "api_id" {
  description = "Restrict access to the given API ID (i.e. the API has to be created first)."
}

variable "region" {
  description = "Restrict privileges to a given region."
}

variable "iam_role_name" {
  description = "Optional: Name of IAM role to attach the generated policy to."
  default     = ""
}

variable "iam_user_name" {
  description = "Optional: Name of an IAM user which will be given the same privileges. Intended for CI/CD."
  default     = ""
}

# ------------------------------------------------------------------------------
# Resources
# ------------------------------------------------------------------------------
resource "aws_iam_role_policy" "main" {
  count  = "${var.iam_role_name != "" ? 1 : 0}"
  name   = "${var.prefix}-apigateway-policy"
  role   = "${var.iam_role_name}"
  policy = "${data.aws_iam_policy_document.main.json}"
}

resource "aws_iam_user_policy" "main" {
  count  = "${var.iam_user_name != "" ? 1 : 0}"
  name   = "${var.prefix}-apigateway-policy"
  user   = "${var.iam_user_name}"
  policy = "${data.aws_iam_policy_document.main.json}"
}

data "aws_iam_policy_document" "main" {
  statement {
    effect = "Allow"

    actions = [
      "apigateway:*",
    ]

    resources = [
      "arn:aws:apigateway:${var.region}::/restapis/${var.api_id}/*",
    ]
  }
}

# ------------------------------------------------------------------------------
# Output
# ------------------------------------------------------------------------------
output "policy_name" {
  value = "${aws_iam_role_policy.main.name}"
}

output "policy_id" {
  value = "${aws_iam_role_policy.main.id}"
}
