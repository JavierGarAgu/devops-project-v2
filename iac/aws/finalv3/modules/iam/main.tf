############################################
# Unified Jumpbox IAM Role
############################################
resource "aws_iam_role" "jumpbox_role" {
  name = "jumpbox-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

############################################
# EKS Policy Attachments
############################################
resource "aws_iam_role_policy_attachment" "eks_cluster" {
  role       = aws_iam_role.jumpbox_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role_policy_attachment" "eks_worker" {
  role       = aws_iam_role.jumpbox_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "vpc_resource_controller" {
  role       = aws_iam_role.jumpbox_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
}

############################################
# ECR Custom Policy
############################################
resource "aws_iam_policy" "jumpbox_ecr_policy" {
  name        = "jumpbox-ecr-policy"
  description = "Allow jumpbox to authenticate, pull and push to cars & docker ECR"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ecr:GetAuthorizationToken"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:DescribeRepositories",
          "ecr:ListImages"
        ],
        Resource = [
          var.docker_arn,
          var.cars_arn
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "jumpbox_ecr_policy_attach" {
  role       = aws_iam_role.jumpbox_role.name
  policy_arn = aws_iam_policy.jumpbox_ecr_policy.arn
}

############################################
# RDS Secrets Policy
############################################
data "aws_iam_policy_document" "jumpbox_secrets_doc" {
  statement {
    sid     = "AllowGetDbMasterSecret"
    effect  = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret"
    ]
    resources = [
      var.rds_arn
    ]
  }
}

resource "aws_iam_policy" "jumpbox_secrets_policy" {
  name        = "jumpbox-secrets-get-policy"
  description = "Allow jumpbox to read the RDS master secret only"
  policy      = data.aws_iam_policy_document.jumpbox_secrets_doc.json
}

resource "aws_iam_role_policy_attachment" "jumpbox_secrets_attach" {
  role       = aws_iam_role.jumpbox_role.name
  policy_arn = aws_iam_policy.jumpbox_secrets_policy.arn
}

############################################
# Instance Profile
############################################
resource "aws_iam_instance_profile" "jumpbox_profile" {
  name = "jumpbox-instance-profile"
  role = aws_iam_role.jumpbox_role.name
}
