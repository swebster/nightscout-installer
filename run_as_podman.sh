#!/usr/bin/env bash

PODMAN_HOME='/home/podman'

function run_as_podman() {
  local -r podman_uid=$(id -u podman)

  sudo systemd-run \
    --scope \
    --quiet \
    --uid="$podman_uid" \
    --working-directory="$PODMAN_HOME" \
    "$@"
}
