provider "aws" {
  region = "eu-west-1"
}

module "certificate" {
  source  = "../"
  prefix  = "example"
  domain  = "example.com"
  zone_id = "D34D8E3F1733AA"

  tags {
    environment = "dev"
    terraform   = "True"
  }
}

output "certificate_arn" {
  value = "${module.certificate.certificate_arn}"
}
