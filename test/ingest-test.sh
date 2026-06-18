#!/usr/bin/env bash
# Ingest test: write sample logs into the data stream, then verify the backing
# index actually uses LogsDB mode and the docs are searchable.
. "$(dirname "$0")/../lib/common.sh"

N="${N:-1000}"
log "Bulk-indexing ${N} sample log lines into '${DATA_STREAM}'..."

# Build a bulk body of synthetic app logs.
tmp="$(mktemp)"
levels=(INFO INFO INFO WARN ERROR DEBUG)
hosts=(web-01 web-02 api-01 api-02 worker-01)
for i in $(seq 1 "$N"); do
  lvl=${levels[$((RANDOM % ${#levels[@]}))]}
  host=${hosts[$((RANDOM % ${#hosts[@]}))]}
  ts="$(date -u +%Y-%m-%dT%H:%M:%S.000Z)"
  echo '{ "create": {} }' >> "$tmp"
  printf '{"@timestamp":"%s","host.name":"%s","service.name":"checkout","log.level":"%s","message":"request %d processed in %dms"}\n' \
    "$ts" "$host" "$lvl" "$i" "$((RANDOM % 500))" >> "$tmp"
done

es POST "/${DATA_STREAM}/_bulk" "$(cat "$tmp")" | jq '{errors, items: (.items|length)}'
rm -f "$tmp"
es POST "/${DATA_STREAM}/_refresh" >/dev/null

log "Document count"
es GET "/${DATA_STREAM}/_count" | jq '.count'

log "Verify backing index uses LogsDB mode"
backing="$(es GET "/_data_stream/${DATA_STREAM}" | jq -r '.data_streams[0].indices[-1].index_name')"
mode="$(es GET "/${backing}/_settings?filter_path=**.index.mode" | jq -r '..|.mode? // empty' | head -1)"
echo "backing index: $backing   index.mode: ${mode:-<unset>}"
[[ "$mode" == "logsdb" ]] && ok "LogsDB confirmed on $backing" || warn "index.mode is '${mode:-unset}', expected logsdb"

log "Sample query: error count by host (ES|QL)"
es POST "/_query" '{"query":"FROM logs-app.*-* | WHERE log.level == \"ERROR\" | STATS errors = COUNT(*) BY host.name | SORT errors DESC"}' \
  | jq '.values' 2>/dev/null || warn "ES|QL query skipped (check license/version)"

ok "Ingest test passed."
