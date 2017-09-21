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

variable "domain" {
  description = "The domain name to associate with the Drone ELB. (Must have an ACM certificate)."
}

variable "zone_id" {
  description = "Zone ID for the domains route53 alias record."
}

variable "certificate_arn" {
  description = "ACM certificate ARN for the domain."
}

variable "authorized_cidr" {
  description = "List of CIDR blocks which can reach the Drone web interface."
  type        = "list"
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
  description = "Shared secret used to authenticate agents with the Drone server. (KMS Encrypted)."
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
resource "aws_route53_record" "main" {
  zone_id = "${var.zone_id}"
  name    = "${var.domain}"
  type    = "A"

  alias {
    name                   = "${module.network.external_elb_dns}"
    zone_id                = "${module.network.external_elb_zone_id}"
    evaluate_target_health = false
  }
}

module "network" {
  source = "./network"

  prefix          = "${var.prefix}"
  environment     = "${var.environment}"
  certificate_arn = "${var.certificate_arn}"
  vpc_id          = "${var.vpc_id}"
  subnet_ids      = ["${var.subnet_ids}"]
}

module "server" {
  source = "./server"

  prefix              = "${var.prefix}"
  environment         = "${var.environment}"
  domain              = "${var.domain}"
  cluster_id          = "${module.cluster.id}"
  cluster_sg          = "${module.cluster.security_group_id}"
  cluster_role        = "${module.cluster.role_id}"
  load_balancer_name  = "${module.network.external_elb_name}"
  load_balancer_sg    = "${module.network.external_elb_sg}"
  postgres_connection = "${module.postgres.connection_string}"
  drone_secret        = "${var.drone_secret}"
  drone_github_org    = "${var.drone_github_org}"
  drone_github_admins = ["${var.drone_github_admins}"]
  drone_github_client = "${var.drone_github_client}"
  drone_github_secret = "${var.drone_github_secret}"
}

# Manually attach the internal ELB to the clusters ASG.
resource "aws_autoscaling_attachment" "cluster" {
  autoscaling_group_name = "${module.cluster.asg_id}"
  elb                    = "${module.network.internal_elb_id}"
}

module "agent" {
  source = "./agent"

  prefix       = "${var.prefix}"
  environment  = "${var.environment}"
  domain       = "${module.network.internal_elb_dns}"
  cluster_id   = "${module.cluster.id}"
  cluster_role = "${module.cluster.role_id}"
  task_count   = "${var.instance_count}"
  drone_secret = "${var.drone_secret}"
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

# http/https ingress to the cluster is set up by the container service module.
resource "aws_security_group_rule" "http_ingress" {
  security_group_id = "${module.network.external_elb_sg}"
  type              = "ingress"
  protocol          = "tcp"
  from_port         = "80"
  to_port           = "80"
  cidr_blocks       = ["${var.authorized_cidr}"]
}

resource "aws_security_group_rule" "https_ingress" {
  security_group_id = "${module.network.external_elb_sg}"
  type              = "ingress"
  protocol          = "tcp"
  from_port         = "443"
  to_port           = "443"
  cidr_blocks       = ["${var.authorized_cidr}"]
}

# Cluster should only allow GRPC ingress from the internal ELB
resource "aws_security_group_rule" "grpc_ingress" {
  security_group_id        = "${module.cluster.security_group_id}"
  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = "9000"
  to_port                  = "9000"
  source_security_group_id = "${module.network.internal_elb_sg}"
}

# Internal ELB needs access to do health checks on the cluster.
resource "aws_security_group_rule" "internal_elb_health_checks" {
  security_group_id        = "${module.cluster.security_group_id}"
  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = "8000"
  to_port                  = "8000"
  source_security_group_id = "${module.network.internal_elb_sg}"
}

# Cluster can ingress the internal ELB (which means agents can ingress on GRPC).
resource "aws_security_group_rule" "cluster_ingress_internal_grpc" {
  security_group_id        = "${module.network.internal_elb_sg}"
  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = "9000"
  to_port                  = "9000"
  source_security_group_id = "${module.cluster.security_group_id}"
}

# Postgres allow ingress from cluster.
resource "aws_security_group_rule" "server_ingress_postgres" {
  security_group_id        = "${module.postgres.security_group_id}"
  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = "${module.postgres.port}"
  to_port                  = "${module.postgres.port}"
  source_security_group_id = "${module.cluster.security_group_id}"
}

# ------------------------------------------------------------------------------
# Output
# ------------------------------------------------------------------------------
output "security_group_id" {
  value = "${module.cluster.security_group_id}"
}

output "endpoint" {
  value = "https://${var.domain}"
}
