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

# ------------ DATA SOURCES ------------

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

# ------------ KEY PAIR ------------

resource "tls_private_key" "example" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "generated_key" {
  key_name   = "terraform-key"
  public_key = tls_private_key.example.public_key_openssh
}

# ------------ VPC & SUBNETS ------------

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = { Name = "main-vpc" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = { Name = "main-igw" }
}

resource "aws_subnet" "admin_subnet" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[0]
  tags = { Name = "admin-subnet" }
}

resource "aws_subnet" "eks_subnet_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = false
  availability_zone       = data.aws_availability_zones.available.names[1]
  tags = { Name = "eks-subnet-a" }
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

# ------------ SECURITY GROUPS ------------

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

resource "aws_security_group" "eks_jumpbox_sg" {
  name        = "jumpbox-sg"
  description = "Allow SSH from admin_vm"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.ssh_allow_all.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "jumpbox-sg" }
}

# ------------ EC2 INSTANCES ------------

resource "aws_instance" "admin_vm" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t4g.nano"
  key_name                    = aws_key_pair.generated_key.key_name
  subnet_id                   = aws_subnet.admin_subnet.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.ssh_allow_all.id]

  user_data = templatefile("${path.module}/setup_admin.sh", {
    private_key = tls_private_key.example.private_key_pem,
    jumpbox_ip  = aws_instance.eks_jumpbox.private_ip
  })

  depends_on = [aws_instance.eks_jumpbox]

  tags = {
    Name = "admin-vm"
  }

  provisioner "file" {
    source      = "${path.module}/setup_jumpbox.sh"
    destination = "/home/ec2-user/setup_jumpbox.sh"
    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = tls_private_key.example.private_key_pem
      host        = self.public_ip
    }
  }

  provisioner "file" {
    source      = "${path.module}/bin/offline_binaries.tar.gz"
    destination = "/home/ec2-user/offline_binaries.tar.gz"
    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = tls_private_key.example.private_key_pem
      host        = self.public_ip
    }
  }
}

resource "aws_instance" "eks_jumpbox" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t4g.nano"
  key_name                    = aws_key_pair.generated_key.key_name
  subnet_id                   = aws_subnet.eks_subnet_a.id
  associate_public_ip_address = false
  vpc_security_group_ids      = [aws_security_group.eks_jumpbox_sg.id]
  tags = { Name = "eks-jumpbox" }
}

# ------------ OUTPUTS ------------

output "admin_vm_public_ip" {
  value = aws_instance.admin_vm.public_ip
}

output "jumpbox_private_ip" {
  value = aws_instance.eks_jumpbox.private_ip
}

output "private_key_pem" {
  value     = tls_private_key.example.private_key_pem
  sensitive = true
}
