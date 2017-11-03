# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
variable "prefix" {
  description = "A prefix used for naming resources."
}

variable "state_bucket" {
  description = "Name of the S3 bucket used for storing Terraform state."
}

variable "lock_table" {
  description = "Optional: Name of the DynamoDB lock table used for Terraform state, if it differs from the state bucket name."
  default     = ""
}

variable "account_id" {
  description = "Restrict access to a given account ID."
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
  name   = "${var.prefix}-terraform-state-policy"
  role   = "${var.iam_role_name}"
  policy = "${data.aws_iam_policy_document.main.json}"
}

resource "aws_iam_user_policy" "main" {
  count  = "${var.iam_user_name != "" ? 1 : 0}"
  name   = "${var.prefix}-terraform-state-policy"
  user   = "${var.iam_user_name}"
  policy = "${data.aws_iam_policy_document.main.json}"
}

data "aws_iam_policy_document" "main" {
  statement {
    effect = "Allow"

    actions = [
      "dynamodb:*",
    ]

    resources = [
      "arn:aws:dynamodb:${var.region}:${var.account_id}:table/${coalesce(var.lock_table, var.state_bucket)}",
    ]

    condition = {
      test     = "ForAllValues:StringLike"
      variable = "dynamodb:LeadingKeys"

      values = [
        "${var.state_bucket}/${var.prefix}/*",
      ]
    }
  }

  statement {
    effect = "Allow"

    actions = [
      "s3:*",
    ]

    # NOTE: The role should already have ViewOnlyAccess for the bucket itself.
    resources = [
      "arn:aws:s3:::${var.state_bucket}/${var.prefix}/*",
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
