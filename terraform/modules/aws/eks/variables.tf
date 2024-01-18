variable "region" {
  description = "Region"
  type        = string
}

variable "cluster_name" {
  description = "Cluster Name"
  type        = string
}

variable "cluster_version" {
  description = "Cluster Version"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private Subnet IDs"
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "Public Subnet IDs"
  type        = list(string)
}

variable "kms_key_administrators" {
  description = "kms key administrators"
  type        = list(string)
}
