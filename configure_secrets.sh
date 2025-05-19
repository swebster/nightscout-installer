#!/usr/bin/env bash

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
readonly CF_API_ROOT='https://api.cloudflare.com/client/v4'
readonly ENV_SECRETS="${SCRIPT_DIR}/.env.secrets"
readonly TMP_SECRETS="${ENV_SECRETS}.tmp"
trap 'rm -f ${TMP_SECRETS}' EXIT

# https://github.com/nightscout/cgm-remote-monitor?tab=readme-ov-file#required
function config_ns_api_secret() {
  read -rp 'Enter your Nightscout API secret: ' ns_api_secret
  if [[ ${#ns_api_secret} -lt 12 ]]; then
    >&2 echo 'Error: NIGHTSCOUT_API_SECRET must be at least 12 characters long.'
    exit 1
  fi
  echo "NIGHTSCOUT_API_SECRET=${ns_api_secret}"
}

function validate_cf_token() {
  declare -a token_options
  token_options+=(-H "Authorization: Bearer $1")
  local -r validation=$(curl -s "${token_options[@]}" "${CF_API_ROOT}/user/tokens/verify")
  local -r is_valid=$(echo "${validation}" | jq '.success == true and .result.status == "active"')

  if [[ "${is_valid}" = 'true' ]]; then
    echo "${validation}" | jq -r '.messages[0].message'
  else
    echo "${validation}" | jq -r '.errors[0].message'
    exit 1
  fi
}

# https://github.com/caddy-dns/cloudflare?tab=readme-ov-file#configuration
function config_cf_api_token() {
  read -rp 'Enter your Cloudflare API token: ' cf_api_token
  validate_cf_token "${cf_api_token}"
  echo "CLOUDFLARE_API_TOKEN=${cf_api_token}"
}

function config_curl_options() {
  declare -ag curl_options
  local cf_login_email cf_api_key
  curl_options+=(-H 'Accept: application/json')
  read -rp 'Enter your Cloudflare login e-mail: ' cf_login_email
  curl_options+=(-H "X-Auth-Email: ${cf_login_email}")
  read -rp 'Enter your Cloudflare API key: ' cf_api_key
  curl_options+=(-H "X-Auth-Key: ${cf_api_key}")
}

function config_cf_account_id() {
  local -r accounts=$(curl -fsS "${curl_options[@]}" "${CF_API_ROOT}/accounts")

  if [[ $? -ne 0 || $(echo "${accounts}" | jq '.result | length') -eq 0 ]]; then
    >&2 echo 'Error: Failed to retrieve list of accounts from Cloudflare.'
    exit 1
  fi
  echo 'Retrieved the following accounts from Cloudflare:'
  echo "${accounts}" | jq -r '.result | to_entries[] | [.key, .value.id, .value.name] | @csv'

  declare -i account_index
  read -rp 'Enter the index of the correct account [0]: ' account_index
  account_index=${account_index:-0}
  cf_account_id=$(echo "${accounts}" | jq -r ".result[${account_index}].id")

  if [[ $? -ne 0 || ${#cf_account_id} -eq 0 || "${cf_account_id}" == 'null' ]]; then
    >&2 echo 'Error: Failed to identify Cloudflare account.'
    exit 1
  fi
  echo "CLOUDFLARE_ACCOUNT_ID=${cf_account_id}"
}

function config_cf_tunnel_id() {
  local -r env_local="${SCRIPT_DIR}/.env.local"
  local -r cf_tunnel_name=$(grep CLOUDFLARE_TUNNEL_NAME "${env_local}" | cut -d= -f2)
  if [[ -z "${cf_tunnel_name}" ]]; then
    >&2 echo "Error: Failed to retrieve CLOUDFLARE_TUNNEL_NAME from ${env_local}."
    exit 1
  fi

  local -r tunnel_path="accounts/${cf_account_id}/cfd_tunnel"
  local -r query_params="name=${cf_tunnel_name}&is_deleted=false"
  local -r tunnels=$(curl -fsS "${curl_options[@]}" "${CF_API_ROOT}/${tunnel_path}?${query_params}")

  if [[ $? -ne 0 || $(echo "${tunnels}" | jq '.result | length') -eq 0 ]]; then
    >&2 echo 'Error: Failed to retrieve list of tunnels from Cloudflare.'
    exit 1
  fi

  cf_tunnel_id=$(echo "${tunnels}" | jq -r '.result[0].id')

  if [[ $? -ne 0 || ${#cf_tunnel_id} -eq 0 || "${cf_tunnel_id}" == 'null' ]]; then
    >&2 echo 'Error: Failed to identify Cloudflare tunnel.'
    exit 1
  fi
  echo "CLOUDFLARE_TUNNEL_ID=${cf_tunnel_id}"
}

function config_cf_tunnel_token() {
  local -r token_path="accounts/${cf_account_id}/cfd_tunnel/${cf_tunnel_id}/token"
  local -r token=$(curl -fsS "${curl_options[@]}" "${CF_API_ROOT}/${token_path}")

  if [[ $? -ne 0 || $(echo "${token}" | jq '.result | length') -eq 0 ]]; then
    >&2 echo 'Error: Failed to retrieve tunnel token from Cloudflare.'
    exit 1
  fi

  cf_tunnel_token=$(echo "${token}" | jq -r ".result")

  if [[ $? -ne 0 || ${#cf_tunnel_token} -eq 0 || "${cf_tunnel_token}" == 'null' ]]; then
    >&2 echo 'Error: Failed to identify Cloudflare tunnel token.'
    exit 1
  fi
  echo "CLOUDFLARE_TUNNEL_TOKEN=${cf_tunnel_token}"
}

function config_cf_tunnel_cred() {
  config_curl_options
  config_cf_account_id
  config_cf_tunnel_id
  config_cf_tunnel_token

  cf_tunnel_cred=$(echo "${cf_tunnel_token}" | \
    base64 -d | \
    jq -c '{ AccountTag: .a, TunnelSecret: .s, TunnelID: .t }'
  )
  echo "CLOUDFLARE_TUNNEL_CRED=${cf_tunnel_cred}"
}

if [[ ! -f "${ENV_SECRETS}" ]]; then
  grep COMPOSE_FILE "${ENV_SECRETS}.template" > "${TMP_SECRETS}"

  config_ns_api_secret
  config_cf_api_token
  config_cf_tunnel_cred

  printf '%s=%s\n' \
    NIGHTSCOUT_API_SECRET "${ns_api_secret}" \
    CLOUDFLARE_API_TOKEN "${cf_api_token}" \
    CLOUDFLARE_TUNNEL_CRED "${cf_tunnel_cred}" \
    >> "${TMP_SECRETS}"

  mv -f "${TMP_SECRETS}" "${ENV_SECRETS}"
  chmod 0600 "${ENV_SECRETS}"
fi
