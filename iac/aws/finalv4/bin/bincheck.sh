#!/bin/bash

echo "====== INSTALLATION VERIFICATION ======"

check_tool() {
    local name="$1"
    local version_cmd="$2"

    echo -e "\n🔍 Checking: $name"
    BIN_PATH=$(command -v "$name" || true)

    if [[ -z "$BIN_PATH" ]]; then
        echo "  ✗ $name is NOT in PATH"
    else
        echo "  ✓ Path: $BIN_PATH"
        echo -n "  ✓ Version: "
        $version_cmd || echo "Error retrieving version"
    fi
}

check_tool "aws" "aws --version"
check_tool "kubectl" "kubectl version --client"
check_tool "docker" "docker --version"
check_tool "dockerd" "dockerd --version"
check_tool "containerd" "containerd --version"
check_tool "helm" "helm version --short"

echo -e "\nAll checks complete."