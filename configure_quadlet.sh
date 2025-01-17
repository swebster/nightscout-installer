#!/usr/bin/env bash

readonly CONFIG_ROOT="${XDG_CONFIG_HOME:-$HOME/.config}"
readonly PODLET_FILE=.task/quadlet.config
trap 'rm -f docker-compose.config.yml' EXIT

# identify the appropriate podlet schema for the local version of podman
function identify_podlet_schema() {
  local -r schema_extractor='s/podman version ([0-9]+\.[0-9]+).*/\1/; s/4\.9/4.8/'
  local -r podman_version=$(podman --version | sed -E "${schema_extractor}")
  local -r schemas=('4.4' '4.5' '4.6' '4.7' '4.8' '5.0')
  if printf '%s\n' "${schemas[@]}" | grep -Fxq "${podman_version}"; then
    podlet_schema="${podman_version}"
  fi
}

# generate intermediate compose file with interpolated variables
$(command -v podman || command -v docker) compose \
  -f docker-compose.yml -f docker-compose.networks.yml \
  config --no-normalize -o docker-compose.config.yml

# revert .services.[].ports and volumes to short syntax for compatibility with podlet
yq -Pi '.services *= (load("docker-compose.yml") |
    # just select the ports and volumes from the original file
    .services | .[] |= pick(["ports", "volumes"])
  )' docker-compose.config.yml

if command -v podman >/dev/null; then
  identify_podlet_schema
fi

# generate quadlet configuration files from the intermediate compose file
mkdir -p "${CONFIG_ROOT}/containers/systemd"
if ! podlet_output=$(podlet ${podlet_schema:+-p $podlet_schema }-u \
  compose docker-compose.config.yml); then
  exit 1
fi

# record the full paths of all of the generated container/network/pod files
printf '%s\n' "${podlet_output}" | sed -n 's/^Wrote to file: //gp' > "${PODLET_FILE}"

# correct the network configuration of all of the generated container files and
# enable auto-updates for all containers that should use the latest images
grep '\.container$' "${PODLET_FILE}" | xargs sed -i \
  -e '/^Network=/s/$/.network/g' \
  -e '/^Image=[^:]*:latest$/s/$/\nAutoUpdate=registry/'
