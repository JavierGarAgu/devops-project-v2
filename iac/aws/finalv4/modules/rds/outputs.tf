output "phostname" {
  value = aws_db_instance.private_postgres.address
}

output "rds_arn"{
  value = aws_db_instance.private_postgres.master_user_secret[0].secret_arn
}