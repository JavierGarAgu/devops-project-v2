terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

resource "aws_ecrpublic_repository" "public_example" {
  provider = aws.us_east_1

  repository_name = "bar"

  catalog_data {
    about_text        = "About Text"
    architectures     = ["ARM"]
    description       = "Description"
    operating_systems = ["Linux"]
    usage_text        = "Usage Text"
  }

  tags = {
    env = "production"
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
