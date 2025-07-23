#!/bin/bash

TOOLS=("kubectl" "docker" "dockerd" "containerd" "helm" "aws")

echo "Looking up installed packages for specified tools..."

for tool in "${TOOLS[@]}"; do
  BIN_PATH=$(command -v "$tool" 2>/dev/null)

  if [[ -z "$BIN_PATH" ]]; then
    echo "$tool: not found in PATH"
    continue
  fi

  PKG_NAME=$(rpm -qf "$BIN_PATH" 2>/dev/null)

  if [[ "$PKG_NAME" == *"is not owned"* ]]; then
    echo "$tool not installed"
  else
    echo "$tool: binary at $BIN_PATH is owned by package $PKG_NAME UNISTALLING"
    sudo rpm -e --nodeps "$PKG_NAME"
  fi
done
