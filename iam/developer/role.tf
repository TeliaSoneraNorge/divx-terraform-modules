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
module "role" {
  source = "../role"

  prefix          = "${var.prefix}-developer"
  trusted_account = "${var.trusted_account}"
  users           = "${var.users}"
}

resource "aws_iam_role_policy" "protect_role" {
  name   = "${var.prefix}-protect-policy"
  role   = "${module.role.name}"
  policy = "${data.aws_iam_policy_document.protect_role.json}"
}

data "aws_iam_policy_document" "protect_role" {
  # NOTE: We allow reading the policies so users can better understand the roles scope.
  statement {
    effect = "Allow"

    actions = [
      "iam:GetRolePolicy",
    ]

    resources = [
      "${module.role.arn}",
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "iam:GetPolicyVersion",
    ]

    resources = [
      "*"
    ]
  }

  # NOTE: Disallow users from making changes to the developer role and policies.
  statement {
    effect = "Deny"

    not_actions = [
      "iam:GenerateServiceLastAccessedDetails",
      "iam:ListInstanceProfilesForRole",
      "iam:ListAttachedRolePolicies",
      "iam:ListRolePolicies",
      "iam:GetRolePolicy",
    ]

    resources = [
      "${module.role.arn}",
    ]
  }
}

# ------------------------------------------------------------------------------
# Output
# ------------------------------------------------------------------------------
output "name" {
  value = "${module.role.name}"
}

output "arn" {
  value = "${module.role.arn}"
}

output "url" {
  value = "${module.role.url}"
}
