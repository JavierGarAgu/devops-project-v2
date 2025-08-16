# Jumpbox IAM Role
resource "aws_iam_role" "jumpbox_role" {
  name = "jumpbox-role" # unified name
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

# Attach EKS-related policies
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

# Custom ECR Policy
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
          aws_ecr_repository.cars.arn,
          aws_ecr_repository.docker.arn
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "jumpbox_ecr_policy_attach" {
  role       = aws_iam_role.jumpbox_role.name
  policy_arn = aws_iam_policy.jumpbox_ecr_policy.arn
}

# Instance Profile for EC2 Jumpbox
resource "aws_iam_instance_profile" "jumpbox_profile" {
  name = "jumpbox-instance-profile"
  role = aws_iam_role.jumpbox_role.name
}
