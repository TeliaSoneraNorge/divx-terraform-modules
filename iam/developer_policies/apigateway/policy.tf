# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
variable "prefix" {
  description = "Restrict access to resources with the given prefix."
}

variable "api_id" {
  description = "Restrict access to the given API ID (i.e. the API has to be created first)."
}

variable "region" {
  description = "Restrict privileges to a given region."
}

variable "iam_role_name" {
  description = "Name of IAM role to attach the generated policy to."
}

# ------------------------------------------------------------------------------
# Resources
# ------------------------------------------------------------------------------
resource "aws_iam_role_policy" "main" {
  name   = "${var.prefix}-lambda-policy"
  role   = "${var.iam_role_name}"
  policy = "${data.aws_iam_policy_document.main.json}"
}

data "aws_iam_policy_document" "main" {
  statement {
    effect = "Allow"
    actions = [
      "apigateway:*"
    ]
    resources = [
      "arn:aws:apigateway:${var.region}::/restapis/${var.api_id}/*"
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
