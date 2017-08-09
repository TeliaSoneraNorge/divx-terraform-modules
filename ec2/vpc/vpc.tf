# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
variable "prefix" {
  description = "Prefix used for resource names."
}

variable "environment" {
  description = "Environment tag which is applied to resources."
  default     = ""
}

variable "cidr_block" {
  description = "CIDR block to use for the VPC."
  default     = "10.0.0.0/16"
}

variable "dns_hostnames" {
  description = "Boolean flag for whether instances should be given a dns hostname."
  default     = "false"
}

# ------------------------------------------------------------------------------
# Resources
# ------------------------------------------------------------------------------
data "aws_availability_zones" "main" {}

resource "aws_vpc" "main" {
  cidr_block           = "${var.cidr_block}"
  instance_tenancy     = "default"
  enable_dns_support   = "true"
  enable_dns_hostnames = "${var.dns_hostnames}"

  tags {
    Name        = "${var.prefix}-vpc"
    terraform   = "true"
    environment = "${var.environment}"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = "${aws_vpc.main.id}"

  tags {
    Name        = "${var.prefix}-internet-gateway"
    terraform   = "true"
    environment = "${var.environment}"
  }
}

resource "aws_route_table" "main" {
  vpc_id = "${aws_vpc.main.id}"

  tags {
    Name        = "${var.prefix}-rt-public"
    terraform   = "true"
    environment = "${var.environment}"
  }
}

resource "aws_route" "main" {
  route_table_id         = "${aws_route_table.main.id}"
  gateway_id             = "${aws_internet_gateway.main.id}"
  destination_cidr_block = "0.0.0.0/0"
}

resource "aws_subnet" "main" {
  count             = "${length(data.aws_availability_zones.main.names)}"
  vpc_id            = "${aws_vpc.main.id}"
  cidr_block        = "${cidrsubnet(var.cidr_block, length(data.aws_availability_zones.main.names), count.index)}"
  availability_zone = "${element(data.aws_availability_zones.main.names, count.index)}"

  tags {
    Name        = "${var.prefix}-subnet-${count.index}"
    terraform   = "true"
    environment = "${var.environment}"
  }
}

resource "aws_route_table_association" "main" {
  count          = "${length(data.aws_availability_zones.main.names)}"
  subnet_id      = "${element(aws_subnet.main.*.id, count.index)}"
  route_table_id = "${aws_route_table.main.id}"
}

# ------------------------------------------------------------------------------
# Output
# ------------------------------------------------------------------------------
output "vpc_id" {
  value = "${aws_vpc.main.id}"
}

output "subnet_ids" {
  value = "${aws_subnet.main.*.id}"
}
