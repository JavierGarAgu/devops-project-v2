#!/bin/bash

exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1
set -x

# Jumpbox IP is embedded directly by Terraform
jumpbox_ip="__JUMPBOX_IP__"

echo "Using jumpbox IP: ${jumpbox_ip}" >> /home/ec2-user/debug.txt

# Install necessary packages
sudo yum update -y
sudo yum install -y unzip curl jq git awscli docker openssh-clients

sudo systemctl enable docker
sudo systemctl start docker
sudo usermod -aG docker ec2-user

# Save the private key to file
cat <<EOF > /home/ec2-user/jumpbox.pem
__PRIVATE_KEY__
EOF

chmod 600 /home/ec2-user/jumpbox.pem
chown ec2-user:ec2-user /home/ec2-user/jumpbox.pem

# Wait for jumpbox SSH port
echo "Waiting for jumpbox SSH to be ready..."
for i in {1..30}; do
  ssh -o StrictHostKeyChecking=no -i /home/ec2-user/jumpbox.pem ec2-user@"${jumpbox_ip}" "echo ok" && break
  sleep 10
done

# Transfer setup files
scp -o StrictHostKeyChecking=no -i /home/ec2-user/jumpbox.pem /home/ec2-user/setup_jumpbox.sh ec2-user@"${jumpbox_ip}":/home/ec2-user/
scp -o StrictHostKeyChecking=no -i /home/ec2-user/jumpbox.pem /home/ec2-user/bin/* ec2-user@"${jumpbox_ip}":/home/ec2-user/bin/

# Execute script on the jumpbox
ssh -o StrictHostKeyChecking=no -i /home/ec2-user/jumpbox.pem ec2-user@"${jumpbox_ip}" "chmod +x /home/ec2-user/setup_jumpbox.sh && bash /home/ec2-user/setup_jumpbox.sh"
