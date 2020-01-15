variable "domain" {}
variable "hostname" {}
variable "krill_version" {}
variable "krill_auth_token" {}
variable "krill_build_path" {}
variable "krill_log_level" {}
variable "krill_use_ta" {}
variable "krill_fqdn" {}
variable "docker_compose_dir" {}
variable "ipv4_address" {}
variable "ssh_key_path" {}
variable "ssh_user" {}
variable "src_tal" {}
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
    KRILL_AUTH_TOKEN    = var.krill_auth_token
    KRILL_LOG_LEVEL     = var.krill_log_level
    KRILL_USE_TA        = var.krill_use_ta
    KRILL_FQDN          = var.krill_fqdn
    KRILL_VERSION       = local.krill_version
    SRC_TAL             = var.src_tal
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

resource "null_resource" "setup_docker" {
  # Normally this next provisioner will be skipped as we use a Krill Docker
  # image published to Docker Hub, but if requested this provisioner will be
  # invoked to build a Krill Docker image from local sources. The krill_build_cmd
  # value will be set to 'null' if the user didn't supply var.krill_build_path,
  # in which case this provisioner will be skipped entirely.
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    environment = local.docker_env_vars
    working_dir = var.krill_build_path
    command     = local.krill_build_cmd
  }

  # Pre-create a Docker volume containing krill config files to be used by the
  # test suite. The cat to temporary container approach works whether Docker is
  # local or remote.
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    environment = local.docker_env_vars
    working_dir = "../resources/krill_configs"
    command     = <<-EOT
        docker volume create krill_configs
        for CFG_FILE in $(ls -1); do
            docker run --rm -v krill_configs:/krill_configs -i alpine \
                sh -c "cat > /krill_configs/$CFG_FILE" < $CFG_FILE
        done
    EOT
  }

  # pre-build any images that need building, otherwise they get built on first
  # use during the tests which is noisy and makes the tests appear to block for
  # a long time.
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    environment = local.docker_env_vars
    working_dir = var.docker_compose_dir
    command     = <<-EOT
        docker-compose pull
        docker-compose build --parallel ${var.docker_is_local ? "" : "--compress"}
    EOT
  }

  provisioner "local-exec" {
    when        = destroy
    interpreter = ["/bin/bash", "-c"]
    environment = merge(local.docker_env_vars, local.krill_env_vars)
    working_dir = var.docker_compose_dir
    command     = <<-EOT
        docker volume rm --force krill_configs
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