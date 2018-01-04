# -------------------------------------------------------------------------------
# Resources
# -------------------------------------------------------------------------------
resource "aws_security_group_rule" "worker_ingress_tsa" {
  security_group_id = "${module.atc.security_group_id}"
  type              = "ingress"
  protocol          = "tcp"
  from_port         = "${var.tsa_port}"
  to_port           = "${var.tsa_port}"
  cidr_blocks       = ["${data.aws_vpc.concourse.cidr_block}"]
}

resource "aws_security_group_rule" "lb_ingress_atc" {
  security_group_id        = "${module.atc.security_group_id}"
  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = "${var.atc_port}"
  to_port                  = "${var.atc_port}"
  source_security_group_id = "${module.external_lb.security_group_id}"
}

resource "aws_autoscaling_attachment" "external_lb" {
  autoscaling_group_name = "${module.atc.id}"
  alb_target_group_arn   = "${module.external_target.target_group_arn}"
}

resource "aws_autoscaling_attachment" "internal_lb" {
  autoscaling_group_name = "${module.atc.id}"
  alb_target_group_arn   = "${module.internal_target.target_group_arn}"
}

module "atc" {
  source = "../ec2/asg"

  prefix            = "${var.prefix}-atc"
  user_data         = "${data.template_file.atc.rendered}"
  vpc_id            = "${var.vpc_id}"
  subnet_ids        = "${var.private_subnet_ids}"
  await_signal      = "true"
  pause_time        = "PT5M"
  health_check_type = "ELB"
  instance_policy   = "${data.aws_iam_policy_document.atc.json}"
  instance_count    = "${var.atc_count}"
  instance_type     = "${var.atc_type}"
  instance_ami      = "${var.instance_ami}"
  instance_key      = "${var.instance_key}"
  tags              = "${var.tags}"
}

data "template_file" "atc" {
  template = "${file("${path.module}/config/atc.yml")}"

  vars {
    stack_name                = "${var.prefix}-atc-asg"
    region                    = "${data.aws_region.current.name}"
    target_group              = "${module.internal_target.target_group_arn}"
    concourse_download_url    = "https://github.com/concourse/concourse/releases/download/v${var.concourse_version}/concourse_linux_amd64"
    github_client_id          = "${var.github_client_id}"
    github_client_secret      = "${var.github_client_secret}"
    github_users              = "${join(",", "${var.github_users}")}"
    github_teams              = "${join(",", "${var.github_teams}")}"
    concourse_web_host        = "https://${var.domain}:${var.web_port}"
    concourse_postgres_source = "${module.postgres.connection_string}"
    log_group_name            = "${aws_cloudwatch_log_group.atc.name}"
    log_level                 = "${var.log_level}"
    tsa_host_key              = "${file("${var.concourse_keys}/tsa_host_key")}"
    session_signing_key       = "${file("${var.concourse_keys}/session_signing_key")}"
    authorized_worker_keys    = "${file("${var.concourse_keys}/authorized_worker_keys")}"
    vault_url                 = "${var.vault_url}"
    vault_client_token        = "${var.vault_client_token}"
    encryption_key            = "${var.encryption_key}"
    old_encryption_key        = "${var.old_encryption_key}"
  }
}

resource "aws_cloudwatch_log_group" "atc" {
  name = "${var.prefix}-atc"
}

data "aws_iam_policy_document" "atc" {
  statement {
    effect = "Allow"

    resources = [
      "${aws_cloudwatch_log_group.atc.arn}",
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
      "elasticloadbalancing:DescribeTargetHealth",
    ]
  }
}
