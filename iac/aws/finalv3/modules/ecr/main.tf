# ECR Private Repositories
resource "aws_ecr_repository" "cars" {
  name                 = "cars"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
  tags = { Name = "cars" }
}

resource "aws_ecr_repository" "docker" {
  name                 = "docker"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
  tags = { Name = "docker" }
}