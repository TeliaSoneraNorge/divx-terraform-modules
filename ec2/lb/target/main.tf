# ------------------------------------------------------------------------------
# Resources
# ------------------------------------------------------------------------------
locals {
  tcp_default = {
    protocol            = "TCP"
    port                = "8080"
    interval            = "30"
    healthy_threshold   = "2"
    unhealthy_threshold = "2"
  }

  tcp_health = "${merge(local.tcp_default, var.health)}"

  http_default = {
    protocol            = "HTTP"
    port                = "8080"
    interval            = "30"
    timeout             = "5"
    healthy_threshold   = "2"
    unhealthy_threshold = "2"
    matcher             = "200"
  }

  http_health = "${merge(local.http_default, var.health)}"
}

# HACK: If we don't depend on this the target group is created and associated with the service before
# the LB is ready and listeners are attached. Which fails, see https://github.com/hashicorp/terraform/issues/12634.
resource "null_resource" "lb_exists" {
  triggers {
    alb_name = "${var.target["load_balancer"]}"
  }
}

resource "aws_lb_target_group" "HTTP" {
  depends_on   = ["null_resource.lb_exists"]
  count        = "${var.target["protocol"] != "TCP" ? "1" : "0"}"
  vpc_id       = "${var.vpc_id}"
  port         = "${var.target["port"]}"
  protocol     = "${var.target["protocol"]}"
  health_check = ["${local.http_health}"]

  # NOTE: TF is unable to destroy a target group while a listener is attached,
  # therefor we have to create a new one before destroying the old. This also means
  # we have to let it have a random name, and then tag it with the desired name.
  lifecycle {
    create_before_destroy = true
  }

  tags = "${merge(var.tags, map("Name", "${var.prefix}-target-${var.target["port"]}"))}"
}

resource "aws_lb_target_group" "TCP" {
  depends_on   = ["null_resource.lb_exists"]
  count        = "${var.target["protocol"] == "TCP" ? "1" : "0"}"
  vpc_id       = "${var.vpc_id}"
  port         = "${var.target["port"]}"
  protocol     = "${var.target["protocol"]}"
  health_check = ["${local.tcp_health}"]

  # NOTE: TF is unable to destroy a target group while a listener is attached,
  # therefor we have to create a new one before destroying the old. This also means
  # we have to let it have a random name, and then tag it with the desired name.
  lifecycle {
    create_before_destroy = true
  }

  tags = "${merge(var.tags, map("Name", "${var.prefix}-target-${var.target["port"]}"))}"
}
