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