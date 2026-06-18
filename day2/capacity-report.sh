#!/usr/bin/env bash
# Capacity report: shard sizes vs the 30-50GB target, shard count vs the 1000/node
# limit, and per-tier disk. Use this to decide when to add a node.
. "$(dirname "$0")/../lib/common.sh"

log "Largest shards (target 30-50GB primary; investigate anything >50GB)"
es GET "/_cat/shards?bytes=gb&h=index,shard,prirep,store,node&s=store:desc" | head -15

log "Shard count per node (hard limit 1000 per non-frozen node)"
es GET "/_cat/nodes?h=name,node.role&v" | while read -r line; do echo "$line"; done
es GET "/_cat/allocation?h=node,shards&v"

log "Index store size by data stream"
es GET "/_cat/indices/logs-*?bytes=mb&h=index,docs.count,store.size,pri,rep&s=store.size:desc" | head -20

log "Total log volume"
es GET "/logs-*/_stats/store?filter_path=_all.total.store.size_in_bytes" \
  | jq '{total_gb: ((._all.total.store.size_in_bytes // 0) / 1073741824 | floor)}'

ok "Capacity report done. Rule of thumb: add a hot node when ingest pushes shards past 50GB or a node nears 1000 shards / 85% disk."
