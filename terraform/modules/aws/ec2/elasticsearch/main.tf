# Resource to install Elasticsearch using a remote-exec provisioner.
resource "terraform_data" "install_elasticsearch" {
  triggers_replace = {
    instance_id = var.instance_id # Trigger to re-provision when the EC2 instance changes
  }

  # SSH connection configuration for the remote provisioner to connect to the EC2 instance.
  connection {
    type        = "ssh"
    user        = var.user
    private_key = var.private_key_path
    host        = var.host_ip
  }

  # Transfer the Docker Compose file to the remote EC2 instance.
  provisioner "file" {
    source      = "${path.module}/docker-compose.yml"
    destination = "/tmp/docker-compose.yml"
  }

  # Transfer the Elasticsearch configuration file to the remote EC2 instance.
  provisioner "file" {
    source      = "${path.module}/config"
    destination = "/tmp/config"
  }

  provisioner "file" {
    source      = "${path.module}/scripts"
    destination = "/tmp/scripts"
  }

  # Transfer a custom shell script to the remote EC2 instance for installing and configuring Elasticsearch.
  provisioner "file" {
    source      = "${path.module}/install_elasticsearch.sh"
    destination = "/tmp/install_elasticsearch.sh"
  }

  # Execute the installation script on the remote EC2 instance.
  provisioner "remote-exec" {
    inline = [
      "sudo bash /tmp/install_elasticsearch.sh", # Command to execute the installation script with root privileges
    ]
  }
}
