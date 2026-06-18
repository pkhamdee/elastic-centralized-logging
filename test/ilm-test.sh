#!/usr/bin/env bash
# Verify the data stream is ILM-managed and inspect its lifecycle state.
. "$(dirname "$0")/../lib/common.sh"

log "ILM policy attached to '${DATA_STREAM}'?"
es GET "/${DATA_STREAM}/_ilm/explain" \
  | jq '.indices | to_entries[] | {index: .key, managed: .value.managed, policy: .value.policy, phase: .value.phase, action: .value.action}'

log "Policy definition"
es GET "/_ilm/policy/logs-lifecycle" | jq '.["logs-lifecycle"].policy.phases | keys'

ok "ILM test done. In production, watch 'phase' advance hot -> warm -> cold -> frozen over time."
