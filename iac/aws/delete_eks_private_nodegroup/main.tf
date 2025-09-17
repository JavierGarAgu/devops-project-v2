terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "eu-north-1"
}

# -----------------------------
# Minimal EKS cluster block
# -----------------------------
resource "aws_eks_cluster" "this" {
  name     = "placeholder-cluster-name"         # Placeholder, real name comes from import
  role_arn = "arn:aws:iam::123456789012:role/placeholder-role"

  vpc_config {
    subnet_ids = ["subnet-0123456789abcdef0"]   # Fake subnet ID, import will replace
  }
}

# -----------------------------
# Minimal EKS node group block
# -----------------------------
resource "aws_eks_node_group" "private_ng" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "placeholder-nodegroup-name"
  node_role_arn   = "arn:aws:iam::123456789012:role/placeholder-node-role"
  subnet_ids      = ["subnet-0123456789abcdef0"]

  scaling_config {
    desired_size = 1
    min_size     = 1
    max_size     = 1
  }
}
