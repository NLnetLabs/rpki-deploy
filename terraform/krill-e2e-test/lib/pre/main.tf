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
  private_key_pem = "${file(pathexpand(var.ssh_key_path))}"
}

# TODO: Use "locals" instead of "null_data_source".
data "null_data_source" "prevalues1" {
  inputs = {
    # ke2et stands for Krill end-to-end test
    hostname = "%{if var.hostname != ""}${var.hostname}%{else}ke2et${random_string.hostname.result}%{endif}"
  }
}

data "null_data_source" "prevalues2" {
  inputs = {
    fqdn = join(".", [data.null_data_source.prevalues1.outputs["hostname"], var.domain])
  }
}

data "null_data_source" "values" {
  inputs = {
    fqdn    = data.null_data_source.prevalues2.outputs["fqdn"]
    src_tal = replace(var.src_tal, "<FQDN>", data.null_data_source.prevalues2.outputs["fqdn"])
  }
}

output "tls_public_key" {
  value = data.tls_public_key.ssh_key
}

output "hostname" {
  value = data.null_data_source.prevalues1.outputs["hostname"]
}

output "fqdn" {
  value = data.null_data_source.values.outputs["fqdn"]
}

output "src_tal" {
  value = data.null_data_source.values.outputs["src_tal"]
}

output "ssh_key_path" {
  value = pathexpand(var.ssh_key_path)
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
