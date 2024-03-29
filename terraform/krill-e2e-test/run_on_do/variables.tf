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
  description = "The DNS/Droplet/DockerMachine/host name of the machine to create. Default: generated"
  default     = ""
}

variable "domain" {
  type        = string
  description = "The domain under which DigitalOcean A and AAAA DNS records will be created for hostname. Default: do.nlnetlabs.nl"
  default     = "do.nlnetlabs.nl"
}

variable "size" {
  type        = string
  default     = "s-4vcpu-8gb"
  description = "The size of the Digital Ocean Droplet to create. Default: s-4vcpu-8gb"
}

variable "region" {
  type        = string
  default     = "ams3"
  description = "The Digital Ocean region in which to create the new Droplet. Default: Amsterdam (ams3)"
}

variable "tags" {
  type        = set(string)
  default     = []
  description = "One or more strings to tag the new Digital Ocean Droplet with. Default: None."
}

variable "krill_admin_token" {
  type        = string
  default     = "61d81ea4-8a89-42c1-bb23-3e7eb79eaa60"
  description = "The authentication token Krill should restrict access to. Default: Random."
}

variable "krill_log_level" {
  type        = string
  default     = "debug"
  description = "The level at which Krill should log. Can be: off, error, warn, info or debug. Default: info."
}

variable "krill_build_path" {
  type        = string
  default     = ""
  description = "Path to a Git clone of https://github.com/NLnetLabs/krill.git which will be built on the Droplet. Default: None."
}

variable "krill_version" {
  type        = string
  default     = "v0.4.2"
  description = "The Docker image version identifier, i.e. nlnetlabs/krill:<version>. Default: v0.4.2. Ignored if krill_build_path is set."
}

variable "docker_compose_dir" {
  type        = string
  default     = "../lib/docker/"
  description = "The relative or absolute path to the directory containing the docker-compose.yml template to deploy."
}

variable "src_tal" {
  type        = string
  default     = "https://<FQDN>/ta/ta.tal"
  description = "A URI or filename (in the baserelyingparties image /opt/ dir) of the TAL to use. <FQDN> will be replaced in the given URL. Examples: https://<FQDN>/ta/ta.tal, or ripe-pilot.tal"
}

variable "krill_use_ta" {
  type        = bool
  default     = true
  description = "Whether or not Krill should act as a TA for testing purposes. Default: true. Set to false when using an alternate src_tal."
}

variable "run_tests" {
  type        = bool
  default     = true
  description = "Whether or not to run the post deployment tests."
}

variable "test_suite_path" {
  type        = string
  default     = ""
  description = "The absolute path to the directory containing the Python tests to run."
}

variable "tmp_dir" {
  type        = string
  default     = null
}