# ------------------------------------------------------------------------------
# Resources
# ------------------------------------------------------------------------------
module "service" {
  source = "../service"

  prefix                   = "${var.prefix}"
  vpc_id                   = "${var.vpc_id}"
  cluster_id               = "${var.cluster_id}"
  cluster_role_id          = "${var.cluster_role_id}"
  task_container_count     = "${var.task_container_count}"
  task_definition_cpu      = "${var.task_definition_cpu}"
  task_definition_ram      = "${var.task_definition_ram}"
  task_definition_image_id = "${var.task_definition_image_id}"
  health = "${var.health}"

  target {
    protocol      = "${var.target["protocol"]}"
    port          = "${var.target["port"]}"
    load_balancer = "${var.target["load_balancer"]}"
  }

  tags = "${var.tags}"
}

resource "aws_lb_listener_rule" "thing" {
  listener_arn = "${var.listener_rule["listener_arn"]}"
  priority     = "${lookup(var.listener_rule, "priority", 100)}"

  action {
    type             = "forward"
    target_group_arn = "${module.service.target_group_arn}"
  }

  condition {
    field  = "${var.listener_rule["pattern"]}-pattern"
    values = ["${var.listener_rule["values"]}"]
  }
}
