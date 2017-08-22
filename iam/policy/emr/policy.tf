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
  name   = "${var.prefix}-emr-policy"
  role   = "${var.iam_role_name}"
  policy = "${data.aws_iam_policy_document.main.json}"
}

data "aws_iam_policy_document" "main" {
  statement {
    effect = "Allow"

    not_actions = [
      "elasticmapreduce:RunJobFlow",
      "elasticmapreduce:AddTags",
      "elasticmapreduce:RemoveTags",
    ]

    resources = [
      "*",
    ]

    condition = {
      test     = "StringLike"
      variable = "elasticmapreduce:ResourceTag/Name"
      values   = ["${coalesce(var.resources, "${var.prefix}-*")}"]
    }
  }

  statement {
    effect = "Allow"

    actions = [
      "elasticmapreduce:RunJobFlow",
    ]

    resources = [
      "*",
    ]

    condition = {
      test     = "StringLike"
      variable = "elasticmapreduce:RequestTag/Name"
      values   = ["${coalesce(var.resources, "${var.prefix}-*")}"]
    }
  }

  statement {
    effect = "Allow"

    # NOTE: RemoveTags is not restricted from deleting the Name tag. (aws:TagKeys did not work...).
    actions = [
      "elasticmapreduce:AddTags",
      "elasticmapreduce:RemoveTags",
    ]

    resources = [
      "*",
    ]

    condition = {
      test     = "StringLike"
      variable = "elasticmapreduce:ResourceTag/Name"
      values   = ["${coalesce(var.resources, "${var.prefix}-*")}"]
    }

    condition = {
      test     = "StringLikeIfExists"
      variable = "elasticmapreduce:RequestTag/Name"
      values   = ["${coalesce(var.resources, "${var.prefix}-*")}"]
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
