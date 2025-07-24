#!/bin/bash

exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1
set -x

jumpbox_ip="__JUMPBOX_IP__"
private_key="__PRIVATE_KEY__"

echo "Using jumpbox IP: ${jumpbox_ip}" >> /home/ec2-user/debug.txt

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

while [ ! -f /home/ec2-user/rpms.tar.gz ]; do
  echo "Waiting for rpms.tar.gz to be available..."
  sleep 1
done

# Transfer files
scp -o StrictHostKeyChecking=no -i /home/ec2-user/jumpbox.pem /home/ec2-user/setup_jumpbox.sh ec2-user@"${jumpbox_ip}":/home/ec2-user/
scp -o StrictHostKeyChecking=no -i /home/ec2-user/jumpbox.pem /home/ec2-user/rpms.tar.gz ec2-user@"${jumpbox_ip}":/home/ec2-user/

# Wait until rpms.tar.gz is fully present on remote system
echo "Waiting for rpms.tar.gz to appear on remote host..."
while true; do
  local_size=$(ls -l /home/ec2-user/rpms.tar.gz | awk '{print $5}')
  remote_size=$(ssh -o StrictHostKeyChecking=no -i /home/ec2-user/jumpbox.pem ec2-user@"${jumpbox_ip}" "ls -l /home/ec2-user/rpms.tar.gz 2>/dev/null | awk '{print \$5}'")
  if [[ "$remote_size" == "$local_size" && -n "$remote_size" ]]; then
    break
  fi
  sleep 1
done

# Execute remote setup
ssh -o StrictHostKeyChecking=no -i /home/ec2-user/jumpbox.pem ec2-user@"${jumpbox_ip}" "chmod +x /home/ec2-user/setup_jumpbox.sh && sudo bash /home/ec2-user/setup_jumpbox.sh"
