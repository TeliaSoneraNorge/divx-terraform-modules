# ------------------------------------------------------------------------------
# Output
# ------------------------------------------------------------------------------
output "certificate_arn" {
  value = "${aws_acm_certificate_validation.main.certificate_arn}"
}
