provider "aws" {
  region = var.region
}

data "aws_subnet" "target" {
  id = var.subnet_id
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
  subnet_id                   = var.subnet_id
  key_name                    = var.key_name
  vpc_security_group_ids      = [local.sg_id]
  associate_public_ip_address = true

  tags = {
    Name = "grafana-ansible"
  }
}
