# Private RDS Instance (NO hardcoded password)
resource "aws_db_subnet_group" "private_db_subnet_group" {
  name       = "private-db-subnet-group"
  subnet_ids = [aws_subnet.db_subnet_a.id, aws_subnet.db_subnet_b.id]
  tags       = { Name = "private-db-subnet-group" }
}
# Random (username only; password managed by RDS/Secrets Manager)
resource "random_string" "db_master_username" {
  length  = 15     # 1 char will be added as prefix to ensure AWS validity
  upper   = false
  lower   = true
  numeric = true   # <- fixed: replaced deprecated "number" with "numeric"
  special = false
}

locals {
  db_master_username = "u${random_string.db_master_username.result}"
}

resource "aws_db_instance" "private_postgres" {
  identifier                   = "private-project-db"
  allocated_storage            = 20
  storage_type                 = "gp2"
  engine                       = "postgres"
  engine_version               = "14.18"
  instance_class               = "db.t3.micro"
  username                     = local.db_master_username
  manage_master_user_password  = true
  publicly_accessible          = false
  skip_final_snapshot          = true
  deletion_protection          = false
  vpc_security_group_ids       = [aws_security_group.db_sg.id]
  db_subnet_group_name         = aws_db_subnet_group.private_db_subnet_group.name
  tags = { Name = "private-project-db" }
}