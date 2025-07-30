#!/bin/bash

set -e

VERSION="2.25.0"
PKG_NAME="awscli"
PYTHON_VER="3.9"

HOME_BASE="$HOME/awscli-rpm"
BUILD_DIR="$HOME_BASE/build"
RPM_DIR="$HOME_BASE/rpms"
TMP_DIR="$HOME_BASE/tmp"

# Clean previous build
rm -rf "$BUILD_DIR" "$TMP_DIR"
mkdir -p "$BUILD_DIR"
mkdir -p "$TMP_DIR"
mkdir -p "$RPM_DIR"

# Export TMPDIR to avoid using small /tmp
export TMPDIR="$TMP_DIR"

# Create destination directories inside BUILD_DIR
mkdir -p "$BUILD_DIR/usr/bin"
mkdir -p "$BUILD_DIR/usr/lib/python${PYTHON_VER}/site-packages"
mkdir -p "$BUILD_DIR/usr/share/bash-completion/completions"
mkdir -p "$BUILD_DIR/usr/share/doc/${PKG_NAME}-2"
mkdir -p "$BUILD_DIR/usr/share/zsh/site-functions"

# Copy binaries and supporting files
cp /usr/bin/aws "$BUILD_DIR/usr/bin/"
cp /usr/bin/aws_completer "$BUILD_DIR/usr/bin/"

cp -r /usr/lib/python${PYTHON_VER}/site-packages/awscli "$BUILD_DIR/usr/lib/python${PYTHON_VER}/site-packages/"
cp -r /usr/lib/python${PYTHON_VER}/site-packages/awscli-${VERSION}.dist-info "$BUILD_DIR/usr/lib/python${PYTHON_VER}/site-packages/"

cp /usr/share/bash-completion/completions/aws "$BUILD_DIR/usr/share/bash-completion/completions/"
cp -r /usr/share/doc/awscli-2 "$BUILD_DIR/usr/share/doc/"
cp /usr/share/zsh/site-functions/_awscli "$BUILD_DIR/usr/share/zsh/site-functions/"

# Build RPM using fpm with runtime dependencies
fpm -s dir -t rpm \
  -n "$PKG_NAME" \
  -v "$VERSION" \
  -C "$BUILD_DIR" \
  --prefix / \
  --package "$RPM_DIR/${PKG_NAME}-${VERSION}.rpm" \
  --depends "python${PYTHON_VER}" \
  --depends "python${PYTHON_VER}-botocore" \
  --depends "python${PYTHON_VER}-s3transfer" \
  --depends "python${PYTHON_VER}-dateutil" \
  --depends "python${PYTHON_VER}-urllib3" \
  --depends "python${PYTHON_VER}-pyyaml" \
  --depends "python${PYTHON_VER}-rsa" \
  --depends "python${PYTHON_VER}-colorama"

echo -e "\n✅ RPM built at: $RPM_DIR/${PKG_NAME}-${VERSION}.rpm"
