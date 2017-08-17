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

variable "iam_role_name" {
  description = "Name of IAM role to attach the generated policy to."
}

# ------------------------------------------------------------------------------
# Resources
# ------------------------------------------------------------------------------
resource "aws_iam_role_policy" "main" {
  name   = "${var.prefix}-iam-policy"
  role   = "${var.iam_role_name}"
  policy = "${data.aws_iam_policy_document.main.json}"
}

data "aws_iam_policy_document" "main" {
  statement {
    effect = "Allow"

    actions = [
      "iam:AddRoleToInstanceProfile",
      "iam:AttachRolePolicy",
      "iam:CreateInstanceProfile",
      "iam:CreateRole",
      "iam:CreatePolicy",
      "iam:CreatePolicyVersion",
      "iam:DeleteInstanceProfile",
      "iam:DeleteRole",
      "iam:DeletePolicy",
      "iam:DeletePolicyVersion",
      "iam:DeleteRolePolicy",
      "iam:DetachRolePolicy",
      "iam:GetInstanceProfile",
      "iam:GetRole",
      "iam:GetRolePolicy",
      "iam:GetPolicy",
      "iam:GetPolicyVersion",
      "iam:SetDefaultPolicyVersion",
      "iam:PutRolePolicy",
      "iam:PassRole",
      "iam:RemoveRoleFromInstanceProfile",
      "iam:UpdateAssumeRolePolicy",
      "iam:UpdateAssumeRolePolicy",
      "iam:List*",
      "iam:Simulate*",
    ]

    resources = [
      "arn:aws:iam::${var.account_id}:role/${coalesce(var.resources, "${var.prefix}-*")}",
      "arn:aws:iam::${var.account_id}:instance-profile/${coalesce(var.resources, "${var.prefix}-*")}",
      "arn:aws:iam::${var.account_id}:policy/${coalesce(var.resources, "${var.prefix}-*")}",
    ]
  }

  # NOTE: Restrict users from assuming roles they can create.
  statement {
    effect = "Deny"

    actions = [
      "sts:AssumeRole",
    ]

    resources = [
      "arn:aws:iam::${var.account_id}:role/${coalesce(var.resources, "${var.prefix}-*")}",
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
