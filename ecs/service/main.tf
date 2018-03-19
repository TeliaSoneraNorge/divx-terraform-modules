# ------------------------------------------------------------------------------
# Resources
# ------------------------------------------------------------------------------
data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

# HACK: If we don't depend on this the target group is created and associated with the service before
# the LB is ready and listeners are attached. Which fails, see https://github.com/hashicorp/terraform/issues/12634.
resource "null_resource" "lb_exists" {
  triggers {
    alb_name = "${var.target["load_balancer"]}"
  }
}

resource "aws_lb_target_group" "main" {
  depends_on   = ["null_resource.lb_exists"]
  vpc_id       = "${var.vpc_id}"
  protocol     = "${var.target["protocol"]}"
  port         = "${var.target["port"]}"
  health_check = ["${var.health}"]

  # NOTE: TF is unable to destroy a target group while a listener is attached,
  # therefor we have to create a new one before destroying the old. This also means
  # we have to let it have a random name, and then tag it with the desired name.
  lifecycle {
    create_before_destroy = true
  }

  tags = "${merge(var.tags, map("Name", "${var.prefix}-target-${var.target["port"]}"))}"
}

resource "aws_ecs_service" "main" {
  depends_on                        = ["null_resource.lb_exists", "aws_iam_role.service"]
  name                              = "${var.prefix}"
  cluster                           = "${var.cluster_id}"
  task_definition                   = "${aws_ecs_task_definition.main.arn}"
  desired_count                     = "${var.task_container_count}"
  iam_role                          = "${aws_iam_role.service.arn}"
  health_check_grace_period_seconds = "0"

  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200

  load_balancer {
    target_group_arn = "${aws_lb_target_group.main.arn}"
    container_name   = "${var.prefix}"
    container_port   = "${var.target["port"]}"
  }

  placement_strategy {
    type  = "spread"
    field = "instanceId"
  }
}

# NOTE: Takes a map of KEY = value and turns it into a list of: { name: KEY, value: value }.
data "null_data_source" "task_environment" {
  count = "${length(var.task_definition_environment)}"

  inputs = {
    name  = "${element(keys(var.task_definition_environment), count.index)}"
    value = "${element(keys(var.task_definition_environment), count.index)}"
  }
}

# NOTE: HostPort must be 0 to use dynamic port mapping.
resource "aws_ecs_task_definition" "main" {
  family = "${var.prefix}"

  container_definitions = <<EOF
[{
    "name": "${var.prefix}",
    "image": "${var.task_definition_image}",
    "cpu": ${var.task_definition_cpu},
    "memory": ${var.task_definition_ram},
    "essential": true,
    "portMappings": [{
      "HostPort": 0,
      "ContainerPort": ${var.target["port"]}
    }],
    "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
            "awslogs-group": "${aws_cloudwatch_log_group.main.name}",
            "awslogs-region": "${data.aws_region.current.name}",
            "awslogs-stream-prefix": "container"
        }
    },
    "command": ${jsonencode(var.task_definition_command)},
    "environment": ${jsonencode(data.null_data_source.task_environment.*.outputs)}
}]
EOF
}

resource "aws_cloudwatch_log_group" "main" {
  name = "${var.prefix}"
}

resource "aws_iam_role" "service" {
  name               = "${var.prefix}-service-role"
  assume_role_policy = "${data.aws_iam_policy_document.service_assume.json}"
}

resource "aws_iam_role_policy" "service_permissions" {
  name   = "${var.prefix}-service-permissions"
  role   = "${aws_iam_role.service.id}"
  policy = "${data.aws_iam_policy_document.service_permissions.json}"
}

resource "aws_iam_role_policy" "log_agent" {
  name   = "${var.prefix}-log-permissions"
  role   = "${var.cluster_role_id}"
  policy = "${data.aws_iam_policy_document.task_log.json}"
}
