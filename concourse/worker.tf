# -------------------------------------------------------------------------------
# Resources
# -------------------------------------------------------------------------------
resource "aws_security_group_rule" "atc_ingress_baggageclaim" {
  security_group_id        = "${module.worker.security_group_id}"
  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = "7788"
  to_port                  = "7788"
  source_security_group_id = "${module.atc.security_group_id}"
}

resource "aws_security_group_rule" "atc_ingress_garden" {
  security_group_id        = "${module.worker.security_group_id}"
  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = "7777"
  to_port                  = "7777"
  source_security_group_id = "${module.atc.security_group_id}"
}

module "worker" {
  source = "../ec2/asg"

  prefix               = "${var.prefix}-worker"
  user_data            = "${data.template_file.worker.rendered}"
  vpc_id               = "${var.vpc_id}"
  subnet_ids           = "${var.private_subnet_ids}"
  pause_time           = "PT5M"
  health_check_type    = "EC2"
  instance_policy      = "${data.aws_iam_policy_document.worker.json}"
  instance_count       = "${var.worker_count}"
  instance_type        = "${var.worker_type}"
  instance_volume_size = "50"
  instance_ami         = "${var.instance_ami}"
  instance_key         = "${var.instance_key}"
  tags                 = "${var.tags}"
}

data "template_file" "worker" {
  template = "${file("${path.module}/config/worker.yml")}"

  vars {
    concourse_download_url = "https://github.com/concourse/concourse/releases/download/v${var.concourse_version}/concourse_linux_amd64"
    concourse_tsa_host     = "${module.internal_lb.dns_name}"
    log_group_name         = "${aws_cloudwatch_log_group.worker.name}"
    log_group_region       = "${data.aws_region.current.name}"
    log_level              = "${var.log_level}"
    worker_key             = "${file("${var.concourse_keys}/worker_key")}"
    pub_worker_key         = "${file("${var.concourse_keys}/worker_key.pub")}"
    pub_tsa_host_key       = "${file("${var.concourse_keys}/tsa_host_key.pub")}"
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
      "ec2:DescribeInstances",
    ]
  }
}
