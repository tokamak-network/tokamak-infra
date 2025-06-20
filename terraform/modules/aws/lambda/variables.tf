# A list of IDs for private subnets within the specified VPC.
variable "private_subnet_ids" {
  description = "Private Subnet IDs"
  type        = list(string)
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "function_name" {
  type = string
}

variable "s3_bucket_id" {
  type = string
}

variable "s3_bucket_arn" {
  type = string
}

variable "es_endpoint" {
  type = string
}

variable "es_port" {
  type = string
}

variable "es_basic_auth" {
  type = string
}

variable "git_user_name" {
  type = string
}

variable "git_repo_name" {
  type = string
}

variable "source_version" {
  type = string
}

variable "network_name" {
  type = string
}
