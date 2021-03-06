output "ipv4_address" {
  value = module.create_infra.ipv4_address
}

output "fqdn" {
  value = join(".", [var.hostname, var.domain])
}

# Usage: eval $(terraform output docker_env_vars)
output "docker_env_vars" {
  value = <<-EOF
    export DOCKER_TLS_VERIFY="1"
    export DOCKER_MACHINE_NAME="${var.hostname}}"
    export DOCKER_HOST="${module.docker_deploy.docker_url}"
    export DOCKER_CERT_PATH="${module.docker_deploy.cert_path}"
    export KRILL_VERSION="${module.docker_deploy.krill_version}"
    export KRILL_ADMIN_TOKEN="${var.krill_admin_token}"
    export KRILL_LOG_LEVEL="${var.krill_log_level}"
    export KRILL_FQDN="${join(".", [var.hostname, var.domain])}"
    export KRILL_USE_TA="${var.krill_use_ta}"
    export SRC_TAL="${replace(var.src_tal, "<KRILL_FQDN>", join(".", [var.hostname, var.domain]))}"
    EOF
}

# Usage: eval $(terraform output unset_docker_env_vars)
output "unset_docker_env_vars" {
  value = <<-EOF
    unset DOCKER_TLS_VERIFY
    unset DOCKER_HOST
    unset DOCKER_CERT_PATH
    unset DOCKER_MACHINE_NAME
    EOF
}