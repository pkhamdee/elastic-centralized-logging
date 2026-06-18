#!/usr/bin/env bash
# Run the full platform setup in order. Idempotent: safe to re-run.
. "$(dirname "$0")/../lib/common.sh"
cd "$(dirname "$0")"

for step in 00-wait-for-cluster.sh \
            20-snapshot-repo-minio.sh \
            30-ilm-policy.sh \
            40-component-templates.sh \
            50-index-template.sh \
            60-roles-users.sh \
            70-slm-policy.sh; do
  log "RUN $step"
  bash "$step"
  echo
done
ok "Platform setup complete."
