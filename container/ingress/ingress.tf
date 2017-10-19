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

variable "cluster_sg" {
  description = "Security group of the container cluster."
}

variable "load_balancer_arn" {
  description = "ARN of the load balancer (network or application)."
  default     = ""
}

variable "load_balancer_sg" {
  description = "Security group of the load balancer."
  default     = ""
}

variable "target" {
  description = "Configuration for the target group attached to the cluster."
  default     = {}
}

variable "health" {
  description = "Configuration for the health check for the target group."
  default     = {}
}

variable "listeners" {
  description = "Configuration of listeners for the load balancer which are forwarded to the target group. (Protocol can be TCP, HTTP, HTTPS or HTTP/S)."
  default     = {}
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
  default_target = {
    port              = ""
    protocol          = "TCP"
  }
  target = "${merge(local.default_target, var.target)}"

  default_health = {
    port              = "${local.target["port"]}"
    path              = "/"
    protocol          = "${local.target["protocol"]}"
  }
  health = "${merge(local.default_health, var.health)}"

  default_listeners = {
    protocol              = "HTTP"
    ports                 = "80"
    certificate_arn       = ""
  }
  listeners = "${merge(local.default_listeners, var.listeners)}"

  # Listener related variables
  ports    = "${split(",", local.listeners["ports"])}"
  protocol = "${local.listeners["protocol"]}"
  http     = "${local.protocol == "HTTP" || local.protocol == "HTTP/S" ? "true" : "false"}"
  https    = "${local.protocol == "HTTPS" || local.protocol == "HTTP/S" ? "true" : "false"}"
  tcp      = "${local.http || local.https ? "false" : "true" }"
}

resource "aws_lb_target_group" "main" {
  depends_on = ["aws_iam_role_policy.service_permissions"]
  vpc_id     = "${var.vpc_id}"
  port       = "${local.target["port"]}"
  protocol   = "${local.target["protocol"]}"

  health_check {
    path                = "${local.health["path"]}"
    port                = "${local.health["port"]}"
    protocol            = "${local.health["protocol"]}"
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

  tags = "${merge(var.tags, map("Name", "${var.prefix}-target-${local.target["port"]}"))}"
}


resource "aws_lb_listener" "http" {
  depends_on        = ["aws_lb_target_group.main"]
  count             = "${local.http == "true" ? 1 : 0}"
  load_balancer_arn = "${var.load_balancer_arn}"
  port              = "${element(local.ports, 0)}"
  protocol          = "HTTP"

  default_action {
    target_group_arn = "${aws_lb_target_group.main.arn}"
    type             = "forward"
  }
}

resource "aws_lb_listener" "https" {
  depends_on        = ["aws_lb_target_group.main"]
  count             = "${local.https == "true" ? 1 : 0}"
  load_balancer_arn = "${var.load_balancer_arn}"
  port              = "${element(local.ports, 1)}"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2015-05"
  certificate_arn   = "${local.targets["certificate_arn"]}"

  default_action {
    target_group_arn = "${aws_lb_target_group.main.arn}"
    type             = "forward"
  }
}

resource "aws_lb_listener" "tcp" {
  depends_on        = ["aws_lb_target_group.main"]
  count             = "${local.tcp == "true" ? length(local.ports) : 0}"
  load_balancer_arn = "${var.load_balancer_arn}"
  port              = "${element(local.ports, count.index)}"
  protocol          = "TCP"

  default_action {
    target_group_arn = "${aws_lb_target_group.main.arn}"
    type             = "forward"
  }
}

# ------------------------------------------------------------------------------
# Output
# ------------------------------------------------------------------------------
output "target_group_arn" {
  value = "${aws_lb_target_group.main.arn}"
}
