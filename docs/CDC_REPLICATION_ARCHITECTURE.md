# POC Setup: MSK (AWS) → Replicator (Azure VM) → Confluent Cloud

**Purpose**: POC setup demonstrating how data is replicated from MSK on AWS to Confluent Cloud via the Replicator running on an Azure VM. Includes end-to-end CDC from PostgreSQL RDS, with optional field-level encryption in transit.

**Last Updated**: March 2026

**Screenshots:** Place images in `docs/images/` and name them as referenced below. See `docs/images/README.md` for the mapping.

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Component Map](#2-component-map)
3. [Data Flow](#3-data-flow)
4. [Source Database (PostgreSQL)](#4-source-database-postgresql)
5. [Topic Message Format](#5-topic-message-format)
6. [Configuration Reference](#6-configuration-reference)
7. [Quick Reference Commands](#7-quick-reference-commands)
8. [IAM Authentication (AWS MSK)](#8-iam-authentication-aws-msk)
9. [Field-Level Encryption](#9-field-level-encryption)
10. [Message Envelope (Confluent Cloud)](#10-message-envelope-confluent-cloud)
11. [Docker – Azure VM Replicator](#11-docker--azure-vm-replicator)

---

## 1. Architecture Overview

### 1.1 High-Level Flow

```
┌─────────────────┐     ┌─────────────────────────┐     ┌─────────────┐     ┌─────────────────────┐     ┌──────────────────┐     ┌─────────────────────┐     ┌──────────────────┐
│ PostgreSQL RDS  │     │      EC2 (AWS)         │     │   AWS MSK   │     │  Azure VM / Docker   │     │ Confluent Cloud   │     │ FMC SQL Server      │     │  Azure SQL        │
│    (Source)     │     │ kafka-connect-worker   │     │  (Kafka)    │     │     Replicator       │     │                   │     │    Connector         │     │   Database        │
├─────────────────┤     ├─────────────────────────┤     ├─────────────┤     ├─────────────────────┤     ├──────────────────┤     ├─────────────────────┤     ├──────────────────┤
│ • public.       │ WAL │ • Kafka Connect        │ CDC │ Topic:      │ IAM │ • Consumes from MSK │ API │ • products        │ FMC │ • Consumes from CC   │ JDBC │ • products        │
│   products      │────▶│ • Debezium Connector   │────▶│ psgsrc_     │────▶│ • Produces to CC    │────▶│                   │────▶│ • Writes to SQL      │────▶│   table            │
│ • WAL=logical   │5432 │ • Optional: SMT Encrypt│9098 │   encrypt_  │9198 │ • Optional: SMT     │ key │                   │     │                     │     │                   │
│ • SSL/TLS       │     │   (Kryptonite/BTDS)    │     │   v1.*      │     │   Decrypt           │     │                   │     │                     │     │                   │
└─────────────────┘     └─────────────────────────┘     └─────────────┘     └─────────────────────┘     └──────────────────┘     └─────────────────────┘     └──────────────────┘
        │                              │                        │
        │ 5432 (SSL)                   │ 9098 (SASL_SSL + IAM)  │
        │ pgoutput                     │                        │
        └──────────────────────────────┴────────────────────────┘
                         VPC (AWS Region)
```

### 1.2 Downstream (Optional)

| Component | Role |
|-----------|------|
| **FMC SQL Server Sink** | Consumes CDC from Confluent Cloud → writes to SQL Server |
| **Azure SQL Server** | Final destination DB (products table) |

---

## 2. Component Map

| Component | Location | Role | Key Config |
|-----------|----------|------|------------|
| **RDS PostgreSQL** | AWS, private subnet | Source DB; `public.products` | `wal_level=logical`, `rds.logical_replication=1` |
| **EC2 kafka-connect-worker** | AWS, public subnet | Kafka Connect + Debezium | IAM role for MSKConnect |
| **Debezium Connector** | EC2 | CDC from PostgreSQL → MSK | `debezium-postgres-psgsrc` |
| **AWS MSK** | AWS, private subnet | Kafka cluster; 3 brokers | IAM auth, port 9098 (private), 9198 (public) |
| **Azure VM (Replicator)** | Azure | Kafka Connect + Replicator | AWS creds in `~/.aws/credentials` |
| **Replicator Connector** | Azure VM / Docker | MSK → Confluent Cloud | `msk-to-confluent-cloud-replicator` |
| **Confluent Cloud** | Cloud region | Destination Kafka | API key auth |
| **FMC SQL Server Sink** | Confluent Cloud (managed) | Consume CDC → write to SQL | |
| **Azure SQL Server** | Azure | Final destination DB | Table: products; JDBC/TLS |

---

## 3. Data Flow

| Stage | From | To | Protocol | Purpose |
|-------|------|-----|----------|---------|
| **①** | PostgreSQL RDS | Debezium | WAL (pgoutput), port 5432, SSL | CDC capture via logical replication |
| **②** | Debezium | AWS MSK | SASL_SSL + IAM, port 9098 | Produce CDC events to Kafka topics |
| **③** | Replicator | MSK | SASL_SSL + IAM, port 9198 | Consume from MSK (public endpoint) |
| **④** | Replicator | Confluent Cloud | SASL_SSL + API key | Produce to Confluent Cloud topics |
| **⑤** | FMC SQL Server Sink | Confluent Cloud | SASL_SSL | Consume CDC → write to Azure SQL |

---

## 4. Source Database (PostgreSQL)

### 4.1 `public.products` Table

The source table in PostgreSQL RDS. Debezium captures changes via logical replication (pgoutput).

#### Table Schema

| Column | Type | Notes |
|--------|------|-------|
| `id` | INTEGER | Primary key |
| `name` | VARCHAR | Product name |
| `category` | VARCHAR | Category |
| `price` | DECIMAL(10,2) | Price (nullable) |
| `stock_quantity` | INTEGER | Stock (nullable) |
| `last_updated` | TIMESTAMP | Last update time |

#### Verification Queries

```sql
-- All rows
SELECT * FROM products;

-- Row count
SELECT COUNT(*) FROM products;

-- Latest updated
SELECT * FROM products ORDER BY last_updated DESC;

-- Schema (psql)
\d public.products
```

#### Sample Data (Representative)

| id | name | category | price | stock_quantity | last_updated |
|----|------|----------|-------|----------------|--------------|
| 1 | Laptop | Electronics | 1150.00 | 10 | 2026-02-26 19:13:04 |
| 2 | Smartphone | Electronics | 800.00 | 30 | 2026-02-26 19:13:04 |
| 3 | Desk Chair | Furniture | 150.00 | 20 | 2026-02-26 19:13:04 |
| 33 | Wireless Headphones | Electronics | 79.99 | 50 | 2026-03-04 15:40:28 |

**Note:** `price` and `stock_quantity` may be NULL for some rows. The CDC pipeline propagates all columns to Kafka and SQL Server.

![PostgreSQL source products table](images/postgres-products-table.png)

---

## 5. Topic Message Format

### 5.1 `public.products` Topic

#### Encrypted Topic (MSK)

When consuming from the encrypted topic in MSK (e.g. `psgsrc_encrypt_v1.public.products`), the payload appears as base64-encoded ciphertext. The Debezium SMT encrypts the value before producing to Kafka.

**Raw message structure:**

```json
{"schema":null,"payload":"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"}
```

The `payload` field contains base64-encoded ciphertext. **Decryption happens in the Replicator SMT** before producing to Confluent Cloud. The SQL Server Sink and downstream consumers never see the encrypted form.

**Consume from encrypted topic (MSK):**

```bash
./bin/kafka-console-consumer.sh \
  --bootstrap-server <MSK_PUBLIC_BOOTSTRAP_SERVERS> \
  --consumer.config ~/msk-client.properties \
  --topic psgsrc_encrypt_v1.public.products \
  --from-beginning \
  --max-messages 5
```

---

#### Decrypted Topic (Confluent Cloud)

After the Replicator (with `ExtractNewRecordState` SMT), messages in Confluent Cloud use a flattened structure. The SQL Server Sink consumes this format.

#### Message Key

```json
{"id": 19}
```

The key contains the primary key field(s) from the source table.

#### Message Value – Insert/Update

```json
{
  "id": 19,
  "name": "Wireless Headphones",
  "category": "Electronics",
  "price": 79.99,
  "stock_quantity": 50,
  "last_updated": 1730138753808
}
```

#### Message Value – Delete Event

For a delete, the value includes `__deleted` and nulls for other fields:

```json
{
  "id": 19,
  "name": null,
  "category": null,
  "price": null,
  "stock_quantity": null,
  "last_updated": 0,
  "__deleted": "true"
}
```

#### Tombstone Message Sequence

A delete operation produces **two consecutive messages** in the topic:

| Offset | Key | Value | Description |
|--------|-----|-------|-------------|
| **6** | `{"id": 19}` | `{"id": 19, "name": null, "category": null, "price": null, ...}` | Delete event – payload with `__deleted: "true"` and nulls |
| **7** | `{"id": 19}` | `null` | **Tombstone** – signals logical delete for log compaction |

![Tombstone message detail – Confluent Cloud Messages view](images/tombstone-message-detail.png)

![Tombstone reference – message list showing value = null at offset 7](images/tombstone-reference.png)

The tombstone (value = `null`) has the same key as the deleted record. It enables Kafka log compaction to purge older versions. The SQL Server Sink uses `delete.on.null` to perform a DELETE when it sees a tombstone.

| Event Type | Key | Value |
|------------|-----|-------|
| **Insert** | `{"id": N}` | Full row with field values |
| **Update** | `{"id": N}` | Full row with updated values |
| **Delete** | `{"id": N}` | Row with `__deleted: "true"` and nulls, then tombstone (`null`) |

**Schema Registry:** Messages use JSON Schema (JSON_SR); Schema ID is stored in the Confluent Cloud message envelope.

---

### 5.2 SQL Server `products` Table

The SQL Server Sink writes to the target table. Schema includes an optional `_deleted` flag for soft-delete tracking.

#### Table Schema

| Column | Type | Notes |
|--------|------|-------|
| `id` | INT | Primary key |
| `name` | NVARCHAR | Product name |
| `category` | NVARCHAR | Category |
| `price` | DECIMAL(10,2) | Price |
| `stock_quantity` | INT | Stock |
| `last_updated` | TIMESTAMP | Last update |
| `_deleted` | BIT/BOOLEAN | Soft-delete flag (`false` for active rows) |

#### Verification Queries

```sql
-- Row count
SELECT COUNT(*) FROM products;

-- Latest rows (ordered by id desc)
SELECT * FROM products ORDER BY id DESC;

-- Active rows only (if using soft-delete)
SELECT * FROM products WHERE _deleted = 0;
```

**Delete verification:** After a DELETE in PostgreSQL, the tombstone in Kafka triggers a DELETE in SQL Server. The row is removed; it will not appear in `SELECT * FROM products`. A successful delete reduces the row count.

![SQL Server products table – DbVisualizer](images/sql-server-products-table.png)

---

## 6. Configuration Reference

### 6.1 Kafka Connect (EC2) – Distributed Properties

Full template: `config/connect-distributed.properties.example`. Copy to `connect-distributed.properties` and replace placeholders.

| Placeholder | Purpose |
|-------------|---------|
| `<MSK_BOOTSTRAP_SERVERS>` | MSK broker list (e.g. `b-1.xxx.kafka.region.amazonaws.com:9098,b-2.xxx:9098,b-3.xxx:9098`) |
| `<PLUGIN_PATH>` | Path to plugins (e.g. `/home/ec2-user/kafka-connect/plugins`) |

```properties
# Kafka Connect distributed mode
bootstrap.servers=<MSK_BOOTSTRAP_SERVERS>

# Group and cluster
group.id=connect-cluster
config.storage.topic=connect-config-v2
offset.storage.topic=connect-offsets-v2
status.storage.topic=connect-status-v2
# ... (see config/connect-distributed.properties.example)
```

---

### 6.2 Debezium Connector (with SMT Encryption)

```json
{
  "name": "debezium-postgres-psgsrc-encrypt-v1",
  "config": {
    "connector.class": "io.debezium.connector.postgresql.PostgresConnector",
    "database.hostname": "<RDS_HOST>",
    "database.port": "5432",
    "database.user": "<DB_USER>",
    "database.password": "<DB_PASSWORD>",
    "database.dbname": "<DB_NAME>",
    "database.server.name": "psgsrc",
    "topic.prefix": "psgsrc_encrypt_v1",
    "table.include.list": "public.products",
    "plugin.name": "pgoutput",
    "database.sslmode": "verify-full",
    "database.sslrootcert": "/certs/global-bundle.pem",
    "producer.override.security.protocol": "SASL_SSL",
    "producer.override.sasl.mechanism": "AWS_MSK_IAM",
    "producer.override.sasl.jaas.config": "software.amazon.msk.auth.iam.IAMLoginModule required;",
    "producer.override.sasl.client.callback.handler.class": "software.amazon.msk.auth.iam.IAMClientCallbackHandler",
    "key.converter": "org.apache.kafka.connect.json.JsonConverter",
    "key.converter.schemas.enable": "true",
    "value.converter": "org.apache.kafka.connect.json.JsonConverter",
    "value.converter.schemas.enable": "true",
    "publication.name": "dbz_publication_products_v1",
    "slot.name": "debezium_psgsrc_products_v1",
    "snapshot.mode": "initial",
    "topic.creation.default.replication.factor": "2",
    "topic.creation.default.partitions": "6",
    "time.precision.mode": "connect",
    "transforms": "encrypt",
    "transforms.encrypt.type": "com.btds.Encryption",
    "transforms.encrypt.key": "<BASE64_ENCRYPTION_KEY>"
  }
}
```

**Placeholders:**
- `<RDS_HOST>` – RDS endpoint hostname
- `<DB_USER>` – Database username
- `<DB_PASSWORD>` – Database password (use config provider or secrets manager)
- `<DB_NAME>` – Database name
- `<BASE64_ENCRYPTION_KEY>` – Base64-encoded encryption key for SMT

---

### 6.3 Replicator Connector (with SMT Decryption)

```json
{
  "name": "msk-to-confluent-cloud-replicator-encrypted",
  "config": {
    "connector.class": "io.confluent.connect.replicator.ReplicatorSourceConnector",
    "tasks.max": "1",
    "topic.whitelist": "psgsrc_encrypt_v1.public.products",
    "topic.rename.format": "${topic}",
    "src.kafka.bootstrap.servers": "<MSK_BOOTSTRAP_SERVERS>",
    "src.kafka.security.protocol": "SASL_SSL",
    "src.kafka.sasl.mechanism": "AWS_MSK_IAM",
    "src.kafka.sasl.jaas.config": "software.amazon.msk.auth.iam.IAMLoginModule required;",
    "src.kafka.sasl.client.callback.handler.class": "software.amazon.msk.auth.iam.IAMClientCallbackHandler",
    "src.kafka.ssl.endpoint.identification.algorithm": "https",
    "src.consumer.group.id": "replicator-source-consumer-v1",
    "src.consumer.auto.offset.reset": "earliest",

    "src.key.converter": "org.apache.kafka.connect.json.JsonConverter",
    "src.key.converter.schemas.enable": "true",
    "src.value.converter": "org.apache.kafka.connect.json.JsonConverter",
    "src.value.converter.schemas.enable": "true",

    "dest.kafka.bootstrap.servers": "<CCLOUD_BOOTSTRAP_SERVERS>",
    "dest.kafka.security.protocol": "SASL_SSL",
    "dest.kafka.sasl.mechanism": "PLAIN",
    "dest.kafka.sasl.jaas.config": "org.apache.kafka.common.security.plain.PlainLoginModule required username='<CCLOUD_API_KEY>' password='<CCLOUD_API_SECRET>';",
    "dest.kafka.ssl.endpoint.identification.algorithm": "https",
    "confluent.topic.replication.factor": "3",
    "dest.topic.replication.factor": "3",
    "topic.auto.create": "true",
    "topic.preserve.partitions": "true",
    "topic.config.sync": "false",
    "offset.timestamps.commit": "false",
    "offset.topic.commit": "true",
    "provenance.header.enable": "true",

    "header.converter": "org.apache.kafka.connect.converters.ByteArrayConverter",

    "key.converter": "io.confluent.connect.json.JsonSchemaConverter",
    "key.converter.schema.registry.url": "<SCHEMA_REGISTRY_URL>",
    "key.converter.basic.auth.credentials.source": "USER_INFO",
    "key.converter.basic.auth.user.info": "<SR_API_KEY>:<SR_API_SECRET>",

    "value.converter": "io.confluent.connect.json.JsonSchemaConverter",
    "value.converter.schema.registry.url": "<SCHEMA_REGISTRY_URL>",
    "value.converter.basic.auth.credentials.source": "USER_INFO",
    "value.converter.basic.auth.user.info": "<SR_API_KEY>:<SR_API_SECRET>",

    "transforms": "decrypt,extractNewRecordState",
    "transforms.decrypt.type": "com.btds.Decryption",
    "transforms.decrypt.key": "<BASE64_ENCRYPTION_KEY>",

    "transforms.extractNewRecordState.type": "io.debezium.transforms.ExtractNewRecordState",
    "transforms.extractNewRecordState.flatten.struct.field": "payload",
    "transforms.extractNewRecordState.delete.tombstone.handling.mode": "rewrite-with-tombstone",

    "errors.tolerance": "none",
    "errors.log.enable": "true",
    "errors.log.include.messages": "true"
  }
}
```

**Placeholders:**
- `<MSK_BOOTSTRAP_SERVERS>` – MSK public bootstrap (e.g. `b-1-public.<cluster>.kafka.<region>.amazonaws.com:9198,...`)
- `<CCLOUD_BOOTSTRAP_SERVERS>` – Confluent Cloud bootstrap URL
- `<CCLOUD_API_KEY>` – Confluent Cloud API key
- `<CCLOUD_API_SECRET>` – Confluent Cloud API secret
- `<SCHEMA_REGISTRY_URL>` – Confluent Schema Registry URL
- `<SR_API_KEY>` – Schema Registry API key
- `<SR_API_SECRET>` – Schema Registry API secret
- `<BASE64_ENCRYPTION_KEY>` – Same key used in Debezium encrypt SMT

---

### 6.4 SQL Server Sink Connector (Confluent Cloud FMC)

Consumes CDC from Confluent Cloud topics and writes to Microsoft SQL Server / Azure SQL.

#### Basic Configuration

| Setting | Value | Notes |
|---------|-------|-------|
| **Connector** | Microsoft SQL Server Sink | Confluent Cloud Fully Managed Connector |
| **Topics** | `psgsrc_encrypt_v1.public.products` | Match Replicator output topic |
| **Connection host** | `<SQL_SERVER_HOST>` | Azure SQL: `<server>.database.windows.net` |
| **Connection port** | `1433` | Default SQL Server port |
| **Connection user** | `<SQL_USER>` | Must have `db_datareader` and `db_datawriter` |
| **Connection password** | `<SQL_PASSWORD>` | Use secrets manager in production |
| **Database name** | `<DATABASE_NAME>` | Target database |
| **SSL mode** | `require` | Required for Azure SQL |
| **Input Kafka record value format** | `JSON_SR` | Schema Registry required |
| **Input Kafka record key format** | `JSON_SR` | Schema Registry required |
| **Insert mode** | `UPSERT` | Idempotent inserts/updates |
| **PK mode** | `record_key` | Use record key for primary key |
| **Auto create table** | `true` | Creates tables if they do not exist |

![SQL Server Sink – Advanced configuration](images/sql-server-sink-advanced-config.png)

#### Advanced Configuration

| Category | Setting | Value |
|----------|---------|-------|
| **Converter** | Value Converter Schema ID Deserializer | `io.confluent.kafka.serializers.schema.id.DualSchemaIdDeserializer` |
| | Value Converter Reference Subject Name Strategy | `DefaultReferenceSubjectNameStrategy` |
| | Key Converter Schema ID Deserializer | `io.confluent.kafka.serializers.schema.id.DualSchemaIdDeserializer` |
| | Value Converter Decimal Format | `BASE64` |
| | Value Converter Value Subject Name Strategy | `TopicNameStrategy` |
| | Key Converter Key Subject Name Strategy | `TopicNameStrategy` |
| | Value Converter Flatten Singleton Unions | `false` |
| **Error Handling** | Errors Tolerance | `all` |
| | Value Converter Ignore Default For Nullables | `false` |
| | Enable Connector Auto-restart | `true` |
| | Delete on null | `true` |
| **Polling** | Schema context | `default` |
| | Max poll interval (ms) | `300000` (5 minutes) |
| | Max poll records | `500` |
| **Database** | Auto create table | `true` |
| | Auto add columns | `false` |
| | Database timezone | `UTC` |
| | Table name format | `${topic}` |
| | Timezone used for Date | `DB_TIMEZONE` |
| | Timestamp Precision Mode | `microseconds` |
| | Table types | `TABLE` |
| | PK mode | `record_key` |
| | When to quote SQL identifiers | `ALWAYS` |
| | Max rows per batch | `3000` |
| | Date Calendar System | `LEGACY` |

#### Transforms – TopicRegexRouter

Use `TopicRegexRouter` to map Debezium topic names (e.g. `psgsrc_encrypt_v1.public.products`) to simple table names (e.g. `products`).

| Setting | Value |
|---------|-------|
| **Transform Name** | `transform_0` |
| **Transform Type** | `io.confluent.connect.cloud.transforms.TopicRegexRouter` |
| **regex** | `([^\.]*).([^\.]*).([^\.]*)` |
| **replacement** | `$3` |

**Behavior:** The regex captures three dot-separated segments. `$3` keeps only the third (table name).

| Source Topic | Result |
|--------------|--------|
| `psgsrc_encrypt_v1.public.products` | `products` |
| `psgsrc.public.products` | `products` |

With `table.name.format` set to `${topic}`, the sink uses these simplified names for SQL Server tables.

#### Placeholders

| Placeholder | Purpose |
|-------------|---------|
| `<SQL_SERVER_HOST>` | SQL Server hostname (Azure: `<server>.database.windows.net`) |
| `<SQL_USER>` | SQL Server username |
| `<SQL_PASSWORD>` | SQL Server password |
| `<DATABASE_NAME>` | Target database name |

**Note:** Topics must be in JSON Schema format (JSON_SR). The Replicator must use `JsonSchemaConverter` for key and value so the Sink can deserialize correctly.

---

## 7. Quick Reference Commands

### 7.1 Connect to RDS (from EC2)

```bash
export RDSHOST="<RDS_ENDPOINT>"
psql "host=$RDSHOST port=5432 dbname=postgres user=<DB_USER> sslmode=verify-full sslrootcert=/certs/global-bundle.pem" -W
```

### 7.2 Sample Insert (Products Table)

```sql
INSERT INTO products (id, name, category, price, stock_quantity, last_updated)
VALUES (34, 'Wireless Headphones', 'Electronics', 79.99, 50, NOW());
```

### 7.3 Consume from MSK (Encrypted Topic)

```bash
./bin/kafka-console-consumer.sh \
  --bootstrap-server <MSK_PUBLIC_BOOTSTRAP_SERVERS> \
  --consumer.config ~/msk-client.properties \
  --topic psgsrc_encrypt_v1.public.products \
  --from-beginning \
  --max-messages 5
```

**Note:** Encrypted payloads appear as base64-encoded strings. Decryption happens in the Replicator SMT before producing to Confluent Cloud.

### 7.4 SSH to EC2 (Kafka Connect Worker)

```bash
ssh -i "<PEM_KEY_PATH>" ec2-user@<EC2_PUBLIC_IP_OR_HOSTNAME>
```

### 7.5 SSH to Azure VM (Replicator)

```bash
ssh -i "<PEM_KEY_PATH>" azureuser@<AZURE_VM_IP>
```

### 7.6 Docker – Replicator (Azure VM)

```bash
# Start
docker-compose -f docker/docker-compose.yml up -d

# Stop
docker-compose -f docker/docker-compose.yml down

# Restart
docker-compose -f docker/docker-compose.yml restart replicator

# Logs
docker-compose -f docker/docker-compose.yml logs -f replicator
```

### 7.7 Connector REST API (Replicator)

Base URL: `http://localhost:8083`. Connector name: `msk-to-confluent-cloud-replicator-encrypted`.

| Action | Command |
|--------|---------|
| Create | `curl -s -X POST -H "Content-Type: application/json" -d @config/replicator-connector.json http://localhost:8083/connectors` |
| List | `curl -s http://localhost:8083/connectors` |
| Status | `curl -s http://localhost:8083/connectors/msk-to-confluent-cloud-replicator-encrypted/status` |
| Pause | `curl -s -X PUT http://localhost:8083/connectors/msk-to-confluent-cloud-replicator-encrypted/pause` |
| Resume | `curl -s -X PUT http://localhost:8083/connectors/msk-to-confluent-cloud-replicator-encrypted/resume` |
| Delete | `curl -s -X DELETE http://localhost:8083/connectors/msk-to-confluent-cloud-replicator-encrypted` |

---

## 8. IAM Authentication (AWS MSK)

AWS MSK supports IAM-based authentication instead of static SASL credentials. The pipeline uses IAM for both the Kafka Connect worker (EC2) and the Replicator (Azure VM).

### 8.1 How IAM Auth Works

| Aspect | Details |
|--------|---------|
| **Mechanism** | SASL mechanism `AWS_MSK_IAM` with `IAMLoginModule` |
| **Credentials** | Short-lived SigV4 signatures derived from IAM credentials |
| **No static secrets** | No username/password stored; IAM role or access keys used |
| **Ports** | 9098 (private VPC), 9198 (public) – both SASL_SSL |

### 8.2 Required IAM Permissions

The IAM principal (user, role, or EC2 instance profile) must have:

```json
{
  "Effect": "Allow",
  "Action": [
    "kafka-cluster:Connect",
    "kafka-cluster:DescribeCluster",
    "kafka-cluster:DescribeTopic",
    "kafka-cluster:ReadData",
    "kafka-cluster:WriteData",
    "kafka-cluster:CreateTopic",
    "kafka-cluster:DescribeGroup",
    "kafka-cluster:AlterGroup"
  ],
  "Resource": [
    "arn:aws:kafka:<region>:<account>:cluster/<cluster-name>/*",
    "arn:aws:kafka:<region>:<account>:topic/<cluster-name>/*",
    "arn:aws:kafka:<region>:<account>:group/<cluster-name>/*"
  ]
}
```

### 8.3 Kafka Connect Configuration

```properties
security.protocol=SASL_SSL
sasl.mechanism=AWS_MSK_IAM
sasl.jaas.config=software.amazon.msk.auth.iam.IAMLoginModule required;
sasl.client.callback.handler.class=software.amazon.msk.auth.iam.IAMClientCallbackHandler
```

The `aws-msk-iam-auth` JAR provides `IAMLoginModule` and `IAMClientCallbackHandler`. Credentials are resolved in this order:

1. **Environment:** `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`
2. **Shared credentials:** `~/.aws/credentials`
3. **Instance profile:** EC2/ECS task role (no config needed)
4. **Container credentials:** ECS task role

### 8.4 Azure VM – Credential Setup

The Replicator runs on an Azure VM and consumes from MSK. It cannot use an EC2 instance profile. Options:

| Method | Use Case |
|--------|----------|
| **`~/.aws/credentials`** | Mounted into Docker; IAM user access keys |
| **Environment variables** | `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION` |
| **IAM role for Azure** | If using Azure Arc or federated identity to AWS |

**Security:** Use IAM user with minimal permissions; rotate keys regularly. Prefer IAM roles over long-lived access keys when possible.

---

## 9. Field-Level Encryption

The pipeline supports optional field-level encryption for CDC payloads between Debezium and the Replicator.

### 9.1 Flow

```
Debezium (Encrypt SMT) → MSK (encrypted payload) → Replicator (Decrypt SMT) → Confluent Cloud (plain)
```

| Stage | Format | Location |
|-------|--------|----------|
| **Before encrypt** | Debezium envelope with `payload` | In-memory, Debezium |
| **After encrypt** | `payload` = base64 ciphertext | MSK topic |
| **After decrypt** | Debezium envelope, then flattened | Replicator → Confluent Cloud |

### 9.2 Encryption SMT (Debezium)

- **Class:** `com.btds.Encryption`
- **Input:** Full Connect record (key, value, headers)
- **Output:** Value `payload` field replaced with base64-encoded ciphertext
- **Key:** Base64-encoded symmetric key; must match Decrypt SMT

### 9.3 Decryption SMT (Replicator)

- **Class:** `com.btds.Decryption`
- **Input:** Connect record with encrypted `payload`
- **Output:** `payload` decrypted back to Debezium envelope
- **Key:** Same base64 key as Encryption SMT

### 9.4 Key Management

| Requirement | Notes |
|-------------|-------|
| **Key symmetry** | Same key on Debezium and Replicator |
| **Storage** | Use AWS Secrets Manager, Parameter Store, or FileConfigProvider |
| **Rotation** | Plan for key rotation; may require dual-key support |
| **Never commit** | Keys must not be in version control |

### 9.5 Encrypted vs Plain Topics

| Topic | Encrypted? | Consumer |
|-------|------------|----------|
| `psgsrc_encrypt_v1.public.products` | Yes | Replicator (decrypts) |
| `psgsrc.public.products` | No | Plain Debezium format |

---

## 10. Message Envelope (Confluent Cloud)

### 10.1 Debezium Envelope (Source)

Before transforms, Debezium produces a wrapped envelope:

```json
{
  "schema": { ... },
  "payload": {
    "before": null,
    "after": { "id": 19, "name": "Wireless Headphones", ... },
    "source": {
      "version": "2.5.0",
      "connector": "postgresql",
      "name": "psgsrc",
      "ts_ms": 1730138753808,
      "db": "postgres",
      "table": "products"
    },
    "op": "c",
    "ts_ms": 1730138753808
  }
}
```

| Field | Purpose |
|-------|---------|
| `before` | Previous row state (null for INSERT) |
| `after` | New row state |
| `source` | Connector metadata (db, table, ts_ms) |
| `op` | Operation: `c`=create, `u`=update, `d`=delete |
| `ts_ms` | Event timestamp |

### 10.2 Confluent Cloud Envelope (Confluent Wire Format)

Confluent Cloud uses Schema Registry for serialization. Messages include:

| Component | Description |
|-----------|-------------|
| **Magic byte** | Schema format identifier |
| **Schema ID** | 4-byte schema ID from Schema Registry |
| **Payload** | Serialized JSON (or Avro, Protobuf) |

The schema ID is stored in the message envelope; consumers use it to fetch the schema from Schema Registry for deserialization.

### 10.3 After ExtractNewRecordState

The Replicator uses `ExtractNewRecordState` to flatten the Debezium envelope:

| Input | Output |
|-------|--------|
| `payload.after` | Becomes the message value |
| `payload.before` | Used for delete detection |
| `source`, `op` | Removed or in headers |

**Insert/Update value:**

```json
{
  "id": 19,
  "name": "Wireless Headphones",
  "category": "Electronics",
  "price": 79.99,
  "stock_quantity": 50,
  "last_updated": 1730138753808
}
```

**Delete:** Tombstone (value = `null`) with same key; optional `__deleted` payload before tombstone.

### 10.4 Headers (Provenance)

With `provenance.header.enable=true`, the Replicator adds headers:

| Header | Purpose |
|--------|---------|
| `confluent.replicator.source.topic` | Source topic name |
| `confluent.replicator.source.partition` | Source partition |
| `confluent.replicator.source.offset` | Source offset |

---

## 11. Docker – Azure VM Replicator

The Replicator runs in Docker on an Azure VM. Sensitive values are omitted; use environment variables or secrets.

### 11.1 Files

| File | Purpose |
|------|---------|
| `docker/Dockerfile` | Kafka Connect image with plugin directories |
| `docker/docker-compose.yml` | Replicator service definition |
| `docker/.env.example` | Placeholder env vars (copy to `.env`) |

### 11.2 Dockerfile

```dockerfile
FROM confluentinc/cp-kafka-connect:7.6.0
ENV CONNECT_PLUGIN_PATH="/usr/share/java,/usr/share/confluent-hub-components,/plugins"
RUN mkdir -p /plugins/aws-msk-iam-auth /plugins/btds-encryption
```

Plugins are mounted at runtime via `docker-compose`.

### 11.3 Docker Compose

```yaml
services:
  replicator:
    build:
      context: ..
      dockerfile: docker/Dockerfile
    ports:
      - "8083:8083"
    environment:
      CONNECT_BOOTSTRAP_SERVERS: ${CCLOUD_BOOTSTRAP_SERVERS}
      CONNECT_REST_ADVERTISED_HOST_NAME: replicator
      # ... (see docker/docker-compose.yml)
    volumes:
      - ../plugins:/plugins:ro
      - ~/.aws:/home/appuser/.aws:ro
```

### 11.4 Run

```bash
# 1. Add plugin JARs to plugins/aws-msk-iam-auth/ and plugins/btds-encryption/
# 2. Create .env from docker/.env.example
# 3. Ensure ~/.aws/credentials has MSK IAM access

cd /path/to/bluesquared
docker-compose -f docker/docker-compose.yml up -d
```

### 11.5 Register Replicator Connector

After the container is up, create the Replicator connector via REST (see [§6.3](#63-replicator-connector-with-smt-decryption)). Use config provider or env vars for secrets.

---

## Security Notes

- **Never commit** API keys, passwords, or encryption keys to version control.
- Use **AWS Secrets Manager**, **Parameter Store**, or Kafka Connect **FileConfigProvider** for sensitive config.
- Ensure **encryption keys** are identical on Debezium (encrypt) and Replicator (decrypt) sides.
- RDS and MSK should be in **private subnets**; EC2 in public subnet with appropriate security groups.
- Use **IAM roles** for MSK authentication instead of static credentials where possible.

---

## Related Documentation

- [Debezium PostgreSQL Connector](https://debezium.io/documentation/reference/stable/connectors/postgresql.html)
- [Confluent Replicator](https://docs.confluent.io/platform/current/multi-dc-deployments/replicator/index.html)
- [AWS MSK IAM Authentication](https://docs.aws.amazon.com/msk/latest/developerguide/iam-access-control.html)
- [Microsoft SQL Server Sink Connector (Confluent Cloud)](https://docs.confluent.io/cloud/current/connectors/cc-microsoft-sql-server-sink.html)
