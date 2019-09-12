output "ipv4_address" {
  value = data.digitalocean_droplet.krilldemo.ipv4_address
}

output "fqdn" {
  value = join(".", [var.hostname, var.domain])
}

# Usage: eval $(terraform output docker_env_vars)
output "docker_env_vars" {
  value = <<-EOF
    export DOCKER_TLS_VERIFY="1"
    export DOCKER_HOST="${dockermachine_digitalocean.krilldemo.docker_url}"
    export DOCKER_CERT_PATH="${dockermachine_digitalocean.krilldemo.storage_path_computed}"
    export DOCKER_MACHINE_NAME=${var.hostname}
    export KRILL_STAGING_CERT=${var.use_staging_cert}
    export KRILL_AUTH_TOKEN=${var.krill_auth_token}
    export KRILL_LOG_LEVEL=${var.krill_log_level}
    export KRILL_FQDN=${data.null_data_source.values.outputs["krill_fqdn"]}
    export KRILL_VERSION=${data.null_data_source.values.outputs["krill_version"]}
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