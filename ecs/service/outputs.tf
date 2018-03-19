# ------------------------------------------------------------------------------
# Output
# ------------------------------------------------------------------------------
output "service_arn" {
  value = "${aws_ecs_service.main.id}"
}

output "target_group_arn" {
  value = "${aws_lb_target_group.main.arn}"
}

output "service_role_arn" {
  value = "${aws_iam_role.service.arn}"
}

output "service_role_name" {
  value = "${aws_iam_role.service.name}"
}

output "task_role_arn" {
  value = "${aws_iam_role.task.arn}"
}

output "task_role_name" {
  value = "${aws_iam_role.task.name}"
}
