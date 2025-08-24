output "admin_public_ip" {
  value = aws_instance.admin.public_ip
}

output "jumpbox_private_ip" {
  value = aws_instance.jumpbox.private_ip
}
