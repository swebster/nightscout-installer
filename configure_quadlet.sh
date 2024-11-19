#!/usr/bin/env bash

readonly CONFIG_ROOT="${XDG_CONFIG_HOME:-$HOME/.config}"
readonly PODLET_FILE=.task/quadlet.config
trap 'rm -f docker-compose.config.yml' EXIT

# generate intermediate compose file with interpolated variables
$(which podman || which docker) compose \
  -f docker-compose.yml -f docker-compose.networks.yml \
  config --no-normalize -o docker-compose.config.yml

# revert .services.[].ports and volumes to short syntax for compatibility with podlet
yq -Pi '.services *= (load("docker-compose.yml") |
    # just select the ports and volumes from the original file
    .services | .[] |= pick(["ports", "volumes"])
  )' docker-compose.config.yml

# generate the appropriate podlet flags for the local version of podman
podman_version=$(which podman >/dev/null && podman --version || echo 'podman version 4.9.3')
major_minor=$(sed -n 's/podman version //p' <<< "${podman_version}" | cut -d. -f -2)
podlet_schema="${major_minor/4.9/4.8}"
pod_flag=$(test "${major_minor%%.*}" -ge 5 && echo --pod)

# generate quadlet configuration files from the intermediate compose file
mkdir -p "${CONFIG_ROOT}/containers/systemd"
if ! podlet_output=$(podlet -p "${podlet_schema}" -u -i --skip-services-check \
  compose ${pod_flag:+"$pod_flag"} docker-compose.config.yml); then
  exit 1
fi

# record the full paths of all of the generated container/network/pod files
printf '%s\n' "${podlet_output}" | sed -n 's/^Wrote to file: //gp' > "${PODLET_FILE}"

# correct the network configuration of all of the generated container files
grep '\.container$' "${PODLET_FILE}" | xargs sed -i '/^Network=/s/$/.network/g'
