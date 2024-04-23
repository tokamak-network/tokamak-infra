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

# Create EBS volume for Elasticsearch data storage
resource "aws_ebs_volume" "elasticsearch_data" {
  availability_zone = aws_instance.elasticsearch_instance.availability_zone
  size              = 100
  type              = "gp3"
  tags = {
    Name = "ElasticsearchDataVolume"
  }
}

# Attach the EBS volume to the EC2 instance
resource "aws_volume_attachment" "elasticsearch_data_attach" {
  device_name  = "/dev/xvdf"
  volume_id    = aws_ebs_volume.elasticsearch_data.id
  instance_id  = aws_instance.elasticsearch_instance.id
  force_detach = true
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

# DLM lifecycle policy for EBS snapshots
resource "aws_dlm_lifecycle_policy" "ebs_snapshot_policy" {
  description        = "Daily snapshot of Elasticsearch EBS volume"
  execution_role_arn = aws_iam_role.dlm_lifecycle_role.arn
  state              = "ENABLED"

  policy_details {
    resource_types = ["VOLUME"]

    schedule {
      name = "Daily Snapshots"

      create_rule {
        interval      = 24
        interval_unit = "HOURS"
        times         = ["23:45"]
      }

      retain_rule {
        count = 7
      }

      tags_to_add = {
        "SnapshotCreator" = "TerraformDLM"
      }

      copy_tags = false
    }

    target_tags = {
      "Name" = "ElasticsearchDataVolume"
    }
  }
}

# IAM role for DLM to manage snapshots
resource "aws_iam_role" "dlm_lifecycle_role" {
  name = "dlm_lifecycle_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "dlm.amazonaws.com"
        }
      },
    ]
  })
}

# IAM policy to allow the DLM role to manage EBS snapshots
resource "aws_iam_role_policy" "dlm_lifecycle_policy" {
  name = "dlm_snapshot_policy"

  role = aws_iam_role.dlm_lifecycle_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ec2:CreateSnapshot",
          "ec2:DeleteSnapshot",
          "ec2:DescribeVolumes",
          "ec2:DescribeSnapshots"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

# Module to configure Elasticsearch on the EC2 instance.
module "elasticsearch" {
  source = "./elasticsearch"

  instance_id      = aws_instance.elasticsearch_instance.id
  host_ip          = aws_instance.elasticsearch_instance.public_ip
  private_key_path = tls_private_key.ssh_key.private_key_pem # Path to the private key.
  user             = "ec2-user"                              # Default user, adjust based on the AMI used.
}
