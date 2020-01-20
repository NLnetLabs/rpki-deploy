output "ipv4_address" {
  value = "127.0.0.1"
}

output "fqdn" {
  value = "localhost"
}

# Usage: eval $(terraform output docker_env_vars)
output "docker_env_vars" {
  value = <<-EOF
    export KRILL_VERSION="${module.docker_deploy.krill_version}"
    export KRILL_STAGING_CERT=true
    export KRILL_AUTH_TOKEN="${var.krill_auth_token}"
    export KRILL_LOG_LEVEL="${var.krill_log_level}"
    export KRILL_FQDN="localhost"
    export KRILL_USE_TA="${var.krill_use_ta}"
    export SRC_TAL="${replace(var.src_tal, "<FQDN>", "localhost")}"
    EOF
}
