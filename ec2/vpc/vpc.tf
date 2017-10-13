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

variable "nat_gateways" {
  description = "Number of NAT gateways to provision. (A number between 0 and N. An elastic IP is created for each NAT gateway.)"
  default     = "0"
}

variable "dns_hostnames" {
  description = "Boolean flag for whether instances should be given a dns hostname."
  default     = "false"
}

variable "tags" {
  description = "A map of tags (key-value pairs) passed to resources."
  type        = "map"
  default     = {}
}

# ------------------------------------------------------------------------------
# Resources
# ------------------------------------------------------------------------------
data "aws_availability_zones" "main" {}

locals {
  az_count  = "${length(data.aws_availability_zones.main.names)}"
  nat_count = "${min(length(data.aws_availability_zones.main.names), var.nat_gateways)}"
}

# NOTE: depends_on is added for the vpc because terraform sometimes
# fails to destroy VPC's where internet gateway is attached. If this happens,
# we can manually detach it in the console and run terraform destroy again.
resource "aws_vpc" "main" {
  cidr_block           = "${var.cidr_block}"
  instance_tenancy     = "default"
  enable_dns_support   = "true"
  enable_dns_hostnames = "${var.dns_hostnames}"

  tags = "${merge(var.tags, map("Name", "${var.prefix}-vpc"))}"
}

resource "aws_internet_gateway" "main" {
  depends_on = ["aws_vpc.main"]
  vpc_id     = "${aws_vpc.main.id}"

  tags = "${merge(var.tags, map("Name", "${var.prefix}-internet-gateway"))}"
}

resource "aws_route_table" "main" {
  depends_on = ["aws_vpc.main"]
  vpc_id     = "${aws_vpc.main.id}"

  tags = "${merge(var.tags, map("Name", "${var.prefix}-rt-public"))}"
}

resource "aws_route" "main" {
  depends_on             = ["aws_internet_gateway.main", "aws_route_table.main"]
  route_table_id         = "${aws_route_table.main.id}"
  gateway_id             = "${aws_internet_gateway.main.id}"
  destination_cidr_block = "0.0.0.0/0"
}

resource "aws_subnet" "public" {
  count                   = "${local.az_count}"
  vpc_id                  = "${aws_vpc.main.id}"
  cidr_block              = "${cidrsubnet(var.cidr_block, local.az_count * 2, count.index)}"
  availability_zone       = "${element(data.aws_availability_zones.main.names, count.index)}"
  map_public_ip_on_launch = "true"

  tags = "${merge(var.tags, map("Name", "${var.prefix}-public-subnet-${count.index + 1}"))}"
}

resource "aws_route_table_association" "public" {
  count          = "${local.az_count}"
  subnet_id      = "${element(aws_subnet.public.*.id, count.index)}"
  route_table_id = "${aws_route_table.main.id}"
}

resource "aws_subnet" "private" {
  count                   = "${local.az_count}"
  vpc_id                  = "${aws_vpc.main.id}"
  cidr_block              = "${cidrsubnet(var.cidr_block, local.az_count * 2, count.index)}"
  availability_zone       = "${element(data.aws_availability_zones.main.names, count.index)}"
  map_public_ip_on_launch = "false"

  tags = "${merge(var.tags, map("Name", "${var.prefix}-private-subnet-${count.index + 1}"))}"
}

resource "aws_route_table_association" "private" {
  count          = "${local.az_count}"
  subnet_id      = "${element(aws_subnet.private.*.id, count.index)}"
  route_table_id = "${aws_route_table.main.id}"
}

resource "aws_eip" "private" {
  count = "${local.nat_count}"
}

resource "aws_nat_gateway" "private" {
  depends_on    = ["aws_internet_gateway.main"]
  count         = "${local.nat_count}"
  allocation_id = "${element(aws_eip.private.*.id, count.index)}"
  subnet_id     = "${element(aws_subnet.private.*.id, count.index)}"
}

# ------------------------------------------------------------------------------
# Output
# ------------------------------------------------------------------------------
output "vpc_id" {
  value = "${aws_vpc.main.id}"
}

output "public_subnet_ids" {
  value = "${aws_subnet.public.*.id}"
}

output "private_subnet_ids" {
  value = "${aws_subnet.private.*.id}"
}
