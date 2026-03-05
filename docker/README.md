# Docker – Azure VM Replicator

Run the Replicator (MSK → Confluent Cloud) in Docker on an Azure VM.

## Prerequisites

1. **BTDS Decryption JAR** – `plugins/btds-encryption/smt-decryption-1.0-SNAPSHOT.jar` (included)
2. **AWS credentials** – `~/.aws/credentials` with IAM access to MSK
3. **Confluent Cloud** – API key, Schema Registry URL and credentials

---

## Docker Commands

Run from project root. Connect REST API: `http://localhost:8083`.

| Action | Command |
|--------|---------|
| **Start** | `docker-compose -f docker/docker-compose.yml up -d` |
| **Stop** | `docker-compose -f docker/docker-compose.yml down` |
| **Restart** | `docker-compose -f docker/docker-compose.yml restart replicator` |
| **Logs** | `docker-compose -f docker/docker-compose.yml logs -f replicator` |
| **Build (no cache)** | `docker-compose -f docker/docker-compose.yml build --no-cache` |
| **Status** | `docker-compose -f docker/docker-compose.yml ps` |

---

## Connector Commands

Base URL: `http://localhost:8083`. Connector name: `msk-to-confluent-cloud-replicator-encrypted`.

| Action | Command |
|--------|---------|
| **Create** | `curl -s -X POST -H "Content-Type: application/json" -d @config/replicator-connector.json http://localhost:8083/connectors` |
| **List all** | `curl -s http://localhost:8083/connectors` |
| **Status** | `curl -s http://localhost:8083/connectors/msk-to-confluent-cloud-replicator-encrypted/status` |
| **Config** | `curl -s http://localhost:8083/connectors/msk-to-confluent-cloud-replicator-encrypted` |
| **Pause** | `curl -s -X PUT http://localhost:8083/connectors/msk-to-confluent-cloud-replicator-encrypted/pause` |
| **Resume** | `curl -s -X PUT http://localhost:8083/connectors/msk-to-confluent-cloud-replicator-encrypted/resume` |
| **Delete** | `curl -s -X DELETE http://localhost:8083/connectors/msk-to-confluent-cloud-replicator-encrypted` |
| **Tasks status** | `curl -s http://localhost:8083/connectors/msk-to-confluent-cloud-replicator-encrypted/tasks` |

---

## Setup

```bash
# 1. Copy env template and fill placeholders
cp docker/.env.example docker/.env
# Edit docker/.env with your values

# 2. Start Replicator (from project root)
docker-compose -f docker/docker-compose.yml up -d

# 3. Wait for Connect to be ready (~60–90s), then create connector
# Copy config/replicator-connector.json.example to config/replicator-connector.json
# Replace placeholders: <MSK_BOOTSTRAP_SERVERS>, <CCLOUD_*>, <SCHEMA_REGISTRY_URL>, <SR_API_KEY>, <SR_API_SECRET>, <BASE64_ENCRYPTION_KEY>, <TOPIC_PREFIX>

curl -s -X POST -H "Content-Type: application/json" -d @config/replicator-connector.json http://localhost:8083/connectors | jq .

# 4. Check status
curl -s http://localhost:8083/connectors/msk-to-confluent-cloud-replicator-encrypted/status | jq .
```

## Placeholders (no secrets in repo)

| Variable | Purpose |
|----------|---------|
| `CCLOUD_BOOTSTRAP_SERVERS` | Confluent Cloud bootstrap URL |
| `CCLOUD_API_KEY` | Confluent Cloud API key |
| `CCLOUD_API_SECRET` | Confluent Cloud API secret |
| `SCHEMA_REGISTRY_URL` | Schema Registry URL |
| `SR_API_KEY` | Schema Registry API key |
| `SR_API_SECRET` | Schema Registry API secret |
| `MSK_BOOTSTRAP_SERVERS` | MSK public bootstrap (for connector config) |
| `AWS_REGION` | AWS region for MSK |

## Volumes

- `~/.aws` → `/home/appuser/.aws` (read-only, for MSK IAM)

## Upload plugins to Azure VM

```bash
# From project root
./scripts/upload-plugins-to-azure.sh

# Or manually (set SSH_KEY and VM_HOST as needed):
scp -i <SSH_KEY> -r plugins azureuser@<VM_IP>:~/
```
