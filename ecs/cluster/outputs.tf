# ------------------------------------------------------------------------------
# Output
# ------------------------------------------------------------------------------
output "id" {
  value = "${aws_ecs_cluster.main.id}"
}

output "asg_id" {
  value = "${module.asg.id}"
}

output "role_name" {
  value = "${module.asg.role_name}"
}

output "role_arn" {
  value = "${module.asg.role_arn}"
}

output "role_id" {
  value = "${module.asg.role_id}"
}

output "security_group_id" {
  value = "${module.asg.security_group_id}"
}
