variable "ssh_key_path" {}
variable "domain" {}
variable "hostname" {}
variable "src_tal" {}

# Digital Ocean error "Only valid hostname characters are allowed. (a-z, A-Z, 0-9, . and -)""
resource "random_string" "hostname" {
  length  = 9
  upper   = true
  lower   = true
  number  = true
  special = false
}

data "tls_public_key" "ssh_key" {
  count           = var.hostname != "localhost" ? 1 : 0
  private_key_pem = file(pathexpand(var.ssh_key_path))
}

locals {
  hostname = var.hostname != "" ? var.hostname : "ke2et${random_string.hostname.result}"
}

locals {
  fqdn     = var.domain != "" ? join(".", [local.hostname, var.domain]) : local.hostname
}

locals {
  src_tal  = replace(var.src_tal, "<FQDN>", local.fqdn)
}

output "tls_public_key" {
  value = var.hostname != "localhost" ? data.tls_public_key.ssh_key[0] : null
}

output "hostname" {
  value = local.hostname
}

output "fqdn" {
  value = local.fqdn
}

output "src_tal" {
  value = local.src_tal
}

output "ssh_key_path" {
  value = var.ssh_key_path != "" ? pathexpand(var.ssh_key_path) : null
}

output "ingress_tcp_ports" {
  value = [
    22,   # SSH
    80,   # NGINX redirect to HTTPS
    323,  # FORT validator RTR
    443,  # NGINX proxy to Krill
    873,  # Rsync
    3323, # Routinator RTR
    2376, # Docker daemon
    8080, # RIPE NCC RPKI validator 3 (HTTP)
    8083, # OctoRPKI RTR
    8084, # RCynic RTR
    8085, # rpki-client RTR
    8086, # rpki-prover RTR
    8323, # RIPE NCC RPKI Validator 3 RTR
    9556  # Routinator prometheus exportor (HTTP)
  ]
}