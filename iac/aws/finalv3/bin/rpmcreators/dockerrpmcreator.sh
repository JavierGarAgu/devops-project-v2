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
CONFIG_DIR="$BUILD_DIR/config"
RPM_OUT_DIR="$BUILD_DIR/output"
POSTINSTALL="$BUILD_DIR/docker-postinstall.sh"
TMPDIR="$BUILD_DIR/tmp"
RPMBUILD_TOPDIR="$BUILD_DIR/rpmbuild"

# ===============================
# 📁 CREATE FOLDERS
# ===============================
mkdir -p "$BIN_DIR" "$SYSTEMD_DIR" "$CONFIG_DIR" "$RPM_OUT_DIR" "$TMPDIR" "$RPMBUILD_TOPDIR"

# Set TMPDIR to avoid /tmp usage by fpm
export TMPDIR

# ===============================
# 📦 COPY BINARIES
# ===============================
cp "$(command -v docker)" "$BIN_DIR/docker"
cp "$(command -v dockerd)" "$BIN_DIR/dockerd"

# Detect and copy docker-init (tini)
if command -v docker-init &>/dev/null; then
  cp "$(command -v docker-init)" "$BIN_DIR/docker-init"
else
  echo "❌ ERROR: docker-init not found. You must provide this binary or build it."
  exit 1
fi

# Copy containerd binaries
cp /usr/bin/containerd "$BIN_DIR/containerd"
cp /usr/bin/containerd-shim-runc-v2 "$BIN_DIR/containerd-shim-runc-v2"
cp /usr/bin/ctr "$BIN_DIR/ctr"

# Copy runc binary
cp /usr/sbin/runc "$BIN_DIR/runc"

# ===============================
# 🔧 COPY AND PATCH SYSTEMD FILES
# ===============================
cp /usr/lib/systemd/system/docker.service "$SYSTEMD_DIR/docker.service"
cp /usr/lib/systemd/system/docker.socket "$SYSTEMD_DIR/docker.socket"
cp /usr/lib/systemd/system/containerd.service "$SYSTEMD_DIR/containerd.service"

# Remove broken ExecStartPre from docker.service
sed -i '/docker-setup-runtimes.sh/d' "$SYSTEMD_DIR/docker.service"

# ===============================
# 📄 COPY CONFIG FILES
# ===============================
mkdir -p "$CONFIG_DIR/etc/docker"
mkdir -p "$CONFIG_DIR/etc/containerd"

# Docker daemon config
echo '{"userland-proxy": false}' > "$CONFIG_DIR/etc/docker/daemon.json"

# Copy containerd config file if exists
if [ -f /etc/containerd/config.toml ]; then
  cp /etc/containerd/config.toml "$CONFIG_DIR/etc/containerd/config.toml"
fi

# ===============================
# 🧩 POST-INSTALL SCRIPT
# ===============================
cat << 'EOF' > "$POSTINSTALL"
#!/bin/bash
set -e

echo "🔧 Setting up Docker and dependencies..."

# Make sure config dirs exist (they should be created by RPM install of the config file)
mkdir -p /etc/docker
mkdir -p /etc/containerd

# DO NOT copy daemon.json here from build dir — it is installed by the RPM

# Create systemd symlinks
ln -sf /usr/lib/systemd/system/docker.socket /etc/systemd/system/sockets.target.wants/docker.socket
ln -sf /usr/lib/systemd/system/docker.service /etc/systemd/system/multi-user.target.wants/docker.service
ln -sf /usr/lib/systemd/system/containerd.service /etc/systemd/system/multi-user.target.wants/containerd.service

# Reload systemd daemon and enable services
systemctl daemon-reexec || true
systemctl daemon-reload || true
systemctl enable containerd.service || true
systemctl enable docker.service || true
systemctl enable docker.socket || true

# Restart services
systemctl restart containerd || true
systemctl restart docker || true
EOF

chmod +x "$POSTINSTALL"

# ===============================
# 🚀 BUILD RPM WITH FPM
# ===============================
fpm -s dir -t rpm \
  -n "$NAME" \
  -v "$VER" \
  -a "$ARCH" \
  --description "Docker Engine $VER packaged as RPM with containerd and runc dependencies" \
  --after-install "$POSTINSTALL" \
  --depends iptables \
  --depends iproute \
  --depends libseccomp \
  --rpm-rpmbuild-define "_topdir $RPMBUILD_TOPDIR" \
  --rpm-rpmbuild-define "_tmppath $TMPDIR" \
  --package "$RPM_OUT_DIR/${NAME}-${VER}.${ARCH}.rpm" \
  "$BIN_DIR/docker=/usr/bin/docker" \
  "$BIN_DIR/dockerd=/usr/bin/dockerd" \
  "$BIN_DIR/docker-init=/usr/bin/docker-init" \
  "$BIN_DIR/containerd=/usr/bin/containerd" \
  "$BIN_DIR/containerd-shim-runc-v2=/usr/bin/containerd-shim-runc-v2" \
  "$BIN_DIR/ctr=/usr/bin/ctr" \
  "$BIN_DIR/runc=/usr/sbin/runc" \
  "$SYSTEMD_DIR/docker.service=/usr/lib/systemd/system/docker.service" \
  "$SYSTEMD_DIR/docker.socket=/usr/lib/systemd/system/docker.socket" \
  "$SYSTEMD_DIR/containerd.service=/usr/lib/systemd/system/containerd.service" \
  "$CONFIG_DIR/etc/docker/daemon.json=/etc/docker/daemon.json" \
  "$CONFIG_DIR/etc/containerd/config.toml=/etc/containerd/config.toml"

# ===============================
# ✅ DONE
# ===============================
echo -e "\n✅ RPM built: $RPM_OUT_DIR/${NAME}-${VER}.${ARCH}.rpm"
