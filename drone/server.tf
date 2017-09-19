module "server" {
  source = "../container/service"

  prefix             = "${var.prefix}-server"
  environment        = "${var.environment}"
  vpc_id             = "${var.vpc_id}"
  cluster_id         = "${module.cluster.id}"
  cluster_sg         = "${module.cluster.security_group_id}"
  cluster_role       = "${module.cluster.role_id}"
  load_balancer_name = "${aws_elb.main.name}"
  load_balancer_sg   = "${aws_security_group.main.id}"
  task_definition    = "${aws_ecs_task_definition.server.arn}"
  task_log_group_arn = "${aws_cloudwatch_log_group.server.arn}"
  container_count    = "1"

  port_mapping = {
    "8000" = "8000"
    "9000" = "9000"
  }
}

resource "aws_ecs_task_definition" "server" {
  family                = "${var.prefix}-server"
  container_definitions = "${data.template_file.server.rendered}"
  task_role_arn         = "${aws_iam_role.server.arn}"

  volume {
    name      = "drone-volume"
    host_path = "/var/lib/drone"
  }
}

data "template_file" "server" {
  depends_on = ["module.postgres"]
  template   = "${file("${path.module}/config/server.json")}"

  vars {
    name          = "${var.prefix}-server"
    version       = "latest"
    log_group     = "${aws_cloudwatch_log_group.server.name}"
    region        = "${data.aws_region.current.name}"
    drone_secret  = "${var.drone_secret}"
    drone_host    = "${aws_elb.main.dns_name}"
    remote_driver = "postgres"
    remote_config = "${module.postgres.connection_string}?sslmode=disable"
    github_org    = "${var.drone_github_org}"
    github_admins = "${join(",", var.drone_github_admins)}"
    github_client = "${var.drone_github_client}"
    github_secret = "${var.drone_github_secret}"
  }
}

resource "aws_cloudwatch_log_group" "server" {
  name = "${var.prefix}-server"
}

resource "aws_iam_role" "server" {
  name               = "${var.prefix}-server-task-role"
  assume_role_policy = "${data.aws_iam_policy_document.assume.json}"
}

data "aws_iam_policy_document" "assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}
