variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private Subnet IDs"
  type        = list(string)
}


variable "rds_name" {
  description = "RDS Name"
  type        = string
}
