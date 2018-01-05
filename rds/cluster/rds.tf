# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
variable "prefix" {
  description = "A prefix used for naming resources."
}

variable "username" {
  description = "Username."
}

variable "password" {
  description = "Password."
}

variable "port" {
  description = "Database port."
  default     = "5439"
}

variable "engine" {
  description = "Type of DB engine."
  default     = "aurora-postgresql"
}

variable "instance_type" {
  description = "Type of DB instance to provision."
  default     = "db.r4.large"
}

variable "instance_count" {
  description = "Number of DB instances to provision for the cluster."
  default     = "1"
}

variable "vpc_id" {
  description = "ID of the VPC for the subnets."
}

variable "subnet_ids" {
  description = "ID of subnets for the RDS subnet group."
  type        = "list"
}

variable "tags" {
  description = "A map of tags (key-value pairs) passed to resources."
  type        = "map"
  default     = {}
}

# -------------------------------------------------------------------------------
# Resources
# -------------------------------------------------------------------------------
data "aws_availability_zones" "available" {}

resource "aws_rds_cluster" "main" {
  cluster_identifier           = "${var.prefix}-cluster"
  database_name                = "main"
  master_username              = "${var.username}"
  master_password              = "${var.password}"
  port                         = "${var.port}"
  engine                       = "${var.engine}"
  backup_retention_period      = 7
  preferred_backup_window      = "02:00-03:00"
  preferred_maintenance_window = "wed:04:00-wed:04:30"
  skip_final_snapshot          = "true"
  vpc_security_group_ids       = ["${aws_security_group.main.id}"]

  # NOTE: This is duplicated because subnet_group does not return the name.
  db_subnet_group_name = "${var.prefix}-subnet-group"

  tags = "${merge(var.tags, map("Name", "${var.prefix}-cluster"))}"
}

resource "aws_rds_cluster_instance" "main" {
  count                = "${var.instance_count}"
  identifier           = "${var.prefix}-instance-${count.index + 1}"
  cluster_identifier   = "${aws_rds_cluster.main.id}"
  instance_class       = "${var.instance_type}"
  engine               = "${var.engine}"
  db_subnet_group_name = "${aws_db_subnet_group.main.name}"
  publicly_accessible  = true

  tags = "${merge(var.tags, map("Name", "${var.prefix}-instance-${count.index + 1}"))}"
}

resource "aws_db_subnet_group" "main" {
  name        = "${var.prefix}-subnet-group"
  description = "Terraformed subnet group."
  subnet_ids  = ["${var.subnet_ids}"]

  tags = "${merge(var.tags, map("Name", "${var.prefix}-subnet-group"))}"
}

resource "aws_security_group" "main" {
  name        = "${var.prefix}-sg"
  description = "Terraformed security group."
  vpc_id      = "${var.vpc_id}"

  tags = "${merge(var.tags, map("Name", "${var.prefix}-sg"))}"
}

resource "aws_security_group_rule" "egress" {
  security_group_id = "${aws_security_group.main.id}"
  type              = "egress"
  protocol          = "-1"
  from_port         = 0
  to_port           = 0
  cidr_blocks       = ["0.0.0.0/0"]
}

# ------------------------------------------------------------------------------
# Output
# ------------------------------------------------------------------------------
output "id" {
  value = "${aws_rds_cluster.main.id}"
}

output "endpoint" {
  value = "${aws_rds_cluster.main.endpoint}"
}

output "connection_string" {
  value = "postgres://${var.username}:${var.password}@${aws_rds_cluster.main.endpoint}:${var.port}/main"
}

output "port" {
  value = "${aws_rds_cluster.main.port}"
}

output "database" {
  value = "${aws_rds_cluster.main.database_name}"
}

output "security_group_id" {
  value = "${aws_security_group.main.id}"
}

output "subnet_group_id" {
  value = "${aws_db_subnet_group.main.id}"
}

output "subnet_group_arn" {
  value = "${aws_db_subnet_group.main.arn}"
}
