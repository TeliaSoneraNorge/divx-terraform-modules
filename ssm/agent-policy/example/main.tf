provider "aws" {
  region = "eu-west-1"
}

module "agent-policy" {
  source = "../"

  prefix        = "${var.prefix}"
  role          = "<role>"
  output_bucket = "<bucket>"
  tags          = "${var.tags}"
}
