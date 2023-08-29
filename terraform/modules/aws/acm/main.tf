resource "aws_acm_certificate" "this" {
  count = length(var.service_names)

  domain_name   = "${var.service_names[count.index]}.${var.parent_domain}"
  key_algorithm = "RSA_2048"

  validation_method = "DNS"
}

data "aws_route53_zone" "this" {
  name         = var.parent_domain
  private_zone = false
}

resource "aws_route53_record" "this" {
  count = length(var.service_names)

  allow_overwrite = true
  name            = tolist(aws_acm_certificate.this[count.index].domain_validation_options)[0].resource_record_name
  records         = [tolist(aws_acm_certificate.this[count.index].domain_validation_options)[0].resource_record_value]
  ttl             = 60
  type            = tolist(aws_acm_certificate.this[count.index].domain_validation_options)[0].resource_record_type
  zone_id         = data.aws_route53_zone.this.zone_id
}

resource "aws_acm_certificate_validation" "this" {
  count = length(var.service_names)

  certificate_arn         = aws_acm_certificate.this[count.index].arn
  validation_record_fqdns = [aws_route53_record.this[count.index].fqdn]
}
