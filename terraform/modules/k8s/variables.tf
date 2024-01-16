variable "network_name" {
  description = "Network Name"
  type        = string
}

variable "profile" {
  description = "AWS CLI Profile"
  type        = string
}

variable "region" {
  description = "Region"
  type        = string
}

variable "vpc" {
  description = "VPC"
  type        = any
}

variable "cluster_name" {
  description = "Cluster Name"
  type        = string
}

variable "fargate_profiles" {
  description = "Cluster Fargate Profile"
  type        = any
}

variable "cluster_endpoint" {
  description = "Cluster Endpoint"
  type        = string
}

variable "cluster_certificate_authority_data" {
  description = "Cluster Certificate Authority Data"
  type        = string
}

variable "cluster_oidc_issuer_url" {
  description = "Cluster OIDC Issuer URL"
  type        = string
}

variable "oidc_provider_arn" {
  description = "OIDC Provider ARN"
  type        = string
}

variable "aws_acm_certificate_validation" {
  description = "AWS ACM Certificatie Validation"
  type        = any
}

variable "efs_id" {
  description = "EFS_ID"
  type        = string
}


variable "efs_es_id" {
  description = "EFS_ES_ID"
  type        = string
}

variable "aws_secretsmanager_id" {
  description = "AWS_Secretmanager_ID"
  type        = string
}

variable "external_secret_namespace" {
  description = "External_Secret_Namespace"
  type        = string
}
