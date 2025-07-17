#!/bin/bash

exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
set -x

echo "[+] Setting up jumpbox (offline install)"

cd /home/ec2-user
mkdir -p /home/ec2-user/bin

# Extract binaries
tar -xzvf offline_binaries.tar.gz -C /home/ec2-user

# Install all binaries
cd /home/ec2-user/offline_bins
for bin in *; do
  sudo cp -v "$bin" /usr/local/bin/
  sudo chmod +x /usr/local/bin/"$bin"
done

# Setup Docker (minimal)
sudo mkdir -p /etc/docker
sudo systemctl enable docker || true
sudo systemctl start docker || true
sudo usermod -aG docker ec2-user || true

echo "[+] Jumpbox setup complete"
