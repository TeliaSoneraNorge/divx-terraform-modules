# ------------------------------------------------------------------------------
# Resources
# ------------------------------------------------------------------------------
resource "aws_iam_role_policy" "kinesis" {
  count  = "${contains(var.services, "kinesis") == "true" ? 1 : 0}"
  name   = "${var.prefix}-kinesis-policy"
  role   = "${var.iam_role_name}"
  policy = "${data.aws_iam_policy_document.kinesis.json}"
}

resource "aws_iam_user_policy" "kinesis" {
  count  = "${contains(var.services, "kinesis") && var.iam_user_name != "" ? 1 : 0}"
  name   = "${var.prefix}-kinesis-policy"
  user   = "${var.iam_role_name}"
  policy = "${data.aws_iam_policy_document.kinesis.json}"
}

data "aws_iam_policy_document" "kinesis" {
  statement {
    effect = "Allow"

    actions = [
      "kinesis:*",
    ]

    resources = [
      "arn:aws:kinesis:${var.region}:${var.account_id}:stream/${coalesce(var.resources, "${var.prefix}-*")}",
    ]
  }
}

