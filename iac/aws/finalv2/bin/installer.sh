#!/bin/bash

set -e

INSTALL_DIR="$HOME/install_tmp"
ARCH=$(uname -m)

# Normalize architecture label
if [[ "$ARCH" == "aarch64" ]]; then
  ARCH="arm64"
fi

mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

echo "[+] Installing AWS CLI v2..."
if ! command -v aws &> /dev/null; then
  curl -s "https://awscli.amazonaws.com/awscli-exe-linux-${ARCH}.zip" -o "awscliv2.zip"
  unzip -q awscliv2.zip
  sudo ./aws/install --install-dir /usr/local/aws-cli --bin-dir /usr/local/bin --update
  echo "[✓] AWS CLI installed"
else
  echo "[✓] AWS CLI already installed"
fi

echo "[+] Installing kubectl..."
if ! command -v kubectl &> /dev/null; then
  KUBECTL_VERSION="v1.30.1"
  ARCH="arm64"
  curl -Lo kubectl "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${ARCH}/kubectl"
  chmod +x kubectl
  sudo mv kubectl /usr/local/bin/kubectl
  echo "[✓] kubectl installed to /usr/local/bin"
else
  echo "[✓] kubectl already installed"
fi

echo "[+] Installing Docker..."
if ! command -v docker &> /dev/null; then
  sudo dnf install -y docker
  sudo systemctl enable --now docker
  echo "[✓] Docker installed and started"
else
  echo "[✓] Docker already installed"
fi

echo "[+] Installing containerd..."
if ! command -v containerd &> /dev/null; then
  sudo dnf install -y containerd
  sudo systemctl enable --now containerd
  echo "[✓] containerd installed and started"
else
  echo "[✓] containerd already installed"
fi

echo "[+] Installing Helm..."
if ! command -v helm &> /dev/null; then
  curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
  chmod 700 get_helm.sh
  ./get_helm.sh
  echo "[✓] Helm installed"
else
  echo "[✓] Helm already installed"
fi

echo "[✓] All tools installed successfully."