terraform {
  required_version = ">= 0.13"

  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.19.0"
    }
  }
}

# -----------------------------
# EC2 Key Pair for SSH access
# -----------------------------
resource "aws_key_pair" "kube_demo" {
  key_name   = "kube-demo"
  public_key = file("~/.ssh/kube-demo.pub") # Replace with the path to your public key
}

# -----------------------------
# EKS Cluster
# -----------------------------
resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  role_arn = var.cluster_role_arn
  version  = "1.33"

  vpc_config {
    subnet_ids              = var.subnet_ids
    endpoint_public_access  = true
    endpoint_private_access = true
    security_group_ids      = [var.security_group_id]
  }

  depends_on = [var.cluster_role_arn]
}

resource "aws_security_group_rule" "cp_from_nodes" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"

  security_group_id        = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
  source_security_group_id = var.security_group_id

  description              = "Worker nodes to API server"
}

resource "aws_security_group_rule" "nodes_from_cp_10250" {
  type                     = "ingress"
  from_port                = 10250
  to_port                  = 10250
  protocol                 = "tcp"
  security_group_id        = var.security_group_id
  source_security_group_id = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
  description              = "EKS control plane to kubelet"
}

resource "aws_eks_node_group" "default" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.cluster_name}-ng"
  node_role_arn   = var.node_role_arn
  subnet_ids      = var.subnet_ids
  scaling_config {
    desired_size = 1
    max_size     = 1
    min_size     = 1
  }

  instance_types = ["t3.small"]

  depends_on = [
    aws_eks_cluster.this,
    kubernetes_config_map.aws_auth,
    aws_security_group_rule.cp_from_nodes
  ]
}

resource "aws_eks_node_group" "private1" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.cluster_name}-ng-private1"
  node_role_arn   = var.node_role_arn
  subnet_ids      = var.subnet_ids

  # Scaling configuration
  scaling_config {
    desired_size = 2
    min_size     = 2
    max_size     = 4
  }

  # EC2 instance type
  instance_types = ["t3.medium"]

  # Node volume
  disk_size = 20

  # SSH access
  remote_access {
    ec2_ssh_key = aws_key_pair.kube_demo.key_name
  }

  # Networking
  ami_type      = "AL2_x86_64"
  capacity_type = "ON_DEMAND"

  # IAM / Access permissions
  tags = {
    "k8s.io/cluster-autoscaler/enabled" = "true"
  }

  force_update_version = true

  depends_on = [
    aws_eks_cluster.this,
    kubernetes_config_map.aws_auth,
    aws_security_group_rule.cp_from_nodes
  ]
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

provider "kubectl" {
  host                   = aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.this.certificate_authority[0].data)
  load_config_file       = false

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", aws_eks_cluster.this.name]
  }
}

provider "helm" {
  kubernetes = {
    host                   = aws_eks_cluster.this.endpoint
    cluster_ca_certificate = base64decode(aws_eks_cluster.this.certificate_authority[0].data)

    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = [
        "eks",
        "get-token",
        "--cluster-name",
        aws_eks_cluster.this.name
      ]
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
        username = "cluster"
        groups   = ["system:masters"]
      },
      {
        rolearn  = var.node_role_arn
        username = "node"
        groups   = ["system:masters"]
      }
    ])
  }

  depends_on = [aws_eks_cluster.this]
}

# -----------------------------
# Namespace for cert-manager
# -----------------------------

# -----------------------------
# Download and apply cert-manager CRDs
# -----------------------------
# data "http" "cert_manager_crds" {
#   url = "https://github.com/cert-manager/cert-manager/releases/download/v1.6.3/cert-manager.crds.yaml"
# }

# data "kubectl_file_documents" "cert_manager_crds" {
#   content = data.http.cert_manager_crds.body
# }

# resource "kubectl_manifest" "cert_manager_crds" {
#   for_each           = data.kubectl_file_documents.cert_manager_crds.manifests
#   yaml_body          = each.value
#   server_side_apply  = true
#   force_new          = true
#   depends_on         = [kubernetes_namespace.cert_manager]
# }

# -----------------------------
# Helm release for cert-manager
# -----------------------------
resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = "v1.18.2"
  create_namespace = true
  namespace        = "cert-manager"
  cleanup_on_fail  = true

  set = [{
    name  = "installCRDs"
    value = true
  }]
  depends_on = [aws_eks_node_group.default]
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
# ARC Helm release
# -----------------------------
resource "helm_release" "arc" {
  name             = "controller"
  repository       = "https://actions-runner-controller.github.io/actions-runner-controller"
  chart            = "actions-runner-controller"
  namespace        = kubernetes_namespace.arc.metadata[0].name
  create_namespace = false

  wait    = true
  timeout = 600

  depends_on = [kubernetes_secret.arc_github_token]
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

  depends_on = [kubernetes_namespace.arc]
}
