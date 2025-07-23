#!/bin/bash
set -e

# ===============================
# 🛠️ CONFIGURATION
# ===============================
VER="25.0.8"
NAME="docker"
ARCH="$(uname -m)"
BUILD_DIR="$HOME/docker-rpm-build"
BIN_DIR="$BUILD_DIR/bin"
SYSTEMD_DIR="$BUILD_DIR/systemd"
RPM_OUT_DIR="$BUILD_DIR/output"
POSTINSTALL="$BUILD_DIR/docker-postinstall.sh"
TMPDIR="$BUILD_DIR/tmp"
RPMBUILD_TOPDIR="$BUILD_DIR/rpmbuild"

# ===============================
# 📁 CREATE FOLDERS
# ===============================
mkdir -p "$BIN_DIR" "$SYSTEMD_DIR" "$RPM_OUT_DIR" "$TMPDIR" "$RPMBUILD_TOPDIR"

# Set TMPDIR to avoid /tmp usage by fpm
export TMPDIR

# ===============================
# 📦 COPY BINARIES
# ===============================
cp "$(command -v docker)" "$BIN_DIR/docker"
cp "$(command -v dockerd)" "$BIN_DIR/dockerd"

# ===============================
# 🔧 COPY SYSTEMD FILES
# ===============================
cp /usr/lib/systemd/system/docker.service "$SYSTEMD_DIR/docker.service"
cp /usr/lib/systemd/system/docker.socket "$SYSTEMD_DIR/docker.socket"

# ===============================
# 🧩 POST-INSTALL SCRIPT (if needed)
# ===============================
cat << 'EOF' > "$POSTINSTALL"
#!/bin/bash
set -e
echo "🔧 Enabling Docker service..."
systemctl daemon-reexec || true
systemctl enable docker.service || true
systemctl enable docker.socket || true
EOF
chmod +x "$POSTINSTALL"

# ===============================
# 🚀 BUILD RPM WITH FPM
# ===============================
fpm -s dir -t rpm \
  -n "$NAME" \
  -v "$VER" \
  -a "$ARCH" \
  --description "Docker Engine $VER packaged as RPM" \
  --after-install "$POSTINSTALL" \
  --rpm-rpmbuild-define "_topdir $RPMBUILD_TOPDIR" \
  --rpm-rpmbuild-define "_tmppath $TMPDIR" \
  --package "$RPM_OUT_DIR/${NAME}-${VER}.${ARCH}.rpm" \
  "$BIN_DIR/docker=/usr/bin/docker" \
  "$BIN_DIR/dockerd=/usr/bin/dockerd" \
  "$SYSTEMD_DIR/docker.service=/usr/lib/systemd/system/docker.service" \
  "$SYSTEMD_DIR/docker.socket=/usr/lib/systemd/system/docker.socket"

# ===============================
# ✅ DONE
# ===============================
echo -e "\n✅ RPM built: $RPM_OUT_DIR/${NAME}-${VER}.${ARCH}.rpm"
