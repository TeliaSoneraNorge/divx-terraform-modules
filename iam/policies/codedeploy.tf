# ------------------------------------------------------------------------------
# Resources
# ------------------------------------------------------------------------------
resource "aws_iam_role_policy" "codedeploy" {
  count  = "${contains(var.services, "codedeploy") == "true" ? 1 : 0}"
  name   = "${var.prefix}-codedeploy-policy"
  role   = "${var.iam_role_name}"
  policy = "${data.aws_iam_policy_document.codedeploy.json}"
}

resource "aws_iam_user_policy" "codedeploy" {
  count  = "${contains(var.services, "codedeploy") && var.iam_user_name != "" ? 1 : 0}"
  name   = "${var.prefix}-codedeploy-policy"
  user   = "${var.iam_role_name}"
  policy = "${data.aws_iam_policy_document.codedeploy.json}"
}

data "aws_iam_policy_document" "codedeploy" {
  statement {
    effect = "Allow"

    actions = [
      "codedeploy:*",
    ]

    resources = [
      "arn:aws:codedeploy:${var.region}:${var.account_id}:deploymentgroup:${coalesce(var.resources, "${var.prefix}-*")}",
      "arn:aws:codedeploy:${var.region}:${var.account_id}:application:${coalesce(var.resources, "${var.prefix}-*")}",
    ]
  }
}
