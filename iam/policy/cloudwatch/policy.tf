# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
variable "prefix" {
  description = "A prefix used for naming resources."
}

variable "resources" {
  description = "Restrict access to specific resources. Defaults to 'prefix-*'."
  default     = ""
}

variable "account_id" {
  description = "Restrict access to a given account ID."
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
  name   = "${var.prefix}-cloudformation-policy"
  role   = "${var.iam_role_name}"
  policy = "${data.aws_iam_policy_document.main.json}"
}

data "aws_iam_policy_document" "main" {
  statement {
    effect = "Allow"

    actions = [
      "cloudwatch:*",
    ]

    resources = [
      "arn:aws:logs:${var.region}:${var.account_id}:log-group:${coalesce(var.resources, "${var.prefix}-*")}",
      "arn:aws:logs:${var.region}:${var.account_id}:log-group:/aws/lambda/${coalesce(var.resources, "${var.prefix}-*")}",
      "arn:aws:events:${var.region}:${var.account_id}:rule/${coalesce(var.resources, "${var.prefix}-*")}",
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
