output "wafv2_arn" {
  value       = aws_wafv2_web_acl.block_ddos.arn
  description = "arn of waf"
}
