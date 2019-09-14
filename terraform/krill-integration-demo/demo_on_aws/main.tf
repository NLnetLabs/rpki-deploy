data "tls_public_key" "krilldemo" {
  private_key_pem = "${file(var.ssh_key_path)}"
}

module "create_infra" {
  source        = "../lib/infra/aws"
  key_name      = "krill"
  key_openssh   = "data.tls_public_key.krilldemo.public_key_openssh"
  instance_type = "t2.micro"
  subnet_id     = "subnet-b3a4d8c4"
  domain        = var.domain
  hostname      = var.hostname
  region        = var.region
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