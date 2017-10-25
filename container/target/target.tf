# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
variable "prefix" {
  description = "A prefix used for naming resources."
}

variable "vpc_id" {
  description = "Optional: ID of a VPC where the target group (optional) will be registered."
  default     = ""
}

variable "load_balancer_arn" {
  description = "ARN of the load balancer (network or application)."
  default     = ""
}

variable "load_balancer_sg" {
  description = "Security group of the load balancer."
  default     = ""
}

variable "cluster_sg" {
  description = "Security group of the container cluster."
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
  default         = "${lookup(var.target, "health", "${var.target["protocol"]}/")}"
  parts           = "${split("/", local.default)}"
  health_protocol = "${element(local.parts, 0)}"
  health_path     = "${local.health_protocol != "TCP" ? "/${element(local.parts, 1)}" : ""}"
}

resource "aws_lb_target_group" "main" {
  count    = "${lookup(var.target, "port", "") == "" ? 0 : 1}"
  vpc_id   = "${var.vpc_id}"
  port     = "${var.target["port"]}"
  protocol = "${var.target["protocol"]}"

  health_check {
    // NOTE: Port is deliberately left out because dynamic ports are enforced.
    path                = "${local.health_path}"
    protocol            = "${local.health_protocol}"
    interval            = "30"
    timeout             = "5"
    healthy_threshold   = "5"
    unhealthy_threshold = "2"
    matcher             = "200"
  }

  /**
  * NOTE: TF is unable to destroy a target group while a listener is attached,
  * therefor we have to create a new one before destroying the old. This also means
  * we have to let it have a random name, and then tag it with the desired name.
  */
  lifecycle {
    create_before_destroy = true
  }

  tags = "${merge(var.tags, map("Name", "${var.prefix}-target-${var.target["port"]}"))}"
}

resource "aws_lb_listener" "main" {
  depends_on        = ["aws_lb_target_group.main"]
  count             = "${lookup(var.target, "port", "") == "" ? 0 : length(var.listeners)}"
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
  value = "${local.target["port"]}"
}
