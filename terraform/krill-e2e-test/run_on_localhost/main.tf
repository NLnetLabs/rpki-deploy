module "pre" {
  source       = "../lib/pre"
  domain       = ""
  hostname     = "localhost"
  src_tal      = var.src_tal
  ssh_key_path = ""
}

module "docker_deploy" {
  source             = "../lib/docker"
  docker_compose_dir = var.docker_compose_dir
  domain             = ""
  hostname           = "localhost"
  krill_auth_token   = var.krill_auth_token
  krill_build_path   = var.krill_build_path
  krill_log_level    = var.krill_log_level
  krill_version      = var.krill_version
  krill_use_ta       = var.krill_use_ta
  krill_fqdn         = "nginx.krill.test"
  ipv4_address       = "127.0.0.1"
  ssh_key_path       = ""
  ssh_user           = ""
  src_tal            = "https://nginx.krill.test/ta/ta.tal"
  docker_is_local    = true
}

module "post" {
  source             = "../lib/post"
  docker_compose_dir = var.docker_compose_dir
  domain             = ""
  hostname           = "localhost"
  docker_url         = ""
  docker_cert_path   = ""
  krill_build_path   = var.krill_build_path
  krill_fqdn         = "nginx.krill.test"
  krill_use_ta       = var.krill_use_ta
  krill_version      = module.docker_deploy.krill_version
  krill_auth_token   = var.krill_auth_token
  src_tal            = "https://nginx.krill.test/ta/ta.tal"
  run_tests          = var.run_tests
  ssh_key_path       = ""
  ssh_user           = ""
  docker_is_local    = true
  docker_ready       = module.docker_deploy.ready
}
