# Dynamically generate an RSA SSH key pair for EC2 instance access
resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# Create an AWS key pair resource using the public key generated above
resource "aws_key_pair" "generated_key" {
  key_name   = "ec2-ssh-key" # Name of the SSH key pair on AWS
  public_key = tls_private_key.ssh_key.public_key_openssh
}

# Create security group
resource "aws_security_group" "elasticsearch_sg" {
  name        = "elasticsearch-sg"
  description = "Security group for Elasticsearch"
  vpc_id = var.vpc_id

  # Inbound rule for SSH (port 22)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Allow SSH access from anywhere (not recommended for production)
  }

  # Outbound rule (allow all traffic)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "elasticsearch_instance" {
  ami                    = var.ami
  instance_type          = var.instance_type
  key_name               = aws_key_pair.generated_key.key_name
  vpc_security_group_ids = [aws_security_group.elasticsearch_sg.id]
  subnet_id = var.public_subnet_ids 

  tags = {
    Name = "ElasticsearchInstance"
  }
}

# Create a secret in AWS Secrets Manager to store the SSH private key
resource "aws_secretsmanager_secret" "ssh_key" {
  name        = "ec2-ssh-key" # Name of the secret for the private key
}

# Create a new version of the secret containing the SSH private key
resource "aws_secretsmanager_secret_version" "ssh_key_version" {
  secret_id     = aws_secretsmanager_secret.ssh_key.id
  secret_string = tls_private_key.ssh_key.private_key_pem
}


module "elasticsearch" {
  source            = "./elasticsearch"
  instance_id       = aws_instance.elasticsearch_instance.id
  host_ip           = aws_instance.elasticsearch_instance.public_ip
  private_key_path  = tls_private_key.ssh_key.private_key_pem # Pass the generated private key to the module
  user              = "ec2-user"
}


