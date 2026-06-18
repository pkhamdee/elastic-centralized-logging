#!/usr/bin/env bash
# Safe rolling restart of ONE node, following Elastic's documented procedure:
#   1) disable shard allocation + flush, 2) stop/patch/start the node,
#   3) re-enable allocation and wait for green.
# Usage: ./rolling-restart.sh <container-name>     (local stack uses docker stop/start)
. "$(dirname "$0")/../lib/common.sh"

NODE="${1:?usage: rolling-restart.sh <container-name>}"

log "1/5 Disabling replica shard allocation (primaries stay put)..."
es PUT "/_cluster/settings" '{"persistent":{"cluster.routing.allocation.enable":"primaries"}}' | jq '.persistent'

log "2/5 Flushing to speed up recovery..."
es POST "/_flush" >/dev/null || true

log "3/5 Stopping node container '${NODE}'..."
docker stop "$NODE" >/dev/null
sleep 5
log "    (apply your upgrade/patch here, then continuing)"
docker start "$NODE" >/dev/null

log "4/5 Waiting for the node to rejoin..."
for i in $(seq 1 60); do
  if es GET "/_cat/nodes?h=name" | grep -q "$NODE"; then ok "node rejoined"; break; fi
  sleep 5
done

log "5/5 Re-enabling allocation and waiting for green..."
es PUT "/_cluster/settings" '{"persistent":{"cluster.routing.allocation.enable":null}}' | jq '.persistent'
es GET "/_cluster/health?wait_for_status=green&timeout=300s" | jq '{status, relocating_shards, initializing_shards}'
ok "Rolling restart of ${NODE} complete."
