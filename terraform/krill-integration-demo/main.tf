provider "digitalocean" {
  token   = "${var.do_token}"
  version = "~> 1.1"
}

# This provider is used to resolve conditional or incomplete values which are
# used by the rest of the template.
data "null_data_source" "values" {
  inputs = {
    krill_version   = var.krill_build_path != "" ? "dirty" : var.krill_version
    krill_build_cmd = var.krill_build_path != "" ? "docker build -t nlnetlabs/krill:dirty ." : "echo skipping Krill build" 
    krill_fqdn      = join(".", [var.hostname, var.domain])
  }
}

# This provider is used to obtain the SSH key fingerprint of the SSH key that
# the user wants to use to login to the newly created Droplet.
data "tls_public_key" "krilldemo" {
  private_key_pem = "${file(var.ssh_key_path)}"
}

# Create a Digital Ocean Droplet, but not directly via the Digital Ocean
# provider, rather via the Docker Machine provider which supports Digital
# Ocean. After creating the Droplet, Docker Machine will ensure that a Docker
# Daemon is running and secured on the Droplet and that we have the necessary
# credentials to interact with it remotely. As the Docker Machine library is
# included in the Terraform Docker Machine provider this avoids the need for
# the user to install and use Docker Machine separately.
resource "dockermachine_digitalocean" "krilldemo" {
  name                             = var.hostname
  engine_install_url               = "https://get.docker.com"
  digitalocean_access_token        = var.do_token
  digitalocean_region              = var.region
  digitalocean_size                = var.size
  digitalocean_ssh_key_fingerprint = data.tls_public_key.krilldemo.public_key_fingerprint_md5
  digitalocean_tags                = join(",", var.tags)
  digitalocean_image               = "ubuntu-16-04-x64"
  digitalocean_ipv6                = true

  # Create the "external" Docker volume needed by the Docker Compose template.
  # We can't do this using the Terraform Docker provider because that provider
  # can only be configured with a previously know remote Docker daemon URL, and
  # we don't know that URL prior to deployment because it depends on the IP
  # address given back to us by Digital Ocean once the Droplet has been
  # created.
  provisioner "local-exec" {
    # Set DOCKER_ env vars that cause the docker command below to talk to the
    # _remote_ Docker daemon running on the Droplet, not to any local Docker
    # daemon. Use the configured connection details to instruct the remote
    # Docker daemon to create a persistent "external" (not defined by the
    # compose template) Docker volume for storing Lets Encrypt certificates.
    environment = {
      DOCKER_TLS_VERIFY   = "1"
      DOCKER_HOST         = "${self.docker_url}"
      DOCKER_CERT_PATH    = "${self.storage_path_computed}"
      DOCKER_MACHINE_NAME = "${self.name}"
    }
    command = "docker volume create krill_letsencrypt_certs"
  }

  # Normally this next provisioner will be skipped as we use a Krill Docker
  # image published to Docker Hub, but if requested this provisioner will be
  # invoked to build Krill Docker image from local sources. The krill_build_cmd
  # value will be set to 'null' if the user didn't supply var.krill_build_path,
  # in which case this provisioner will be skipped entirely.
  provisioner "local-exec" {
    # Set DOCKER_ env vars that cause the docker command below to talk to the
    # remote_Docker daemon running on the Droplet, not to our local Docker
    # daemon (if it even exists).
    environment = {
      DOCKER_TLS_VERIFY   = "1"
      DOCKER_HOST         = "${self.docker_url}"
      DOCKER_CERT_PATH    = "${self.storage_path_computed}"
      DOCKER_MACHINE_NAME = "${self.name}"
    }
    working_dir = var.krill_build_path
    command     = data.null_data_source.values.outputs["krill_build_cmd"]
  }

  # Deploy nginx, Routinator, Krill and rsyncd containers via the _remote_
  # Docker daemon running on the Digital Ocean droplet.
  provisioner "local-exec" {
    working_dir = var.docker_compose_dir
    command     = "docker-compose up --build -d"
    # Set DOCKER_ env vars that cause the docker command below to talk to the
    # _remote_ Docker daemon running on the Droplet, not to our local Docker
    # daemon (if it even exists), and set KRILL_ env vars that are referenced
    # by the Docker Compose template.
    environment = {
      DOCKER_TLS_VERIFY   = "1"
      DOCKER_HOST         = "${self.docker_url}"
      DOCKER_CERT_PATH    = "${self.storage_path_computed}"
      DOCKER_MACHINE_NAME = "${self.name}"
      KRILL_STAGING_CERT  = var.use_staging_cert
      KRILL_AUTH_TOKEN    = var.krill_auth_token
      KRILL_LOG_LEVEL     = var.krill_log_level
      KRILL_FQDN          = data.null_data_source.values.outputs["krill_fqdn"]
      KRILL_VERSION       = data.null_data_source.values.outputs["krill_version"]
    }
  }
}

# Obtain the Digital Ocean ID of the Droplet created by the Docker Machine
# Terraform provider.
data "digitalocean_droplet" "krilldemo" {
  name       = var.hostname
  depends_on = [dockermachine_digitalocean.krilldemo]
}

# Create a DNS A record in Digital Ocean for the new Droplet.
resource "digitalocean_record" "krilldemo_ipv4" {
  domain = var.domain
  type   = "A"
  name   = var.hostname
  value  = data.digitalocean_droplet.krilldemo.ipv4_address
  ttl    = 60
}

# Create a DNS AAAA record in Digital Ocean for the new Droplet.
resource "digitalocean_record" "krilldemo_ipv6" {
  domain = var.domain
  type   = "AAAA"
  name   = var.hostname
  value  = data.digitalocean_droplet.krilldemo.ipv6_address
  ttl    = 60
}

# Create a Digital Ocean firewall and associate it with the new Droplet.
resource "digitalocean_firewall" "krilldemo" {
  name        = join("", [var.hostname, "firewall"])
  droplet_ids = [data.digitalocean_droplet.krilldemo.id]

  # -> ssh
  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = [var.admin_ipv4_cidr, var.admin_ipv6_cidr]
  }

  # -> http
  inbound_rule {
    protocol         = "tcp"
    port_range       = "80"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  # -> https
  inbound_rule {
    protocol         = "tcp"
    port_range       = "443"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  # -> icmp
  inbound_rule {
    protocol         = "icmp"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  # -> docker daemon
  inbound_rule {
    protocol         = "tcp"
    port_range       = 2376
    source_addresses = [var.admin_ipv4_cidr, var.admin_ipv6_cidr]
  }

  # -> rsync
  inbound_rule {
    protocol         = "tcp"
    port_range       = 873
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  # -> routinator prometheus exportor
  inbound_rule {
    protocol         = "tcp"
    port_range       = 9556
    source_addresses = [var.admin_ipv4_cidr, var.admin_ipv6_cidr]
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
