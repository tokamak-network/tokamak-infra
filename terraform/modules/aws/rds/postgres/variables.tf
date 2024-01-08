variable "rds_name" {
  description = "RDS Name"
  type        = string
}

variable "rds_allocated_storage" {
  description = "RDS Allocated Storage"
  type        = number
}

variable "private_subnet_ids" {
  description = "Private Subnet IDs"
  type        = list(string)
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "from_port" {
  description = "Ingress From Port"
  type        = number
}

variable "to_port" {
  description = "Ingress To Port"
  type        = number
}

variable "db_parameters" {
  description = "DB Parameters"
  type        = list(any)
  default = [
    {
      apply_method = ""
      name         = ""
      value        = ""
    }
  ]
}
