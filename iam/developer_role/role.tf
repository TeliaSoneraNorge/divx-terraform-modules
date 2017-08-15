# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
variable "prefix" {
  description = "(Optional) Prefix added to the role name."
  default     = ""
}

variable "user_account_id" {
  description = "ID of the account where the listed users exist."
}

variable "users" {
  type        = "list"
  description = "List of users which will be allowed to assume this role."
}

# ------------------------------------------------------------------------------
# Resources
# ------------------------------------------------------------------------------
data "aws_iam_account_alias" "current" {}

resource "aws_iam_role" "developer" {
  name               = "${join("-", compact(list("${var.prefix}", "developer-role")))}"
  assume_role_policy = "${data.aws_iam_policy_document.assume_developer.json}"

  lifecycle {
    create_before_destroy = true
  }
}

data "aws_iam_policy_document" "assume_developer" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = ["${formatlist("arn:aws:iam::%s:user/%s", var.user_account_id, var.users)}"]
    }

    condition = {
      test     = "Bool"
      variable = "aws:MultiFactorAuthPresent"
      values   = ["true", "false"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "view_only_policy" {
  role       = "${aws_iam_role.developer.name}"
  policy_arn = "arn:aws:iam::aws:policy/job-function/ViewOnlyAccess"
}

resource "aws_iam_role_policy" "protect_role" {
  name   = "${var.prefix}-protect-policy"
  role   = "${aws_iam_role.developer.name}"
  policy = "${data.aws_iam_policy_document.protect_role.json}"
}

data "aws_iam_policy_document" "protect_role" {
  # NOTE: Disallow users from making changes to the developer role and policies.
  statement {
    effect = "Deny"

    not_actions = [
      "iam:ListAttachedRolePolicies",
      "iam:ListPolicyVersions",
      "iam:GetPolicyVersion",
      "iam:ListRolePolicies",
      "iam:GetRolePolicy",
    ]

    resources = [
      "${aws_iam_role.developer.arn}",
    ]
  }
}

# ------------------------------------------------------------------------------
# Output
# ------------------------------------------------------------------------------
output "role_name" {
  value = "${aws_iam_role.developer.name}"
}

output "role_arn" {
  value = "${aws_iam_role.developer.arn}"
}

output "role_url" {
  value = "https://signin.aws.amazon.com/switchrole?account=${data.aws_iam_account_alias.current.account_alias}&roleName=${aws_iam_role.developer.name}"
}
