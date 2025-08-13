terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# Create a public ECR repository
resource "aws_ecrpublic_repository" "public_example" {
  repository_name = "public-example"

  catalog_data {
    description       = "container for some things"
    operating_systems = ["Linux"]
    architectures     = ["x86"]
  }

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

output "repository_url" {
  description = "The URL of the public ECR repository"
  value       = aws_ecrpublic_repository.public_example.repository_uri
}

output "repository_name" {
  description = "The name of the public ECR repository"
  value       = aws_ecrpublic_repository.public_example.repository_name
}

output "repository_arn" {
  description = "The ARN of the public ECR repository"
  value       = aws_ecrpublic_repository.public_example.arn
}

output "registry_id" {
  description = "The registry ID where the public ECR repository was created"
  value       = aws_ecrpublic_repository.public_example.registry_id
}
