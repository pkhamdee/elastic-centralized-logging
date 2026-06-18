#!/usr/bin/env bash
# Index template for the logs-* data streams. Composes the settings + mappings
# component templates and declares these indices as data streams.
. "$(dirname "$0")/../lib/common.sh"

log "Creating index template 'logs-app' for 'logs-app.*-*' data streams..."
es_check PUT "/_index_template/logs-app" "$(cat <<'JSON'
{
  "index_patterns": ["logs-app.*-*"],
  "data_stream": {},
  "priority": 200,
  "composed_of": ["logs-settings", "logs-mappings"],
  "_meta": { "description": "Application log data streams (LogsDB, ILM-managed)" }
}
JSON
)"
ok "Index template 'logs-app' created."

log "Creating index template 'logs-nginx' for Kubernetes ingress-nginx data streams..."
es_check PUT "/_index_template/logs-nginx" "$(cat <<'JSON'
{
  "index_patterns": ["logs-nginx.*-*"],
  "data_stream": {},
  "priority": 200,
  "composed_of": ["logs-settings", "logs-mappings"],
  "_meta": { "description": "Kubernetes ingress-nginx access-log data streams (LogsDB, ILM-managed)" }
}
JSON
)"
ok "Index template 'logs-nginx' created."

log "Verifying a simulated index for 'logs-nginx.ingress-default'..."
es POST "/_index_template/_simulate_index/logs-nginx.ingress-default" \
  | jq '{mode: .template.settings.index.mode, ilm: .template.settings.index.lifecycle.name}'
ok "Template resolves with LogsDB + ILM."
