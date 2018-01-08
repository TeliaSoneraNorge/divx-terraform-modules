# -------------------------------------------------------------------------------
# Resources
# -------------------------------------------------------------------------------
resource "aws_sns_topic" "worker" {
  name = "${var.prefix}-worker-lifecycle"
}

resource "aws_autoscaling_lifecycle_hook" "worker" {
  name                    = "${var.prefix}-worker-lifecycle"
  autoscaling_group_name  = "${module.worker.id}"
  lifecycle_transition    = "autoscaling:EC2_INSTANCE_TERMINATING"
  default_result          = "CONTINUE"
  heartbeat_timeout       = "3600"
  notification_target_arn = "${aws_sns_topic.worker.arn}"
  role_arn                = "${aws_iam_role.lifecycle.arn}"
}

resource "aws_iam_role" "lifecycle" {
  name               = "${var.prefix}-lifecycle-role"
  assume_role_policy = "${data.aws_iam_policy_document.asg_assume.json}"
}

resource "aws_iam_role_policy" "lifecycle" {
  name   = "${var.prefix}-lifecycle-permissions"
  role   = "${aws_iam_role.lifecycle.id}"
  policy = "${data.aws_iam_policy_document.asg_permissions.json}"
}

data "aws_iam_policy_document" "asg_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["autoscaling.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "asg_permissions" {
  statement {
    effect = "Allow"

    resources = [
      "${aws_sns_topic.worker.arn}",
    ]

    actions = [
      "sns:Publish",
    ]
  }
}
