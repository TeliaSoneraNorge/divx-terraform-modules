provider "aws" {
  region = "eu-west-1"
}

module "machine_user" {
  source  = "github.com/TeliaSoneraNorge/divx-terraform-modules//iam/machine"
  prefix  = "example-machine-user"
  keybase = "colincoleman"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "",
            "Effect": "Allow",
            "Action": "*",
            "Resource": [
              "*"
            ]
        }
    ]
}
EOF
}
