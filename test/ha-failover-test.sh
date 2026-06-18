#!/usr/bin/env bash
# HA test: kill the hot data node, confirm the cluster keeps serving queries
# (replica on another node takes over), then bring it back and confirm recovery.
# Requires the local compose stack (uses docker).
. "$(dirname "$0")/../lib/common.sh"

VICTIM="${VICTIM:-es01}"   # hot data node in the local stack

log "Baseline: doc count + health"
before="$(es GET "/${DATA_STREAM}/_count" | jq -r '.count')"
es GET "/_cluster/health" | jq '{status, number_of_nodes}'
echo "docs before: $before"

log "Stopping data node '${VICTIM}'..."
docker stop "$VICTIM" >/dev/null
sleep 10

log "Cluster health after node loss (expect yellow, NOT red)"
es GET "/_cluster/health" | jq '{status, number_of_nodes, unassigned_shards}'

log "Queries still served from replicas?"
after="$(es GET "/${DATA_STREAM}/_count" | jq -r '.count')"
echo "docs after node loss: $after"
[[ "$after" == "$before" ]] && ok "no data loss, queries still answered" || warn "count changed ($before -> $after)"

log "Restarting '${VICTIM}'..."
docker start "$VICTIM" >/dev/null
es GET "/_cluster/health?wait_for_status=green&timeout=120s" | jq '{status, active_shards, relocating_shards}'
ok "HA failover test complete. (A single-replica setup survives ONE node loss per shard copy.)"
