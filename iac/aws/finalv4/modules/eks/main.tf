terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
  }
  required_version = ">= 1.5.0"
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  role_arn = var.cluster_role_arn
  version  = "1.30"

  vpc_config {
    subnet_ids              = var.subnet_ids
    endpoint_public_access  = var.public_cluster
    endpoint_private_access = true
    security_group_ids      = [var.security_group_id]
  }

  depends_on = [var.cluster_role_arn]
}

provider "kubernetes" {
  host                   = aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.this.certificate_authority[0].data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", aws_eks_cluster.this.name]
  }
}

provider "helm" {
  kubernetes {
    host                   = aws_eks_cluster.this.endpoint
    cluster_ca_certificate = base64decode(aws_eks_cluster.this.certificate_authority[0].data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", aws_eks_cluster.this.name]
    }
  }
}

# aws-auth configmap
resource "kubernetes_config_map" "aws_auth" {
  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  data = {
    mapRoles = yamlencode([
      {
        rolearn  = var.cluster_role_arn
        username = "eks-cluster"
        groups   = ["system:masters"]
      },
      {
        rolearn  = var.jumpbox_role_arn
        username = "jumpbox"
        groups   = ["system:masters"]
      }
    ])
  }

  depends_on = [aws_eks_cluster.this]
}

# -----------------------------
# CERT-MANAGER Helm chart
# -----------------------------
resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  namespace  = "cert-manager"
  create_namespace = true

  set {
    name  = "installCRDs"
    value = "true"
  }
}

# -----------------------------
# ACTIONS RUNNER CONTROLLER
# -----------------------------
resource "helm_release" "arc" {
  name       = "controller"
  repository = "https://actions-runner-controller.github.io/actions-runner-controller"
  chart      = "actions-runner-controller"
  namespace  = "actions-runner-system"
  create_namespace = true
}

# -----------------------------
# Secret for GitHub Token
# -----------------------------
resource "kubernetes_secret" "arc_github_token" {
  metadata {
    name      = "controller-manager"
    namespace = "actions-runner-system"
  }

  data = {
    github_token = var.github_token
  }

  type = "Opaque"

  depends_on = [helm_release.arc]
}
