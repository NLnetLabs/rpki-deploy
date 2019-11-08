variable "do_token" {
  type        = string
  description = "Your Digital Ocean API token."
}

variable "ssh_key_path" {
  type        = string
  description = "The filesystem path to the SSH private key for access to the created Droplet."
}

variable "admin_ipv4_cidr" {
  type        = string
  description = "The IPv4 CIDR to restrict administrative access to. Default: unrestricted"
  default     = "0.0.0.0/0"
}

variable "admin_ipv6_cidr" {
  type        = string
  description = "The IPv6 CIDR to restrict administrative access to. Default: unrestricted"
  default     = "::/0"
}

variable "hostname" {
  type        = string
  description = "The DNS/EC2/DockerMachine/host name of the machine to create. Default: generated"
  default     = ""
}

variable "domain" {
  type        = string
  description = "The domain under which DigitalOcean A and AAAA DNS records will be created for hostname."
  default     = "do.nlnetlabs.nl"
}

variable "size" {
  type        = string
  default     = "s-1vcpu-1gb"
  description = "The size of the Digital Ocean Droplet to create. Default: s-1vcpu-1gb"
}

variable "region" {
  type        = string
  description = "The Digital Ocean region in which to create the new Droplet. Default: Amsterdam (ams3)"
  default     = "ams3"
}

variable "tags" {
  type        = set(string)
  description = "One or more strings to tag the new Digital Ocean Droplet with. Default: None."
  default     = []
}

variable "krill_auth_token" {
  type        = string
  description = "The authentication token Krill should restrict access to. Default: Random."
  default     = "None"
}

variable "krill_log_level" {
  type        = string
  description = "The level at which Krill should log. Can be: off, error, warn, info or debug. Default: info."
  default     = "info"
}

variable "use_staging_cert" {
  type        = bool
  description = "Whether or not the HTTPS Lets Encrypt certificate is requested to be staging or production. If false, Routinator will refuse to fetch the Krill TAL file. Default: true (staging)."
  default     = false
}

variable "krill_build_path" {
  type        = string
  description = "Path to a Git clone of https://github.com/NLnetLabs/krill.git which will be built on the Droplet. Default: None."
  default     = ""
}

variable "krill_version" {
  type        = string
  description = "The Docker image version identifier, i.e. nlnetlabs/krill:<version>. Default: v0.1.0. Ignored if krill_build_path is set."
  default     = "v0.2.1"
}

variable "docker_compose_dir" {
  type        = string
  description = "The relative or absolute path to the directory containing the docker-compose.yml template to deploy."
  default     = "../lib/docker/"
}

variable "src_tal" {
  type        = string
  description = "A URI or filename (in the baserelyingparties image /opt/ dir) of the TAL to use. <FQDN> will be replaced in the given URL. Examples: https://<FQDN>/ta/ta.tal, or ripe-pilot.tal"
  default     = "https://<FQDN>/ta/ta.tal"
}

variable "krill_use_ta" {
  type        = bool
  default     = true
  description = "Whether or not Krill should act as a TA for testing purposes. Default: true. Set to false when using an alternate src_tal."
}
