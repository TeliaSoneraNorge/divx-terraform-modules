# ------------------------------------------------------------------------------
# Resources
# ------------------------------------------------------------------------------
resource "aws_iam_role_policy" "ecs" {
  count  = "${contains(var.services, "ecs") == "true" ? 1 : 0}"
  name   = "${var.prefix}-ecs-policy"
  role   = "${var.iam_role_name}"
  policy = "${data.aws_iam_policy_document.ecs.json}"
}

data "aws_iam_policy_document" "ecs" {
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

  statement {
    effect = "Allow"

    actions = [
      "ecs:DescribeTasks",
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

  # NOTE: ViewOnlyAccess does not include ecs:Describe*
  statement {
    effect = "Allow"

    actions = [
      "ecs:DescribeClusters",
      "ecs:DescribeServices",
      "ecs:DescribeTaskDefinition",
    ]

    resources = [
      "*",
    ]

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

