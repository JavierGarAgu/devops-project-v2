terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "eu-north-1"
}

# ✅ Security Group allowing inbound access to port 5432
resource "aws_security_group" "postgres_sg" {
  name        = "allow-postgres"
  description = "Allow PostgreSQL inbound traffic"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "PostgreSQL"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # ❗ Replace with your IP (e.g., "123.45.67.89/32") for better security
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "postgres-sg"
  }
}

# ✅ Fetch default VPC (required for Security Group)
data "aws_vpc" "default" {
  default = true
}

# ✅ PostgreSQL RDS instance
resource "aws_db_instance" "postgres" {
  identifier              = "final-project-db"
  allocated_storage       = 20
  storage_type            = "gp2"
  engine                  = "postgres"
  engine_version          = "13.15"
  instance_class          = "db.t3.micro"
  db_name                 = "final_project"
  username                = "postgres"
  password                = "password"
  publicly_accessible     = true
  skip_final_snapshot     = true
  deletion_protection     = false
  vpc_security_group_ids  = [aws_security_group.postgres_sg.id]

  tags = {
    Name = "final-project-db"
  }
}

# ✅ Output for connection URL
output "postgres_connection_url" {
  description = "Connection string for the PostgreSQL RDS instance"
  value       = "postgresql://${aws_db_instance.postgres.username}:${aws_db_instance.postgres.password}@${aws_db_instance.postgres.address}:${aws_db_instance.postgres.port}/${aws_db_instance.postgres.db_name}"
  sensitive   = true
}
