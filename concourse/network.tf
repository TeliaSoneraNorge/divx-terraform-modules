# -------------------------------------------------------------------------------
# Resources
# -------------------------------------------------------------------------------
resource "aws_security_group_rule" "ingress" {
  security_group_id = "${module.external_lb.security_group_id}"
  type              = "ingress"
  protocol          = "tcp"
  from_port         = "${var.web_port}"
  to_port           = "${var.web_port}"
  cidr_blocks       = ["${var.authorized_cidr}"]
}

resource "aws_route53_record" "main" {
  zone_id = "${var.zone_id}"
  name    = "${var.domain}"
  type    = "A"

  alias {
    name                   = "${module.external_lb.dns_name}"
    zone_id                = "${module.external_lb.zone_id}"
    evaluate_target_health = false
  }
}

module "external_lb" {
  source = "../ec2/lb"

  prefix     = "${var.prefix}-external"
  type       = "application"
  internal   = "false"
  vpc_id     = "${var.vpc_id}"
  subnet_ids = "${var.public_subnet_ids}"
  tags       = "${var.tags}"
}

module "internal_lb" {
  source = "../ec2/lb"

  prefix     = "${var.prefix}-internal"
  type       = "network"
  internal   = "true"
  vpc_id     = "${var.vpc_id}"
  subnet_ids = "${var.private_subnet_ids}"
  tags       = "${var.tags}"
}

module "external_target" {
  source            = "../container/target"
  prefix            = "${var.prefix}"
  vpc_id            = "${var.vpc_id}"
  load_balancer_arn = "${module.external_lb.arn}"
  tags              = "${var.tags}"

  target {
    attachment = "${module.atc.id}"
    protocol   = "HTTP"
    port       = "${var.atc_port}"
    health     = "HTTP:traffic-port/"
  }

  listeners = [{
    protocol        = "HTTPS"
    port            = "${var.web_port}"
    certificate_arn = "${var.certificate_arn}"
  }]
}

module "internal_target" {
  source            = "../container/target"
  prefix            = "${var.prefix}"
  vpc_id            = "${var.vpc_id}"
  load_balancer_arn = "${module.internal_lb.arn}"
  tags              = "${var.tags}"

  target {
    attachment = "${module.atc.id}"
    protocol   = "TCP"
    port       = "${var.tsa_port}"
    health     = "TCP:${var.tsa_port}"
  }

  listeners = [
    {
      protocol = "TCP"
      port     = "${var.tsa_port}"
    },
    {
      protocol = "TCP"
      port     = "80"
    },
  ]
}