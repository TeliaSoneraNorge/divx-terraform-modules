# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
variable "prefix" {
  description = "A prefix used for naming resources."
}

variable "resources" {
  description = "Restrict access to specific resources. Defaults to 'prefix-*'."
  default     = ""
}

variable "account_id" {
  description = "Restrict access to a given account ID."
}

variable "region" {
  description = "Restrict privileges to a given region."
}

variable "iam_role_name" {
  description = "Name of IAM role to attach the generated policy to."
}

# ------------------------------------------------------------------------------
# Resources
# ------------------------------------------------------------------------------
resource "aws_iam_role_policy" "main" {
  name   = "${var.prefix}-asg-policy"
  role   = "${var.iam_role_name}"
  policy = "${data.aws_iam_policy_document.main.json}"
}

data "aws_iam_policy_document" "main" {
  # NOTE: Describe* is granted via ViewOnlyAccess.
  statement {
    effect = "Allow"

    not_actions = [
      "autoscaling:CreateAutoScalingGroup",
      "autoscaling:UpdateAutoScalingGroup",
      "autoscaling:AttachLoadBalancers",
      "autoscaling:CreateOrUpdateTags",
      "autoscaling:DeleteTags",
    ]

    resources = [
      "arn:aws:autoscaling:${var.region}:${var.account_id}:launchConfiguration:*:launchConfigurationName/${coalesce(var.resources, "${var.prefix}-*")}",
      "arn:aws:autoscaling:${var.region}:${var.account_id}:autoScalingGroup:*:autoScalingGroupName/${coalesce(var.resources, "${var.prefix}-*")}",
    ]

    condition = {
      test     = "StringLike"
      variable = "autoscaling:ResourceTag/Name"
      values   = ["${coalesce(var.resources, "${var.prefix}-*")}"]
    }
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
output "policy_name" {
  value = "${aws_iam_role_policy.main.name}"
}

output "policy_id" {
  value = "${aws_iam_role_policy.main.id}"
}
