terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = "eu-north-1"
}

# -----------------------
# Networking (VPC & Subnets)
# -----------------------

resource "aws_vpc" "project" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = "project-vpc"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.project.id
  tags = {
    Name = "project-igw"
  }
}

# Public subnets
resource "aws_subnet" "public1_a" {
  vpc_id                  = aws_vpc.project.id
  cidr_block              = "10.0.0.0/20"
  availability_zone       = "eu-north-1a"
  map_public_ip_on_launch = false
  tags = {
    Name = "project-subnet-public1-eu-north-1a"
  }
}

resource "aws_subnet" "public2_b" {
  vpc_id                  = aws_vpc.project.id
  cidr_block              = "10.0.16.0/20"
  availability_zone       = "eu-north-1b"
  map_public_ip_on_launch = false
  tags = {
    Name = "project-subnet-public2-eu-north-1b"
  }
}

resource "aws_subnet" "public3_c" {
  vpc_id                  = aws_vpc.project.id
  cidr_block              = "10.0.32.0/20"
  availability_zone       = "eu-north-1c"
  map_public_ip_on_launch = false
  tags = {
    Name = "project-subnet-public3-eu-north-1c"
  }
}

# Private subnets
resource "aws_subnet" "private1_a" {
  vpc_id            = aws_vpc.project.id
  cidr_block        = "10.0.128.0/20"
  availability_zone = "eu-north-1a"
  tags = {
    Name = "project-subnet-private1-eu-north-1a"
  }
}

resource "aws_subnet" "private2_b" {
  vpc_id            = aws_vpc.project.id
  cidr_block        = "10.0.144.0/20"
  availability_zone = "eu-north-1b"
  tags = {
    Name = "project-subnet-private2-eu-north-1b"
  }
}

resource "aws_subnet" "private3_c" {
  vpc_id            = aws_vpc.project.id
  cidr_block        = "10.0.160.0/20"
  availability_zone = "eu-north-1c"
  tags = {
    Name = "project-subnet-private3-eu-north-1c"
  }
}

# -----------------------
# NAT & EIP
# -----------------------

resource "aws_eip" "nat" {
  domain = "vpc"
  tags = {
    Name = "project-nat-eip"
  }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public1_a.id
  tags = {
    Name = "project-nat-public1-eu-north-1a"
  }
  depends_on = [aws_internet_gateway.igw]
}

# -----------------------
# Route tables
# -----------------------

# Public route table with IGW route
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.project.id
  tags = {
    Name = "project-rtb-public"
  }
}

resource "aws_route" "public_igw" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

# Associate all public subnets with the public RTB
resource "aws_route_table_association" "public1_a" {
  subnet_id      = aws_subnet.public1_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public2_b" {
  subnet_id      = aws_subnet.public2_b.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public3_c" {
  subnet_id      = aws_subnet.public3_c.id
  route_table_id = aws_route_table.public.id
}

# Private route tables (per AZ) with default route to NAT
resource "aws_route_table" "private1_a" {
  vpc_id = aws_vpc.project.id
  tags = {
    Name = "project-rtb-private1-eu-north-1a"
  }
}

resource "aws_route" "private1_nat" {
  route_table_id         = aws_route_table.private1_a.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat.id
}

resource "aws_route_table_association" "private1_a" {
  subnet_id      = aws_subnet.private1_a.id
  route_table_id = aws_route_table.private1_a.id
}

resource "aws_route_table" "private2_b" {
  vpc_id = aws_vpc.project.id
  tags = {
    Name = "project-rtb-private2-eu-north-1b"
  }
}

resource "aws_route" "private2_nat" {
  route_table_id         = aws_route_table.private2_b.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat.id
}

resource "aws_route_table_association" "private2_b" {
  subnet_id      = aws_subnet.private2_b.id
  route_table_id = aws_route_table.private2_b.id
}

resource "aws_route_table" "private3_c" {
  vpc_id = aws_vpc.project.id
  tags = {
    Name = "project-rtb-private3-eu-north-1c"
  }
}

resource "aws_route" "private3_nat" {
  route_table_id         = aws_route_table.private3_c.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat.id
}

resource "aws_route_table_association" "private3_c" {
  subnet_id      = aws_subnet.private3_c.id
  route_table_id = aws_route_table.private3_c.id
}

# Optional: default/main route table (only local routes, as in your output)
resource "aws_default_route_table" "main" {
  default_route_table_id = aws_vpc.project.default_route_table_id
  tags = {
    Name = "project-rtb-main"
  }
}

# -----------------------
# IAM Roles & Policy Attachments
# -----------------------

# EKS cluster role
data "aws_iam_policy" "AmazonEKSClusterPolicy" {
  arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role" "eks_cluster" {
  name = "EKS_IAM_Role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
  description        = "Allows the cluster Kubernetes control plane to manage AWS resources on your behalf."
  max_session_duration = 3600
  tags = {
    Name = "EKS_IAM_Role"
  }
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = data.aws_iam_policy.AmazonEKSClusterPolicy.arn
}


# EKS node group role
data "aws_iam_policy" "AmazonEKSWorkerNodePolicy" {
  arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}
data "aws_iam_policy" "AmazonEC2ContainerRegistryReadOnly" {
  arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}
data "aws_iam_policy" "AmazonEKS_CNI_Policy" {
  arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role" "eks_nodes" {
  name = "Workernode_group_IAM_Role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
  description          = "nodegroup private"
  max_session_duration = 3600
  tags = {
    Name = "Workernode_group_IAM_Role"
  }
}

# -----------------------
# EKS Addons
# -----------------------

resource "aws_eks_addon" "coredns" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "coredns"
  resolve_conflicts_on_update = "OVERWRITE"
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "kube-proxy"
  resolve_conflicts_on_update = "OVERWRITE"
}

resource "aws_eks_addon" "vpc_cni" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "vpc-cni"
  resolve_conflicts_on_update = "OVERWRITE"
}

resource "aws_eks_addon" "pod_identity_agent" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "eks-pod-identity-agent"
  resolve_conflicts_on_update = "OVERWRITE"
}

resource "aws_iam_role_policy_attachment" "node_worker" {
  role       = aws_iam_role.eks_nodes.name
  policy_arn = data.aws_iam_policy.AmazonEKSWorkerNodePolicy.arn
}

resource "aws_iam_role_policy_attachment" "node_ecr_ro" {
  role       = aws_iam_role.eks_nodes.name
  policy_arn = data.aws_iam_policy.AmazonEC2ContainerRegistryReadOnly.arn
}

resource "aws_iam_role_policy_attachment" "node_cni" {
  role       = aws_iam_role.eks_nodes.name
  policy_arn = data.aws_iam_policy.AmazonEKS_CNI_Policy.arn
}

# -----------------------
# EKS Cluster & Node Group
# -----------------------

resource "aws_eks_cluster" "this" {
  name     = "private-eks"
  version  = "1.33"
  role_arn = aws_iam_role.eks_cluster.arn

  vpc_config {
    subnet_ids              = [
      aws_subnet.private1_a.id,
      aws_subnet.private2_b.id,
      aws_subnet.private3_c.id
    ]
    endpoint_public_access  = false
    endpoint_private_access = true
  }

  enabled_cluster_log_types = [] # matches your disabled logging
  tags = {}
  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy
  ]
}

resource "aws_eks_node_group" "private_ng" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "private-ng"
  node_role_arn   = aws_iam_role.eks_nodes.arn
  subnet_ids = [
    aws_subnet.private1_a.id,
    aws_subnet.private2_b.id,
    aws_subnet.private3_c.id
  ]

  instance_types = ["t3.medium"]
  ami_type       = "AL2023_x86_64_STANDARD"
  disk_size      = 20
  capacity_type  = "ON_DEMAND"
  version        = "1.33"
  release_version = "1.33.3-20250821"

  scaling_config {
    desired_size = 2
    min_size     = 2
    max_size     = 2
  }

  update_config {
    max_unavailable = 1
  }

  tags = {}

  depends_on = [
    aws_iam_role_policy_attachment.node_worker,
    aws_iam_role_policy_attachment.node_ecr_ro,
    aws_iam_role_policy_attachment.node_cni
  ]
}

# -----------------------
# Helpful outputs
# -----------------------

output "vpc_id" {
  value = aws_vpc.project.id
}

output "public_subnet_ids" {
  value = [aws_subnet.public1_a.id, aws_subnet.public2_b.id, aws_subnet.public3_c.id]
}

output "private_subnet_ids" {
  value = [aws_subnet.private1_a.id, aws_subnet.private2_b.id, aws_subnet.private3_c.id]
}

output "eks_cluster_name" {
  value = aws_eks_cluster.this.name
}

output "node_group_name" {
  value = aws_eks_node_group.private_ng.node_group_name
}
