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
  name   = "${var.prefix}-ec2-policy"
  role   = "${var.iam_role_name}"
  policy = "${data.aws_iam_policy_document.main.json}"
}

data "aws_iam_policy_document" "main" {
  # NOTE: The instance profiles which can be passed is limited to the prefix by `iam:PassRole`.
  statement {
    effect = "Allow"

    not_actions = [
      "ec2:CreateSecurityGroup",
      "ec2:CreateVolume",
      "ec2:CreateTags",
      "ec2:DeleteTags",
      "ec2:DescribeTags",
      "ec2:RunInstances",
      "ec2:AllocateAddress",
      "ec2:AssociateAddress",
      "ec2:DisassociateAddress",
      "ec2:ReleaseAddress",
      "ec2:CreateImage",
      "ec2:RegisterImage",
      "ec2:CreateKeyPair",
      "ec2:DeleteKeyPair",
      "ec2:MonitorInstances",
    ]

    resources = [
      "arn:aws:ec2:${var.region}:${var.account_id}:*/*",
      "arn:aws:ec2:${var.region}::image/*",
      "arn:aws:ec2:${var.region}::snapshot/*",
    ]

    condition = {
      test     = "StringLike"
      variable = "ec2:ResourceTag/Name"
      values   = ["${coalesce(var.resources, "${var.prefix}-*")}"]
    }
  }

  # NOTE: Many EC2 actions do not support resource level permissions.
  statement {
    effect = "Allow"

    actions = [
      "ec2:AllocateAddress",
      "ec2:AssociateAddress",
      "ec2:DisassociateAddress",
      "ec2:ReleaseAddress",
      "ec2:DescribeTags",
      "ec2:CreateImage",
      "ec2:RegisterImage",
      "ec2:CreateKeyPair",
      "ec2:DeleteKeyPair",
      "ec2:MonitorInstances",
      "ec2:CreateSecurityGroup",
    ]

    resources = [
      "*"
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "ec2:CreateTags",
    ]

    resources = [
      "arn:aws:ec2:${var.region}:${var.account_id}:*/*",
      "arn:aws:ec2:${var.region}::image/*",
      "arn:aws:ec2:${var.region}::snapshot/*",
    ]

    condition = {
      test     = "StringLikeIfExists"
      variable = "ec2:ResourceTag/Name"
      values   = ["${coalesce(var.resources, "${var.prefix}-*")}"]
    }

    condition = {
      test     = "StringLikeIfExists"
      variable = "aws:RequestTag/Name"
      values   = ["${coalesce(var.resources, "${var.prefix}-*")}"]
    }
  }

  statement {
    effect = "Allow"

    actions = [
      "ec2:DeleteTags",
    ]

    resources = [
      "arn:aws:ec2:${var.region}:${var.account_id}:*/*",
      "arn:aws:ec2:${var.region}::image/*",
      "arn:aws:ec2:${var.region}::snapshot/*",
    ]

    condition = {
      test     = "StringLike"
      variable = "ec2:ResourceTag/Name"
      values   = ["${coalesce(var.resources, "${var.prefix}-*")}"]
    }

    condition = {
      test     = "ForAllValues:StringNotEquals"
      variable = "aws:TagKeys"
      values   = ["Name"]
    }
  }

  statement {
    effect = "Allow"

    actions = [
      "ec2:RunInstances",
    ]

    resources = [
      "arn:aws:ec2:${var.region}:${var.account_id}:*/*",
      "arn:aws:ec2:${var.region}::snapshot/*",
    ]

    condition = {
      test     = "StringLike"
      variable = "ec2:ResourceTag/Name"
      values   = ["${coalesce(var.resources, "${var.prefix}-*")}"]
    }
  }

  statement {
    effect = "Allow"

    actions = [
      "ec2:RunInstances",
    ]

    # NOTE: Tags are created when running the instance (RequestTag).
    resources = [
      "arn:aws:ec2:${var.region}:${var.account_id}:instance/*",
      "arn:aws:ec2:${var.region}:${var.account_id}:volume/*",
    ]

    condition = {
      test     = "StringLike"
      variable = "aws:RequestTag/Name"
      values   = ["${coalesce(var.resources, "${var.prefix}-*")}"]
    }
  }

  statement {
    effect = "Allow"

    actions = [
      "ec2:RunInstances",
    ]

    # NOTE: Images are most likely not created. I.e., wildcard.
    resources = [
      "arn:aws:ec2:${var.region}::image/*",
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
