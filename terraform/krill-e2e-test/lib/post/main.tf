variable "domain" {}
variable "hostname" {}
variable "docker_url" {}
variable "docker_cert_path" {}
variable "docker_ready" {}
variable "ssh_key_path" {}
variable "ssh_user" {}
variable "krill_build_path" {}
variable "krill_fqdn" {}
variable "krill_use_ta" {}
variable "src_tal" {}
variable "rsync_base" {}
variable "run_tests" {
    type = bool
}
variable "docker_is_local" {
    type = bool
    default = false
}

locals {
    env_vars = {
        DOCKER_TLS_VERIFY   = var.docker_is_local ? null : "1"
        DOCKER_HOST         = var.docker_is_local ? null : var.hostname
        DOCKER_CERT_PATH    = var.docker_is_local ? null : var.docker_cert_path
        DOCKER_MACHINE_NAME = var.docker_is_local ? null : var.hostname
        KRILL_FQDN          = var.docker_is_local ? "localhost" : var.krill_fqdn
        KRILL_USE_TA        = var.krill_use_ta
        SRC_TAL             = var.docker_is_local ? "https://localhost/ta/ta.tal" : var.src_tal
        RSYNC_BASE          = var.rsync_base
    }
}

resource "null_resource" "setup_remote" {
    count = var.docker_is_local ? 0 : 1

    triggers = {
        docker_ready = "${var.docker_ready}"
    }

    provisioner "file" {
        connection {
            type        = "ssh"
            user        = var.ssh_user
            private_key = file(var.ssh_key_path)
            host        = var.krill_fqdn
        }

        source = "../scripts/resources/roa.delta"
        destination = "/tmp/delta.1"
    }

    # requires root because the /tmp/ka path was created by Docker when
    # mounting /tmp/ka into the Krill volume.
    provisioner "remote-exec" {
        connection {
            type        = "ssh"
            user        = var.ssh_user
            private_key = file(var.ssh_key_path)
            host        = var.krill_fqdn
        }

        inline = [
            "sudo mv /tmp/delta.1 /tmp/ka/"
        ]
    }
}

resource "null_resource" "setup_local" {
    count = var.docker_is_local ? 1 : 0

    provisioner "local-exec" {
        command = <<EOT
          mkdir /tmp/ka
          cp ../scripts/resources/roa.delta /tmp/ka/delta.1
EOT
    }
}

resource "null_resource" "run_tests" {
    count = var.run_tests ? 1 : 0

    triggers = {
        docker_ready = "${var.docker_ready}"
    }

    provisioner "local-exec" {
        environment = local.env_vars
        interpreter = ["/bin/bash"]
        working_dir = "../scripts"
        command = "./configure_krill.sh"
    }

    provisioner "local-exec" {
        environment = local.env_vars
        interpreter = ["/bin/bash"]
        working_dir = "../lib/docker"
        command = "../../scripts/test_krill.sh"
    }

    provisioner "local-exec" {
        environment = local.env_vars
        interpreter = ["/bin/bash"]
        working_dir = "../lib/docker"
        command = "../../scripts/test_python_client.sh"
    }
}
