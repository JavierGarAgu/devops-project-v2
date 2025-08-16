#!/bin/bash

exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1
set -x

echo "[+] Setting up jumpbox (offline install)"

JUMPDIR="/home/ec2-user"

# Extract binaries
tar -xzvf rpms.tar.gz -C "$JUMPDIR"

RPM_DIR="$JUMPDIR/rpms"

if [[ ! -d "$RPM_DIR" ]]; then
  echo "Directory $RPM_DIR does not exist."
  exit 1
fi

echo "Installing all RPM packages from $RPM_DIR..."

for rpm in "$RPM_DIR"/*.rpm; do
  if [[ -f "$rpm" ]]; then
    echo "Installing $rpm..."
    if ! sudo rpm -i --force --nodeps "$rpm"; then
      echo "Failed to install $rpm, continuing with the rest..."
    fi
  else
    echo "No RPM files found in $RPM_DIR."
  fi
done

echo "All RPM packages installed."

echo "[+] Jumpbox setup complete"

source /home/ec2-user/env.sh

# Get secret from AWS
secret=$(aws secretsmanager get-secret-value --secret-id "$rds_arn" --query 'SecretString' --output text)

# Extract username and password
user=$(echo "$secret" | jq -r .username)
pass=$(echo "$secret" | jq -r .password)

# Escape colon in password for .pgpass
escaped_pass=$(echo "$pass" | sed 's/:/\\:/g')

# Create .pgpass in current user's home
echo "${phostname}:5432:*:${user}:${escaped_pass}" > ~/.pgpass
chmod 600 ~/.pgpass

# Connect with psql (password will be read from .pgpass)
psql -h "$phostname" -U "$user" -d postgres -f init.sql


