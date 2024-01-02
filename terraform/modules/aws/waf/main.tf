resource "aws_wafv2_web_acl" "block_ddos" {
  name = "${var.cluster_name}-block-ddos"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  rule {
    name = "AWS-AWSManagedRulesAnonymousIpList"
    priority = 0

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name = "AWSManagedRulesAnonymousIpList"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      sampled_requests_enabled = true
      cloudwatch_metrics_enabled = true
      metric_name = "AWS-AWSManagedRulesAnonymousIpList"
    }
  }

  rule {
    name = "AWS-AWSManagedRulesAmazonIpReputationList"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name = "AWSManagedRulesAmazonIpReputationList"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      sampled_requests_enabled = true
      cloudwatch_metrics_enabled = true
      metric_name = "AWS-AWSManagedRulesAmazonIpReputationList"
    }
  }

  rule {
    name = "block_too_many_request"
    priority = 2

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit = 30000
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      sampled_requests_enabled = true
      cloudwatch_metrics_enabled = true
      metric_name = "block_too_many_request"
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = false
    metric_name                = "${var.cluster_name}-waf-main-metrics"
    sampled_requests_enabled   = false
  }
}