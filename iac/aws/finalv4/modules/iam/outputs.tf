output "eks_cluster_role_arn" {
  value = aws_iam_role.eks_cluster_role.arn
}

output "eks_node_role_arn" {
  value = aws_iam_role.eks_node_role.arn
}


output "jumpbox_role_arn" {
  value = aws_iam_role.jumpbox_role.arn
}

output "jumpbox_profile" {
  value = aws_iam_instance_profile.jumpbox_profile.name
}
