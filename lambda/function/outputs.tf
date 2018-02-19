# ------------------------------------------------------------------------------
# Output
# ------------------------------------------------------------------------------
output "role_arn" {
  value = "${aws_iam_role.main.arn}"
}

output "function_arn" {
  value = "${aws_lambda_function.main.arn}"
}

output "function_name" {
  value = "${var.prefix}-function"
}
