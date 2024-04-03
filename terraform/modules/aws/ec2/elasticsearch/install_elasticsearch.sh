#!/bin/bash

#log file for auditability and troubleshooting
LOG_FILE="/var/log/elasticsearch_docker_setup.log"
exec &> >(tee -a "$LOG_FILE")

echo "Starting setup at $(date)"

# Update the system securely
echo "Updating the system..."
sudo yum update -y

# Remove any potentially conflicting packages
echo "Removing conflicting packages..."
sudo yum remove -y python3-requests

# Install Docker
echo "Installing Docker..."
sudo yum install -y docker

# Enable and start the Docker service
echo "Enabling and starting Docker..."
sudo systemctl enable docker
sudo systemctl start docker

# Install pip3 for Docker Compose installation
echo "Installing pip3..."
sudo yum install -y python3-pip

# Install a specific version of Docker Python package
echo "Installing Docker Python package..."
sudo pip3 install docker==6.1.3

# Install Docker Compose
echo "Installing Docker Compose..."
sudo pip3 install docker-compose

# Verify Docker and Docker Compose installation
echo "Verifying Docker and Docker Compose installation..."
sudo docker --version
sudo docker-compose --version

# Assuming docker-compose.yml is already transferred to /tmp
cd /tmp || exit

echo "Starting Elasticsearch with Docker Compose..."
sudo docker-compose up -d

echo "Setup completed at $(date)"
