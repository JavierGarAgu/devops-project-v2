# Set SSH directory
$sshDir = "$env:USERPROFILE\.ssh"
if (-not (Test-Path $sshDir)) {
    New-Item -ItemType Directory -Path $sshDir
}

# Path for the private key
$privateKeyPath = "$sshDir\ciphertrust_key.pem"

# Write private key from Terraform output if it doesn't exist
if (-not (Test-Path $privateKeyPath)) {
    terraform output -raw ciphertrust_private_key_pem | Set-Content -Path $privateKeyPath -Encoding ascii -Force

    # Secure permissions
    icacls $privateKeyPath /inheritance:r | Out-Null
    icacls $privateKeyPath /grant:r "$($env:USERNAME):(R)" | Out-Null
    icacls $privateKeyPath /remove "Users" | Out-Null
}
else {
    Write-Host "Key $privateKeyPath already exists"
}

# Get the public IP of the CTM EC2 instance from Terraform output
$publicIp = terraform output -raw ec2_public_ip
Write-Host "Connecting to CipherTrust Manager at IP: $publicIp"

# SSH into the CipherTrust Manager
ssh -o StrictHostKeyChecking=no -i $privateKeyPath ksadmin@$publicIp
