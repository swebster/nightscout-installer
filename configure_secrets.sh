#!/usr/bin/env bash

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
readonly ENV_SECRETS="${SCRIPT_DIR}/.env.secrets"
readonly TMP_SECRETS="${ENV_SECRETS}.tmp"
trap 'rm -f ${TMP_SECRETS}' EXIT

# https://github.com/nightscout/cgm-remote-monitor?tab=readme-ov-file#required
function config_ns_api_secret() {
  read -rp "Enter your Nightscout API secret: " ns_api_secret
  if [[ ${#ns_api_secret} -lt 12 ]]; then
    >&2 echo "Error: NIGHTSCOUT_API_SECRET must be at least 12 characters long."
    exit 1
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

# shellcheck disable=SC2181
function config_cf_account_id() {
  local -r cf_api_root='https://api.cloudflare.com/client/v4'

  declare -a options
  options+=(-H 'Accept: application/json')
  read -rp "Enter your Cloudflare login e-mail: " cf_login_email
  options+=(-H "X-Auth-Email: ${cf_login_email}")
  read -rp "Enter your Cloudflare API key: " cf_api_key
  options+=(-H "X-Auth-Key: ${cf_api_key}")
  local -r accounts=$(curl -fsS "${options[@]}" "${cf_api_root}/accounts")

  if [[ $? -ne 0 || $(echo "${accounts}" | jq '.result | length') -eq 0 ]]; then
    >&2 echo "Error: Failed to retrieve list of accounts from Cloudflare."
    exit 1
  fi
  echo 'Retrieved the following accounts from Cloudflare:'
  echo "${accounts}" | jq -r '.result | to_entries[] | [.key, .value.id, .value.name] | @csv'

  local account_index
  read -rp "Enter the index of the correct account [0]: " account_index
  account_index=${account_index:-0}
  cf_account_id=$(echo "${accounts}" | jq -r ".result[${account_index}].id")

  if [[ $? -ne 0 || ${#cf_account_id} -eq 0 || "${cf_account_id}" == 'null' ]]; then
    >&2 echo "Error: Failed to identify Cloudflare account."
    exit 1
  fi
  echo "CLOUDFLARE_ACCOUNT_ID=${cf_account_id}"
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
