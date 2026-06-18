#!/usr/bin/env bash
# Component templates: one for settings (LogsDB index mode + ILM + tiering),
# one for mappings (ECS-aligned core fields). Index templates compose these.
. "$(dirname "$0")/../lib/common.sh"

log "Creating settings component template 'logs-settings'..."
# index.mode=logsdb turns on smart sorting + synthetic _source + better codecs.
# Since 9.2 any logs-* data stream uses LogsDB by default; we set it explicitly
# so the behavior is obvious and portable to older 8.17+ clusters.
es_check PUT "/_component_template/logs-settings" "$(cat <<'JSON'
{
  "template": {
    "settings": {
      "index.mode": "logsdb",
      "index.lifecycle.name": "logs-lifecycle",
      "index.number_of_shards": 1,
      "index.number_of_replicas": 1,
      "index.codec": "best_compression",
      "index.routing.allocation.include._tier_preference": "data_hot"
    }
  },
  "_meta": { "description": "LogsDB + ILM + hot-first allocation for log data streams" }
}
JSON
)"
ok "logs-settings created."

log "Creating mappings component template 'logs-mappings'..."
es_check PUT "/_component_template/logs-mappings" "$(cat <<'JSON'
{
  "template": {
    "mappings": {
      "properties": {
        "@timestamp":       { "type": "date" },
        "host.name":        { "type": "keyword" },
        "service.name":     { "type": "keyword" },
        "log.level":        { "type": "keyword" },
        "log.logger":       { "type": "keyword" },
        "data_stream.type":      { "type": "constant_keyword" },
        "data_stream.dataset":   { "type": "constant_keyword" },
        "data_stream.namespace": { "type": "constant_keyword" },
        "message":          { "type": "match_only_text" },
        "trace.id":         { "type": "keyword" },
        "labels":           { "type": "object", "dynamic": true }
      }
    }
  },
  "_meta": { "description": "ECS-aligned core fields for application logs" }
}
JSON
)"
ok "logs-mappings created."
