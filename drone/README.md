## Drone.io (work in progress)

Template for provisioning a Drone.io cluster in an autoscaling group. Tracked in [#18](https://github.com/TeliaSoneraNorge/divx-terraform-modules/issues/18).

```hcl
provider "aws" {
  profile = "default"
  region  = "eu-west-1"
}

module "drone" {
  source = "../../drone"

  prefix              = "drone-test"
  domain              = "drone.example.com"
  zone_id             = "<parent-domain-zone-id>"
  certificate_arn     = "<domain-certificate-arn>"
  authorized_cidr     = ["0.0.0.0/0"]
  vpc_id              = "vpc-12356789"
  subnet_ids          = ["subnet-12345678", "subnet-23456789"]
  instance_key        = ""
  drone_secret        = "<kms-encrypted-secret>"
  postgres_password   = "<kms-encrypted-password>"
  drone_github_admins = ["itsdalmo"]
  drone_github_client = "<github-oauth-client>"
  drone_github_secret = "<github-oauth-secret>"

  tags {
    terraform   = "True"
    environment = "dev"
  }
}

resource "aws_security_group_rule" "ssh_ingress" {
  security_group_id        = "${module.drone.security_group_id}"
  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = "22"
  to_port                  = "22"
  source_security_group_id = "sg-12345678"
}
```
