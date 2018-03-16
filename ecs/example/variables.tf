# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
variable "prefix" {
  default = "ecs-test"
}

provider "aws" {
  region = "eu-west-1"
}

variable "tags" {
  type = "map"

  default = {
    terraform   = "True"
    environment = "dev"
    test        = "true"
  }
}

