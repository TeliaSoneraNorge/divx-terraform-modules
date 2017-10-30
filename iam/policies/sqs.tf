# ------------------------------------------------------------------------------
# Resources
# ------------------------------------------------------------------------------
resource "aws_iam_role_policy" "sqs" {
  count  = "${contains(var.services, "sqs") == "true" ? 1 : 0}"
  name   = "${var.prefix}-sqs-policy"
  role   = "${var.iam_role_name}"
  policy = "${data.aws_iam_policy_document.sqs.json}"
}

resource "aws_iam_user_policy" "sqs" {
  count  = "${contains(var.services, "sqs") && var.iam_user_name != "" ? 1 : 0}"
  name   = "${var.prefix}-sqs-policy"
  user   = "${var.iam_role_name}"
  policy = "${data.aws_iam_policy_document.sqs.json}"
}

data "aws_iam_policy_document" "sqs" {
  statement {
    effect = "Allow"

    actions = [
      "sqs:*",
    ]

    resources = [
      "arn:aws:sqs:${var.region}:${var.account_id}:${coalesce(var.resources, "${var.prefix}-*")}",
    ]
  }
}
