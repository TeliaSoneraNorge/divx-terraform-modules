# ------------------------------------------------------------------------------
# Resources
# ------------------------------------------------------------------------------
resource "aws_iam_role_policy" "cloudformation" {
  count  = "${contains(var.services, "cloudformation") && var.iam_role_name != "" ? 1 : 0}"
  name   = "${var.prefix}-cloudformation-policy"
  role   = "${var.iam_role_name}"
  policy = "${data.aws_iam_policy_document.cloudformation.json}"
}

resource "aws_iam_user_policy" "cloudformation" {
  count  = "${contains(var.services, "cloudformation") && var.iam_user_name != "" ? 1 : 0}"
  name   = "${var.prefix}-cloudformation-policy"
  user   = "${var.iam_role_name}"
  policy = "${data.aws_iam_policy_document.cloudformation.json}"
}

data "aws_iam_policy_document" "cloudformation" {
  statement {
    effect = "Allow"

    actions = [
      "cloudformation:*",
    ]

    resources = [
      "arn:aws:cloudformation:${var.region}:${var.account_id}:stack/${coalesce(var.resources, "${var.prefix}-*/*")}",
    ]
  }
}
