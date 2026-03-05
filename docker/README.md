# Docker – Azure VM Replicator

Run the Replicator (MSK → Confluent Cloud) in Docker on an Azure VM.

## Prerequisites

1. **BTDS Decryption JAR** – `plugins/btds-encryption/smt-decryption-1.0-SNAPSHOT.jar` (included)
2. **AWS credentials** – `~/.aws/credentials` with IAM access to MSK
3. **Confluent Cloud** – API key, Schema Registry URL and credentials

## Setup

```bash
# 1. Copy env template and fill placeholders
cp docker/.env.example docker/.env
# Edit docker/.env with your values

# 2. Build and run (from project root)
docker-compose -f docker/docker-compose.yml up -d

# 3. Register Replicator connector (replace placeholders in config first)
# Copy config/replicator-connector.json.example to config/replicator-connector.json
# Replace <MSK_BOOTSTRAP_SERVERS>, <CCLOUD_*>, <SCHEMA_REGISTRY_URL>, <SR_API_KEY>, <SR_API_SECRET>, <BASE64_ENCRYPTION_KEY>, <TOPIC_PREFIX>
# Then: curl -X POST -H "Content-Type: application/json" -d @config/replicator-connector.json http://localhost:8083/connectors
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
