#!/usr/bin/env bash
# Smoke test: cluster is healthy and the tier roles are present.
. "$(dirname "$0")/../lib/common.sh"

log "Cluster health"
health="$(es GET /_cluster/health)"
echo "$health" | jq '{status, number_of_nodes, number_of_data_nodes, active_shards, unassigned_shards}'
status="$(echo "$health" | jq -r .status)"
[[ "$status" == "green" || "$status" == "yellow" ]] || { echo "FAIL: cluster status is $status"; exit 1; }
ok "cluster status: $status"

log "Node roles"
es GET "/_cat/nodes?h=name,node.role,master&v"

log "Checking expected data tiers are represented"
roles="$(es GET '/_nodes/_all/settings?filter_path=nodes.*.roles' )"
for tier in data_hot data_warm data_cold data_frozen; do
  if echo "$roles" | grep -q "\"$tier\""; then ok "tier present: $tier"; else warn "tier MISSING: $tier"; fi
done

ok "Smoke test passed."
