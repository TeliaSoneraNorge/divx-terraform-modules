# ------------------------------------------------------------------------------
# Output
# ------------------------------------------------------------------------------
output "arn" {
  value = "${aws_lb.main.arn}"
}

output "name" {
  // arn:aws:elasticloadbalancing:<region>:<account-id>:loadbalancer/app/<name>/<uuid>
  value = "${element(split("/", aws_lb.main.name), 2)}"
}

output "dns_name" {
  value = "${aws_lb.main.dns_name}"
}

output "zone_id" {
  value = "${aws_lb.main.zone_id}"
}

output "origin_id" {
  value = "${element(split(".", aws_lb.main.dns_name), 0)}"
}

output "security_group_id" {
  value = "${element(concat(aws_security_group.main.*.id, list("")), 0)}"
}
