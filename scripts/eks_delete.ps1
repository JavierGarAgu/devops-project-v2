# -------------------------
# CONFIGURATION
# -------------------------
$Folder1 = "..\iac\aws\eks_private_nodegroup"
$Folder2 = "..\iac\aws\delete_eks_private_nodegroup"

# -------------------------
Push-Location $Folder1
terraform destroy -target "aws_eks_node_group.private_ng" -auto-approve -var "github_token=1"
terraform destroy -target "aws_eks_cluster.this" -auto-approve -var "github_token=1"
terraform destroy -auto-approve
Pop-Location

Write-Host "EKS resources destroyed first then the rest of resources"
