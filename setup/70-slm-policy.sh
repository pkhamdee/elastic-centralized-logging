#!/usr/bin/env bash
# Snapshot Lifecycle Management: nightly cluster snapshots into the MinIO repo,
# retained 30 days. This is your disaster-recovery backup, separate from the
# searchable snapshots that ILM creates for the cold/frozen tiers.
. "$(dirname "$0")/../lib/common.sh"

log "Creating SLM policy 'nightly-snapshots'..."
es_check PUT "/_slm/policy/nightly-snapshots" "$(cat <<JSON
{
  "schedule": "0 30 1 * * ?",
  "name": "<nightly-{now/d}>",
  "repository": "${SNAP_REPO}",
  "config": {
    "indices": ["*"],
    "include_global_state": true
  },
  "retention": {
    "expire_after": "30d",
    "min_count": 5,
    "max_count": 50
  }
}
JSON
)"
ok "SLM policy created (runs daily at 01:30)."

log "Triggering one snapshot now to validate end-to-end..."
es POST "/_slm/policy/nightly-snapshots/_execute" | jq '.'
ok "SLM validated. Check status with: es GET /_slm/policy/nightly-snapshots?human"
