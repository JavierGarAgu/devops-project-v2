#!/bin/bash

set -e

# Create systemd symlinks
ln -sf /usr/lib/systemd/system/docker.socket /etc/systemd/system/sockets.target.wants/docker.socket
ln -sf /usr/lib/systemd/system/docker.service /etc/systemd/system/multi-user.target.wants/docker.service

# Reload systemd
sudo mkdir -p /etc/docker
echo '{"userland-proxy": false}' | sudo tee /etc/docker/daemon.json
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl restart docker
systemctl daemon-reexec
systemctl daemon-reload
