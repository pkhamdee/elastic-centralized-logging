#!/usr/bin/env bash
# Force-merge read-only warm/cold indices down to one segment to reclaim space and
# speed up search. Only run on indices that are no longer being written to.
# ILM already does this in the warm phase; use this for manual cleanup or backfill.
. "$(dirname "$0")/../lib/common.sh"

PATTERN="${1:-logs-*}"

log "Candidate indices NOT in the hot tier (safe to force-merge)"
es GET "/_cat/indices/${PATTERN}?h=index,pri.store.size,creation.date.string&s=creation.date" | head -20

read -r -p "Force-merge all '${PATTERN}' indices on warm/cold tiers to 1 segment? [y/N] " ans
[[ "${ans:-N}" =~ ^[Yy]$ ]] || { warn "aborted"; exit 0; }

log "Force-merging (this is I/O heavy; run off-peak)..."
es POST "/${PATTERN}/_forcemerge?max_num_segments=1&wait_for_completion=true" \
  | jq '{shards: ._shards}'
ok "Force-merge complete."
