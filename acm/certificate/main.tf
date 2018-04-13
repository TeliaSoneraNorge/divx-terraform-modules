# ------------------------------------------------------------------------------
# Resource
# ------------------------------------------------------------------------------
resource "aws_acm_certificate" "main" {
  domain_name       = "${var.domain}"
  validation_method = "DNS"
  tags              = "${var.tags}"
}

resource "aws_route53_record" "cert_validation" {
  zone_id = "${var.zone_id}"
  name    = "${aws_acm_certificate.main.domain_validation_options.0.resource_record_name}"
  type    = "${aws_acm_certificate.main.domain_validation_options.0.resource_record_type}"
  ttl     = 60

  records = [
    "${aws_acm_certificate.main.domain_validation_options.0.resource_record_value}",
  ]
}

resource "aws_acm_certificate_validation" "main" {
  certificate_arn = "${aws_acm_certificate.main.arn}"

  validation_record_fqdns = [
    "${aws_route53_record.cert_validation.fqdn}",
  ]
}
