# ------------------------------------------------------------------------------
# Resources
# ------------------------------------------------------------------------------
resource "aws_iam_role_policy" "cloudwatch" {
  count  = "${contains(var.services, "cloudwatch") && var.iam_role_name != "" ? 1 : 0}"
  name   = "${var.prefix}-cloudwatch-policy"
  role   = "${var.iam_role_name}"
  policy = "${data.aws_iam_policy_document.cloudwatch.json}"
}

resource "aws_iam_user_policy" "cloudwatch" {
  count  = "${contains(var.services, "cloudwatch") && var.iam_user_name != "" ? 1 : 0}"
  name   = "${var.prefix}-cloudwatch-policy"
  user   = "${var.iam_role_name}"
  policy = "${data.aws_iam_policy_document.cloudwatch.json}"
}

data "aws_iam_policy_document" "cloudwatch" {
  // TODO: Can we restrict cloudwatch access using tags?
  statement {
    effect = "Allow"

    actions = [
      "cloudwatch:*",
    ]

    resources = [
      "*",
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "logs:*",
      "events:*",
    ]

    resources = [
      "arn:aws:logs:${var.region}:${var.account_id}:log-group:${coalesce(var.resources, "${var.prefix}-*")}",
      "arn:aws:logs:${var.region}:${var.account_id}:log-group:/aws/lambda/${coalesce(var.resources, "${var.prefix}-*")}",
      "arn:aws:events:${var.region}:${var.account_id}:rule/${coalesce(var.resources, "${var.prefix}-*")}",
    ]
  }
}
