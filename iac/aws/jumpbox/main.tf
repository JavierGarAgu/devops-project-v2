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

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-*-arm64"]
  }
}

# Generate RSA key for admin VM
resource "tls_private_key" "admin_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "admin_key_pair" {
  key_name   = "terraform-admin-key"
  public_key = tls_private_key.admin_key.public_key_openssh
}

# Generate RSA key for jumpbox
resource "tls_private_key" "jumpbox_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "jumpbox_key_pair" {
  key_name   = "terraform-jumpbox-key"
  public_key = tls_private_key.jumpbox_key.public_key_openssh
}

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = { Name = "main-vpc" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "main-igw" }
}

resource "aws_subnet" "admin_subnet" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[0]
  tags = { Name = "admin-subnet" }
}

resource "aws_subnet" "jumpbox_subnet" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = false
  availability_zone       = data.aws_availability_zones.available.names[1]
  tags = { Name = "jumpbox-subnet" }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "public-rt" }
}

resource "aws_route_table_association" "admin_assoc" {
  subnet_id      = aws_subnet.admin_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_security_group" "ssh_allow_all" {
  name        = "allow-ssh"
  description = "Allow SSH inbound"
  vpc_id      = aws_vpc.main.id

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

resource "aws_security_group" "jumpbox_sg" {
  name        = "jumpbox-sg"
  description = "Allow SSH from admin subnet"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.1.0/24"]  # Only admin subnet can SSH to jumpbox
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "jumpbox-sg" }
}

resource "aws_instance" "admin_vm" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t4g.nano"
  key_name                    = aws_key_pair.admin_key_pair.key_name
  subnet_id                   = aws_subnet.admin_subnet.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.ssh_allow_all.id]

  # Provision jumpbox private key inside admin VM for SSH to jumpbox
  user_data = <<-EOF
              #!/bin/bash
              mkdir -p /home/ec2-user/.ssh
              echo '${tls_private_key.jumpbox_key.private_key_pem}' > /home/ec2-user/.ssh/jumpbox_id_rsa
              chmod 600 /home/ec2-user/.ssh/jumpbox_id_rsa
              chown ec2-user:ec2-user /home/ec2-user/.ssh/jumpbox_id_rsa
              EOF

  tags = { Name = "admin-vm" }
}

resource "aws_instance" "jumpbox" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t4g.nano"
  key_name                    = aws_key_pair.jumpbox_key_pair.key_name
  subnet_id                   = aws_subnet.jumpbox_subnet.id
  associate_public_ip_address = false
  vpc_security_group_ids      = [aws_security_group.jumpbox_sg.id]
  tags = { Name = "jumpbox" }
}

output "admin_vm_public_ip" {
  value = aws_instance.admin_vm.public_ip
}

output "jumpbox_private_ip" {
  value = aws_instance.jumpbox.private_ip
}

output "admin_private_key_pem" {
  value     = tls_private_key.admin_key.private_key_pem
  sensitive = true
}

output "jumpbox_private_key_pem" {
  value     = tls_private_key.jumpbox_key.private_key_pem
  sensitive = true
}
