variable "domain" {}
variable "hostname" {}
variable "docker_url" {}
variable "docker_cert_path" {}
variable "ssh_key_path" {}
variable "ssh_user" {}
variable "krill_build_path" {}
variable "krill_fqdn" {}
variable "krill_use_ta" {}
variable "src_tal" {}
variable "run_tests" {
    type = bool
}

resource "null_resource" "run_tests" {
    count = var.run_tests  ? 1 : 0

    triggers = {
        docker_url = "${var.docker_url}"
        docker_cert_path = "${var.docker_cert_path}"
    }

    provisioner "file" {
        content     = <<-EOT
        A: 2001:12ff::/32-48 => 22548
        A: 200.160.0.0/20-24 => 22548
        A: 189.76.96.0/19-24 => 11752
        A: 2001:12fe::/32-48 => 11752
        EOT
        destination = "/tmp/delta.1"

        connection {
            type        = "ssh"
            user        = var.ssh_user
            private_key = file(var.ssh_key_path)
            host        = var.krill_fqdn
        }
    }

    # requires root because the /tmp/ka path was created by Docker when
    # mounting /tmp/ka into the Krill volume.
    provisioner "remote-exec" {
        inline = [
            "sudo mv /tmp/delta.1 /tmp/ka/"
        ]

        connection {
            type        = "ssh"
            user        = var.ssh_user
            private_key = file(var.ssh_key_path)
            host        = var.krill_fqdn
        }
    }

    provisioner "local-exec" {
        environment = {
            DOCKER_TLS_VERIFY="1"
            DOCKER_MACHINE_NAME="${var.hostname}"
            DOCKER_HOST="${var.docker_url}"
            DOCKER_CERT_PATH="${var.docker_cert_path}"
            KRILL_FQDN="${var.krill_fqdn}"
            KRILL_USE_TA="${var.krill_use_ta}"
            SRC_TAL="${var.src_tal}"
        }

        interpreter = ["/bin/bash"]
        working_dir = "../scripts"
        command = "./configure_krill.sh"
    }

    provisioner "local-exec" {
        environment = {
            DOCKER_TLS_VERIFY="1"
            DOCKER_MACHINE_NAME="${var.hostname}"
            DOCKER_HOST="${var.docker_url}"
            DOCKER_CERT_PATH="${var.docker_cert_path}"
            KRILL_FQDN="${var.krill_fqdn}"
            KRILL_USE_TA="${var.krill_use_ta}"
            SRC_TAL="${var.src_tal}"
        }

        interpreter = ["/bin/bash"]
        working_dir = "../lib/docker"
        command = "../../scripts/test_krill.sh"
    }

    provisioner "local-exec" {
        environment = {
            DOCKER_TLS_VERIFY="1"
            DOCKER_MACHINE_NAME="${var.hostname}"
            DOCKER_HOST="${var.docker_url}"
            DOCKER_CERT_PATH="${var.docker_cert_path}"
            KRILL_BUILD_PATH="${var.krill_build_path}"
            KRILL_FQDN="${var.krill_fqdn}"
            KRILL_USE_TA="${var.krill_use_ta}"
            SRC_TAL="${var.src_tal}"
        }

        interpreter = ["/bin/bash"]
        working_dir = "../lib/docker"
        command = "../../scripts/test_python_client.sh"
    }
}
