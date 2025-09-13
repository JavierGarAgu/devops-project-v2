#!/usr/bin/env bash

set -Eeuo pipefail

# Default Docker binary location for Amazon Linux 2023 setup
DOCKER=/usr/bin/docker
if [ ! -x "$DOCKER" ]; then
    # Fallback to runner-local bin if installed there
    DOCKER=/home/runner/bin/docker
fi

# Preserve MTU from host Docker network if ARC_DOCKER_MTU_PROPAGATION is enabled
if [[ "${ARC_DOCKER_MTU_PROPAGATION:-false}" == true ]] &&
   (($# >= 2)) && [[ $1 == network && $2 == create ]]; then

    # Detect MTU from default bridge network
    mtu=$("$DOCKER" network inspect bridge --format '{{index .Options "com.docker.network.driver.mtu"}}' 2>/dev/null || echo "")
    shift 2

    # Prepend MTU option if detected
    if [[ -n "$mtu" ]]; then
        set -- network create --opt com.docker.network.driver.mtu="$mtu" "$@"
    fi
fi

# Execute the real docker command
exec "$DOCKER" "$@"
