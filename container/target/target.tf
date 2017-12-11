# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
variable "prefix" {
  description = "A prefix used for naming resources."
}

variable "vpc_id" {
  description = "ID of a VPC where the target group will be registered."
}

variable "load_balancer_arn" {
  description = "AN of the load balancer (network or application)."
}

variable "target" {
  description = "Configuration for the target group attached to the cluster (dynamic port mapping)."
  default     = {}
}

variable "listeners" {
  description = "Configuration of listeners for the load balancer which are forwarded to the target group. (Protocol can be TCP, HTTP or HTTPS)."
  default     = []
}

variable "tags" {
  description = "A map of tags (key-value pairs) passed to resources."
  type        = "map"
  default     = {}
}

# ------------------------------------------------------------------------------
# Resources
# ------------------------------------------------------------------------------
locals {
  default         = "${lookup(var.target, "health", "${var.target["protocol"]}:traffic-port/")}"
  splits          = "${split(":", local.default)}"
  second_split    = "${split("/", element(local.splits, 1))}"
  health_protocol = "${element(local.splits, 0)}"
  health_port     = "${element(local.second_split, 0)}"
  health_path     = "${local.health_protocol != "TCP" ? "/${element(local.second_split, 1)}" : ""}"
}

# HACK: If we don't depend on this the target group is created and associated with the service before
# the LB is ready and listeners are attached. Which fails, see https://github.com/hashicorp/terraform/issues/12634.
resource "null_resource" "alb_exists" {
  triggers {
    alb_name = "${var.load_balancer_arn}"
  }
}

resource "aws_lb_target_group" "main" {
  depends_on = ["null_resource.alb_exists"]
  vpc_id     = "${var.vpc_id}"
  port       = "${var.target["port"]}"
  protocol   = "${var.target["protocol"]}"

  health_check {
    path                = "${local.health_path}"
    port                = "${local.health_port}"
    protocol            = "${local.health_protocol}"
    interval            = "30"
    timeout             = "5"
    healthy_threshold   = "5"
    unhealthy_threshold = "2"
    matcher             = "200"
  }

  # NOTE: TF is unable to destroy a target group while a listener is attached,
  # therefor we have to create a new one before destroying the old. This also means
  # we have to let it have a random name, and then tag it with the desired name.
  lifecycle {
    create_before_destroy = true
  }

  tags = "${merge(var.tags, map("Name", "${var.prefix}-target-${var.target["port"]}"))}"
}

resource "aws_lb_listener" "main" {
  depends_on        = ["aws_lb_target_group.main"]
  count             = "${length(var.listeners)}"
  load_balancer_arn = "${var.load_balancer_arn}"
  port              = "${lookup(var.listeners[count.index], "port")}"
  protocol          = "${lookup(var.listeners[count.index], "protocol")}"
  ssl_policy        = "${lookup(var.listeners[count.index], "protocol") == "HTTPS" ? "ELBSecurityPolicy-2015-05" : ""}"
  certificate_arn   = "${lookup(var.listeners[count.index], "certificate_arn", "")}"

  default_action {
    target_group_arn = "${aws_lb_target_group.main.arn}"
    type             = "forward"
  }
}

resource "aws_autoscaling_attachment" "main" {
  count                  = "${lookup(var.target, "attachment", "") == "" ? 0 : 1}"
  autoscaling_group_name = "${var.target["attachment"]}"
  abl_target_group_arn   = "${aws_lb_target_group.main.arn}"
}

# ------------------------------------------------------------------------------
# Output
# ------------------------------------------------------------------------------
output "target_group_arn" {
  value = "${aws_lb_target_group.main.arn}"
}

output "container_port" {
  value = "${var.target["port"]}"
}
