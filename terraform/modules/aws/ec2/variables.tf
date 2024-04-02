variable "ami" {
    description = "AMI ID of the instance"
    type = string
}
variable "instance_type" {
    description = "EC2 Instance type"
    type = string
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
