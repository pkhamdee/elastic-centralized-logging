#!/usr/bin/env bash
# Take an on-demand snapshot (e.g. before an upgrade) and report status.
. "$(dirname "$0")/../lib/common.sh"

SNAP="manual-$(date -u +%Y%m%d-%H%M%S)"
log "Taking snapshot '${SNAP}' into repository '${SNAP_REPO}' (waiting for completion)..."
es PUT "/_snapshot/${SNAP_REPO}/${SNAP}?wait_for_completion=true" '{
  "indices": "logs-*",
  "include_global_state": false
}' | jq '{snapshot: .snapshot.snapshot, state: .snapshot.state, shards: .snapshot.shards}'

log "Recent snapshots in repository"
es GET "/_snapshot/${SNAP_REPO}/_all?verbose=false" | jq '.snapshots[-5:] | .[] | {snapshot, state}'
ok "Snapshot done. Restore with: es POST /_snapshot/${SNAP_REPO}/${SNAP}/_restore"
