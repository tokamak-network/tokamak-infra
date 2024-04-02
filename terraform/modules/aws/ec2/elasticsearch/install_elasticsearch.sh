#!/bin/bash

# Update the system
sudo yum update -y


sudo yum remove -y python3-requests  # Remove conflicting package
sudo yum update -y                   # Update the system
sudo yum install -y docker           # Install Docker
sudo systemctl enable docker
sudo systemctl start docker
sudo yum install -y python3-pip     # Install pip3
sudo pip3 install docker==6.1.3     # Install specific version of Docker Python package
sudo pip3 install docker-compose 

# Navigate to the directory containing the docker-compose.yml file
cd /tmp

# Assuming docker-compose.yml is already transferred to /tmp
echo "Starting Elasticsearch with Docker Compose..."
sudo docker-compose up -d
