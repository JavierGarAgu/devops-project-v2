# -----------------------------
# EKS Cluster
# -----------------------------
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

# -----------------------------
# Providers
# -----------------------------
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

# -----------------------------
# aws-auth ConfigMap
# -----------------------------
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
# Namespace for cert-manager
# -----------------------------
resource "kubernetes_namespace" "cert_manager" {
  metadata {
    name = "cert-manager"
  }

  depends_on = [kubernetes_config_map.aws_auth]
}

# -----------------------------
# CRDs for cert-manager (official k8s provider)
# -----------------------------
locals {
  crd_docs = [
    for doc in split("---", file("./bin/cert-manager.crds.yaml")) :
    yamldecode(doc)
    if trimspace(doc) != ""
  ]
}

resource "kubernetes_manifest" "cert_manager_crds" {
  for_each = { for idx, crd in local.crd_docs : idx => crd }
  manifest = each.value
  depends_on = [kubernetes_namespace.cert_manager]
}

# -----------------------------
# Helm release for cert-manager
# -----------------------------
resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  namespace        = kubernetes_namespace.cert_manager.metadata[0].name
  create_namespace = false

  wait    = true
  timeout = 600

  depends_on = [kubernetes_manifest.cert_manager_crds]
}

# -----------------------------
# Namespace for Actions Runner Controller (ARC)
# -----------------------------
resource "kubernetes_namespace" "arc" {
  metadata {
    name = "actions-runner-system"
  }

  depends_on = [helm_release.cert_manager]
}

# -----------------------------
# Helm release for ARC
# -----------------------------
resource "helm_release" "arc" {
  name             = "controller"
  repository       = "https://actions-runner-controller.github.io/actions-runner-controller"
  chart            = "actions-runner-controller"
  namespace        = kubernetes_namespace.arc.metadata[0].name
  create_namespace = false

  wait    = true
  timeout = 600

  depends_on = [kubernetes_namespace.arc]
}

# -----------------------------
# GitHub Token Secret for ARC
# -----------------------------
resource "kubernetes_secret" "arc_github_token" {
  metadata {
    name      = "controller-manager"
    namespace = kubernetes_namespace.arc.metadata[0].name
  }

  data = {
    github_token = var.github_token
  }

  type = "Opaque"

  depends_on = [helm_release.arc]
}
