#!/usr/bin/env bash
# Daily health check: status, unassigned shards (with reason), disk watermarks,
# pending tasks, and hot-thread hints. Run from cron or a dashboard.
. "$(dirname "$0")/../lib/common.sh"

log "Cluster health"
es GET "/_cluster/health" | jq '{status, nodes: .number_of_nodes, data_nodes: .number_of_data_nodes, active_shards, unassigned_shards, active_shards_percent_as_number}'

log "Any unassigned shards? (explain first one if so)"
unassigned="$(es GET '/_cat/shards?h=index,shard,prirep,state' | awk '$4=="UNASSIGNED"' | head -5)"
if [[ -n "$unassigned" ]]; then
  echo "$unassigned"
  es POST "/_cluster/allocation/explain" '{}' | jq '{index, shard, primary, can_allocate, "explanation": .allocate_explanation}'
else
  ok "no unassigned shards"
fi

log "Disk usage per node (watch the 85% low watermark)"
es GET "/_cat/allocation?h=node,shards,disk.percent,disk.used,disk.avail&v"

log "Pending cluster tasks (should be 0 at rest)"
es GET "/_cluster/pending_tasks" | jq '.tasks | length'

log "JVM heap pressure per node"
es GET "/_cat/nodes?h=name,heap.percent,ram.percent,cpu,load_1m&v"
ok "Health check done."
