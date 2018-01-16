# -------------------------------------------------------------------------------
# Resources
# -------------------------------------------------------------------------------
data "aws_region" "current" {
  current = true
}

resource "aws_security_group_rule" "atc_ingress_baggageclaim" {
  security_group_id        = "${module.worker.security_group_id}"
  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = "7788"
  to_port                  = "7788"
  source_security_group_id = "${var.atc_sg}"
}

resource "aws_security_group_rule" "atc_ingress_garden" {
  security_group_id        = "${module.worker.security_group_id}"
  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = "7777"
  to_port                  = "7777"
  source_security_group_id = "${var.atc_sg}"
}

module "worker" {
  source = "../../ec2/asg"

  prefix               = "${var.prefix}-worker"
  user_data            = "${data.template_file.worker.rendered}"
  vpc_id               = "${var.vpc_id}"
  subnet_ids           = "${var.private_subnet_ids}"
  await_signal         = "true"
  pause_time           = "PT5M"
  health_check_type    = "EC2"
  instance_policy      = "${data.aws_iam_policy_document.worker.json}"
  instance_count       = "${var.instance_count}"
  instance_type        = "${var.instance_type}"
  instance_volume_size = "50"
  instance_ami         = "${var.instance_ami}"
  instance_key         = "${var.instance_key}"
  tags                 = "${var.tags}"
}

data "template_file" "worker" {
  template = "${file("${path.module}/cloud-config.yml")}"

  vars {
    stack_name       = "${var.prefix}-worker-asg"
    region           = "${data.aws_region.current.name}"
    lifecycle_topic  = "${aws_sns_topic.worker.arn}"
    tsa_host         = "${var.tsa_host}"
    tsa_port         = "${var.tsa_port}"
    log_group_name   = "${aws_cloudwatch_log_group.worker.name}"
    log_level        = "${var.log_level}"
    worker_team      = "${var.worker_team}"
    worker_key       = "${file("${var.concourse_keys}/worker_key")}"
    pub_worker_key   = "${file("${var.concourse_keys}/worker_key.pub")}"
    pub_tsa_host_key = "${file("${var.concourse_keys}/tsa_host_key.pub")}"
  }
}

resource "aws_cloudwatch_log_group" "worker" {
  name = "${var.prefix}-worker"
}

data "aws_iam_policy_document" "worker" {
  statement {
    effect = "Allow"

    resources = [
      "${aws_cloudwatch_log_group.worker.arn}",
    ]

    actions = [
      "logs:CreateLogStream",
      "logs:CreateLogGroup",
      "logs:PutLogEvents",
    ]
  }

  statement {
    effect = "Allow"

    resources = ["*"]

    actions = [
      "cloudwatch:PutMetricData",
      "cloudwatch:GetMetricStatistics",
      "cloudwatch:ListMetrics",
      "ec2:DescribeTags",
    ]
  }

  statement {
    effect = "Allow"

    resources = [
      "${aws_sns_topic.worker.arn}",
    ]

    actions = [
      "sns:Subscribe",
      "sns:Unsubscribe",
    ]
  }

  # TODO: Scope this to lifecycled-* (as this is what lifecycled names the sqs queues)
  statement {
    effect = "Allow"

    resources = ["*"]

    actions = [
      "sqs:*",
    ]
  }

  # TODO: See if this can be scoped to ASG's with a given prefix?
  statement {
    effect = "Allow"

    resources = ["*"]

    actions = [
      "autoscaling:DescribeAutoScalingInstances",
      "autoscaling:DescribeLifecycleHooks",
      "autoscaling:RecordLifecycleActionHeartbeat",
      "autoscaling:CompleteLifecycleAction",
    ]
  }
}

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
