# ------------------------------------------------------------------------------
# Resources
# ------------------------------------------------------------------------------
data "aws_region" "current" {}

resource "aws_ecs_cluster" "main" {
  name = "${var.prefix}-cluster"
}

resource "aws_cloudwatch_log_group" "main" {
  name = "${var.prefix}-cluster-agent"
}

data "template_file" "main" {
  template = "${file("${path.module}/cloud-config.yml")}"

  vars {
    region           = "${data.aws_region.current.name}"
    stack_name       = "${var.prefix}-cluster-asg"
    log_group_name   = "${aws_cloudwatch_log_group.main.name}"
    ecs_cluster_name = "${aws_ecs_cluster.main.name}"
    ecs_log_level    = "${var.ecs_log_level}"
  }
}

data "aws_iam_policy_document" "permissions" {
  # TODO: Restrict privileges to specific ECS services.
  statement {
    effect    = "Allow"
    resources = ["*"]

    actions = [
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:GetRepositoryPolicy",
      "ecr:DescribeRepositories",
      "ecr:ListImages",
      "ecr:DescribeImages",
      "ecr:BatchGetImage",
      "ecs:CreateCluster",
      "ecs:DeregisterContainerInstance",
      "ecs:DiscoverPollEndpoint",
      "ecs:Poll",
      "ecs:RegisterContainerInstance",
      "ecs:StartTelemetrySession",
      "ecs:Submit*",
    ]
  }

  statement {
    effect = "Allow"

    resources = [
      "${aws_cloudwatch_log_group.main.arn}",
    ]

    actions = [
      "logs:CreateLogStream",
      "logs:CreateLogGroup",
      "logs:PutLogEvents",
    ]
  }
}

module "asg" {
  source            = "../../ec2/asg"
  prefix            = "${var.prefix}-cluster"
  user_data         = "${data.template_file.main.rendered}"
  vpc_id            = "${var.vpc_id}"
  subnet_ids        = "${var.subnet_ids}"
  await_signal      = "true"
  pause_time        = "PT5M"
  health_check_type = "EC2"
  instance_policy   = "${data.aws_iam_policy_document.permissions.json}"
  instance_count    = "${var.instance_count}"
  instance_type     = "${var.instance_type}"
  instance_ami      = "${var.instance_ami}"
  instance_key      = "${var.instance_key}"
  tags              = "${var.tags}"
}

resource "aws_security_group_rule" "ingress" {
  count                    = "${length(var.load_balancer_count)}"
  security_group_id        = "${module.asg.security_group_id}"
  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = "32768"
  to_port                  = "65535"
  source_security_group_id = "${element(var.load_balancers, count.index)}"
}
