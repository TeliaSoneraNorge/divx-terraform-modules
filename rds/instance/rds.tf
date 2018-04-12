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
  default     = "postgres"
}

variable "instance_type" {
  description = "Type of DB instance to provision."
  default     = "db.m3.medium"
}

variable "storage_size" {
  description = "Storage allocated for the DB."
  default     = "50"
}

variable "vpc_id" {
  description = "ID of the VPC for the subnets."
}

variable "subnet_ids" {
  description = "ID of subnets for the RDS subnet group."
  type        = "list"
}

variable "public_access" {
  description = "Flag whether the DB should be publicly accessible."
  default     = "false"
}

variable "skip_snapshot" {
  description = "Flag whether to skip the final snapshot."
  default     = "true"
}

variable "multi_az" {
  description = "Optional: Disable multiple availability zones for the DB instance."
  default     = "true"
}

variable "tags" {
  description = "A map of tags (key-value pairs) passed to resources."
  type        = "map"
  default     = {}
}

variable "db_name" {
  description = "Optional: The name of the database to create when the DB instance is created."
  default     = "main"
}

# -------------------------------------------------------------------------------
# Resources
# -------------------------------------------------------------------------------
resource "aws_db_instance" "main" {
  depends_on             = ["aws_db_subnet_group.main"]
  identifier             = "${var.prefix}-db"
  name                   = "${var.db_name}"
  username               = "${var.username}"
  password               = "${var.password}"
  port                   = "${var.port}"
  engine                 = "${var.engine}"
  instance_class         = "${var.instance_type}"
  storage_type           = "gp2"
  allocated_storage      = "${var.storage_size}"
  skip_final_snapshot    = "${var.skip_snapshot}"
  publicly_accessible    = "${var.public_access}"
  vpc_security_group_ids = ["${aws_security_group.main.id}"]
  multi_az               = "${var.multi_az}"

  # NOTE: This is duplicated because subnet_group does not return the name.
  db_subnet_group_name = "${var.prefix}-subnet-group"

  tags = "${merge(var.tags, map("Name", "${var.prefix}-db"))}"
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
  value = "${aws_db_instance.main.id}"
}

output "arn" {
  value = "${aws_db_instance.main.arn}"
}

output "address" {
  value = "${aws_db_instance.main.address}"
}

output "endpoint" {
  value = "${aws_db_instance.main.endpoint}"
}

output "connection_string" {
  value = "postgres://${var.username}:${var.password}@${aws_db_instance.main.address}:${var.port}/main"
}

output "port" {
  value = "${aws_db_instance.main.port}"
}

output "database" {
  value = "${aws_db_instance.main.name}"
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
