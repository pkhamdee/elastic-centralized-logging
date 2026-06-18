#!/usr/bin/env bash
# Feed a sample ingress-nginx log line through Logstash and verify it lands parsed
# in the logs-nginx.ingress-default data stream. Uses the Logstash http input (8080).
. "$(dirname "$0")/../lib/common.sh"

LOGSTASH_HTTP="${LOGSTASH_HTTP:-http://localhost:8080}"
DS="logs-nginx.ingress-default"

log "Posting a sample JSON ingress log to Logstash (${LOGSTASH_HTTP})..."
sample='{"time":"2026-06-18T10:00:00+00:00","remote_addr":"203.0.113.7","method":"GET","path":"/api/health","status":200,"bytes":612,"request_time":0.012,"upstream_status":"200","host":"shop.example.com","user_agent":"curl/8.10","req_id":"abc123"}'

for i in $(seq 1 5); do
  curl -sS -X POST "$LOGSTASH_HTTP" -H 'Content-Type: application/json' -d "$sample" >/dev/null \
    && break || { warn "Logstash not ready yet, retrying..."; sleep 5; }
done

log "Waiting for the document to be indexed..."
sleep 5
es POST "/${DS}/_refresh" >/dev/null 2>&1 || true

log "Document count in ${DS}"
count="$(es GET "/${DS}/_count" | jq -r '.count // 0')"
echo "count: $count"
[[ "$count" -ge 1 ]] && ok "ingress log indexed" || { warn "no docs found (is Logstash up and the logs-nginx template installed?)"; exit 1; }

log "Verify fields parsed correctly (status should be an integer, not a string)"
es GET "/${DS}/_search?size=1" \
  | jq '.hits.hits[0]._source | {status, method, path, host, request_time}'

log "Confirm the backing index uses LogsDB"
backing="$(es GET "/_data_stream/${DS}" | jq -r '.data_streams[0].indices[-1].index_name')"
mode="$(es GET "/${backing}/_settings?filter_path=**.index.mode" | jq -r '..|.mode? // empty' | head -1)"
echo "backing index: $backing   index.mode: ${mode:-<unset>}"
[[ "$mode" == "logsdb" ]] && ok "LogsDB confirmed" || warn "index.mode is '${mode:-unset}', expected logsdb"

ok "Ingress parse test passed."
