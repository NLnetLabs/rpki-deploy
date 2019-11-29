variable "do_token" {}
variable "key_fingerprint" {}
variable "size" {}
variable "domain" {}
variable "hostname" {}
variable "tags" {}
variable "admin_ipv4_cidr" {}
variable "admin_ipv6_cidr" {}
variable "region" {}
variable "ssh_key_path" {}
variable "ingress_tcp_ports" {}

provider "digitalocean" {
  token   = var.do_token
  version = "~> 1.10"
}

resource "digitalocean_droplet" "krilldemo" {
  name     = var.hostname
  image    = "ubuntu-16-04-x64"
  region   = var.region
  size     = var.size
  ipv6     = true
  ssh_keys = [var.key_fingerprint]
  tags     = var.tags
}

# Create a DNS A record in Digital Ocean for the new Droplet.
resource "digitalocean_record" "krilldemo_ipv4" {
  domain = var.domain
  type   = "A"
  name   = var.hostname
  value  = digitalocean_droplet.krilldemo.ipv4_address
  ttl    = 60
}

# Create a DNS AAAA record in Digital Ocean for the new Droplet.
resource "digitalocean_record" "krilldemo_ipv6" {
  domain = var.domain
  type   = "AAAA"
  name   = var.hostname
  value  = digitalocean_droplet.krilldemo.ipv6_address
  ttl    = 60
}

# Create a Digital Ocean firewall and associate it with the new Droplet.
resource "digitalocean_firewall" "krilldemo" {
  name        = join("", [var.hostname, "firewall"])
  droplet_ids = [digitalocean_droplet.krilldemo.id]

  dynamic "inbound_rule" {
    iterator = port
    for_each = var.ingress_tcp_ports
    content {
        port_range = port.value
        protocol = "tcp"
        source_addresses = [var.admin_ipv4_cidr, var.admin_ipv6_cidr]
    }
  }

  # -> icmp
  inbound_rule {
    protocol         = "icmp"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  # allow all outbound TCP
  outbound_rule {
    protocol              = "tcp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  # allow all outbound UDP
  outbound_rule {
    protocol              = "udp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  # allow outbound ICMP
  outbound_rule {
    protocol              = "icmp"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
}

output "ipv4_address" {
  value = digitalocean_droplet.krilldemo.ipv4_address
}

output "ssh_user" {
  value = "root"
}