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

$publicIp = terraform output -raw admin_vm_public_ip
Write-Host "ip: $publicIp"

ssh -o StrictHostKeyChecking=no -i $privateKeyPath ec2-user@$publicIp
