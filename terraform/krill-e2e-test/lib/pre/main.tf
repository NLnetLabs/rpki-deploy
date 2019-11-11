variable "ssh_key_path" {}
variable "domain" {}
variable "hostname" {}
variable "src_tal" {}

# Digital Ocean error "Only valid hostname characters are allowed. (a-z, A-Z, 0-9, . and -)""
resource "random_string" "hostname" {
    length = 9
    upper = true
    lower = true
    number = true
    special = false
}

data "tls_public_key" "ssh_key" {
  private_key_pem = "${file(var.ssh_key_path)}"
}

data "null_data_source" "prevalues1" {
  inputs = {
    # ke2et stands for Krill end-to-end test
    hostname = "%{ if var.hostname != "" }${var.hostname}%{ else }ke2et${random_string.hostname.result}%{ endif }"
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