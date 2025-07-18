#!/bin/bash
set -euxo pipefail

DEST=~/offline_rpms
mkdir -p "$DEST"
cd "$DEST"

echo "[+] Checking and installing missing binaries..."

# List of binaries with their install package names (adjust package names if needed)
declare -A BINARIES_PACKAGES=(
  [aws]="awscli"
  [kubectl]="kubectl"
  [docker]="docker"
  [dockerd]="docker"          # dockerd comes with docker package
  [containerd]="containerd"
  [helm]="helm"
)

# Map binary -> actual full path after which
declare -A BINARIES_PATHS

for bin in "${!BINARIES_PACKAGES[@]}"; do
  path=$(which "$bin" || echo "")
  if [[ -z "$path" ]]; then
    echo "[!] $bin not found, installing package ${BINARIES_PACKAGES[$bin]}..."
    # Install the package; you might need sudo or root access
    yum install -y "${BINARIES_PACKAGES[$bin]}"
    # Re-run which after install
    path=$(which "$bin" || echo "")
    if [[ -z "$path" ]]; then
      echo "[!] Failed to find $bin even after install, skipping."
      continue
    fi
  fi
  BINARIES_PATHS[$bin]=$path
done

echo "[+] Packaging installed binaries..."

get_version() {
  case "$1" in
    aws) aws --version 2>&1 | awk '{print $1}' | cut -d/ -f2 ;;
    kubectl) kubectl version --client --short 2>/dev/null | awk '{print $3}' | sed 's/^v//' ;;
    docker) docker --version | awk '{print $3}' | sed 's/,//' ;;
    dockerd) dockerd --version | awk '{print $3}' | sed 's/,//' ;;
    containerd) containerd --version | awk '{print $3}' ;;
    helm) helm version --short | sed 's/^v//' | cut -d+ -f1 ;;
    *) echo "1.0" ;;
  esac
}

for name in "${!BINARIES_PATHS[@]}"; do
  bin_path="${BINARIES_PATHS[$name]}"
  if [[ -x "$bin_path" ]]; then
    version=$(get_version "$name" || echo "1.0")
    echo "[+] Packaging $name ($version) from $bin_path..."
    fpm -s dir -t rpm -n "$name" -v "$version" --prefix=/usr/bin "$bin_path"
  else
    echo "[!] $name binary not executable at $bin_path, skipping."
  fi
done

echo "[✓] All available binaries packaged as RPMs in: $DEST"