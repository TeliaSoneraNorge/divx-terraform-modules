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
  name   = "${var.prefix}-ecs-policy"
  role   = "${var.iam_role_name}"
  policy = "${data.aws_iam_policy_document.main.json}"
}

data "aws_iam_policy_document" "main" {
  statement {
    effect = "Allow"

    actions = [
      "ecs:*",
    ]

    resources = [
      "arn:aws:ecs:${var.region}:${var.account_id}:cluster/${coalesce(var.resources, "${var.prefix}-*")}",
      "arn:aws:ecs:${var.region}:${var.account_id}:service/${coalesce(var.resources, "${var.prefix}-*")}",
      "arn:aws:ecs:${var.region}:${var.account_id}:task-definition/${coalesce(var.resources, "${var.prefix}-*:*")}",
    ]
  }

  # NOTE: Describe* is also granted via ViewOnlyAccess.
  statement {
    effect = "Allow"

    actions = [
      "ecs:PutAttributes",
      "ecs:DeleteAttributes",
      "ecs:Poll",
      "ecs:ListTasks",
      "ecs:StopTask",
      "ecs:StartTelemetrySession",
      "ecs:UpdateContainerAgent",
      "ecs:UpdateContainerInstancesState",
    ]

    resources = [
      "arn:aws:ecs:${var.region}:${var.account_id}:task/*",
      "arn:aws:ecs:${var.region}:${var.account_id}:container/*",
      "arn:aws:ecs:${var.region}:${var.account_id}:container-instance/*",
    ]

    condition = {
      test     = "StringLike"
      variable = "ecs:cluster"
      values   = ["${coalesce(var.resources, "${var.prefix}-*")}"]
    }
  }

  statement {
    effect = "Allow"

    actions = [
      "ecr:*",
    ]

    resources = [
      "arn:aws:ecr:${var.region}:${var.account_id}:repository/${coalesce(var.resources, "${var.prefix}-*")}",
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
