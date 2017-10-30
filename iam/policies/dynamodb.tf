# ------------------------------------------------------------------------------
# Resources
# ------------------------------------------------------------------------------
resource "aws_iam_role_policy" "dynamodb" {
  count  = "${contains(var.services, "dynamodb") == "true" ? 1 : 0}"
  name   = "${var.prefix}-dynamodb-policy"
  role   = "${var.iam_role_name}"
  policy = "${data.aws_iam_policy_document.dynamodb.json}"
}

resource "aws_iam_user_policy" "dynamodb" {
  count  = "${contains(var.services, "dynamodb") && var.iam_user_name != "" ? 1 : 0}"
  name   = "${var.prefix}-dynamodb-policy"
  user   = "${var.iam_role_name}"
  policy = "${data.aws_iam_policy_document.dynamodb.json}"
}

data "aws_iam_policy_document" "dynamodb" {
  statement {
    effect = "Allow"

    actions = [
      "dynamodb:*",
    ]

    resources = [
      "arn:aws:dynamodb:${var.region}:${var.account_id}:table/${coalesce(var.resources, "${var.prefix}-*")}",
    ]
  }
}
