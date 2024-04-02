
resource "null_resource" "install_elasticsearch" {
  triggers = {
    instance_id = var.instance_id
  }

  connection {
    type        = "ssh"
    user        = var.user
    private_key = var.private_key_path
    host        = var.host_ip
  }

  provisioner "file" {
    source      = "${path.module}/docker-compose.yml"
    destination = "/tmp/docker-compose.yml"
  }

  provisioner "file" {
    source      = "${path.module}/elasticsearch.yml"
    destination = "/tmp/elasticsearch.yml"
  }

  provisioner "file" {
    source = "${path.module}/install_elasticsearch.sh"
    destination = "/tmp/install_elasticsearch.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo bash /tmp/install_elasticsearch.sh",
    ]
  }
}
