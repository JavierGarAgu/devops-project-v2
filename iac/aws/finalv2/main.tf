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

data "aws_region" "current" {}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-*-arm64"]
  }
}

resource "tls_private_key" "example" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "generated_key" {
  key_name   = "terraform-key"
  public_key = tls_private_key.example.public_key_openssh
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

resource "aws_subnet" "eks_subnet_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = false
  availability_zone       = data.aws_availability_zones.available.names[1]
  tags = { Name = "eks-subnet-a" }
}

resource "aws_subnet" "eks_subnet_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.3.0/24"
  map_public_ip_on_launch = false
  availability_zone       = data.aws_availability_zones.available.names[2]
  tags = { Name = "eks-subnet-b" }
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

resource "aws_eip" "nat_gw_eip" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.igw]
}

resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_gw_eip.id
  subnet_id     = aws_subnet.admin_subnet.id
  tags = { Name = "nat-gateway" }
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "private-rt" }
}

resource "aws_route" "private_nat_route" {
  route_table_id         = aws_route_table.private_rt.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_gw.id
  depends_on             = [aws_nat_gateway.nat_gw]
}

resource "aws_route_table_association" "eks_subnet_a_assoc" {
  subnet_id      = aws_subnet.eks_subnet_a.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "eks_subnet_b_assoc" {
  subnet_id      = aws_subnet.eks_subnet_b.id
  route_table_id = aws_route_table.private_rt.id
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

resource "aws_security_group" "eks_jumpbox_sg" {
  name        = "jumpbox-sg"
  description = "Allow ALL from anywhere for testing"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "jumpbox-sg" }
}

resource "aws_iam_role" "eks_cluster_role" {
  name = "eksClusterRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "eks.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_role_attach" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role" "jumpbox_role" {
  name = "jumpboxEksRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "ec2.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "jumpbox_eks_cluster_policy_attach" {
  role       = aws_iam_role.jumpbox_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role_policy_attachment" "jumpbox_eks_worker_node_policy_attach" {
  role       = aws_iam_role.jumpbox_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "jumpbox_eks_vpc_resource_controller_attach" {
  role       = aws_iam_role.jumpbox_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
}

resource "aws_iam_instance_profile" "jumpbox_profile" {
  name = "jumpboxInstanceProfile"
  role = aws_iam_role.jumpbox_role.name
}

resource "aws_eks_cluster" "main" {
  name     = "my-private-eks"
  role_arn = aws_iam_role.eks_cluster_role.arn
  version  = "1.30"

  vpc_config {
    subnet_ids = [
      aws_subnet.eks_subnet_a.id,
      aws_subnet.eks_subnet_b.id
    ]
    endpoint_private_access = true
    endpoint_public_access  = false
  }

  depends_on = [aws_iam_role_policy_attachment.eks_cluster_role_attach]
}

locals {
  interface_services = [
    "eks",
    "eks-auth",
    "ec2",
    "sts",
    "logs",
    "ecr.api",
    "ecr.dkr",
    "elasticloadbalancing"
  ]
}

resource "aws_vpc_endpoint" "interface_endpoints" {
  for_each = toset(local.interface_services)

  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.${each.key}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.eks_subnet_a.id, aws_subnet.eks_subnet_b.id]
  security_group_ids  = [aws_security_group.eks_jumpbox_sg.id]
  private_dns_enabled = true
  tags = {
    Name = "vpce-${each.key}"
  }
}

resource "aws_instance" "eks_jumpbox" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t4g.nano"
  key_name                    = aws_key_pair.generated_key.key_name
  subnet_id                   = aws_subnet.eks_subnet_a.id
  associate_public_ip_address = false
  vpc_security_group_ids      = [aws_security_group.eks_jumpbox_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.jumpbox_profile.name
  tags = { Name = "eks-jumpbox" }
}

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

  tags = { Name = "admin-vm" }

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
    source      = "${path.module}/bin/rpms.tar.gz"
    destination = "/home/ec2-user/rpms.tar.gz"
    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = tls_private_key.example.private_key_pem
      host        = self.public_ip
    }
  }
}

output "admin_vm_public_ip" {
  value = aws_instance.admin_vm.public_ip
}

output "jumpbox_private_ip" {
  value = aws_instance.eks_jumpbox.private_ip
}

output "eks_cluster_endpoint" {
  value = aws_eks_cluster.main.endpoint
}

output "eks_cluster_name" {
  value = aws_eks_cluster.main.name
}

output "private_key_pem" {
  value     = tls_private_key.example.private_key_pem
  sensitive = true
}
