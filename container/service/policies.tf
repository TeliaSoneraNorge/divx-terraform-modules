// ECS agent is allowed to log to the task log group
data "aws_iam_policy_document" "task_log" {
  statement {
    effect = "Allow"

    resources = [
      "${var.task_log_group_arn}",
    ]

    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
  }
}

// ECS service is allowed to assume
data "aws_iam_policy_document" "service_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs.amazonaws.com"]
    }
  }
}

// ECS service permissions
data "aws_iam_policy_document" "service_permissions" {
  statement {
    effect = "Allow"

    actions = [
      "ec2:Describe*",
      "elasticloadbalancing:Describe*",
    ]

    resources = ["*"]
  }

  // NOTE: ALB does not support resource level permissions :/
  // TODO: Check whether this is still valid/also applies to network load balancers.
  statement {
    effect = "Allow"

    actions = [
      "elasticloadbalancing:DeregisterInstancesFromLoadBalancer",
      "elasticloadbalancing:RegisterInstancesWithLoadBalancer",
      "elasticloadbalancing:DeregisterTargets",
      "elasticloadbalancing:RegisterTargets",
    ]

    resources = [
      "*",
    ]
  }
}
