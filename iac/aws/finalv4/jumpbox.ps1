# Define SSH directory path
$sshDir = "$env:USERPROFILE\.ssh"
if (-not (Test-Path $sshDir)) {
    New-Item -ItemType Directory -Path $sshDir
}

# Admin VM private key setup
$adminKeyFile = "$sshDir\admin_id_rsa"
if (-not (Test-Path $adminKeyFile)) {
    terraform output -raw private_key_pem | Set-Content -Path $adminKeyFile -Encoding ascii -Force
    icacls $adminKeyFile /inheritance:r | Out-Null
    icacls $adminKeyFile /grant:r "$($env:USERNAME):(R)" | Out-Null
    icacls $adminKeyFile /remove "Users" | Out-Null
} else {
    Write-Host "Admin key $adminKeyFile already exists"
}

# Get IP addresses from Terraform output
$adminPublicIp = terraform output -raw admin_vm_public_ip
$jumpboxPrivateIp = terraform output -raw jumpbox_ip

Write-Host "Admin VM public IP: $adminPublicIp"
Write-Host "Jumpbox private IP: $jumpboxPrivateIp"

# Connect via SSH to the admin VM first
Write-Host "Connecting to admin VM..."

ssh -o StrictHostKeyChecking=no -i $adminKeyFile -t ec2-user@$adminPublicIp `
    "ssh -o StrictHostKeyChecking=no -i /home/ec2-user/.ssh/jumpbox_id_rsa -t ec2-user@$jumpboxPrivateIp"
