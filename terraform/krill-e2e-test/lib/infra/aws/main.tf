variable "key_name" {}
variable "key_openssh" {}
variable "instance_type" {}
variable "domain" {}
variable "hostname" {}
variable "tags" {}
variable "admin_ipv4_cidr" {}
variable "admin_ipv6_cidr" {}
variable "region" {}
variable "ingress_tcp_ports" {}

provider "aws" {
  region = var.region
}

data "aws_availability_zones" "found" {
  state = "available"
}

resource "aws_vpc" "vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = "krille2etest"
  }
}

resource "aws_subnet" "subnet" {
  vpc_id               = aws_vpc.vpc.id
  cidr_block           = cidrsubnet(aws_vpc.vpc.cidr_block, 3, 1)
  availability_zone_id = data.aws_availability_zones.found.zone_ids[0]
}

resource "aws_internet_gateway" "vpc_gw" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "krille2etest"
  }
}

resource "aws_route_table" "route_table" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.vpc_gw.id
  }
  tags = {
    Name = "vpc-route-table"
  }
}

resource "aws_route_table_association" "subnet_association" {
  subnet_id      = aws_subnet.subnet.id
  route_table_id = aws_route_table.route_table.id
}

resource "aws_security_group" "sg" {
  name   = "krille2etest"
  vpc_id = aws_vpc.vpc.id

  dynamic "ingress" {
    iterator = port
    for_each = var.ingress_tcp_ports
    content {
      from_port   = port.value
      to_port     = port.value
      protocol    = "tcp"
      cidr_blocks = [var.admin_ipv4_cidr]
      ipv6_cidr_blocks = [var.admin_ipv6_cidr]
    }
  }

  ingress {
      from_port = -1
      to_port = -1
      protocol = "icmp"
      cidr_blocks = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
  }
}

data "aws_ami" "ubuntu_16_04_lts" {
  owners      = ["099720109477"] # Canonical
  most_recent = true
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-*"]
  }
}

resource "aws_key_pair" "krill" {
  key_name   = var.key_name
  public_key = var.key_openssh
}

resource "aws_instance" "vm" {
  ami             = data.aws_ami.ubuntu_16_04_lts.id
  instance_type   = var.instance_type
  key_name        = var.key_name
  subnet_id       = aws_subnet.subnet.id
  security_groups = [aws_security_group.sg.id]
  tags = merge(map("Name", var.hostname), var.tags)
}

resource "aws_eip" "ip" {
  instance = aws_instance.vm.id
  vpc      = true
}

data "aws_route53_zone" "thezone" {
  name = "${var.domain}."
}

resource "aws_route53_record" "krill_demo_ipv4" {
  zone_id = data.aws_route53_zone.thezone.zone_id
  name    = "${var.hostname}.${var.domain}"
  type    = "A"
  ttl     = "60"
  records = [aws_eip.ip.public_ip]
}

output "ipv4_address" {
  value = aws_eip.ip.public_ip
}

output "ssh_user" {
  value = "ubuntu"
}