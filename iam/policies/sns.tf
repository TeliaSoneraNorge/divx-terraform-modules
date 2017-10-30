# ------------------------------------------------------------------------------
# Resources
# ------------------------------------------------------------------------------
resource "aws_iam_role_policy" "sns" {
  count  = "${contains(var.services, "sns") == "true" ? 1 : 0}"
  name   = "${var.prefix}-sns-policy"
  role   = "${var.iam_role_name}"
  policy = "${data.aws_iam_policy_document.sns.json}"
}

resource "aws_iam_user_policy" "sns" {
  count  = "${contains(var.services, "sns") && var.iam_user_name != "" ? 1 : 0}"
  name   = "${var.prefix}-sns-policy"
  user   = "${var.iam_role_name}"
  policy = "${data.aws_iam_policy_document.sns.json}"
}

data "aws_iam_policy_document" "sns" {
  statement {
    effect = "Allow"

    actions = [
      "sns:*",
    ]

    resources = [
      "arn:aws:sns:${var.region}:${var.account_id}:${coalesce(var.resources, "${var.prefix}-*")}",
      "arn:aws:sns:${var.region}:${var.account_id}:${coalesce(var.resources, "${var.prefix}-*:*")}",
    ]
  }
}
