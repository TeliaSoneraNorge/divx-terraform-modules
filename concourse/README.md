## Concourse CI

A Terraform module for deploying Concourse CI.

### Prerequisites

1. Route53 hosted zone, domain and ACM certificate.

2. Github Oauth application, with an encrypted password:

```bash
aws kms encrypt \
  --key-id <aws-kms-key-id> \
  --plaintext <github-client-secret> \
  --output text \
  --query CiphertextBlob \
  --profile default
```

3. You must generate the necessary keys for Concourse:

```bash
# Create folder
mkdir -p keys

ssh-keygen -t rsa -f ./keys/tsa_host_key -N ''
ssh-keygen -t rsa -f ./keys/worker_key -N ''
ssh-keygen -t rsa -f ./keys/session_signing_key -N ''

# Authorized workers
cp ./keys/worker_key.pub ./keys/authorized_worker_keys
```

### Deploy

```hcl
provider "aws" {
  profile = "default"
  region  = "eu-west-1"
}

module "vpc" {
  source        = "github.com/itsdalmo/tf-modules//ec2/vpc"

  prefix        = "concourse-ci"
  environment   = "dev"
  cidr_block    = "10.0.0.0/16"
  dns_hostnames = "true"
  public_ips    = "true"
}

module "bastion" {
  source      = "github.com/itsdalmo/tf-modules//bastion"

  prefix      = "concourse-ci"
  environment = "dev"
  vpc_id      = "${module.vpc.vpc_id}"
  subnet_ids  = "${module.vpc.subnet_ids}"
  pem_bucket  = "your-key-bucket"
  pem_path    = "example-key.pem"

  authorized_keys = [
    "ssh-rsa <your-public-key>",
  ]

  authorized_cidr = [
    "0.0.0.0/0",
  ]
}

module "concourse" {
  source = "github.com/itsdalmo/tf-modules//concourse/"

  prefix               = "concourse-ci"
  environment          = "dev"
  domain               = "ci.example.com"
  zone_id              = "<zone-id>"
  concourse_keys       = "${path.root}/keys"
  vpc_id               = "${module.vpc.vpc_id}"
  subnet_ids           = "${module.vpc.subnet_ids}"
  authorized_cidr      = ["0.0.0.0/0"]
  postgres_username    = "someuser"
  postgres_password    = "<kms-encrypted-password>"
  instance_key         = "<instance-key-pair>"
  github_client_id     = "<github-client-id>"
  github_client_secret = "<kms-encrypted-github-client-secret>"

  github_users = [
    "itsdalmo",
  ]
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
    effect    = "Allow"
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
```

### Example

Install the `fly` cli and run the following:

```bash
fly -t example login -c https://ci.example.com
fly -t example set-pipeline -p hello-world -c ./example/hello_world.yml
fly -t example unpause-pipeline -p hello-world
```

Log on the concourse web front end and manually trigger the job afterward.
