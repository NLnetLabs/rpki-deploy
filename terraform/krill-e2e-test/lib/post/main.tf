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
        A: 10.0.0.0/24 => 64496
        A: 10.0.1.0/24 => 64496
        EOT
        destination = "/tmp/ka/delta.1"

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
        command = "../scripts/configure_krill.sh"
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
            KRILL_BUILD_PATH="${krill_build_path}"
            KRILL_FQDN="${var.krill_fqdn}"
            KRILL_USE_TA="${var.krill_use_ta}"
            SRC_TAL="${var.src_tal}"
        }

        interpreter = ["/bin/bash"]
        working_dir = "../lib/docker"
        command = "../../scripts/test_python_client.sh"
    }
}