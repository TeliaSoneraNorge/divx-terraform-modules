# ------------------------------------------------------------------------------
# Resources
# ------------------------------------------------------------------------------
resource "aws_iam_role_policy" "s3" {
  count  = "${contains(var.services, "s3") == "true" ? 1 : 0}"
  name   = "${var.prefix}-s3-policy"
  role   = "${var.iam_role_name}"
  policy = "${data.aws_iam_policy_document.s3.json}"
}

resource "aws_iam_user_policy" "s3" {
  count  = "${contains(var.services, "s3") && var.iam_user_name != "" ? 1 : 0}"
  name   = "${var.prefix}-s3-policy"
  user   = "${var.iam_role_name}"
  policy = "${data.aws_iam_policy_document.s3.json}"
}

data "aws_iam_policy_document" "s3" {
  statement {
    effect = "Allow"

    actions = [
      "s3:*",
    ]

    resources = [
      "arn:aws:s3:::${coalesce(var.resources, "${var.prefix}-*")}",
      "arn:aws:s3:::${coalesce(var.resources, "${var.prefix}-*")}/*",
    ]
  }
}
