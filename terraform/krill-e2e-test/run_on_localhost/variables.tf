variable "krill_auth_token" {
  type        = string
  default     = "61d81ea4-8a89-42c1-bb23-3e7eb79eaa60"
  description = "The authentication token Krill should restrict access to. Default: Random."
}

variable "krill_log_level" {
  type        = string
  default     = "debug"
  description = "The level at which Krill should log. Can be: off, error, warn, info or debug. Default: debug."
}

variable "krill_build_path" {
  type        = string
  default     = ""
  description = "Path to a Git clone of https://github.com/NLnetLabs/krill.git which will be built on the Droplet. Default: None."
}

variable "krill_version" {
  type        = string
  default     = "v0.4.2"
  description = "The Docker image version identifier, i.e. nlnetlabs/krill:<version>. Default: v0.1.0. Ignored if krill_build_path is set."
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