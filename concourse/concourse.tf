# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
variable "prefix" {
  description = "Prefix used for resource names."
}

variable "domain" {
  description = "The domain name to associate with the Concourse ELB. (Must have an ACM certificate)."
}

variable "zone_id" {
  description = "Zone ID for the domains route53 alias record."
}

variable "certificate_arn" {
  description = "ACM certificate ARN for the domain."
}

variable "vpc_id" {
  description = "ID of the VPC for the subnets."
}

variable "subnet_ids" {
  description = "ID of subnets where Concourse will be deployed."
  type        = "list"
}

variable "concourse_keys" {
  description = "Path to a directory containing the Concourse SSH keys. (See README.md)."
}

variable "authorized_cidr" {
  description = "List of authorized CIDR blocks which can reach the Concourse web interface."
  type        = "list"
}

variable "github_client_id" {
  description = "Client ID of the Github Oauth application."
}

variable "github_client_secret" {
  description = "Client secret for the Github Oauth application."
}

variable "github_users" {
  description = "List of Github users that can log into the main Concourse team."
  type        = "list"
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

variable "instance_key" {
  description = "EC2 key-pair for Concourse instances."
  default     = ""
}

variable "instance_ami" {
  description = "CoreOS AMI ID for Concourse instances."
  default     = "ami-bbaf0ac2"
}

variable "image_repository" {
  description = "Concourse image repository."
  default     = "concourse/concourse"
}

variable "image_version" {
  description = "Concourse image version."
  default     = "3.6.0"
}

variable "atc_count" {
  description = "Number of ATC instances to provision."
  default     = "2"
}

variable "atc_type" {
  description = "Instance type to provision for the Concourse ATC."
  default     = "t2.small"
}

variable "worker_count" {
  description = "Number of concourse workers to provision."
  default     = "3"
}

variable "worker_type" {
  description = "Instance type to provision for the Concourse workers."
  default     = "t2.medium"
}

variable "web_port" {
  description = "Port specification for the Concourse web interface."
  default     = "443"
}

variable "atc_port" {
  description = "Port specification for the Concourse ATC."
  default     = "8080"
}

variable "tsa_port" {
  description = "Port specification for the Concourse TSA."
  default     = "2222"
}

variable "log_level" {
  description = "Concourse log level (debug|info|error|fatal) for ATC, TSA and Baggageclaim."
  default     = "info"
}

variable "vault_url" {
  description = "Optional: DNS name for the vault backend."
  default     = ""
}

variable "vault_client_token" {
  description = "Optional: Vault client token."
  default     = ""
}

variable "encryption_key" {
  description = "Optional: Key used for encrypting database entries."
}

variable "old_encryption_key" {
  description = "Optional: When changing the encryption key you must use this variable to set the old encryption key."
  default     = ""
}

variable "tags" {
  description = "A map of tags (key-value pairs) passed to resources."
  type        = "map"
  default     = {}
}

# -------------------------------------------------------------------------------
# Resources
# -------------------------------------------------------------------------------
data "aws_region" "current" {
  current = true
}

module "external_elb" {
  source = "./modules/external_elb"

  prefix          = "${var.prefix}-external-elb"
  domain          = "${var.domain}"
  zone_id         = "${var.zone_id}"
  certificate_arn = "${var.certificate_arn}"
  vpc_id          = "${var.vpc_id}"
  subnet_ids      = ["${var.subnet_ids}"]
  authorized_cidr = ["${var.authorized_cidr}"]
  web_port        = "${var.web_port}"
  atc_port        = "${var.atc_port}"
  tags            = "${var.tags}"
}

module "internal_elb" {
  source = "./modules/internal_elb"

  prefix     = "${var.prefix}-internal-elb"
  vpc_id     = "${var.vpc_id}"
  subnet_ids = ["${var.subnet_ids}"]
  tsa_port   = "${var.tsa_port}"
  tags       = "${var.tags}"
}

module "postgres" {
  source = "../rds/instance"

  prefix        = "${var.prefix}-rds"
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
  tags          = "${var.tags}"
}

resource "aws_security_group_rule" "atc_ingress_postgres" {
  security_group_id        = "${module.postgres.security_group_id}"
  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = "${module.postgres.port}"
  to_port                  = "${module.postgres.port}"
  source_security_group_id = "${module.atc.security_group_id}"
}

# Atc ---------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "atc" {
  name = "${var.prefix}-atc"
}

data "template_file" "atc" {
  template = "${file("${path.module}/config/atc.yml")}"

  vars {
    image_version             = "${var.image_version}"
    image_repository          = "${var.image_repository}"
    github_client_id          = "${var.github_client_id}"
    github_client_secret      = "${var.github_client_secret}"
    github_users              = "${join(",", "${var.github_users}")}"
    concourse_web_host        = "https://${var.domain}:${var.web_port}"
    concourse_postgres_source = "${module.postgres.connection_string}"
    log_group_name            = "${aws_cloudwatch_log_group.atc.name}"
    log_group_region          = "${data.aws_region.current.name}"
    log_level                 = "${var.log_level}"
    tsa_host_key              = "${file("${var.concourse_keys}/tsa_host_key")}"
    session_signing_key       = "${file("${var.concourse_keys}/session_signing_key")}"
    authorized_worker_keys    = "${file("${var.concourse_keys}/authorized_worker_keys")}"
    atc_port                  = "${var.atc_port}"
    tsa_port                  = "${var.tsa_port}"
    vault_url                 = "${var.vault_url}"
    vault_client_token        = "${var.vault_client_token}"
    encryption_key            = "${var.encryption_key}"
    old_encryption_key        = "${var.old_encryption_key}"
  }
}

data "aws_iam_policy_document" "atc" {
  statement {
    effect = "Allow"

    resources = [
      "${aws_cloudwatch_log_group.atc.arn}",
    ]

    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
  }

  statement {
    effect = "Allow"

    resources = ["*"]

    actions = [
      "cloudwatch:PutMetricData",
      "cloudwatch:GetMetricStatistics",
      "cloudwatch:ListMetrics",
      "ec2:DescribeTags",
    ]
  }
}

module "atc" {
  source = "../ec2/asg"

  prefix          = "${var.prefix}-atc"
  user_data       = "${data.template_file.atc.rendered}"
  vpc_id          = "${var.vpc_id}"
  subnet_ids      = "${var.subnet_ids}"
  instance_policy = "${data.aws_iam_policy_document.atc.json}"
  instance_count  = "${var.atc_count}"
  instance_type   = "${var.atc_type}"
  instance_ami    = "${var.instance_ami}"
  instance_key    = "${var.instance_key}"
  tags            = "${var.tags}"
}

resource "aws_autoscaling_attachment" "atc_internal" {
  autoscaling_group_name = "${module.atc.id}"
  elb                    = "${module.internal_elb.name}"
}

resource "aws_autoscaling_attachment" "atc_external" {
  autoscaling_group_name = "${module.atc.id}"
  elb                    = "${module.external_elb.name}"
}

resource "aws_security_group_rule" "elb_ingress_tsa" {
  security_group_id        = "${module.atc.security_group_id}"
  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = "${var.tsa_port}"
  to_port                  = "${var.tsa_port}"
  source_security_group_id = "${module.internal_elb.security_group_id}"
}

resource "aws_security_group_rule" "elb_ingress_atc" {
  security_group_id        = "${module.atc.security_group_id}"
  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = "${var.atc_port}"
  to_port                  = "${var.atc_port}"
  source_security_group_id = "${module.external_elb.security_group_id}"
}

# Worker ------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "worker" {
  name = "${var.prefix}-worker"
}

data "template_file" "worker" {
  template = "${file("${path.module}/config/worker.yml")}"

  vars {
    image_version      = "${var.image_version}"
    image_repository   = "${var.image_repository}"
    concourse_tsa_host = "${module.internal_elb.dns_name}"
    log_group_name     = "${aws_cloudwatch_log_group.worker.name}"
    log_group_region   = "${data.aws_region.current.name}"
    log_level          = "${var.log_level}"
    worker_key         = "${file("${var.concourse_keys}/worker_key")}"
    pub_worker_key     = "${file("${var.concourse_keys}/worker_key.pub")}"
    pub_tsa_host_key   = "${file("${var.concourse_keys}/tsa_host_key.pub")}"
  }
}

data "aws_iam_policy_document" "worker" {
  statement {
    effect = "Allow"

    resources = [
      "${aws_cloudwatch_log_group.worker.arn}",
    ]

    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
  }

  statement {
    effect = "Allow"

    resources = ["*"]

    actions = [
      "cloudwatch:PutMetricData",
      "cloudwatch:GetMetricStatistics",
      "cloudwatch:ListMetrics",
      "ec2:DescribeTags",
    ]
  }
}

module "worker" {
  source = "../ec2/asg"

  prefix               = "${var.prefix}-worker"
  user_data            = "${data.template_file.worker.rendered}"
  vpc_id               = "${var.vpc_id}"
  subnet_ids           = "${var.subnet_ids}"
  instance_policy      = "${data.aws_iam_policy_document.worker.json}"
  instance_count       = "${var.worker_count}"
  instance_type        = "${var.worker_type}"
  instance_volume_size = "50"
  instance_ami         = "${var.instance_ami}"
  instance_key         = "${var.instance_key}"
  tags                 = "${var.tags}"
}

resource "aws_security_group_rule" "worker_ingress_tsa" {
  security_group_id        = "${module.internal_elb.security_group_id}"
  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = "${var.tsa_port}"
  to_port                  = "${var.tsa_port}"
  source_security_group_id = "${module.worker.security_group_id}"
}

resource "aws_security_group_rule" "worker_ingress_web" {
  security_group_id        = "${module.internal_elb.security_group_id}"
  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = "80"
  to_port                  = "80"
  source_security_group_id = "${module.worker.security_group_id}"
}

resource "aws_security_group_rule" "atc_ingress_baggageclaim" {
  security_group_id        = "${module.worker.security_group_id}"
  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = "7788"
  to_port                  = "7788"
  source_security_group_id = "${module.atc.security_group_id}"
}

resource "aws_security_group_rule" "atc_ingress_garden" {
  security_group_id        = "${module.worker.security_group_id}"
  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = "7777"
  to_port                  = "7777"
  source_security_group_id = "${module.atc.security_group_id}"
}

# -------------------------------------------------------------------------------
# Output
# -------------------------------------------------------------------------------
output "worker_role_arn" {
  value = "${module.worker.role_arn}"
}

output "worker_role_id" {
  value = "${module.worker.role_id}"
}

output "atc_role_arn" {
  value = "${module.atc.role_arn}"
}

output "atc_role_id" {
  value = "${module.atc.role_id}"
}

output "worker_sg" {
  value = "${module.worker.security_group_id}"
}

output "atc_sg" {
  value = "${module.atc.security_group_id}"
}

output "external_elb_sg" {
  value = "${module.external_elb.security_group_id}"
}

output "internal_elb_sg" {
  value = "${module.internal_elb.security_group_id}"
}

output "postgres_sg" {
  value = "${module.postgres.security_group_id}"
}

output "postgres_port" {
  value = "${module.postgres.port}"
}

output "endpoint" {
  value = "https://${var.domain}:${var.web_port}"
}
