#!/usr/bin/env bash
# RBAC: a writer role for log shippers (Elastic Agent / Logstash) and a read-only
# analyst role scoped to the log data streams. Creates one service-style user each.
. "$(dirname "$0")/../lib/common.sh"

log "Creating role 'log-writer'..."
es_check PUT "/_security/role/log-writer" "$(cat <<'JSON'
{
  "cluster": ["monitor", "manage_index_templates", "manage_ilm", "read_ilm"],
  "indices": [
    {
      "names": ["logs-*"],
      "privileges": ["create_doc", "create_index", "auto_configure", "view_index_metadata"]
    }
  ]
}
JSON
)"
ok "role log-writer created."

log "Creating role 'log-analyst' (read-only)..."
es_check PUT "/_security/role/log-analyst" "$(cat <<'JSON'
{
  "cluster": ["monitor"],
  "indices": [
    {
      "names": ["logs-*"],
      "privileges": ["read", "view_index_metadata"]
    }
  ]
}
JSON
)"
ok "role log-analyst created."

WRITER_PASS="${WRITER_PASS:-changeme-writer}"
ANALYST_PASS="${ANALYST_PASS:-changeme-analyst}"

log "Creating users 'svc-log-writer' and 'analyst1'..."
es_check PUT "/_security/user/svc-log-writer" "{\"password\":\"${WRITER_PASS}\",\"roles\":[\"log-writer\"],\"full_name\":\"Log shipper service account\"}"
es_check PUT "/_security/user/analyst1" "{\"password\":\"${ANALYST_PASS}\",\"roles\":[\"log-analyst\"],\"full_name\":\"Read-only analyst\"}"
ok "Users created. Change the default passwords via WRITER_PASS / ANALYST_PASS env vars."
