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

data "aws_region" "current" {}

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

# Main VPC
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

# Security groups
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
  description = "Allow SSH from admin subnet and VPC Endpoint traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.1.0/24"]
  }

  # Allow HTTPS traffic from VPC endpoints (ECR API & DKR)
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "jumpbox-sg" }
}

# ECR Private Repositories
resource "aws_ecr_repository" "cars" {
  name                 = "cars"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
  tags = { Name = "cars" }
}

resource "aws_ecr_repository" "docker" {
  name                 = "docker"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
  tags = { Name = "docker" }
}

# IAM Role for Jumpbox
resource "aws_iam_role" "jumpbox_role" {
  name = "jumpbox-ecr-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy" "jumpbox_ecr_policy" {
  name        = "jumpbox-ecr-policy"
  description = "Allow jumpbox to authenticate, pull and push to cars & docker ECR"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ecr:GetAuthorizationToken"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:DescribeRepositories",
          "ecr:ListImages"
        ],
        Resource = [
          aws_ecr_repository.cars.arn,
          aws_ecr_repository.docker.arn
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "jumpbox_ecr_policy_attach" {
  role       = aws_iam_role.jumpbox_role.name
  policy_arn = aws_iam_policy.jumpbox_ecr_policy.arn
}

resource "aws_iam_instance_profile" "jumpbox_profile" {
  name = "jumpbox-instance-profile"
  role = aws_iam_role.jumpbox_role.name
}

# EC2 Instances
resource "aws_instance" "admin_vm" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t4g.nano"
  key_name                    = aws_key_pair.admin_key_pair.key_name
  subnet_id                   = aws_subnet.admin_subnet.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.ssh_allow_all.id]

  user_data = templatefile("${path.module}/setup_admin.sh", {
    private_key = tls_private_key.jumpbox_key.private_key_pem,
    jumpbox_ip  = aws_instance.jumpbox.private_ip
  })

  provisioner "file" {
    source      = "${path.module}/setup_jumpbox.sh"
    destination = "/home/ec2-user/setup_jumpbox.sh"
    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = tls_private_key.admin_key.private_key_pem
      host        = self.public_ip
    }
  }

  provisioner "file" {
    source      = "${path.module}/setup_admin.sh"
    destination = "/home/ec2-user/setup_admin.sh"
    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = tls_private_key.admin_key.private_key_pem
      host        = self.public_ip
    }
  }

  provisioner "file" {
    source      = "${path.module}/bin/rpms.tar.gz"
    destination = "/home/ec2-user/rpms.tar.gz"
    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = tls_private_key.admin_key.private_key_pem
      host        = self.public_ip
    }
  }

  tags = { Name = "admin-vm" }

  depends_on = [aws_instance.jumpbox]
}

resource "aws_instance" "jumpbox" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t4g.nano"
  key_name                    = aws_key_pair.jumpbox_key_pair.key_name
  subnet_id                   = aws_subnet.jumpbox_subnet.id
  associate_public_ip_address = false
  vpc_security_group_ids      = [aws_security_group.jumpbox_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.jumpbox_profile.name
  tags = { Name = "jumpbox" }
}

# VPC Interface Endpoints for ECR & dependencies
locals {
  interface_services = [
    "ecr.api",
    "ecr.dkr",
    "sts"
  ]
}

resource "aws_vpc_endpoint" "interface_endpoints" {
  for_each = toset(local.interface_services)

  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.${each.key}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.jumpbox_subnet.id]
  security_group_ids  = [aws_security_group.jumpbox_sg.id]
  private_dns_enabled = true
  tags = {
    Name = "vpce-${each.key}"
  }
}

# Outputs
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

output "ecr_cars_repository_url" {
  value = aws_ecr_repository.cars.repository_url
}

output "ecr_docker_repository_url" {
  value = aws_ecr_repository.docker.repository_url
}
