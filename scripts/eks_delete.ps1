# -------------------------
# CONFIGURATION
# -------------------------
$Folder1 = "..\iac\aws\eks_private_nodegroup"
$Folder2 = "..\iac\aws\delete_eks_private_nodegroup"

# -------------------------
Push-Location $Folder1
terraform state rm kubectl_manifest.aws_auth
terraform state rm kubernetes_namespace.arc
terraform state rm helm_release.arc
terraform state rm helm_release.my_runner
terraform state rm kubernetes_secret.arc_github_token
terraform destroy -auto-approve
Pop-Location

Write-Host "All done! EKS resources destroyed first, then the rest of folder1 resources."
