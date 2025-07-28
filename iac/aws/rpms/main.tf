terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = "eu-north-1"
}

# Obtener la VPC por defecto
data "aws_vpc" "default" {
  default = true
}

# Obtener TODAS las subnets por defecto
data "aws_subnets" "default_subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }

  filter {
    name   = "default-for-az"
    values = ["true"]
  }
}

# Usar la primera subnet
locals {
  default_subnet_id = data.aws_subnets.default_subnets.ids[0]
}

# Obtener el último Amazon Linux 2023 ARM64 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-*-arm64"]
  }
}

# Clave SSH
resource "tls_private_key" "example" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "generated_key" {
  key_name   = "terraform-key"
  public_key = tls_private_key.example.public_key_openssh
}

# Grupo de seguridad
resource "aws_security_group" "ssh_allow_all" {
  name        = "allow-ssh"
  description = "Allow SSH inbound"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "allow-ssh" }
}

# IP privada del jumpbox (ajusta si no lo tienes creado)
locals {
  jumpbox_private_ip = "10.0.2.100"
}

# VM Admin
resource "aws_instance" "admin_vm" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t4g.nano"
  key_name                    = aws_key_pair.generated_key.key_name
  subnet_id                   = local.default_subnet_id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.ssh_allow_all.id]

  tags = {
    Name = "admin-vm"
  }

}

# Outputs
output "admin_vm_public_ip" {
  value = aws_instance.admin_vm.public_ip
}

output "private_key_pem" {
  value     = tls_private_key.example.private_key_pem
  sensitive = true
}
