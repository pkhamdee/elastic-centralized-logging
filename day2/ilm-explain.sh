#!/usr/bin/env bash
# Explain where every log index sits in its lifecycle, and surface ILM errors.
# Usage: ./ilm-explain.sh [index-or-datastream-pattern]   (default: logs-*)
. "$(dirname "$0")/../lib/common.sh"

PATTERN="${1:-logs-*}"

log "Lifecycle state for '${PATTERN}'"
es GET "/${PATTERN}/_ilm/explain?human" \
  | jq '.indices | to_entries[] | {
      index: .key,
      phase: .value.phase,
      action: .value.action,
      step: .value.step,
      age: .value.age,
      error: (.value.step_info.reason // null)
    }'

log "Any indices stuck in the ERROR step?"
es GET "/${PATTERN}/_ilm/explain" \
  | jq -r '.indices | to_entries[] | select(.value.step=="ERROR") | .key' \
  | { grep . && warn "stuck indices above -> retry with: es POST /<index>/_ilm/retry" || ok "none stuck"; }
