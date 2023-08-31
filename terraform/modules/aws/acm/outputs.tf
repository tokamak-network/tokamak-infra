output "aws_acm_certificate_arn" {
  value = { for index, value in aws_acm_certificate.this : var.service_names[index] => value }
}

output "aws_acm_certificate_validation" {
  value = { for index, value in aws_acm_certificate_validation.this : var.service_names[index] => value }
}
