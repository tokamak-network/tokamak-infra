variable "instance_id" {
  description = "ID of the EC2 instance where Elasticsearch will be installed."
}

variable "private_key_path" {
  description = "Path to the private key for SSH access."
}

variable "user" {
  description = "The username for SSH access."
  default     = "ec2-user"
}

variable "host_ip" {
  description = "Public IP of EC2 instance"
}
