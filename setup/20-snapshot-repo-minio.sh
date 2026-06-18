#!/usr/bin/env bash
# Register a MinIO (S3-compatible) snapshot repository for the frozen tier and SLM backups.
# Steps: load S3 client credentials into each node's keystore, reload secure settings,
# then register the repository via the API.
. "$(dirname "$0")/../lib/common.sh"

MINIO_USER="${MINIO_ROOT_USER:-minioadmin}"
MINIO_PASS="${MINIO_ROOT_PASSWORD:-changeme-minio}"
BUCKET="${SNAPSHOT_BUCKET:-es-snapshots}"
NODES="${ES_NODES:-es01 es02 es03}"   # container names

log "Loading S3 client credentials into each node keystore..."
for n in $NODES; do
  docker exec -i "$n" bash -c \
    "echo '$MINIO_USER' | bin/elasticsearch-keystore add -x -f s3.client.default.access_key && \
     echo '$MINIO_PASS' | bin/elasticsearch-keystore add -x -f s3.client.default.secret_key" \
    && ok "keystore set on $n" || warn "could not set keystore on $n (set ES_NODES correctly?)"
done

log "Reloading secure settings across the cluster..."
es POST "/_nodes/reload_secure_settings" | jq '{cluster_name, nodes: (.nodes|length)}' || true

log "Registering snapshot repository '${SNAP_REPO}' -> MinIO bucket '${BUCKET}'..."
es_check PUT "/_snapshot/${SNAP_REPO}" "$(cat <<JSON
{
  "type": "s3",
  "settings": {
    "bucket": "${BUCKET}",
    "endpoint": "minio:9000",
    "protocol": "http",
    "path_style_access": true
  }
}
JSON
)"

log "Verifying repository..."
es POST "/_snapshot/${SNAP_REPO}/_verify" | jq '.'
ok "Snapshot repository ready."
