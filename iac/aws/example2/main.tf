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

# Buscar la última AMI arm64 de Amazon Linux 2023
data "aws_ami" "example" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "architecture"
    values = ["arm64"]
  }
  filter {
    name   = "name"
    values = ["al2023-ami-2023*"]
  }
}

# Crear par de claves
resource "tls_private_key" "example" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "generated_key" {
  key_name   = "tf-generated-key"
  public_key = tls_private_key.example.public_key_openssh
}

# Crear Security Group para permitir SSH
resource "aws_security_group" "allow_ssh" {
  name_prefix = "allow-ssh"

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

  tags = {
    Name = "ssh-access"
  }
}

# Instancia EC2 Spot
resource "aws_instance" "example" {
  ami                         = data.aws_ami.example.id
  instance_type               = "t4g.nano"
  key_name                    = aws_key_pair.generated_key.key_name
  vpc_security_group_ids      = [aws_security_group.allow_ssh.id]

  instance_market_options {
    market_type = "spot"
    spot_options {
      # Puedes eliminar esta línea para usar el precio spot actual automáticamente
      max_price = 0.002
    }
  }

  tags = {
    Name = "test-spot"
  }
}

# Mostrar la clave privada como output (para guardarla y usarla en SSH)
output "private_key_pem" {
  value     = tls_private_key.example.private_key_pem
  sensitive = true
}
output "public_ip" {
  value = aws_instance.example.public_ip
}
