variable "domain" {}
variable "hostname" {}
variable "krill_version" {}
variable "krill_auth_token" {}
variable "krill_build_path" {}
variable "krill_log_level" {}
variable "krill_use_ta" {}
variable "krill_fqdn" {}
variable "use_staging_cert" {}
variable "docker_compose_dir" {}
variable "ipv4_address" {}
variable "ssh_key_path" {}
variable "ssh_user" {}
variable "src_tal" {}
variable "rsync_base" {}
variable "docker_is_local" {
  type = bool
  default = false
}

locals {
  krill_version = var.krill_build_path != "" ? "dirty" : var.krill_version
  krill_build_cmd = var.krill_build_path != "" ? "docker build -t nlnetlabs/krill:dirty --build-arg 'BASE_IMG=ximoneighteen/krillbuildbase' ." : "echo skipping Krill build"

  docker_env_vars = {
    DOCKER_TLS_VERIFY   = var.docker_is_local ? null : "1"
    DOCKER_HOST         = var.docker_is_local ? null : dockermachine_generic.docker_deploy[0].docker_url
    DOCKER_CERT_PATH    = var.docker_is_local ? null : dockermachine_generic.docker_deploy[0].storage_path_computed
    DOCKER_MACHINE_NAME = var.docker_is_local ? null : var.hostname
  }

  krill_env_vars = {
    KRILL_STAGING_CERT  = var.use_staging_cert
    KRILL_AUTH_TOKEN    = var.krill_auth_token
    KRILL_LOG_LEVEL     = var.krill_log_level
    KRILL_USE_TA        = var.krill_use_ta
    KRILL_FQDN          = var.krill_fqdn
    KRILL_VERSION       = local.krill_version
    SRC_TAL             = var.src_tal
    RSYNC_BASE          = var.rsync_base
  }
}

resource "dockermachine_generic" "docker_deploy" {
  count              = var.docker_is_local ? 0 : 1
  name               = var.hostname
  engine_install_url = "https://get.docker.com"
  generic_ip_address = var.ipv4_address
  generic_ssh_key    = var.ssh_key_path
  generic_ssh_user   = var.ssh_user
}

resource "null_resource" "setup_remote" {
    count = var.docker_is_local ? 0 : 1

    provisioner "remote-exec" {
        connection {
            type        = "ssh"
            user        = var.ssh_user
            private_key = file(var.ssh_key_path)
            host        = var.krill_fqdn
        }
        inline = [
            "mkdir /tmp/ka"
        ]
    }

    provisioner "file" {
        connection {
            type        = "ssh"
            user        = var.ssh_user
            private_key = file(var.ssh_key_path)
            host        = var.krill_fqdn
        }

        source = "../scripts/resources/krill.conf"
        destination = "/tmp/ka/"
    }
}

resource "null_resource" "setup_local" {
    count = var.docker_is_local ? 1 : 0

    provisioner "local-exec" {
        command = <<-EOT
          mkdir /tmp/ka
          cp ../scripts/resources/krill.conf /tmp/ka/
EOT
    }
}

resource "null_resource" "setup_docker" {
  triggers = {
    setup_done = "${var.docker_is_local ? null_resource.setup_local[0].id : null_resource.setup_remote[0].id}"
  }

  # Normally this next provisioner will be skipped as we use a Krill Docker
  # image published to Docker Hub, but if requested this provisioner will be
  # invoked to build a Krill Docker image from local sources. The krill_build_cmd
  # value will be set to 'null' if the user didn't supply var.krill_build_path,
  # in which case this provisioner will be skipped entirely.
  provisioner "local-exec" {
    environment = local.docker_env_vars
    working_dir = var.krill_build_path
    command     = local.krill_build_cmd
  }

  provisioner "local-exec" {
    when = destroy
    environment = merge(local.docker_env_vars, local.krill_env_vars)
    working_dir = var.docker_compose_dir
    command = <<-EOT
      sudo rm -R /tmp/ka
EOT
  }
}

output "docker_url" {
  value = var.docker_is_local ? null : dockermachine_generic.docker_deploy[0].docker_url
}

output "cert_path" {
  value = var.docker_is_local ? null : dockermachine_generic.docker_deploy[0].storage_path_computed
}

output "krill_version" {
  value = local.krill_version
}

output "ready" {
  value = null_resource.setup_docker.id
}
