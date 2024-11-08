#!/usr/bin/env bash

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
readonly ENV_SECRETS="${SCRIPT_DIR}/.env.secrets"
readonly TMP_SECRETS="${ENV_SECRETS}.tmp"
trap 'rm -f ${TMP_SECRETS}' EXIT

# https://github.com/nightscout/cgm-remote-monitor?tab=readme-ov-file#required
function config_ns_api_secret() {
  read -rp "Enter your Nightscout API secret: " ns_api_secret
  if [ ${#ns_api_secret} -lt 12 ]; then
    echo "Error: NIGHTSCOUT_API_SECRET must be at least 12 characters long."
    exit
  fi
  echo "NIGHTSCOUT_API_SECRET=${ns_api_secret}"
}

# https://github.com/caddy-dns/cloudflare?tab=readme-ov-file#configuration
function config_cf_api_token() {
  read -rp "Enter your Cloudflare API token: " cf_api_token
  echo "CLOUDFLARE_API_TOKEN=${cf_api_token}"
}
function config_cf_zone_token() {
  read -rp "Enter your Cloudflare zone token: " cf_zone_token
  echo "CLOUDFLARE_ZONE_TOKEN=${cf_zone_token}"
}

if [[ ! -f "${ENV_SECRETS}" ]]; then
  grep COMPOSE_FILE "${ENV_SECRETS}.template" > "${TMP_SECRETS}"

  config_ns_api_secret
  config_cf_api_token
  config_cf_zone_token

  printf '%s=%s\n' \
    NIGHTSCOUT_API_SECRET "${ns_api_secret}" \
    CLOUDFLARE_API_TOKEN "${cf_api_token}" \
    CLOUDFLARE_ZONE_TOKEN "${cf_zone_token}" \
    >> "${TMP_SECRETS}"

  mv -f "${TMP_SECRETS}" "${ENV_SECRETS}"
fi
