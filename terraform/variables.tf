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

variable "azs" {
  description = "A list of availability zones names or ids in the region"
  type        = list(string)
}

variable "cluster_name" {
  description = "Cluster Name"
  type        = string
}

variable "cluster_version" {
  description = "Cluster Version"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR Range"
  type        = string

}

variable "vpc_name" {
  description = "VPC Name"
  type        = string
}

variable "efs_name" {
  description = "EFS Name"
  type        = string
}

variable "parent_domain" {
  description = "Parent Domain"
  type        = string
}

variable "service_names" {
  description = "Service Names"
  type        = list(string)
}

variable "alb_bucket_name" {
  description = "ALB Logs Bucket Name"
  type        = string
}

variable "lambda_function_name" {
  description = "Lambda Function Name"
  type        = string 
}

variable "es_endpoint" {
  description = "Elasticsearch Endpoint"
  type        = string
}

variable "es_basic_auth" {
  description = "Elasticsearch Basic Auth"
  type        = string
}

variable "git_user_name" {
  description = "Git User Name for lambda function"
  type        = string
}

variable "git_repo_name" {
  description = "Git Repo Name for lambda function"
  type        = string
}