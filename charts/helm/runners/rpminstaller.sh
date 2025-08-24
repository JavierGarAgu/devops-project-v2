#!/bin/bash

RPM_DIR="/usr/bin/rpms"

# Check if directory exists
if [[ ! -d "$RPM_DIR" ]]; then
  echo "Directory $RPM_DIR does not exist."
  exit 1
fi

echo "[+] Installing psql.rpm library first..."
PSQL_RPM="$RPM_DIR/postgresql15-private-libs-15.13-1.amzn2023.0.1.aarch64.rpm"

if [[ -f "$PSQL_RPM" ]]; then
  sudo dnf install -y "$PSQL_RPM" || {
    echo "Failed to install $PSQL_RPM"
    exit 1
  }
  echo "[✓] psql.rpm installed"
else
  echo "psql.rpm not found in $RPM_DIR."
  exit 1
fi

echo "[+] Installing remaining RPM packages from $RPM_DIR..."

for rpm in "$RPM_DIR"/*.rpm; do
  # Skip psql.rpm
  if [[ "$rpm" == "$PSQL_RPM" ]]; then
    continue
  fi

  if [[ -f "$rpm" ]]; then
    echo "Installing $rpm..."
    sudo dnf install -y "$rpm" || {
      echo "Failed to install $rpm"
      exit 1
    }
  fi
done

echo "[✓] All RPM packages installed."
