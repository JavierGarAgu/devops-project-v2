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
    command = "docker build --no-cache -t ${aws_ecr_repository.private.repository_url}:latest --build-arg RUNNER_VERSION=2.319.1 --build-arg RUNNER_CONTAINER_HOOKS_VERSION=0.4.0 ../../../charts/docker_images/runner"
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