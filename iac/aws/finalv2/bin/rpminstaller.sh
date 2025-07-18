#!/bin/bash
set -euxo pipefail

RPM_DIR=~/offline_rpms

# Map binary names to their paths for removal
declare -A BINARIES=(
  [aws]=/usr/bin/aws
  [kubectl]=/usr/local/bin/kubectl
  [docker]=/usr/bin/docker
  [dockerd]=/usr/bin/dockerd
  [containerd]=/usr/bin/containerd
  [helm]=/usr/local/bin/helm
)

echo "[+] Removing old binaries..."

for bin_path in "${BINARIES[@]}"; do
  if [[ -f "$bin_path" ]]; then
    echo "Removing $bin_path"
    sudo rm -f "$bin_path"
  else
    echo "$bin_path not found, skipping removal."
  fi
done

echo "[+] Installing RPMs..."

# Find all RPM files in RPM_DIR and install them one by one using a while loop
find "$RPM_DIR" -maxdepth 1 -type f -name '*.rpm' | while read -r rpm_file; do
  echo "Installing $rpm_file"
  sudo rpm -Uvh --replacepkgs "$rpm_file"
done

echo "[✓] RPM installation completed."