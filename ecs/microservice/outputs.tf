# -------------------------------------------------------------------------------
# Output
# -------------------------------------------------------------------------------
output "service_arn" {
  value = "${module.service.service_arn}"
}

output "target_group_arn" {
  value = "${module.service.target_group_arn}"
}

output "service_role_arn" {
  value = "${module.service.service_role_arn}"
}

output "service_role_name" {
  value = "${module.service.service_role_name}"
}

output "task_role_arn" {
  value = "${module.service.task_role_arn}"
}

output "task_role_name" {
  value = "${module.service.task_role_name}"
}
