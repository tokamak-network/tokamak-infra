#!/bin/bash

# Log file for auditability and troubleshooting
LOG_FILE="/var/log/elasticsearch_docker_setup.log"
exec &> >(tee -a "$LOG_FILE")

echo "Starting setup at $(date)"

# Ensure the EBS volume is ready and mount it
echo "Checking for /dev/xvdf availability..."
while [ ! -e /dev/xvdf ]; do
    echo "Waiting for /dev/xvdf to become available"
    sleep 1
done
echo "/dev/xvdf is available. Proceeding with setup..."

# Check if the filesystem is formatted or not
if ! blkid /dev/xvdf; then
    echo "No filesystem detected on /dev/xvdf, formatting as xfs..."
    sudo mkfs.xfs /dev/xvdf
    echo "Filesystem formatted."
fi

# Create mount point if it doesn't exist
MOUNT_POINT="/mnt/esdata"
if [ ! -d "$MOUNT_POINT" ]; then
    echo "Creating mount directory $MOUNT_POINT"
    sudo mkdir -p $MOUNT_POINT
fi

# Mount the EBS volume
echo "Mounting /dev/xvdf at $MOUNT_POINT"
if ! mountpoint -q $MOUNT_POINT; then
    sudo mount /dev/xvdf $MOUNT_POINT
    echo "/dev/xvdf mounted at $MOUNT_POINT"
else
    echo "/dev/xvdf is already mounted."
fi

# Add to fstab to ensure persistence across reboots
grep -q "/dev/xvdf $MOUNT_POINT xfs" /etc/fstab || echo "/dev/xvdf $MOUNT_POINT xfs defaults 0 0" | sudo tee -a /etc/fstab

# Update directory permissions to ensure Docker and Elasticsearch have read/write access
echo "Updating directory permissions for Elasticsearch..."
sudo chown -R 1000:1000 $MOUNT_POINT
sudo chmod 750 $MOUNT_POINT

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
