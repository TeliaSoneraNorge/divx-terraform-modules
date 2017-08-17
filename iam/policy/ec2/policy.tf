# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
variable "prefix" {
  description = "A prefix used for naming resources."
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
  name   = "${var.prefix}-ec2-policy"
  role   = "${var.iam_role_name}"
  policy = "${data.aws_iam_policy_document.main.json}"
}

data "aws_iam_policy_document" "main" {
  statement {
    effect = "Allow"

    actions = [
      "ec2:*",
    ]

    resources = [
      "*",
    ]

    # TODO: Restrict access to specific resource names if possible.
    condition = {
      test     = "StringEquals"
      variable = "ec2:Region"
      values   = ["${var.region}"]
    }
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
