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
  value = data.tls_public_key.ssh_key
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
  value = var.ssh_key_path != "" ? pathexpand(var.ssh_key_path) : ""
}

output "ingress_tcp_ports" {
  value = [
    22,   # SSH
    80,   # NGINX redirect to HTTPS
    443,  # NGINX proxy to Krill
    873,  # Rsync
    2376, # Docker daemon
    8080, # RIPE NCC RPKI validator 3 (HTTP)
    9556  # Routinator prometheus exportor (HTTP)
  ]
}