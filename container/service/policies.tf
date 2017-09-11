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

  statement {
    effect = "Allow"

    actions = [
      "elasticloadbalancing:DeregisterInstancesFromLoadBalancer",
      "elasticloadbalancing:RegisterInstancesWithLoadBalancer",
    ]

    resources = [
      "arn:aws:elasticloadbalancing:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:loadbalancer/${contains(keys(var.port_mapping), "0") ? "app/" : ""}${var.load_balancer_name}*",
    ]
  }

  // NOTE: ALB does not support resource level permissions :/
  statement {
    effect = "Allow"

    actions = [
      "elasticloadbalancing:DeregisterTargets",
      "elasticloadbalancing:RegisterTargets",
    ]

    resources = [
      "*",
    ]
  }
}
