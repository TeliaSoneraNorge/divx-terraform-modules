# -------------------------------------------------------------------------------
# Output
# -------------------------------------------------------------------------------
output "role_arn" {
  value = "${module.worker.role_arn}"
}

output "role_id" {
  value = "${module.worker.role_id}"
}

output "security_group_id" {
  value = "${module.worker.security_group_id}"
}
