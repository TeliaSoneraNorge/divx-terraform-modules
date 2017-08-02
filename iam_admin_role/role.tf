# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
variable "prefix" {
  description = "(Optional) Prefix added to the role name."
  default     = ""
}

variable "account_id" {
  description = "ID of the account which is allowed to assume the admin role. sts:AssumeRole can be delegated to users on this account."
}

# ------------------------------------------------------------------------------
# Resources
# ------------------------------------------------------------------------------
data "aws_iam_account_alias" "current" {}

resource "aws_iam_role" "admin" {
  name               = "${join("-", compact(list("${var.prefix}", "admin-role")))}"
  assume_role_policy = "${data.aws_iam_policy_document.assume_admin.json}"
}

data "aws_iam_policy_document" "assume_admin" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${var.account_id}:root"]
    }

    condition = {
      test     = "Bool"
      variable = "aws:MultiFactorAuthPresent"
      values   = ["true"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "admin_policy" {
  role       = "${aws_iam_role.admin.name}"
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# ------------------------------------------------------------------------------
# Output
# ------------------------------------------------------------------------------
output "role_name" {
  value = "${aws_iam_role.admin.name}"
}

output "role_arn" {
  value = "${aws_iam_role.admin.arn}"
}

output "role_url" {
  value = "https://signin.aws.amazon.com/switchrole?account=${data.aws_iam_account_alias.current.account_alias}&roleName=${aws_iam_role.admin.name}"
}
