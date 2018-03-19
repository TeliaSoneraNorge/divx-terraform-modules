# ------------------------------------------------------------------------------
# Output
# ------------------------------------------------------------------------------
output "arn" {
  value = "${aws_ecs_service.main.id}"
}

output "role_arn" {
  value = "${aws_iam_role.service.arn}"
}

output "role_id" {
  value = "${aws_iam_role.service.id}"
}

output "target_group_arn" {
  value = "${aws_lb_target_group.main.arn}"
}
