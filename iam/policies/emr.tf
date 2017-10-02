# ------------------------------------------------------------------------------
# Resources
# ------------------------------------------------------------------------------
resource "aws_iam_role_policy" "emr" {
  count  = "${contains(var.services, "emr") == "true" ? 1 : 0}"
  name   = "${var.prefix}-emr-policy"
  role   = "${var.iam_role_name}"
  policy = "${data.aws_iam_policy_document.emr.json}"
}

data "aws_iam_policy_document" "emr" {
  statement {
    effect = "Allow"

    not_actions = [
      "elasticmapreduce:RunJobFlow",
      "elasticmapreduce:AddTags",
      "elasticmapreduce:RemoveTags",
    ]

    resources = [
      "*",
    ]

    condition = {
      test     = "StringLike"
      variable = "elasticmapreduce:ResourceTag/Name"
      values   = ["${coalesce(var.resources, "${var.prefix}-*")}"]
    }
  }

  statement {
    effect = "Allow"

    actions = [
      "elasticmapreduce:RunJobFlow",
    ]

    resources = [
      "*",
    ]

    condition = {
      test     = "StringLike"
      variable = "elasticmapreduce:RequestTag/Name"
      values   = ["${coalesce(var.resources, "${var.prefix}-*")}"]
    }
  }

  statement {
    effect = "Allow"

    # NOTE: RemoveTags is not restricted from deleting the Name tag. (aws:TagKeys did not work...).
    actions = [
      "elasticmapreduce:AddTags",
      "elasticmapreduce:RemoveTags",
    ]

    resources = [
      "*",
    ]

    condition = {
      test     = "StringLike"
      variable = "elasticmapreduce:ResourceTag/Name"
      values   = ["${coalesce(var.resources, "${var.prefix}-*")}"]
    }

    condition = {
      test     = "StringLikeIfExists"
      variable = "elasticmapreduce:RequestTag/Name"
      values   = ["${coalesce(var.resources, "${var.prefix}-*")}"]
    }
  }
}

