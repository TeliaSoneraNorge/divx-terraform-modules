## iam/machine
Module for creating a machine user

```hcl
module "machine_user" {
  source  = "github.com/TeliaSoneraNorge/divx-terraform-modules//iam/machine"
  prefix    = "xqb-machine-user"
  keybase = "colincoleman"
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
