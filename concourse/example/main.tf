provider "aws" {
  region = "eu-west-1"
}

module "vpc" {
  source = "github.com/TeliaSoneraNorge/divx-terraform-modules//ec2/vpc"

  prefix          = "concourse-ci"
  cidr_block      = "10.0.0.0/16"
  dns_hostnames   = "true"
  private_subnets = "3"

  tags = "${var.tags}"
}

module "bastion" {
  source = "github.com/TeliaSoneraNorge/divx-terraform-modules//bastion"

  prefix     = "${var.prefix}"
  vpc_id     = "${module.vpc.vpc_id}"
  subnet_ids = "${module.vpc.public_subnet_ids}"
  pem_bucket = "${var.pem_bucket}"
  pem_path   = "${var.pem_path}"

  authorized_keys = ["${var.authorized_keys}"]

  authorized_cidr = [
    "0.0.0.0/0",
  ]

  tags = "${var.tags}"
}

module "postgres" {
  source = "github.com/TeliaSoneraNorge/divx-terraform-modules//rds/cluster"

  prefix     = "${var.prefix}-aurora"
  username   = "superuser"
  password   = "${var.postgres_password}"
  port       = "5439"
  vpc_id     = "${module.vpc.vpc_id}"
  subnet_ids = ["${module.vpc.private_subnet_ids}"]

  tags = "${var.tags}"
}

module "concourse_atc" {
  source = "../atc"

  prefix               = "${var.prefix}"
  domain               = "${var.domain}"
  zone_id              = "${var.zone_id}"
  web_certificate_arn  = "${var.certificate_arn}"
  web_protocol         = "${var.web_protocol}"
  web_port             = "${var.web_port}"
  authorized_cidr      = ["0.0.0.0/0"]
  concourse_keys       = "${path.root}/keys"
  vpc_id               = "${module.vpc.vpc_id}"
  public_subnet_ids    = "${module.vpc.public_subnet_ids}"
  private_subnet_ids   = "${module.vpc.private_subnet_ids}"
  postgres_connection  = "${module.postgres.connection_string}"
  encryption_key       = "${var.encryption_key}"
  instance_ami         = "${var.instance_ami}"
  instance_key         = "${var.instance_key}"
  basic_auth_username  = "${var.basic_auth_username}"
  basic_auth_password  = "${var.basic_auth_password}"
  github_client_id     = "${var.github_client}"
  github_client_secret = "${var.github_secret}"
  github_users         = ["${var.github_users}"]
  github_teams         = ["${var.github_teams}"]

  tags = "${var.tags}"
}

module "concourse_worker" {
  source = "../worker"

  prefix             = "${var.prefix}"
  concourse_keys     = "${path.root}/keys"
  vpc_id             = "${module.vpc.vpc_id}"
  public_subnet_ids  = "${module.vpc.public_subnet_ids}"
  private_subnet_ids = "${module.vpc.private_subnet_ids}"
  atc_sg             = "${module.concourse_atc.security_group_id}"
  tsa_host           = "${module.concourse_atc.tsa_host}"
  tsa_port           = "${module.concourse_atc.tsa_port}"
  instance_ami       = "${var.instance_ami}"
  instance_key       = "${var.instance_key}"

  tags = "${var.tags}"
}

# ATC ingress postgres
resource "aws_security_group_rule" "atc_ingress_postgres" {
  security_group_id        = "${module.postgres.security_group_id}"
  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = "${module.postgres.port}"
  to_port                  = "${module.postgres.port}"
  source_security_group_id = "${module.concourse_atc.security_group_id}"
}

# Open ATC and workers to Bastion SSH
resource "aws_security_group_rule" "bastion_ingress_atc" {
  security_group_id        = "${module.concourse_atc.security_group_id}"
  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = "22"
  to_port                  = "22"
  source_security_group_id = "${module.bastion.security_group_id}"
}

resource "aws_security_group_rule" "bastion_ingress_worker" {
  security_group_id        = "${module.concourse_worker.security_group_id}"
  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = "22"
  to_port                  = "22"
  source_security_group_id = "${module.bastion.security_group_id}"
}

# Allow workers to fetch ECR images
resource "aws_iam_role_policy" "main" {
  name   = "${var.prefix}-worker-ecr-policy"
  role   = "${module.concourse_worker.role_id}"
  policy = "${data.aws_iam_policy_document.worker.json}"
}

data "aws_iam_policy_document" "worker" {
  statement {
    effect = "Allow"

    actions = [
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:GetRepositoryPolicy",
      "ecr:DescribeRepositories",
      "ecr:ListImages",
      "ecr:DescribeImages",
      "ecr:BatchGetImage",
    ]

    resources = ["*"]
  }
}
