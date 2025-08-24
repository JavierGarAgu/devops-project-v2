terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.5.0"
}

provider "aws" {
  region = "us-east-1"
}

variable "bucket_suffix" {
  description = "Suffix for the Terraform state S3 bucket and lock table"
  type        = string
  default     = "abcd" # replace with your fixed or generated suffix
}

# S3 bucket for Terraform state
resource "aws_s3_bucket" "tf_state" {
  bucket = "tfstate-devopsv2-${var.bucket_suffix}"
}

# Block all public access
resource "aws_s3_bucket_public_access_block" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# DynamoDB table for Terraform state locking
resource "aws_dynamodb_table" "tf_locks" {
  name         = "terraform-locks-${var.bucket_suffix}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}

# Outputs
output "s3_bucket_name" {
  value = aws_s3_bucket.tf_state.bucket
}

output "dynamodb_table_name" {
  value = aws_dynamodb_table.tf_locks.name
}


#TO USE THE S3 AS TFSTATE STORAGE

# terraform {
#   backend "s3" {
#     bucket         = "<BUCKET_NAME_FROM_OUTPUT>"
#     key            = "global/terraform.tfstate"
#     region         = "us-east-1"
#     dynamodb_table = "terraform-locks"
#     encrypt        = true
#   }
# }
