
#AMI ID for the EC2 instance
variable "ami" {
    description = "AMI ID of the instance"
    type = string
}

# EC2 Instance Type
variable "instance_type" {
    description = "EC2 Instance type"
    type = string
}

# The ID of the Virtual Private Cloud (VPC) where resources such as EC2 instances and subnets will be created.
variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

# A list of IDs for private subnets within the specified VPC.
variable "private_subnet_ids" {
  description = "Private Subnet IDs"
  type        = list(string)
}

# A list of IDs for public subnets within the specified VPC.
variable "public_subnet_ids" {
  description = "Public Subnet IDs"
  type        = list(string)
}
