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

resource "kubernetes_namespace" "arc" {
  metadata {
    name = "actions-runner-system"
  }
    depends_on = [
    aws_eks_node_group.private_ng,
    aws_eks_addon.coredns,
    aws_eks_addon.kube_proxy,
    aws_eks_addon.vpc_cni,
    aws_eks_addon.pod_identity_agent,
    aws_eks_addon.cert_manager
  ]
}

# -----------------------------
# ARC Helm release
# -----------------------------
resource "helm_release" "arc" {
  name             = "controller"
  repository       = "https://actions-runner-controller.github.io/actions-runner-controller"
  chart            = "actions-runner-controller"
  namespace        = "actions-runner-system"
  create_namespace = false

  wait    = true
  timeout = 600

  depends_on = [kubernetes_secret.arc_github_token]
}

resource "kubectl_manifest" "aws_auth" {
  yaml_body = <<YAML
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
    - rolearn: ${aws_iam_role.eks_nodes.arn}
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:bootstrappers
        - system:nodes
    - rolearn: ${aws_iam_role.ec2_role.arn}
      username: ec2-admin
      groups:
        - system:masters
    - rolearn: ${aws_iam_role.arc_runner.arn}
      username: arc-runner
      groups:
        - system:masters
YAML

  depends_on = [
    aws_eks_node_group.private_ng,
    aws_eks_addon.coredns,
    aws_eks_addon.kube_proxy,
    aws_eks_addon.vpc_cni,
    aws_eks_addon.pod_identity_agent,
    aws_iam_role.arc_runner
  ]
}

resource "kubernetes_cluster_role_binding" "arc_runner_admin" {
  metadata {
    name = "arc-runner-admin-binding"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }

  subject {
    kind      = "ServiceAccount"
    name      = "my-runner-sa"
    namespace = local.arc_namespace
  }
}

resource "null_resource" "wait_for_oidc" {
  provisioner "local-exec" {
    interpreter = ["PowerShell", "-Command"]

    command = <<EOT
for ($i = 0; $i -lt 10; $i++) {
  try {
    Invoke-WebRequest -Uri '${aws_eks_cluster.this.identity[0].oidc[0].issuer}/.well-known/openid-configuration' -UseBasicParsing -TimeoutSec 10 | Out-Null
    exit 0
  } catch {
    Write-Host 'Waiting for OIDC issuer...'
    Start-Sleep -Seconds 15
  }
}
exit 1
EOT
  }

  depends_on = [aws_eks_cluster.this]
}


data "tls_certificate" "eks_oidc" {
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer
  depends_on = [null_resource.wait_for_oidc]
}

resource "aws_iam_openid_connect_provider" "eks" {
  url            = aws_eks_cluster.this.identity[0].oidc[0].issuer
  client_id_list = ["sts.amazonaws.com"]
  thumbprint_list = [
    data.tls_certificate.eks_oidc.certificates[0].sha1_fingerprint
  ]
}


resource "helm_release" "my_runner" {
  name             = "my-runner"
  chart            = "../../../charts/helm/arc_runner"
  namespace        = "actions-runner-system"
  create_namespace = false

  set = [
    {
      name  = "runner.image"
      value = "${aws_ecr_repository.private.repository_url}:latest"
    },
    {
      name  = "runner.pullpolicy"
      value = "Always"
    },
    {
      name  = "runner.serviceAccountName"
      value = "my-runner-sa"
    },
    {
      name  = "runner.roleArn"
      value = aws_iam_role.arc_runner.arn
    }
  ]

  depends_on = [
    helm_release.arc,
    kubernetes_namespace.arc,
    aws_iam_role.arc_runner
  ]
}




# -----------------------------
# Operator Lifecycle Manager (OLM)
# -----------------------------

# Download OLM CRDs to Terraform
# -----------------------------
# OLM CRDs
# -----------------------------
# -----------------------------
# Helper function to remove large annotations (optional)
# -----------------------------

# -----------------------------
# GitHub Token Secret for ARC
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

  depends_on = [kubernetes_namespace.arc]
}





resource "kubernetes_secret" "ecr_registry" {
  metadata {
    name      = "ecr-registry"
    namespace = "default"
  }

  type = "kubernetes.io/dockerconfigjson"

  data = {
    ".dockerconfigjson" = jsonencode({
      auths = {
        "${aws_ecr_repository.private.repository_url}" = {
          auth = data.aws_ecr_authorization_token.dockertoken.authorization_token
        }
      }
    })
  }

  depends_on = [
    aws_ecr_repository.private,
    data.aws_ecr_authorization_token.dockertoken
  ]
}
