provider "aws" {
  region = var.region
}

locals {
  create_vpc = var.subnet_id == ""
  subnet_id  = var.subnet_id != "" ? var.subnet_id : aws_subnet.auto[0].id
}

data "aws_subnet" "target" {
  id = local.subnet_id
}

data "aws_availability_zones" "available" {}

resource "aws_vpc" "auto" {
  count                = local.create_vpc ? 1 : 0
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "grafana-auto-vpc"
  }
}

resource "aws_internet_gateway" "auto" {
  count  = local.create_vpc ? 1 : 0
  vpc_id = aws_vpc.auto[0].id
}

resource "aws_subnet" "auto" {
  count                   = local.create_vpc ? 1 : 0
  vpc_id                  = aws_vpc.auto[0].id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "grafana-auto-public"
  }
}

resource "aws_route_table" "auto" {
  count  = local.create_vpc ? 1 : 0
  vpc_id = aws_vpc.auto[0].id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.auto[0].id
  }
}

resource "aws_route_table_association" "auto" {
  count          = local.create_vpc ? 1 : 0
  subnet_id      = aws_subnet.auto[0].id
  route_table_id = aws_route_table.auto[0].id
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

resource "aws_security_group" "grafana" {
  count  = var.existing_sg_id == "" ? 1 : 0
  name   = "grafana-ansible-sg"
  vpc_id = data.aws_subnet.target.vpc_id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ingress_cidr_ssh]
  }

  ingress {
    description = "Grafana"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = [var.ingress_cidr_grafana]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

locals {
  sg_id = var.existing_sg_id != "" ? var.existing_sg_id : aws_security_group.grafana[0].id
}

resource "aws_instance" "grafana" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = local.subnet_id
  key_name                    = var.key_name
  vpc_security_group_ids      = [local.sg_id]
  associate_public_ip_address = true

  tags = {
    Name = "grafana-ansible"
  }
}
