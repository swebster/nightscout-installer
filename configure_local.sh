#!/usr/bin/env bash

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
readonly ENV_LOCAL="${SCRIPT_DIR}/.env.local"

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
  config_timezone
  config_domain
  config_tunnel

  printf '%s=%s\n' \
    NIGHTSCOUT_TIMEZONE "${timezone}" \
    DOMAIN_NAME "${domain_name}" \
    CLOUDFLARE_TUNNEL_NAME "${tunnel_name}" \
    > "${ENV_LOCAL}"
fi
