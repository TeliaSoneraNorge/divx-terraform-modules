# -------------------------------------------------------------------------------
# Resources
# -------------------------------------------------------------------------------
data "aws_region" "current" {
  current = true
}

data "aws_vpc" "concourse" {
  id = "${var.vpc_id}"
}

resource "aws_security_group_rule" "workers_ingress_tsa" {
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
  source = "../../ec2/asg"

  prefix            = "${var.prefix}-atc"
  user_data         = "${data.template_file.atc.rendered}"
  vpc_id            = "${var.vpc_id}"
  subnet_ids        = "${var.private_subnet_ids}"
  await_signal      = "true"
  pause_time        = "PT5M"
  health_check_type = "ELB"
  instance_policy   = "${data.aws_iam_policy_document.atc.json}"
  instance_count    = "${var.instance_count}"
  instance_type     = "${var.instance_type}"
  instance_ami      = "${var.instance_ami}"
  instance_key      = "${var.instance_key}"
  tags              = "${var.tags}"
}

data "template_file" "atc" {
  template = "${file("${path.module}/cloud-config.yml")}"

  vars {
    stack_name                = "${var.prefix}-atc-asg"
    region                    = "${data.aws_region.current.name}"
    target_group              = "${module.internal_target.target_group_arn}"
    atc_port                  = "${var.atc_port}"
    tsa_port                  = "${var.tsa_port}"
    basic_auth_username       = "${var.basic_auth_username}"
    basic_auth_password       = "${var.basic_auth_password}"
    github_client_id          = "${var.github_client_id}"
    github_client_secret      = "${var.github_client_secret}"
    github_users              = "${length(var.github_users) > 0 ? "Environment=\"CONCOURSE_GITHUB_AUTH_USER=${join(",", var.github_users)}\"" : ""}"
    github_teams              = "${length(var.github_teams) > 0 ? "Environment=\"CONCOURSE_GITHUB_AUTH_TEAM=${join(",", var.github_teams)}\"" : ""}"
    concourse_web_host        = "${lower(var.web_protocol)}://${module.external_lb.dns_name}:${var.web_port}"
    concourse_postgres_source = "${var.postgres_connection}"
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

resource "aws_security_group_rule" "ingress" {
  security_group_id = "${module.external_lb.security_group_id}"
  type              = "ingress"
  protocol          = "tcp"
  from_port         = "${var.web_port}"
  to_port           = "${var.web_port}"
  cidr_blocks       = ["${var.authorized_cidr}"]
}

resource "aws_route53_record" "main" {
  count   = "${var.domain == "" ? 0 : 1}"
  zone_id = "${var.zone_id}"
  name    = "${var.domain}"
  type    = "A"

  alias {
    name                   = "${module.external_lb.dns_name}"
    zone_id                = "${module.external_lb.zone_id}"
    evaluate_target_health = false
  }
}

module "external_lb" {
  source = "../../ec2/lb"

  prefix     = "${var.prefix}-external"
  type       = "application"
  internal   = "false"
  vpc_id     = "${var.vpc_id}"
  subnet_ids = "${var.public_subnet_ids}"
  tags       = "${var.tags}"
}

module "internal_lb" {
  source = "../../ec2/lb"

  prefix     = "${var.prefix}-internal"
  type       = "network"
  internal   = "true"
  vpc_id     = "${var.vpc_id}"
  subnet_ids = "${var.private_subnet_ids}"
  tags       = "${var.tags}"
}

module "external_target" {
  source            = "../../container/target"
  prefix            = "${var.prefix}"
  vpc_id            = "${var.vpc_id}"
  load_balancer_arn = "${module.external_lb.arn}"
  tags              = "${var.tags}"

  target {
    protocol = "HTTP"
    port     = "${var.atc_port}"
    health   = "HTTP:traffic-port/"
  }

  listeners = [{
    protocol        = "${upper(var.web_protocol)}"
    port            = "${var.web_port}"
    certificate_arn = "${var.web_certificate_arn}"
  }]
}

module "internal_target" {
  source            = "../../container/target"
  prefix            = "${var.prefix}"
  vpc_id            = "${var.vpc_id}"
  load_balancer_arn = "${module.internal_lb.arn}"
  tags              = "${var.tags}"

  target {
    protocol = "TCP"
    port     = "${var.tsa_port}"
    health   = "TCP:${var.tsa_port}"
  }

  listeners = [
    {
      protocol = "TCP"
      port     = "${var.tsa_port}"
    },
    {
      protocol = "TCP"
      port     = "80"
    },
  ]
}
