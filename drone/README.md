## Drone.io (work in progress)

Template for provisioning a Drone.io cluster in an autoscaling group. Tracked in #18.

```hcl
provider "aws" {
  profile = "default"
  region  = "eu-west-1"
}

module "drone" {
  source = "../../drone"

  prefix              = "drone-test"
  environment         = "dev"
  vpc_id              = "vpc-12356789"
  subnet_ids          = ["subnet-12345678", "subnet-23456789"]
  instance_key        = ""
  drone_github_admins = ["itsdalmo"]
  drone_github_client = "<github-oauth-client>"
  drone_github_secret = "<github-oauth-secret>"
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
