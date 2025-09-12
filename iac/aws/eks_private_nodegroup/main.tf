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
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.19.0"
    }
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
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
  depends_on = [ aws_eks_node_group.private_ng ]
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

resource "aws_eks_addon" "cert_manager" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "cert-manager"
  resolve_conflicts_on_update = "OVERWRITE"
  depends_on = [ aws_eks_node_group.private_ng ]
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
    endpoint_public_access  = true
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
    desired_size = 1
    min_size     = 1
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
  namespace        = kubernetes_namespace.arc.metadata[0].name
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
YAML

  depends_on = [
    aws_eks_node_group.private_ng,
    aws_eks_addon.coredns,
    aws_eks_addon.kube_proxy,
    aws_eks_addon.vpc_cni,
    aws_eks_addon.pod_identity_agent
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
    namespace = kubernetes_namespace.arc.metadata[0].name
  }

  data = {
    github_token = var.github_token
  }

  type = "Opaque"

  depends_on = [kubernetes_namespace.arc]
}



# IAM policy for ECR access
resource "aws_iam_policy" "ecr_access" {
  name        = "EKSNodeECRAccess"
  description = "Allow EKS nodes to pull from ECR private repositories"
  policy      = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = "*"
      }
    ]
  })
}

# Attach the policy to the EKS node role
resource "aws_iam_role_policy_attachment" "node_ecr_access" {
  role       = aws_iam_role.eks_nodes.name
  policy_arn = aws_iam_policy.ecr_access.arn
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


# ECR repository
resource "aws_ecr_repository" "private" {
  name                 = "my-private-repo"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }

  force_delete = true

  tags = {
    Name = "my-private-repo"
  }
}

# Get temporary ECR auth token
data "aws_ecr_authorization_token" "dockertoken" {}

# First: login to ECR
resource "null_resource" "docker_login" {
  provisioner "local-exec" {
    command = <<EOT
aws ecr get-login-password --region eu-north-1 | docker login --username AWS --password-stdin ${aws_ecr_repository.private.repository_url}
EOT
  }

  depends_on = [
    aws_ecr_repository.private
  ]
}



# Second: build the Docker image
resource "null_resource" "docker_build" {
  provisioner "local-exec" {
    command = "docker build --no-cache -t ${aws_ecr_repository.private.repository_url}:latest --build-arg RUNNER_VERSION=2.319.1 --build-arg RUNNER_CONTAINER_HOOKS_VERSION=0.4.0 ../../../charts/helm/runners"
  }

  depends_on = [
    null_resource.docker_login
  ]
}

# Third: push the image
resource "null_resource" "docker_push" {
  provisioner "local-exec" {
    command = "docker push ${aws_ecr_repository.private.repository_url}:latest"
  }

  depends_on = [
    null_resource.docker_build
  ]
}

# Security Group for EC2
resource "aws_security_group" "ec2_sg" {
  name        = "ec2-sg"
  description = "Allow access per basic EC2 setup"
  vpc_id      = aws_vpc.project.id

  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ec2-sg"
  }
}

# IAM Role for EC2
resource "aws_iam_role" "ec2_role" {
  name = "basic-ec2-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_role_attach" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"
}

# Attach EKS access policies to EC2 role
resource "aws_iam_role_policy_attachment" "ec2_eks_cluster_policy" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role_policy_attachment" "ec2_eks_worker_policy" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "ec2_ecr_ro_policy" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "basic-ec2-instance-profile"
  role = aws_iam_role.ec2_role.name
}

# EC2 Key Pair
resource "tls_private_key" "ec2_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "ec2_key" {
  key_name   = "ec2-key"
  public_key = tls_private_key.ec2_key.public_key_openssh
}

# Get latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}
# EC2 Instance
resource "aws_instance" "ec2" {
  ami                         = data.aws_ami.amazon_linux2.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public1_a.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.ec2_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2_instance_profile.name
  key_name                    = aws_key_pair.ec2_key.key_name

  tags = {
    Name = "basic-ec2"
  }

  depends_on = [aws_route_table_association.public1_a]
}

output "ec2_instance_id" {
  value = aws_instance.ec2.id
}

output "ec2_public_ip" {
  value = aws_instance.ec2.public_ip
}

output "ec2_security_group_id" {
  value = aws_security_group.ec2_sg.id
}

output "ec2_keypair_name" {
  value = aws_key_pair.ec2_key.key_name
}

output "ec2_private_key_pem" {
  value     = tls_private_key.ec2_key.private_key_pem
  sensitive = true
}

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