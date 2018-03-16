# ------------------------------------------------------------------------------
# Output
# ------------------------------------------------------------------------------
output "target_group_arn" {
  value = "${element(concat(aws_lb_target_group.HTTP.*.arn, aws_lb_target_group.TCP.*.arn),0)}"
}

output "target_port" {
  value = "${var.target["port"]}"
}
