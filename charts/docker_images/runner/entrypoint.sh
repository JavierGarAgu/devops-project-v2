#!/bin/bash

# Source logger and graceful-stop scripts
source /usr/bin/logger.sh
source /usr/bin/graceful-stop.sh

# Handle termination signal
trap graceful_stop TERM

# Start the runner initialization in the background with dumb-init
dumb-init bash <<'SCRIPT' &
source /usr/bin/logger.sh

# Run startup script
/usr/bin/startup.sh
SCRIPT

RUNNER_INIT_PID=$!
log.notice "Runner init started with pid $RUNNER_INIT_PID"

# Wait for the runner init process to finish
wait $RUNNER_INIT_PID
log.notice "Runner init exited. Exiting this process with code 0 so that the container and pod can be garbage-collected by Kubernetes."

# Ensure leftover .runner file is removed
RUNNER_DIR="/runner"
if [ -f "$RUNNER_DIR/.runner" ]; then
    echo "Removing leftover .runner file"
    rm -f "$RUNNER_DIR/.runner"
fi

# Remove trap for TERM signal
trap - TERM
