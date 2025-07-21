#!/bin/bash

set -e

RPM_DIR="$HOME/rpms"
mkdir -p "$RPM_DIR"

echo "====== INSTALLATION VERIFICATION ======"

TOOLS=("kubectl" "docker" "dockerd" "containerd" "helm")

declare -A VERSION_CMDS
VERSION_CMDS[kubectl]="kubectl version --client"
VERSION_CMDS[docker]="docker --version"
VERSION_CMDS[dockerd]="dockerd --version"
VERSION_CMDS[containerd]="containerd --version"
VERSION_CMDS[helm]="helm version --short"

declare -A BIN_PATHS
declare -A VERSIONS

for tool in "${TOOLS[@]}"; do
  echo -e "\n🔍 Checking: $tool"

  BIN_PATH=$(command -v "$tool" || true)

  if [[ -z "$BIN_PATH" ]]; then
    echo "  ✗ $tool is NOT in PATH"
    continue
  fi

  echo "  ✓ Path: $BIN_PATH"
  VERSION_RAW=$(${VERSION_CMDS[$tool]} 2>/dev/null || echo "Error")
  echo "  ✓ Version: $VERSION_RAW"

  VERSION=""
  case $tool in
    kubectl)
      VERSION=$(echo "$VERSION_RAW" | grep -oP 'Client Version: v\K[0-9.]+' || true)
      ;;
    docker|dockerd)
      VERSION=$(echo "$VERSION_RAW" | grep -oP 'version \K[0-9.]+' | head -1)
      ;;
    containerd)
      VERSION=$(echo "$VERSION_RAW" | grep -oP '\b[0-9]+\.[0-9]+\.[0-9]+\b' | head -1)
      ;;
    helm)
      VERSION=$(echo "$VERSION_RAW" | grep -oP '^v\K[0-9.]+' | head -1)
      ;;
  esac

  if [[ -z "$VERSION" ]]; then
    echo "  ✗ Failed to extract version for $tool"
    continue
  fi

  BIN_PATHS["$tool"]="$BIN_PATH"
  VERSIONS["$tool"]="$VERSION"
done

echo -e "\n====== RPM PACKAGING FOR INSTALLED BINARIES ======"

for tool in "${!BIN_PATHS[@]}"; do
  BIN="${BIN_PATHS[$tool]}"
  VER="${VERSIONS[$tool]}"
  PKG_NAME="$RPM_DIR/${tool}-${VER}.rpm"

  echo -e "\n🔍 Processing $tool..."
  echo "  ✓ Version: $VER"
  echo "  ➤ Building RPM: $PKG_NAME"

  fpm -s dir -t rpm \
    -n "$tool" \
    -v "$VER" \
    --package "$PKG_NAME" \
    "$BIN"="/usr/bin/$tool"
done

echo -e "\n✅ RPM build complete."
