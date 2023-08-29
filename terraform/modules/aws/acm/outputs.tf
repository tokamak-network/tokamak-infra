output "aws_acm_certificate_arn" {
  value = { for index, value in aws_acm_certificate.this : var.service_names[index] => value }
}
