output "ssh_sg_id" {
  value = aws_security_group.ssh_allow_all.id
}

output "eks_sg_id" {
  value = aws_security_group.eks_jumpbox_sg.id
}

output "private_key_pem" {
  value     = tls_private_key.this.private_key_pem
  sensitive = true
}

output "key_pair_name" {
  value = aws_key_pair.generated.key_name
}

output "db_sg_id" {
  value = aws_security_group.db_sg.id
}
