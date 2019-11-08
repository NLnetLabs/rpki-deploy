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


# This provider is used to resolve conditional or incomplete values which are
# used by the rest of the template.
data "null_data_source" "values" {
  inputs = {
    krill_version   = var.krill_build_path != "" ? "dirty" : var.krill_version
    krill_build_cmd = var.krill_build_path != "" ? "docker build -t nlnetlabs/krill:dirty --build-arg 'BASE_IMG=ximoneighteen/krillbuildbase' ." : "echo skipping Krill build"
  }
}

resource "dockermachine_generic" "docker_deploy" {
  name               = var.hostname
  engine_install_url = "https://get.docker.com"
  generic_ip_address = var.ipv4_address
  generic_ssh_key    = var.ssh_key_path
  generic_ssh_user   = var.ssh_user

  # Create the "external" Docker volume needed by the Docker Compose template.
  # We can't do this using the Terraform Docker provider because that provider
  # can only be configured with a previously know remote Docker daemon URL, and
  # we don't know that URL prior to deployment because it depends on the IP
  # address given back to us by Digital Ocean once the Droplet has been
  # created.
  provisioner "local-exec" {
    # Set DOCKER_ env vars that cause the docker command below to talk to the
    # _remote_ Docker daemon running on the Droplet, not to any local Docker
    # daemon. Use the configured connection details to instruct the remote
    # Docker daemon to create a persistent "external" (not defined by the
    # compose template) Docker volume for storing Lets Encrypt certificates.
    environment = {
      DOCKER_TLS_VERIFY   = "1"
      DOCKER_HOST         = "${self.docker_url}"
      DOCKER_CERT_PATH    = "${self.storage_path_computed}"
      DOCKER_MACHINE_NAME = "${self.name}"
    }
    command = "docker volume create krill_letsencrypt_certs"
  }

  # Normally this next provisioner will be skipped as we use a Krill Docker
  # image published to Docker Hub, but if requested this provisioner will be
  # invoked to build Krill Docker image from local sources. The krill_build_cmd
  # value will be set to 'null' if the user didn't supply var.krill_build_path,
  # in which case this provisioner will be skipped entirely.
  provisioner "local-exec" {
    # Set DOCKER_ env vars that cause the docker command below to talk to the
    # remote_Docker daemon running on the Droplet, not to our local Docker
    # daemon (if it even exists).
    environment = {
      DOCKER_TLS_VERIFY   = "1"
      DOCKER_HOST         = "${self.docker_url}"
      DOCKER_CERT_PATH    = "${self.storage_path_computed}"
      DOCKER_MACHINE_NAME = "${self.name}"
    }
    working_dir = var.krill_build_path
    command     = data.null_data_source.values.outputs["krill_build_cmd"]
  }

  # Deploy nginx, Routinator, Krill and rsyncd containers via the _remote_
  # Docker daemon running on the Digital Ocean droplet.
  provisioner "local-exec" {
    # Set DOCKER_ env vars that cause the docker command below to talk to the
    # _remote_ Docker daemon running on the Droplet, not to our local Docker
    # daemon (if it even exists), and set KRILL_ env vars that are referenced
    # by the Docker Compose template.
    environment = {
      DOCKER_TLS_VERIFY   = "1"
      DOCKER_HOST         = "${self.docker_url}"
      DOCKER_CERT_PATH    = "${self.storage_path_computed}"
      DOCKER_MACHINE_NAME = "${self.name}"
      KRILL_STAGING_CERT  = var.use_staging_cert
      KRILL_AUTH_TOKEN    = var.krill_auth_token
      KRILL_LOG_LEVEL     = var.krill_log_level
      KRILL_USE_TA        = var.krill_use_ta
      KRILL_FQDN          = var.krill_fqdn
      KRILL_VERSION       = data.null_data_source.values.outputs["krill_version"]
      SRC_TAL             = var.src_tal
    }
    working_dir = var.docker_compose_dir
    command     = "docker-compose build relyingpartybase && docker-compose build --parallel && docker-compose up -d"
  }
}

output "docker_url" {
  value = dockermachine_generic.docker_deploy.docker_url
}

output "cert_path" {
  value = dockermachine_generic.docker_deploy.storage_path_computed
}

output "krill_version" {
  value = data.null_data_source.values.outputs["krill_version"]
}
