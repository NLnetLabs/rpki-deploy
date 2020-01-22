module "pre" {
  source       = "../lib/pre"
  ssh_key_path = var.ssh_key_path
  domain       = var.domain
  hostname     = var.hostname
  src_tal      = var.src_tal
}

module "create_infra" {
  source            = "../lib/infra/do"
  do_token          = var.do_token
  size              = var.size
  tags              = var.tags
  admin_ipv4_cidr   = var.admin_ipv4_cidr
  admin_ipv6_cidr   = var.admin_ipv6_cidr
  domain            = var.domain
  hostname          = module.pre.hostname
  region            = var.region
  key_fingerprint   = module.pre.tls_public_key.public_key_fingerprint_md5
  ssh_key_path      = module.pre.ssh_key_path
  ingress_tcp_ports = module.pre.ingress_tcp_ports
}

module "docker_deploy" {
  source             = "../lib/docker"
  docker_compose_dir = var.docker_compose_dir
  domain             = var.domain
  hostname           = module.pre.hostname
  krill_auth_token   = var.krill_auth_token
  krill_build_path   = var.krill_build_path
  krill_log_level    = var.krill_log_level
  krill_version      = var.krill_version
  krill_use_ta       = var.krill_use_ta
  krill_fqdn         = module.pre.fqdn
  ipv4_address       = module.create_infra.ipv4_address
  ssh_key_path       = module.pre.ssh_key_path
  ssh_user           = module.create_infra.ssh_user
  src_tal            = module.pre.src_tal
}

module "post" {
  source              = "../lib/post"
  domain              = var.domain
  hostname            = module.pre.hostname
  docker_url          = module.docker_deploy.docker_url
  docker_cert_path    = module.docker_deploy.cert_path
  docker_compose_dir  = var.docker_compose_dir
  krill_build_path    = var.krill_build_path
  krill_fqdn          = module.pre.fqdn
  krill_use_ta        = var.krill_use_ta
  krill_version       = var.krill_version
  krill_auth_token    = var.krill_auth_token
  ssh_key_path        = module.pre.ssh_key_path
  ssh_user            = module.create_infra.ssh_user
  src_tal             = module.pre.src_tal
  run_tests           = var.run_tests
  docker_is_local     = false
  docker_ready        = module.docker_deploy.ready
  test_suite_path     = var.test_suite_path
}
