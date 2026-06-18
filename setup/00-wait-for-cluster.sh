#!/usr/bin/env bash
# Wait until the cluster answers and reaches at least yellow health.
. "$(dirname "$0")/../lib/common.sh"

log "Waiting for ${ES_URL} to accept authenticated requests..."
for i in $(seq 1 60); do
  if es GET / >/dev/null 2>&1; then break; fi
  sleep 5
done

log "Waiting for cluster health >= yellow..."
es GET "/_cluster/health?wait_for_status=yellow&timeout=120s" | jq '{status, number_of_nodes, active_shards}'
ok "Cluster is up."
