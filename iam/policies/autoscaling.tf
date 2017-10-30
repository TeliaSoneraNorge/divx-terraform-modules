# ------------------------------------------------------------------------------
# Resources
# ------------------------------------------------------------------------------
resource "aws_iam_role_policy" "autoscaling" {
  count  = "${contains(var.services, "autoscaling") == "true" ? 1 : 0}"
  name   = "${var.prefix}-autoscaling-policy"
  role   = "${var.iam_role_name}"
  policy = "${data.aws_iam_policy_document.autoscaling.json}"
}

resource "aws_iam_user_policy" "autoscaling" {
  count  = "${contains(var.services, "autoscaling") && var.iam_user_name != "" ? 1 : 0}"
  name   = "${var.prefix}-autoscaling-policy"
  user   = "${var.iam_user_name}"
  policy = "${data.aws_iam_policy_document.autoscaling.json}"
}

data "aws_iam_policy_document" "autoscaling" {
  # NOTE: Describe* is granted via ViewOnlyAccess.
  statement {
    effect = "Allow"

    not_actions = [
      "autoscaling:CreateLaunchConfiguration",
      "autoscaling:DeleteLaunchConfiguration",
      "autoscaling:CreateAutoScalingGroup",
      "autoscaling:UpdateAutoScalingGroup",
      "autoscaling:AttachLoadBalancers",
      "autoscaling:CreateOrUpdateTags",
      "autoscaling:DeleteTags",
    ]

    resources = [
      "arn:aws:autoscaling:${var.region}:${var.account_id}:autoScalingGroup:*:autoScalingGroupName/${coalesce(var.resources, "${var.prefix}-*")}",
    ]

    condition = {
      test     = "StringLike"
      variable = "autoscaling:ResourceTag/Name"
      values   = ["${coalesce(var.resources, "${var.prefix}-*")}"]
    }
  }

  # NOTE: Creating launch configurations does not support conditions.
  statement {
    effect = "Allow"

    actions = [
      "autoscaling:CreateLaunchConfiguration",
      "autoscaling:DeleteLaunchConfiguration",
    ]

    resources = [
      "arn:aws:autoscaling:${var.region}:${var.account_id}:launchConfiguration:*:launchConfigurationName/${coalesce(var.resources, "${var.prefix}-*")}",
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "autoscaling:CreateAutoScalingGroup",
      "autoscaling:UpdateAutoScalingGroup",
    ]

    resources = [
      "arn:aws:autoscaling:${var.region}:${var.account_id}:autoScalingGroup:*:autoScalingGroupName/${coalesce(var.resources, "${var.prefix}-*")}",
    ]

    condition = {
      test     = "StringLikeIfExists"
      variable = "autoscaling:LaunchConfigurationName"
      values   = ["${coalesce(var.resources, "${var.prefix}-*")}"]
    }
  }

  statement {
    effect = "Allow"

    actions = [
      "autoscaling:AttachLoadBalancers",
    ]

    resources = [
      "arn:aws:autoscaling:${var.region}:${var.account_id}:autoScalingGroup:*:autoScalingGroupName/${coalesce(var.resources, "${var.prefix}-*")}",
    ]

    condition = {
      test     = "ForAllValues:StringLike"
      variable = "autoscaling:LoadBalancerNames"
      values   = ["${coalesce(var.resources, "${var.prefix}-*")}"]
    }
  }

  statement {
    effect = "Allow"

    actions = [
      "autoscaling:CreateOrUpdateTags",
    ]

    resources = [
      "arn:aws:autoscaling:${var.region}:${var.account_id}:autoScalingGroup:*:autoScalingGroupName/${coalesce(var.resources, "${var.prefix}-*")}",
    ]

    condition = {
      test     = "StringLikeIfExists"
      variable = "aws:RequestTag/Name"
      values   = ["${coalesce(var.resources, "${var.prefix}-*")}"]
    }
  }

  statement {
    effect = "Allow"

    actions = [
      "autoscaling:DeleteTags",
    ]

    resources = [
      "arn:aws:autoscaling:${var.region}:${var.account_id}:autoScalingGroup:*:autoScalingGroupName/${coalesce(var.resources, "${var.prefix}-*")}",
    ]

    condition = {
      test     = "ForAllValues:StringNotEquals"
      variable = "aws:TagKeys"
      values   = ["Name"]
    }
  }
}

# ------------------------------------------------------------------------------
# Output
# ------------------------------------------------------------------------------
