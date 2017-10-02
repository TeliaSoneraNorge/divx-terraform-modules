# ------------------------------------------------------------------------------
# Resources
# ------------------------------------------------------------------------------
resource "aws_iam_role_policy" "elasticsearch" {
  count  = "${contains(var.services, "elasticsearch") == "true" ? 1 : 0}"
  name   = "${var.prefix}-elasticsearch-policy"
  role   = "${var.iam_role_name}"
  policy = "${data.aws_iam_policy_document.elasticsearch.json}"
}

data "aws_iam_policy_document" "elasticsearch" {
  statement {
    effect = "Allow"

    actions = [
      "es:*",
    ]

    resources = [
      "arn:aws:es:${var.region}:${var.account_id}:domain/${coalesce(var.resources, "${var.prefix}-*")}",
    ]
  }
}

