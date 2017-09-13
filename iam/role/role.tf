# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
variable "prefix" {
  description = "Prefix added to the role name."
}

variable "trusted_account" {
  description = "ID of the account which is trusted with access to assume this role."
}

variable "users" {
  type        = "list"
  description = "List of users in the trusted account which will be allowed to assume this role."
}

# ------------------------------------------------------------------------------
# Resources
# ------------------------------------------------------------------------------
data "aws_iam_account_alias" "current" {}

resource "aws_iam_role" "main" {
  name                  = "${var.prefix}-role"
  assume_role_policy    = "${data.aws_iam_policy_document.assume.json}"
  force_detach_policies = "true"
}

data "aws_iam_policy_document" "assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type = "AWS"

      identifiers = [
        "${formatlist("arn:aws:iam::%s:user/%s", var.trusted_account, var.users)}",
      ]
    }

    condition = {
      test     = "Bool"
      variable = "aws:MultiFactorAuthPresent"
      values   = ["true"]
    }

    condition = {
      test     = "NumericLessThan"
      variable = "aws:MultiFactorAuthAge"
      values   = ["3600"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "view_only_policy" {
  role       = "${aws_iam_role.main.name}"
  policy_arn = "arn:aws:iam::aws:policy/job-function/ViewOnlyAccess"
}

# ------------------------------------------------------------------------------
# Output
# ------------------------------------------------------------------------------
output "name" {
  value = "${aws_iam_role.main.name}"
}

output "arn" {
  value = "${aws_iam_role.main.arn}"
}

output "url" {
  value = "https://signin.aws.amazon.com/switchrole?account=${data.aws_iam_account_alias.current.account_alias}&roleName=${aws_iam_role.main.name}"
}
