output "public_ip" {
  value = aws_instance.elasticsearch_instance.public_ip
}

output "es_endpoint" {
  value = aws_route53_record.this.name
}

output "es_port" {
  value = "9200"
}

output "es_basic_auth" {
  value = "Basic bG9nX2J1bGs6ZWxhc3RpYw=="
}
