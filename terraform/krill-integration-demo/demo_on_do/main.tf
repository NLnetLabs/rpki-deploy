data "tls_public_key" "krilldemo" {
  private_key_pem = "${file(var.ssh_key_path)}"
}

module "create_infra" {
  source          = "../lib/infra/do"
  do_token        = var.do_token
  size            = var.size
  tags            = var.tags
  admin_ipv4_cidr = var.admin_ipv4_cidr
  admin_ipv6_cidr = var.admin_ipv6_cidr
  domain          = var.domain
  hostname        = var.hostname
  region          = var.region
  key_fingerprint = data.tls_public_key.krilldemo.public_key_fingerprint_md5
  ssh_key_path    = var.ssh_key_path
}

module "docker_deploy" {
  source             = "../lib/docker"
  docker_compose_dir = var.docker_compose_dir
  domain             = var.domain
  hostname           = var.hostname
  krill_auth_token   = var.krill_auth_token
  krill_build_path   = var.krill_build_path
  krill_log_level    = var.krill_log_level
  krill_version      = var.krill_version
  use_staging_cert   = var.use_staging_cert
  ipv4_address       = module.create_infra.ipv4_address
  ssh_key_path       = var.ssh_key_path
  ssh_user           = module.create_infra.ssh_user
}

resource "null_resource" "configure_krill" {
    triggers = {
        docker_url = "${module.docker_deploy.docker_url}"
        docker_cert_path = "${module.docker_deploy.cert_path}"
    }

    provisioner "file" {
        content     = <<-EOT
        A: 10.0.0.0/24 => 64496
        A: 10.0.1.0/24 => 64496
        EOT
        destination = "/tmp/ka/delta.1"

        connection {
            type        = "ssh"
            user        = module.create_infra.ssh_user
            private_key = "${file(var.ssh_key_path)}"
            host        = module.create_infra.ipv4_address
        }
    }

    provisioner "local-exec" {
        environment = {
            DOCKER_TLS_VERIFY="1"
            DOCKER_MACHINE_NAME="${var.hostname}"
            DOCKER_HOST="${module.docker_deploy.docker_url}"
            DOCKER_CERT_PATH="${module.docker_deploy.cert_path}"            
        }

        interpreter = ["/bin/bash"]
        command = "../configure_krill.sh"
    }
}