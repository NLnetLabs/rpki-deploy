
variable "domain" {}
variable "hostname" {}
variable "docker_url" {}
variable "docker_cert_path" {}
variable "ssh_key_path" {}
variable "ssh_user" {}

resource "null_resource" "run_tests" {
    triggers = {
        docker_url = "${var.docker_url}"
        docker_cert_path = "${var.docker_cert_path}"
    }

    provisioner "file" {
        content     = <<-EOT
        A: 10.0.0.0/24 => 64496
        A: 10.0.1.0/24 => 64496
        EOT
        destination = "/tmp/ka/delta.1"

        connection {
            type        = "ssh"
            user        = var.ssh_user
            private_key = "${file(var.ssh_key_path)}"
            host        = "${join(".", [var.hostname, var.domain])}"
        }
    }

    provisioner "local-exec" {
        environment = {
            DOCKER_TLS_VERIFY="1"
            DOCKER_MACHINE_NAME="${var.hostname}"
            DOCKER_HOST="${var.docker_url}"
            DOCKER_CERT_PATH="${var.docker_cert_path}"
            KRILL_FQDN="${join(".", [var.hostname, var.domain])}"
        }

        interpreter = ["/bin/bash"]
        command = "../scripts/configure_krill.sh"
    }

}