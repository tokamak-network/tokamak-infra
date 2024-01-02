module "waf" {
  source  = "umotif-public/waf-webaclv2/aws"

  name_prefix = "${var.cluster_name}-block-ddos"

  allow_default_action = true

  create_alb_association = false

  visibility_config = {
    cloudwatch_metrics_enabled = false
    metric_name                = "${var.cluster_name}-waf-main-metrics"
    sampled_requests_enabled   = false
  }

  rules = [
    {
      name = "AWS-AWSManagedRulesAnonymousIpList"
      priority = 0
      managed_rule_group_statement = {
          vendor_name = "AWS"
          name = "AWSManagedRulesAnonymousIpList"
      }
      override_action = "none"
      visibility_config = {
        sampled_requests_enabled = true
        cloudwatch_metrics_enabled = true
        metric_name = "AWS-AWSManagedRulesAnonymousIpList"
      }
    },
    {
      name = "AWS-AWSManagedRulesAmazonIpReputationList"
      priority = 1    
      managed_rule_group_statement = {
        vendor_name = "AWS"
        name = "AWSManagedRulesAmazonIpReputationList"
      }
      override_action = "none"
      visibility_config = {
        sampled_requests_enabled = true
        cloudwatch_metrics_enabled = true
        metric_name = "AWS-AWSManagedRulesAmazonIpReputationList"
      }
    },
    {
      name = "block_too_many_request"
      priority = 2
      rate_based_statement = {
        limit = 30000
        evaluation_window_sec = 300
        aggregate_key_type = "IP"
      }
      action = "block"
      visibility_config = {
        sampled_requests_enabled = true
        cloudwatch_metrics_enabled = true
        metric_name = "block_too_many_request"
      }
    }
  ]
}