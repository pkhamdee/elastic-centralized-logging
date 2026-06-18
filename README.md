# Centralized Logging with the Elastic Stack — Reference Project

Companion scripts for the blog post **"Centralize Log Solution with the Elastic Stack."**
Use case: ship **Kubernetes ingress-nginx logs** into a **self-managed Elastic Stack on Ubuntu**.
A runnable, scaled-down stack you can stand up on one machine, plus the Ubuntu install
scripts, the Kubernetes shipper, and the setup/test/day-2 scripts for production.

Built and verified against **Elastic Stack 9.3** (June 2026).

## What's here

```
elastic-centralized-logging/
├── compose/                 # Local stack: 3 ES nodes + Kibana + Logstash + Redis + MinIO
│   ├── docker-compose.yml
│   ├── .env.example
│   └── logstash/pipeline/
│       └── ingress-nginx.conf   # parse ingress logs -> logs-nginx.ingress-default
├── shippers/
│   └── filebeat-daemonset.yaml  # K8s DaemonSet: tail ingress-nginx logs -> Kafka/Logstash
├── ubuntu/
│   └── install-elastic-ubuntu.sh # apt install ES / Logstash / Kibana on Ubuntu (production)
├── lib/
│   └── common.sh            # Shared env + helpers (ES_URL, auth, request wrapper)
├── setup/                   # Build the platform (idempotent, run in order)
│   ├── 00-wait-for-cluster.sh
│   ├── 20-snapshot-repo-minio.sh
│   ├── 30-ilm-policy.sh
│   ├── 40-component-templates.sh
│   ├── 50-index-template.sh     # logs-app + logs-nginx data stream templates
│   ├── 60-roles-users.sh
│   ├── 70-slm-policy.sh
│   └── run-all.sh
├── test/                    # Prove it works
│   ├── smoke-test.sh        # cluster health, node roles
│   ├── ingest-test.sh       # write logs, verify LogsDB index mode
│   ├── parse-ingress-test.sh # feed a sample ingress log, verify it parses + LogsDB
│   ├── ilm-test.sh          # verify lifecycle attached + explain
│   └── ha-failover-test.sh  # kill a data node, confirm queries survive
└── day2/                    # Operate it
    ├── health-check.sh
    ├── capacity-report.sh
    ├── ilm-explain.sh
    ├── snapshot-now.sh
    ├── rolling-restart.sh
    └── force-merge-warm.sh
```

## Prerequisites

- Docker + Docker Compose v2
- `curl` and `jq`
- ~6 GB RAM free for the local cluster

## Quick start

```bash
cd compose
cp .env.example .env          # set passwords + version
docker compose up -d          # 3 ES nodes + Kibana + MinIO
cd ..

# point the scripts at the cluster
export ES_URL="https://localhost:9200"
export ES_USER="elastic"
export ES_PASS="$(grep ELASTIC_PASSWORD compose/.env | cut -d= -f2)"
export ES_CACERT="compose/certs/ca/ca.crt"

./setup/run-all.sh            # repo, ILM, templates, roles, SLM
./test/smoke-test.sh
./test/parse-ingress-test.sh  # feed a sample ingress log through Logstash
```

Kibana: <http://localhost:5601> (user `elastic`, password from `.env`).

## How this maps to the blog post

| Blog section | Files |
|---|---|
| Source: ship ingress logs off Kubernetes | `shippers/filebeat-daemonset.yaml` |
| Logstash: parse ingress logs | `compose/logstash/pipeline/ingress-nginx.conf`, `test/parse-ingress-test.sh` |
| Ingest Kong API gateway logs | `compose/logstash/pipeline/kong-http-log.conf` (port 8081, `logs-kong.proxy` data stream) |
| Install on Ubuntu | `ubuntu/install-elastic-ubuntu.sh` |
| LogsDB + index templates | `setup/40-component-templates.sh`, `setup/50-index-template.sh` |
| ILM (replaces Curator) + tiers | `setup/30-ilm-policy.sh`, `day2/ilm-explain.sh` |
| Frozen tier on object storage | `setup/20-snapshot-repo-minio.sh`, `setup/70-slm-policy.sh` |
| RBAC | `setup/60-roles-users.sh` |
| Proving HA | `test/ha-failover-test.sh` |
| Day-2 operations | everything in `day2/` |

> **Scope note:** the local cluster collapses the hot/warm/frozen tiers onto 3 nodes so it
> runs on a laptop. The blog post describes the production topology (3 master, 3 hot, 2 warm,
> 2 frozen, 2 coordinating, 2 Kibana). The scripts are identical against both — only node
> counts and the `_tier_preference` allocation differ.
