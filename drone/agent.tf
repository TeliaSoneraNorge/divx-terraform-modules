module "agent" {
  source = "../container/service"

  prefix               = "${var.prefix}-agent"
  environment          = "${var.environment}"
  vpc_id               = "${var.vpc_id}"
  cluster_id           = "${module.cluster.id}"
  cluster_sg           = "${module.cluster.security_group_id}"
  cluster_role         = "${module.cluster.role_id}"
  load_balancer_name   = "${aws_elb.main.name}"
  load_balancer_sg     = "${aws_security_group.main.id}"
  task_definition      = "${aws_ecs_task_definition.agent.arn}"
  task_log_group_arn   = "${aws_cloudwatch_log_group.agent.arn}"
  container_count      = "${var.instance_count}"
}

resource "aws_ecs_task_definition" "agent" {
  family                = "${var.prefix}-agent"
  container_definitions = "${data.template_file.agent.rendered}"
  task_role_arn         = "${aws_iam_role.agent.arn}"

  volume {
    name      = "docker-socket"
    host_path = "/var/run/docker.sock"
  }
}

data "template_file" "agent" {
  template = "${file("${path.module}/agent.json")}"

  vars {
    name          = "${var.prefix}-agent"
    version       = "latest"
    log_group     = "${aws_cloudwatch_log_group.agent.name}"
    region        = "${data.aws_region.current.name}"
    drone_server  = "${aws_elb.main.dns_name}:9000"
    drone_secret  = "${var.drone_secret}"
  }
}

resource "aws_cloudwatch_log_group" "agent" {
  name = "${var.prefix}-agent"
}

resource "aws_iam_role" "agent" {
  name               = "${var.prefix}-agent-task-role"
  assume_role_policy = "${data.aws_iam_policy_document.agent_assume.json}"
}

data "aws_iam_policy_document" "agent_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

