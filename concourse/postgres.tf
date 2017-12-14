# -------------------------------------------------------------------------------
# Resources
# -------------------------------------------------------------------------------
resource "aws_security_group_rule" "atc_ingress_postgres" {
  security_group_id        = "${module.postgres.security_group_id}"
  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = "${module.postgres.port}"
  to_port                  = "${module.postgres.port}"
  source_security_group_id = "${module.atc.security_group_id}"
}

module "postgres" {
  source = "../rds/cluster"

  prefix     = "${var.prefix}-aurora"
  username   = "${var.postgres_username}"
  password   = "${var.postgres_password}"
  port       = "${var.postgres_port}"
  vpc_id     = "${var.vpc_id}"
  subnet_ids = ["${var.private_subnet_ids}"]
  tags       = "${var.tags}"
}
