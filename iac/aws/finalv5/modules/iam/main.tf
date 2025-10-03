# -----------------------
# IAM Roles & Policy Attachments
# -----------------------

# EKS cluster role

resource "aws_iam_policy" "allow_assume_arc_runner" {
  name        = "AllowAssumeArcRunnerRole"
  description = "Allow terraform-admin to assume arc-runner-role"
  policy      = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Resource = aws_iam_role.arc_runner.arn
      }
    ]
  })
}

resource "aws_iam_policy_attachment" "attach_assume_arc_runner" {
  name       = "attach-assume-arc-runner"
  policy_arn = aws_iam_policy.allow_assume_arc_runner.arn
  users      = ["terraform-admin"]
}


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

resource "aws_iam_role" "arc_runner" {
  name = "arc-runner-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.eks.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            # subject must match serviceaccount in the namespace
            "${replace(aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:${local.arc_namespace}:my-runner-sa"
          }
        }
      }
    ]
  })
}


resource "aws_iam_role_policy_attachment" "arc_runner_s3" {
  role       = aws_iam_role.arc_runner.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_role_policy_attachment" "arc_runner_eks" {
  role       = aws_iam_role.arc_runner.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
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

# -----------------------
# IAM Policy to allow RDS Secret access
# -----------------------
resource "aws_iam_policy" "arc_runner_rds_secret" {
  name        = "ArcRunnerRDSSecretAccess"
  description = "Allow ARC runner / EKS workloads to read RDS master secret"
  policy      = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = aws_db_instance.postgres.master_user_secret[0].secret_arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "arc_runner_rds_secret_attach" {
  role       = aws_iam_role.arc_runner.name
  policy_arn = aws_iam_policy.arc_runner_rds_secret.arn
}
