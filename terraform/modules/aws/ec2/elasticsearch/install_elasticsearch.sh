
#!/bin/bash

# Log file for auditability and troubleshooting
LOG_FILE="/var/log/elasticsearch_docker_setup.log"
exec &> >(tee -a "$LOG_FILE")

echo "Starting setup at $(date)"

# Update the system securely
echo "Updating the system..."
sudo yum update -y

# Install Docker
echo "Installing Docker..."
sudo yum install -y docker

# Enable and start the Docker service
echo "Enabling and starting Docker..."
sudo systemctl enable docker
sudo systemctl start docker

# Install Docker Compose
echo "Installing Docker Compose..."
DOCKER_COMPOSE_VERSION="v2.3.3"  
sudo mkdir -p /usr/local/lib/docker/cli-plugins
sudo curl -SL "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-linux-x86_64" -o /usr/local/lib/docker/cli-plugins/docker-compose
sudo chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

# Verify Docker and Docker Compose installation
echo "Verifying Docker and Docker Compose installation..."
sudo docker --version
sudo docker compose version 

# Assuming docker-compose.yml is already transferred to /tmp
cd /tmp || exit

echo "Starting Elasticsearch with Docker Compose..."
sudo docker compose up -d  # Using the integrated `docker compose` command

echo "Setup completed at $(date)"
