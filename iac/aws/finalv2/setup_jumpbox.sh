#!/bin/bash
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

set -x  # Enable bash debug mode: print commands as they run

echo "[+] Setting up jumpbox (offline mode)"

# Ensure bin directory exists
mkdir -p /home/ec2-user/bin
cd /home/ec2-user

# Install AWS CLI from local zip
unzip -q bin/awscliv2.zip
sudo ./aws/install

# Install kubectl from local binary
sudo chmod +x bin/kubectl
sudo mv bin/kubectl /usr/local/bin/kubectl

# Install Docker
sudo yum install -y docker
sudo systemctl enable docker
sudo systemctl start docker
sudo usermod -aG docker ec2-user

echo "[+] Jumpbox setup complete"
