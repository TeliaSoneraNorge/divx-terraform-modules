provider "aws" {
  region = "eu-west-1"
}

# NOTE: This is the recommended way of passing secrets (marked as SECRET).
# data "aws_kms_secret" "decrypted" {
#   secret {
#     name    = "postgres_password"
#     payload = "<secret>"
#   }

#   secret {
#     name    = "github_secret"
#     payload = "<secret>"
#   }

#   secret {
#     name    = "vault_token"
#     payload = "<secret>"
#   }

#   secret {
#     name    = "encryption_key"
#     payload = "<secret>"
#   }
# }

module "vpc" {
  source = "github.com/TeliaSoneraNorge/divx-terraform-modules//ec2/vpc"

  prefix          = "concourse-ci"
  cidr_block      = "10.0.0.0/16"
  dns_hostnames   = "true"
  private_subnets = "3"

  tags {
    terraform   = "True"
    environment = "dev"
  }
}

module "bastion" {
  source = "github.com/TeliaSoneraNorge/divx-terraform-modules//bastion"

  prefix     = "concourse-ci"
  vpc_id     = "${module.vpc.vpc_id}"
  subnet_ids = "${module.vpc.public_subnet_ids}"
  pem_bucket = "your-key-bucket"
  pem_path   = "example-key.pem"

  authorized_keys = [
    "ssh-rsa <your-public-key>",
  ]

  authorized_cidr = [
    "0.0.0.0/0",
  ]

  tags {
    terraform   = "True"
    environment = "dev"
  }
}

module "concourse" {
  source = "../"

  prefix               = "concourse-ci"
  domain               = "ci.example.com"
  zone_id              = "<zone-id>"
  certificate_arn      = "arn:aws:acm:eu-west-1:123456789101:certificate/e234a5c6-43e4-4532-9f24-f318dcae78e5"
  concourse_keys       = "${path.root}/keys"
  vpc_id               = "${module.vpc.vpc_id}"
  public_subnet_ids    = "${module.vpc.public_subnet_ids}"
  private_subnet_ids   = "${module.vpc.private_subnet_ids}"
  authorized_cidr      = ["0.0.0.0/0"]
  postgres_username    = "superuser"
  postgres_password    = "SECRET"
  instance_key         = "VARIABLE"
  github_client_id     = "VARIABLE"
  github_client_secret = "SECRET"
  vault_url            = "https://vault.example.com"
  vault_client_token   = "SECRET"
  encryption_key       = "SECRET"

  github_users = [
    "itsdalmo",
  ]

  github_teams = []

  tags {
    terraform   = "True"
    environment = "dev"
  }
}

# Open ATC and workers to Bastion SSH
resource "aws_security_group_rule" "bastion_ingress_atc" {
  security_group_id        = "${module.concourse.atc_sg}"
  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = "22"
  to_port                  = "22"
  source_security_group_id = "${module.bastion.security_group_id}"
}

resource "aws_security_group_rule" "bastion_ingress_worker" {
  security_group_id        = "${module.concourse.worker_sg}"
  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = "22"
  to_port                  = "22"
  source_security_group_id = "${module.bastion.security_group_id}"
}

# Allow workers to fetch ECR images
resource "aws_iam_role_policy" "main" {
  name   = "concourse-ci-worker-ecr-policy"
  role   = "${module.concourse.worker_role_id}"
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

output "endpoint" {
  value = "${module.concourse.endpoint}"
}
