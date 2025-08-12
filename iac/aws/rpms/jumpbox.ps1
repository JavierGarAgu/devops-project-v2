$sshDir = "$env:USERPROFILE\.ssh"
if (-not (Test-Path $sshDir)) {
    New-Item -ItemType Directory -Path $sshDir
}

$privateKeyPath = "$sshDir\id_rsa"

if (-not (Test-Path $privateKeyPath)) {
    terraform output -raw private_key_pem | Set-Content -Path $privateKeyPath -Encoding ascii -Force

    icacls $privateKeyPath /inheritance:r | Out-Null
    icacls $privateKeyPath /grant:r "$($env:USERNAME):(R)" | Out-Null
    icacls $privateKeyPath /remove "Users" | Out-Null
}
else {
    Write-Host "key $privateKeyPath already exists"
}

# Get admin VM public IP
$adminPublicIp = terraform output -raw admin_vm_public_ip
Write-Host "Admin VM Public IP: $adminPublicIp"

# Get jumpbox private IP
$jumpboxPrivateIp = terraform output -raw jumpbox_private_ip
Write-Host "Jumpbox Private IP: $jumpboxPrivateIp"

# SSH command with ProxyJump through admin VM to jumpbox
ssh -o StrictHostKeyChecking=no -i $privateKeyPath -J "ec2-user@$adminPublicIp" "ec2-user@$jumpboxPrivateIp"
