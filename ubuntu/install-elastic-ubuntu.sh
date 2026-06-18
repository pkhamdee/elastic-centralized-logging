#!/usr/bin/env bash
# Install an Elastic Stack 9.x component on Ubuntu (22.04/24.04) via the apt repo.
# Usage: sudo ./install-elastic-ubuntu.sh {elasticsearch|logstash|kibana}
# This is the production install path; the compose stack is for local testing only.
set -euo pipefail

COMPONENT="${1:?usage: install-elastic-ubuntu.sh {elasticsearch|logstash|kibana}}"

echo "==> Adding Elastic 9.x apt repository"
sudo apt-get install -y apt-transport-https wget gnupg
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch \
  | sudo gpg --dearmor -o /usr/share/keyrings/elasticsearch-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/elasticsearch-keyring.gpg] https://artifacts.elastic.co/packages/9.x/apt stable main" \
  | sudo tee /etc/apt/sources.list.d/elastic-9.x.list >/dev/null
sudo apt-get update

case "$COMPONENT" in
  elasticsearch)
    echo "==> Installing Elasticsearch (note the generated elastic password in the output)"
    sudo apt-get install -y elasticsearch
    echo "==> Set heap to <=31GB and <=50% RAM:"
    echo "    echo '-Xms16g' | sudo tee /etc/elasticsearch/jvm.options.d/heap.options"
    echo "    echo '-Xmx16g' | sudo tee -a /etc/elasticsearch/jvm.options.d/heap.options"
    echo "==> Edit /etc/elasticsearch/elasticsearch.yml: cluster.name, node.name, node.roles, discovery.seed_hosts"
    echo "==> Then: sudo systemctl enable --now elasticsearch"
    echo "==> Open ports between nodes: sudo ufw allow 9200/tcp && sudo ufw allow 9300/tcp"
    ;;
  logstash)
    echo "==> Installing Logstash"
    sudo apt-get install -y logstash
    echo "==> Copy your pipeline into /etc/logstash/conf.d/ (see compose/logstash/pipeline/ingress-nginx.conf)"
    echo "==> Put the ES CA cert at /etc/logstash/certs/ca.crt and set ELASTIC_PASSWORD in /etc/default/logstash"
    echo "==> Then: sudo systemctl enable --now logstash"
    echo "==> Open the Beats port: sudo ufw allow 5044/tcp"
    ;;
  kibana)
    echo "==> Installing Kibana"
    sudo apt-get install -y kibana
    echo "==> Edit /etc/kibana/kibana.yml: server.host: 0.0.0.0, elasticsearch.hosts, and the kibana_system credentials"
    echo "==> Enroll with: sudo /usr/share/kibana/bin/kibana-setup --enrollment-token <token-from-es>"
    echo "==> Then: sudo systemctl enable --now kibana   (UI on :5601)"
    echo "==> Open the UI port (behind your VIP/LB): sudo ufw allow 5601/tcp"
    ;;
  *)
    echo "unknown component: $COMPONENT" >&2; exit 1 ;;
esac

echo "==> Done installing ${COMPONENT}."
