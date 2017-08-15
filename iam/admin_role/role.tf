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

resource "aws_iam_role" "admin" {
  name               = "${join("-", compact(list("${var.prefix}", "admin-role")))}"
  assume_role_policy = "${data.aws_iam_policy_document.assume_admin.json}"

  lifecycle {
    create_before_destroy = true
  }
}

data "aws_iam_policy_document" "assume_admin" {
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
