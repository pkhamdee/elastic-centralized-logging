#!/usr/bin/env bash
# Index Lifecycle Management policy that walks log data through the tiers and deletes it.
#   hot     -> rollover at 50GB primary shard or 1 day
#   warm    -> after 7d: shrink to 1 shard, force-merge, lower priority
#   cold    -> after 30d: mount as searchable snapshot (data stays in object store)
#   frozen  -> after 60d: partially-mounted snapshot (cheapest searchable tier)
#   delete  -> after 90d
# Tune the min_age values to your retention requirements.
. "$(dirname "$0")/../lib/common.sh"

log "Creating ILM policy 'logs-lifecycle'..."
es_check PUT "/_ilm/policy/logs-lifecycle" "$(cat <<'JSON'
{
  "policy": {
    "phases": {
      "hot": {
        "actions": {
          "rollover": { "max_primary_shard_size": "50gb", "max_age": "1d" },
          "set_priority": { "priority": 100 }
        }
      },
      "warm": {
        "min_age": "7d",
        "actions": {
          "shrink": { "number_of_shards": 1 },
          "forcemerge": { "max_num_segments": 1 },
          "set_priority": { "priority": 50 }
        }
      },
      "cold": {
        "min_age": "30d",
        "actions": {
          "searchable_snapshot": { "snapshot_repository": "minio-repo" },
          "set_priority": { "priority": 0 }
        }
      },
      "frozen": {
        "min_age": "60d",
        "actions": {
          "searchable_snapshot": { "snapshot_repository": "minio-repo" }
        }
      },
      "delete": {
        "min_age": "90d",
        "actions": { "delete": {} }
      }
    }
  }
}
JSON
)"
ok "ILM policy 'logs-lifecycle' created."
