resource "aws_acm_certificate" "this" {
  count = length(var.service_names)

  domain_name   = "${var.service_names[count.index]}.${var.parent_domain}"
  key_algorithm = "RSA_2048"

  options {
    certificate_transparency_logging_preference = "ENABLED"
  }

  subject_alternative_names = ["${var.service_names[count.index]}.${var.parent_domain}"]
  validation_method         = "DNS"
}
