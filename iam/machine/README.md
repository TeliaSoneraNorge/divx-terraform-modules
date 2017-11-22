## iam/machine
Module for creating a machine user

```hcl
module "machine_user" {
  source  = "./machine-user.tf"
  name    = "xqb-machine-user"
  pgp_key = "keybase:colincoleman"
  policy  = <<EOF
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

```
