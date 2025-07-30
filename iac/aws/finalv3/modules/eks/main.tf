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
