output "vpc_id" {
  value = aws_vpc.main.id
}

output "admin_subnet_id" {
  value = aws_subnet.admin.id
}

output "eks_subnet_ids" {
  value = [aws_subnet.eks_a.id, aws_subnet.eks_b.id]
}

output "eks_subnet_a_id" {
  value = aws_subnet.eks_a.id
}

output "eks_subnet_a_cidr" {
  value = aws_subnet.eks_a.cidr_block
}

output "db_subnet_a_id" {
  value = aws_subnet.db_subnet_a.id
}

output "db_subnet_b_id" {
  value = aws_subnet.db_subnet_b.id
}

output "route_private" {
  value = aws_route_table.private.id
}