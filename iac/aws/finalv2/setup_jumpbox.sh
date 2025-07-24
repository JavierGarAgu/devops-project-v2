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
