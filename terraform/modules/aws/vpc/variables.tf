variable "azs" {
  description = "A list of availability zones names or ids in the region"
  type        = list(string)
}

variable "vpc_cidr" {
  description = "VPC CIDR Range"
  type        = string
}

variable "vpc_name" {
  description = "VPC Name"
  type        = string
}

variable "cluster_name" {
  description = "Cluster Name"
  type        = string
}
