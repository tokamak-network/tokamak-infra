
# Dynamically generate an RSA SSH key pair for secure EC2 instance access.
resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# Create an AWS key pair using the public key generated above. This key pair
# is used to securely SSH into the EC2 instances.
resource "aws_key_pair" "generated_key" {
  key_name   = "ec2-ssh-keyv4" # Unique name for the SSH key pair on AWS.
  public_key = tls_private_key.ssh_key.public_key_openssh
}

# Define a security group for Elasticsearch. 
resource "aws_security_group" "elasticsearch_sg" {
  name        = "elasticsearch-sg"
  description = "Security group for Elasticsearch"
  vpc_id      = var.vpc_id # Associate with a specific VPC. 

  # Inbound rule to allow SSH (port 22) access from anywhere. 
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound rule to allow all outbound traffic. 
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Provision an EC2 instance for Elasticsearch.
resource "aws_instance" "elasticsearch_instance" {
  ami                         = var.ami
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.generated_key.key_name
  vpc_security_group_ids      = [aws_security_group.elasticsearch_sg.id]
  subnet_id                   = var.public_subnet_ids[0]
  associate_public_ip_address = true # Enable public IP to access the instance.

  tags = {
    Name = "ElasticsearchInstance"
  }
}

# Store the SSH private key in AWS Secrets Manager for secure handling.
resource "aws_secretsmanager_secret" "ssh_key" {
  name                    = "ec2-ssh-keyv4" # Unique name for the secret.
  recovery_window_in_days = 0               # Immediate deletion if removed, handle with caution.
}

# Create a new version of the secret containing the SSH private key's value.
resource "aws_secretsmanager_secret_version" "ssh_key_version" {
  secret_id     = aws_secretsmanager_secret.ssh_key.id
  secret_string = tls_private_key.ssh_key.private_key_pem
}

# Module to configure Elasticsearch on the EC2 instance.
module "elasticsearch" {
  source           = "./elasticsearch"
  instance_id      = aws_instance.elasticsearch_instance.id
  host_ip          = aws_instance.elasticsearch_instance.public_ip
  private_key_path = tls_private_key.ssh_key.private_key_pem # Path to the private key.
  user             = "ec2-user"                              # Default user, adjust based on the AMI used.
} 
