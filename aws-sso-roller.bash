#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail
IFS=$'\n\t'

info () { test ! -t 0 && >&2 sed "s/^/:: ${1:-}/g" || >&2 echo -e ":: $@"; }
pass () { >&2 echo -e ":✔ $@"; }
fail () { >&2 echo -e ":✖ $@"; }

ROLLER_CONFIG="${HOME}/.aws_sso_roller"
ROLLER_CLIENT="${ROLLER_CONFIG}/client.json"
ROLLER_AUTH="${ROLLER_CONFIG}/auth.json"
ROLLER_TOKEN="${ROLLER_CONFIG}/token.json"

CACHE=''
if [[ $# -eq 1 && "${1}" == '--cache' ]]; then
  info '--cache detected: persisting and using existing auth'
  CACHE='on'
fi

remove_credentials() {
  # remove unless in debug mode
  if [[ "${CACHE}" != "on" ]]; then
    rm -f "${ROLLER_AUTH}"
    rm -f "${ROLLER_TOKEN}"
  fi
}

cleanup() {
  # currently runs twice with ctrl-c
  remove_credentials

  # shellcheck disable=SC2154
  info ''
  if [[ -n "${1:-}" ]]; then
    fail "Aborted by ${1:-}"
  elif [[ "${__status}" -eq 254 ]]; then
    fail 'The following error occurs if you did not authenticate using the provided URL'
    fail '- An error occurred (AuthorizationPendingException) when calling the CreateToken operation'
    # if case of auth failure, the cache files are always removed
    CACHE="off" remove_credentials
  elif [[ "${__status}" -ne 0 ]]; then
    fail "Failure (status ${__status})"
  fi
}
export -f cleanup

trap '__status=$?; cleanup; exit $__status' EXIT
trap 'trap - HUP; cleanup SIGHUP; kill -HUP $$' HUP
trap 'trap - INT; cleanup SIGINT; kill -INT $$' INT
trap 'trap - TERM; cleanup SIGTERM; kill -TERM $$' TERM

if [[ "$(id -u)" -eq "0" ]]; then
  fail ":: please DO NOT run as root"
  exit 1
fi

# Use 'date' to work on a passed in epoch datetime.
# Supports function parameter or stdin.
# Picks the proper date function depending on MacOS or Linux.
# eg.
#   echo $(epoch 1656207017 +%s)
#   echo 1656207017 | epoch - +"%Y-%m-%dT%H:%M:%S%z"
epoch() {
  local SECONDS
  if [[ "$1" == '-' ]]; then
    SECONDS="$(</dev/stdin cat)"
  else
    SECONDS="$1"
  fi
  shift
  date -r"${SECONDS}" "$@" 2> /dev/null \
    || date --date="@${SECONDS}" "$@" 2> /dev/null \
    || echo 'INVALID_DATE'
}
# prompt <NAME> [DEFAULT_VALUE]
# eg.
#   # a prompt for TEST will appear until a value is provided
#   prompt "TEST"
#   # a prompt for TEST with a default of "Hello" will appear
#   prompt "TEST" "Hello"
#   # Since TEST already contains a value, no prompt appears
#   TEST="Boo"
#   prompt "TEST" "Hello"
prompt() {
  local KEY VALUE DEFAULT
  KEY="$1"
  DEFAULT="${2:-}"
  while [[ -z "${!KEY:-}" ]]; do
    read -p "${KEY} [${DEFAULT}]: " VALUE
    VALUE="${VALUE:-${DEFAULT}}"
    declare -g "${KEY}"="${VALUE}"
  done
}


_process_accounts() {
  local ACCOUNT_ID ACCOUNT_NAME PROFILE ROLES INDEX ACCOUNTS ACCESS_TOKEN
  ACCESS_TOKEN="${1}"
  ACCOUNTS="${2}"
  INDEX=0
  while read -r ACCOUNT_ID ACCOUNT_NAME ; do
    ACCOUNT_NAME="${ACCOUNT_NAME,,}"
    ACCOUNT_NAME="${ACCOUNT_NAME//[^a-z0-9\ _-]/}"
    ACCOUNT_NAME="${ACCOUNT_NAME//[\ _]/-}"
    >&2 echo ":: Setting up roles for ${ACCOUNT_NAME}"

    ROLES="$(aws sso list-account-roles \
      --account-id "${ACCOUNT_ID}" \
      --access-token "${ACCESS_TOKEN}" \
      --profile aws_sso_roller \
      --region "${SSO_REGION}" \
      --no-sign-request \
      --output json \
      | jq -rM '.roleList[] | [.roleName] | @tsv' \
      )"
    while read -r ROLE ; do
      >&2 echo "::   $ROLE"
      PROFILE="${NAMESPACE}-${ACCOUNT_NAME}-${ROLE}"
      aws configure --profile "${PROFILE}" set sso_start_url "${SSO_START_URL}"
      aws configure --profile "${PROFILE}" set sso_region "${SSO_REGION}"
      aws configure --profile "${PROFILE}" set sso_role_name "${ROLE}"
      aws configure --profile "${PROFILE}" set sso_account_id "${ACCOUNT_ID}"
      # update the settings from the custom .ini
      while IFS=$'=' read -r KEY VALUE ; do
        [[ -z "${KEY}" ]] && continue
        aws configure --profile "${PROFILE}" set "${KEY}" "${VALUE}"
      done <<< "${CUSTOM_DATA:-}"
    done <<< "${ROLES}"

    #let INDEX=$INDEX+1
    #[[ $INDEX -ge 2 ]] && break
  done <<< "${ACCOUNTS}"
}

mkdir -p "${ROLLER_CONFIG}"
remove_credentials

# If these weren't provided via environment variables, collect them now
prompt "SSO_START_URL"
prompt "SSO_REGION" "us-east-1"
prompt "NAMESPACE"

# since we are passing URLs as parameters, force CLI not to resolve them
aws --profile aws_sso_roller configure set 'cli_follow_urlparam' 'false'

CUSTOM_INI="${ROLLER_CONFIG}/${NAMESPACE}.ini"
if [[ -f "${CUSTOM_INI}" ]]; then
  info ''
  info "The following additional settings from '${CUSTOM_INI}' will be added:"
  CUSTOM_DATA="$(< "${CUSTOM_INI}")"
  echo "${CUSTOM_DATA}" | info '  '
  info ''
  >&2 read -p ":: Press [Enter] to continue, or CTRL-C if you want to abort."
fi

ROLLER_CLIENT="${ROLLER_CONFIG}/client_${SSO_REGION}.json"
if [[ -f "${ROLLER_CLIENT}" ]]; then
  CLIENT_EXPIRATION="$(<"${ROLLER_CLIENT}" jq -r .clientSecretExpiresAt)"
  NOW="$(date +'%s')"
  if [[ "${NOW}" -gt "${CLIENT_EXPIRATION}" ]]; then
    info 'client secret expired, generating new secret'
    rm -f "${ROLLER_CLIENT}"
  else
    DURATION="$(( (${CLIENT_EXPIRATION}-${NOW})/86400 ))"
    info "client secret still valid for ${DURATION} days."
  fi
fi
if [[ ! -f "${ROLLER_CLIENT}" ]]; then
  aws sso-oidc register-client \
    --client-name aws-sso-roller \
    --client-type public\
    --profile aws_sso_roller \
    --region "${SSO_REGION}" \
    --no-sign-request \
    --output json \
    > "${ROLLER_CLIENT}"
fi
>&2 echo -n ":: client secret expires: "
<"${ROLLER_CLIENT}" jq -r .clientSecretExpiresAt | >&2 epoch - +"%Y-%m-%dT%H:%M:%S%z"
CLIENT_ID="$(<${ROLLER_CLIENT} jq -r .clientId)"
CLIENT_SECRET="$(<${ROLLER_CLIENT} jq -r .clientSecret)"

if [[ ! -f "${ROLLER_AUTH}" ]]; then
  aws sso-oidc start-device-authorization \
    --client-id "${CLIENT_ID}" \
    --client-secret "${CLIENT_SECRET}" \
    --start-url "${SSO_START_URL}" \
    --profile aws_sso_roller \
    --region "${SSO_REGION}" \
    --no-sign-request \
    --output json \
    > "${ROLLER_AUTH}"
  VERIFY_URL="$(<${ROLLER_AUTH} jq -r .verificationUriComplete)"
  info 'Please log in via SSO in your browser using the following URL:'
  info "- ${VERIFY_URL}"
  info ''
  >&2 read -p ":: Press [Enter] after you have logged in"
fi
DEVICE_CODE="$(<${ROLLER_AUTH} jq -r .deviceCode)"

if [[ -f "${ROLLER_TOKEN}" ]]; then
  let TOKEN_AGE="$(date +%s) - $(date -r "${ROLLER_TOKEN}" +%s)"
  TOKEN_EXPIRATION="$(<"${ROLLER_TOKEN}" jq -r .expiresIn)"
  if [[ "${TOKEN_AGE}" -gt "${TOKEN_EXPIRATION}" ]]; then
    info "token expired"
  fi
fi

if [[ ! -f "${ROLLER_TOKEN}" ]]; then
  aws sso-oidc create-token \
    --client-id "${CLIENT_ID}" \
    --client-secret "${CLIENT_SECRET}" \
    --grant-type urn:ietf:params:oauth:grant-type:device_code \
    --device-code "${DEVICE_CODE}" \
    --profile aws_sso_roller \
    --region "${SSO_REGION}" \
    --no-sign-request \
    --output json \
    > "${ROLLER_TOKEN}"
fi

ACCESS_TOKEN="$(<${ROLLER_TOKEN} jq -r .accessToken)"
ACCOUNTS="$(aws sso list-accounts \
  --access-token "${ACCESS_TOKEN}" \
  --profile aws_sso_roller \
  --region "${SSO_REGION}" \
  --no-sign-request \
  --output json \
  | jq -rM '.accountList[] | [.accountId, .accountName] | @tsv' \
  )"

_process_accounts "${ACCESS_TOKEN}" "${ACCOUNTS}"
