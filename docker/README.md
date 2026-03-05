# Docker – Azure VM Replicator

Run the Replicator (MSK → Confluent Cloud) in Docker on an Azure VM.

## Prerequisites

1. **Plugin JARs** – Add to `plugins/`:
   - `plugins/aws-msk-iam-auth/aws-msk-iam-auth-*.jar`
   - `plugins/btds-encryption/btds-encryption-smt-*.jar`
2. **AWS credentials** – `~/.aws/credentials` with IAM access to MSK
3. **Confluent Cloud** – API key, Schema Registry URL and credentials

## Setup

```bash
# 1. Copy env template and fill placeholders
cp docker/.env.example docker/.env
# Edit docker/.env with your values

# 2. Build and run (from project root)
docker-compose -f docker/docker-compose.yml up -d

# 3. Register Replicator connector via REST
# POST http://localhost:8083/connectors
# See docs/CDC_REPLICATION_ARCHITECTURE.md §6.3
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
| `AWS_REGION` | AWS region for MSK |

## Volumes

- `../plugins` → `/plugins` (read-only)
- `~/.aws` → `/home/appuser/.aws` (read-only, for MSK IAM)
