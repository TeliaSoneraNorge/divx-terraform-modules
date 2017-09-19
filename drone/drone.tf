# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
variable "prefix" {
  description = "A prefix used for naming resources."
}

variable "environment" {
  description = "Environment tag which is applied to resources."
  default     = ""
}

variable "vpc_id" {
  description = "ID of the VPC for the subnets."
}

variable "subnet_ids" {
  description = "ID of subnets where bastion can be provisioned."
  type        = "list"
}

variable "instance_type" {
  description = "Type of instance to provision."
  default     = "m3.medium"
}

variable "instance_count" {
  description = "Desired (and minimum) number of instances."
  default     = "2"
}

variable "instance_key" {
  description = "Name of an EC2 key-pair for SSH access."
  default     = ""
}

variable "postgres_username" {
  description = "Username for Postgres."
  default     = "superuser"
}

variable "postgres_password" {
  description = "Password for Postgres (KMS Encrypted)."
}

variable "postgres_port" {
  description = "Port specification for Postgres."
  default     = "5439"
}

variable "drone_secret" {
  description = "Shared secret used to authenticate agents with the Drone server."
  default     = "12345"
}

variable "drone_github_org" {
  description = "Drone Github organization which is allowed to create users."
  default     = ""
}

variable "drone_github_admins" {
  description = "Github usernames which are allowed to administrate Drone."
  type        = "list"
}

variable "drone_github_client" {
  description = "Drone Github client."
}

variable "drone_github_secret" {
  description = "Drone Github secret."
}

# ------------------------------------------------------------------------------
# Resources
# ------------------------------------------------------------------------------
data "aws_region" "current" {
  current = true
}

module "cluster" {
  source = "../container/cluster"

  prefix         = "${var.prefix}"
  environment    = "${var.environment}"
  vpc_id         = "${var.vpc_id}"
  subnet_ids     = ["${var.subnet_ids}"]
  instance_type  = "${var.instance_type}"
  instance_count = "${var.instance_count}"
  instance_key   = "${var.instance_key}"
}

module "postgres" {
  source = "../rds/instance"

  prefix        = "${var.prefix}-rds"
  environment   = "${var.environment}"
  username      = "${var.postgres_username}"
  password      = "${var.postgres_password}"
  port          = "${var.postgres_port}"
  vpc_id        = "${var.vpc_id}"
  subnet_ids    = ["${var.subnet_ids}"]
  engine        = "postgres"
  instance_type = "db.m3.medium"
  storage_size  = "50"
  public_access = "false"
  skip_snapshot = "true"
}

resource "aws_elb" "main" {
  name            = "${var.prefix}-elb"
  subnets         = ["${var.subnet_ids}"]
  security_groups = ["${aws_security_group.main.id}"]

  listener {
    instance_port     = "8000"
    instance_protocol = "tcp"
    lb_port           = "80"
    lb_protocol       = "tcp"
  }

  listener {
    instance_port     = "9000"
    instance_protocol = "tcp"
    lb_port           = "9000"
    lb_protocol       = "tcp"
  }

  health_check {
    target              = "HTTP:8000/"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    interval            = 30
  }

  tags {
    Name        = "${var.prefix}"
    terraform   = "true"
    environment = "${var.environment}"
  }
}

resource "aws_security_group" "main" {
  name        = "${var.prefix}-sg"
  description = "Security group for the Drone.io ELB."
  vpc_id      = "${var.vpc_id}"

  lifecycle {
    create_before_destroy = true
  }

  tags {
    Name        = "${var.prefix}-sg"
    terraform   = "true"
    environment = "${var.environment}"
  }
}

resource "aws_security_group_rule" "server_ingress_postgres" {
  security_group_id        = "${module.postgres.security_group_id}"
  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = "${module.postgres.port}"
  to_port                  = "${module.postgres.port}"
  source_security_group_id = "${module.cluster.security_group_id}"
}

resource "aws_security_group_rule" "outbound" {
  security_group_id = "${aws_security_group.main.id}"
  type              = "egress"
  protocol          = "-1"
  from_port         = 0
  to_port           = 0
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "web_ingress" {
  security_group_id = "${aws_security_group.main.id}"
  type              = "ingress"
  protocol          = "tcp"
  from_port         = "80"
  to_port           = "80"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "agent_ingress" {
  security_group_id = "${aws_security_group.main.id}"
  type              = "ingress"
  protocol          = "tcp"
  from_port         = "9000"
  to_port           = "9000"
  cidr_blocks       = ["0.0.0.0/0"]
}

# ------------------------------------------------------------------------------
# Output
# ------------------------------------------------------------------------------
output "security_group_id" {
  value = "${module.cluster.security_group_id}"
}

output "endpoint" {
  value = "${aws_elb.main.dns_name}"
}
