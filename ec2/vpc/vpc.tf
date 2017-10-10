# ------------------------------------------------------------------------------
# Variables
# ------------------------------------------------------------------------------
variable "prefix" {
  description = "Prefix used for resource names."
}

variable "cidr_block" {
  description = "CIDR block to use for the VPC."
  default     = "10.0.0.0/16"
}

variable "dns_hostnames" {
  description = "Boolean flag for whether instances should be given a dns hostname."
  default     = "false"
}

variable "public_ips" {
  description = "Boolean flag for whether the subnets should delegate public IPs."
  default     = "true"
}

variable "tags" {
  description = "A map of tags (key-value pairs)."
  type        = "map"
  default     = {}
}

# ------------------------------------------------------------------------------
# Resources
# ------------------------------------------------------------------------------
locals {
  tags = "${merge(var.tags, map("terraform", "True"))}"
}

data "aws_availability_zones" "main" {}

# NOTE: depends_on is added for the vpc because terraform sometimes
# fails to destroy VPC's where internet gateway is attached. If this happens,
# we can manually detach it in the console and run terraform destroy again.
resource "aws_vpc" "main" {
  cidr_block           = "${var.cidr_block}"
  instance_tenancy     = "default"
  enable_dns_support   = "true"
  enable_dns_hostnames = "${var.dns_hostnames}"

  tags = "${merge(local.tags, map("Name", "${var.prefix}-vpc"))}"
}

resource "aws_internet_gateway" "main" {
  depends_on = ["aws_vpc.main"]
  vpc_id     = "${aws_vpc.main.id}"

  tags = "${merge(local.tags, map("Name", "${var.prefix}-internet-gateway"))}"
}

resource "aws_route_table" "main" {
  depends_on = ["aws_vpc.main"]
  vpc_id     = "${aws_vpc.main.id}"

  tags = "${merge(local.tags, map("Name", "${var.prefix}-rt-public"))}"
}

resource "aws_route" "main" {
  depends_on             = ["aws_internet_gateway.main", "aws_route_table.main"]
  route_table_id         = "${aws_route_table.main.id}"
  gateway_id             = "${aws_internet_gateway.main.id}"
  destination_cidr_block = "0.0.0.0/0"
}

resource "aws_subnet" "main" {
  count                   = "${length(data.aws_availability_zones.main.names)}"
  vpc_id                  = "${aws_vpc.main.id}"
  cidr_block              = "${cidrsubnet(var.cidr_block, length(data.aws_availability_zones.main.names), count.index)}"
  availability_zone       = "${element(data.aws_availability_zones.main.names, count.index)}"
  map_public_ip_on_launch = "${var.public_ips}"

  tags = "${merge(local.tags, map("Name", "${var.prefix}-subnet-${count.index + 1}"))}"
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
