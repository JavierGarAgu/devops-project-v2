#!/bin/bash
source /usr/bin/logger.sh

RUNNER_ASSETS_DIR=${RUNNER_ASSETS_DIR:-/runnertmp}
RUNNER_HOME=${RUNNER_HOME:-/runner}

export ACTIONS_RUNNER_HOOK_JOB_STARTED=/etc/arc/hooks/job-started.sh
export ACTIONS_RUNNER_HOOK_JOB_COMPLETED=/etc/arc/hooks/job-completed.sh

if [ -n "${STARTUP_DELAY_IN_SECONDS}" ]; then
  log.notice "Delaying startup by ${STARTUP_DELAY_IN_SECONDS} seconds"
  sleep "${STARTUP_DELAY_IN_SECONDS}"
fi

if [ -z "${GITHUB_URL}" ]; then
  log.debug 'Working with public GitHub'
  GITHUB_URL="https://github.com/"
else
  length=${#GITHUB_URL}
  last_char=${GITHUB_URL:length-1:1}

  [[ $last_char != "/" ]] && GITHUB_URL="$GITHUB_URL/"; :
  log.debug "GitHub endpoint URL ${GITHUB_URL}"
fi

if [ -z "${RUNNER_NAME}" ]; then
  log.error 'RUNNER_NAME must be set'
  exit 1
fi

if [ -n "${RUNNER_ORG}" ] && [ -n "${RUNNER_REPO}" ] && [ -n "${RUNNER_ENTERPRISE}" ]; then
  ATTACH="${RUNNER_ORG}/${RUNNER_REPO}"
elif [ -n "${RUNNER_ORG}" ]; then
  ATTACH="${RUNNER_ORG}"
elif [ -n "${RUNNER_REPO}" ]; then
  ATTACH="${RUNNER_REPO}"
elif [ -n "${RUNNER_ENTERPRISE}" ]; then
  ATTACH="enterprises/${RUNNER_ENTERPRISE}"
else
  log.error 'At least one of RUNNER_ORG, RUNNER_REPO, or RUNNER_ENTERPRISE must be set'
  exit 1
fi

if [ -z "${RUNNER_TOKEN}" ]; then
  log.error 'RUNNER_TOKEN must be set'
  exit 1
fi

if [ -z "${RUNNER_REPO}" ] && [ -n "${RUNNER_GROUP}" ]; then
  RUNNER_GROUPS=${RUNNER_GROUP}
fi

if [ ! -d "${RUNNER_HOME}" ]; then
  log.error "$RUNNER_HOME should be an emptyDir mount. Please fix the pod spec."
  exit 1
fi

if [[ "${UNITTEST:-}" == '' ]]; then
  sudo chown -R runner:docker "$RUNNER_HOME"
  shopt -s dotglob
  cp -r "$RUNNER_ASSETS_DIR"/* "$RUNNER_HOME"/
  shopt -u dotglob
fi

if ! cd "${RUNNER_HOME}"; then
  log.error "Failed to cd into ${RUNNER_HOME}"
  exit 1
fi

config_args=()
if [ "${RUNNER_FEATURE_FLAG_ONCE:-}" != "true" ] && [ "${RUNNER_EPHEMERAL}" == "true" ]; then
  config_args+=(--ephemeral)
  log.debug 'Passing --ephemeral to config.sh to enable ephemeral runner.'
fi
if [ "${DISABLE_RUNNER_UPDATE:-}" == "true" ]; then
  config_args+=(--disableupdate)
  log.debug 'Passing --disableupdate to config.sh to disable automatic runner updates.'
fi

update-status "Registering"

retries_left=10
while [[ ${retries_left} -gt 0 ]]; do
  log.debug 'Configuring the runner.'
  ./config.sh --unattended --replace \
    --name "${RUNNER_NAME}" \
    --url "${GITHUB_URL}${ATTACH}" \
    --token "${RUNNER_TOKEN}" \
    --runnergroup "${RUNNER_GROUPS}" \
    --labels "${RUNNER_LABELS}" \
    --work "${RUNNER_WORKDIR}" "${config_args[@]}"

  if [ -f .runner ]; then
    log.debug 'Runner successfully configured.'
    break
  fi

  log.debug 'Configuration failed. Retrying'
  retries_left=$((retries_left - 1))
  sleep 1
done

if [ ! -f .runner ]; then
  log.error 'Configuration failed!'
  exit 2
fi

cat .runner

if [ -z "${UNITTEST:-}" ] && [ -e ./externalstmp ]; then
  mkdir -p ./externals
  mv ./externalstmp/* ./externals/
fi

WAIT_FOR_DOCKER_SECONDS=${WAIT_FOR_DOCKER_SECONDS:-120}
if [[ "${DISABLE_WAIT_FOR_DOCKER}" != "true" ]] && [[ "${DOCKER_ENABLED}" == "true" ]]; then
  log.debug 'Docker enabled runner detected and Docker daemon wait is enabled'
  log.debug "Waiting until Docker is available or timeout of ${WAIT_FOR_DOCKER_SECONDS} seconds"
  if ! timeout "${WAIT_FOR_DOCKER_SECONDS}s" bash -c 'until docker ps ; do sleep 1; done'; then
    log.notice "Docker did not become available in ${WAIT_FOR_DOCKER_SECONDS}s. Exiting."
    exit 1
  fi
else
  log.notice 'Docker wait check skipped. Either Docker is disabled or wait is disabled.'
fi

unset RUNNER_NAME RUNNER_REPO RUNNER_TOKEN STARTUP_DELAY_IN_SECONDS DISABLE_WAIT_FOR_DOCKER

if [ -z "${UNITTEST:-}" ]; then
  mapfile -t env </etc/environment || true
fi

log.notice "WARNING: LATEST TAG HAS BEEN DEPRECATED. SEE GITHUB ISSUE FOR DETAILS:"
log.notice "https://github.com/actions/actions-runner-controller/issues/2056"

update-status "Idle"
exec env -- "${env[@]}" ./run.sh
