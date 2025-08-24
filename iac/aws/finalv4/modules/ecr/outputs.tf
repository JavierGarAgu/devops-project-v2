output "ecr_cars_repository_url" {
  value = aws_ecr_repository.cars.repository_url
}

output "ecr_docker_repository_url" {
  value = aws_ecr_repository.docker.repository_url
}

output "ecr_cars_repository_arn" {
  value       = aws_ecr_repository.cars.arn
}

output "ecr_docker_repository_arn" {
  value       = aws_ecr_repository.docker.arn
}
