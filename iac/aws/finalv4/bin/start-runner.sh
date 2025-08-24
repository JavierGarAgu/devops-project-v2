#!/bin/bash
set -e

# Configure the runner
./config.sh --unattended \
            --url "https://github.com/JavierGarAgu/devops-project-v2" \
            --token "${RUNNER_TOKEN}" \
            --work /runner/_work \
            --labels "custom-runner" \
            --ephemeral

# Run the runner in the foreground
exec ./run.sh
