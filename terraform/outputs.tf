output "wafv2_arn" {
  value       = module.waf.wafv2_arn
  description = "arn of waf"
}

output "load_balancer_attributes" {
  value       = "access_logs.s3.enabled=true,access_logs.s3.bucket=${var.alb_bucket_name},access_logs.s3.prefix=${var.network_name}"
  description = "ingress annotation for collet alb logs"
}
