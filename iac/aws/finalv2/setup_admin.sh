#!/bin/bash

exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1
set -x

jumpbox_ip="__JUMPBOX_IP__"
private_key="__PRIVATE_KEY__"

echo "Using jumpbox IP: ${jumpbox_ip}" >> /home/ec2-user/debug.txt

# Create working directory
cd /home/ec2-user
mkdir -p /home/ec2-user/bin

# Extract offline binaries
tar -xzvf offline_binaries.tar.gz -C /home/ec2-user

# Install binaries to /usr/local/bin
cd /home/ec2-user/offline_bins
for bin in *; do
  sudo cp -v "$bin" /usr/local/bin/
  sudo chmod +x /usr/local/bin/"$bin"
done

# Setup minimal Docker (dockerd might still require manual start if no systemd config)
sudo mkdir -p /etc/docker
sudo systemctl enable docker || true
sudo systemctl start docker || true
sudo usermod -aG docker ec2-user || true

# Save the private key
echo "${private_key}" > /home/ec2-user/jumpbox.pem
chmod 600 /home/ec2-user/jumpbox.pem
chown ec2-user:ec2-user /home/ec2-user/jumpbox.pem

# Wait for jumpbox SSH port
echo "Waiting for jumpbox SSH to be ready..."
for i in {1..30}; do
  ssh -o StrictHostKeyChecking=no -i /home/ec2-user/jumpbox.pem ec2-user@"${jumpbox_ip}" "echo ok" && break
  sleep 10
done

# Transfer files
scp -o StrictHostKeyChecking=no -i /home/ec2-user/jumpbox.pem /home/ec2-user/setup_jumpbox.sh ec2-user@"${jumpbox_ip}":/home/ec2-user/
scp -o StrictHostKeyChecking=no -i /home/ec2-user/jumpbox.pem /home/ec2-user/offline_binaries.tar.gz ec2-user@"${jumpbox_ip}":/home/ec2-user/

# Execute remote setup
ssh -o StrictHostKeyChecking=no -i /home/ec2-user/jumpbox.pem ec2-user@"${jumpbox_ip}" "chmod +x /home/ec2-user/setup_jumpbox.sh && sudo bash /home/ec2-user/setup_jumpbox.sh"
