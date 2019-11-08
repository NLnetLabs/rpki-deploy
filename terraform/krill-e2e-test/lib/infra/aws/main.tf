variable "key_name" {}
variable "key_openssh" {}
variable "instance_type" {}
variable "subnet_id" {}
variable "domain" {}
variable "hostname" {}
variable "region" {}

provider "aws" {
  region = var.region
}

resource "aws_key_pair" "krill" {
  key_name   = var.key_name
  public_key = var.key_openssh
}

resource "aws_instance" "ec2vm" {
  # TODO: use a map to use the right region specific AMI ID
  # This AMI ID is for Ubuntu 16.04 LTS Xenial Xerus eu-west-1 HVM SSD
  # version 20190628.
  ami           = "ami-03746875d916becc0"
  instance_type = var.instance_type
  key_name      = var.key_name
  subnet_id     = var.subnet_id
}

data "aws_route53_zone" "thezone" {
  name = "${var.domain}."
}

resource "aws_route53_record" "krill_demo_ipv4" {
  zone_id = "${data.aws_route53_zone.thezone.zone_id}"
  name    = "${var.hostname}.${var.domain}"
  type    = "A"
  ttl     = "60"
  records = [aws_instance.ec2vm.public_ip]
}

output "ipv4_address" {
  value = aws_instance.ec2vm.public_ip
}

output "ssh_user" {
  value = "ubuntu"
}