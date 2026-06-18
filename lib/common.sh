#!/usr/bin/env bash
# Shared environment and helpers for the Elastic centralized-logging scripts.
# Source this from every script: . "$(dirname "$0")/../lib/common.sh"
set -euo pipefail

ES_URL="${ES_URL:-https://localhost:9200}"
ES_USER="${ES_USER:-elastic}"
ES_PASS="${ES_PASS:-changeme}"
# Path to the CA cert created by the compose stack. Set ES_INSECURE=1 to skip TLS verify.
ES_CACERT="${ES_CACERT:-compose/certs/ca/ca.crt}"

# Snapshot repository name used across setup/day2 scripts.
SNAP_REPO="${SNAP_REPO:-minio-repo}"
# Data stream we write logs into.
DATA_STREAM="${DATA_STREAM:-logs-app.generic-default}"

_curl_tls_args() {
  if [[ "${ES_INSECURE:-0}" == "1" ]]; then
    echo "-k"
  elif [[ -f "$ES_CACERT" ]]; then
    echo "--cacert $ES_CACERT"
  else
    echo "-k"
  fi
}

# es METHOD PATH [JSON_BODY]
# Thin wrapper around curl with auth + TLS. Prints the response body.
es() {
  local method="$1" path="$2" body="${3:-}"
  local tls; tls="$(_curl_tls_args)"
  if [[ -n "$body" ]]; then
    curl -sS $tls -u "$ES_USER:$ES_PASS" \
      -H 'Content-Type: application/json' \
      -X "$method" "${ES_URL}${path}" -d "$body"
  else
    curl -sS $tls -u "$ES_USER:$ES_PASS" \
      -X "$method" "${ES_URL}${path}"
  fi
}

# Same as es() but fails the script on HTTP >= 400.
es_check() {
  local method="$1" path="$2" body="${3:-}"
  local tls; tls="$(_curl_tls_args)"
  local code
  code="$(curl -sS -o /tmp/es_resp.$$ -w '%{http_code}' $tls -u "$ES_USER:$ES_PASS" \
    -H 'Content-Type: application/json' \
    ${body:+-d "$body"} -X "$method" "${ES_URL}${path}")"
  cat /tmp/es_resp.$$; echo
  rm -f /tmp/es_resp.$$
  if [[ "$code" -ge 400 ]]; then
    echo "ERROR: $method $path returned HTTP $code" >&2
    return 1
  fi
}

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m  ✓\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m  ! \033[0m %s\n' "$*"; }

require() { command -v "$1" >/dev/null 2>&1 || { echo "missing dependency: $1" >&2; exit 1; }; }
require curl
require jq
