#!/usr/bin/env bash

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
readonly ENV_LOCAL="${SCRIPT_DIR}/.env.local"
readonly TMP_LOCAL="${ENV_LOCAL}.tmp"
trap 'rm -f ${TMP_LOCAL}' EXIT

function config_docker_host() {
  local -r container_runtime=$(basename "$(command -v podman || command -v docker)")
  if [[ "${container_runtime}" = "podman" ]]; then
    local -r runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
    docker_host="unix://${runtime_dir%/}/podman/podman.sock"
  fi
}

function config_timezone() {
  local -r default_timezone=$(date +%Z)
  read -rp "Enter your local timezone [${default_timezone}]: " timezone
  timezone=${timezone:-$default_timezone}
  echo "NIGHTSCOUT_TIMEZONE=${timezone}"
}

function config_domain() {
  read -rp "Enter your domain name: " domain_name
  echo "DOMAIN_NAME=${domain_name}"
}

function config_tunnel() {
  local -r default_tunnel=$(echo "${domain_name}" | cut -d. -f1)
  read -rp "Enter your tunnel name [${default_tunnel}]: " tunnel_name
  tunnel_name=${tunnel_name:-$default_tunnel}
  echo "CLOUDFLARE_TUNNEL_NAME=${tunnel_name}"
}

if [[ ! -f "${ENV_LOCAL}" ]]; then
  config_docker_host
  config_timezone
  config_domain
  config_tunnel

  if [[ -n "${docker_host}" ]]; then
    printf '%s=%s\n' DOCKER_HOST "${docker_host}" > "${TMP_LOCAL}"
  else
    rm -f "${TMP_LOCAL}"
  fi

  printf '%s=%s\n' \
    NIGHTSCOUT_TIMEZONE "${timezone}" \
    DOMAIN_NAME "${domain_name}" \
    CLOUDFLARE_TUNNEL_NAME "${tunnel_name}" \
    >> "${TMP_LOCAL}"

  mv -f "${TMP_LOCAL}" "${ENV_LOCAL}"
fi
