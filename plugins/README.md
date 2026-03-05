# Kafka Connect Plugins

This folder contains JARs required for the CDC replication pipeline:

1. **AWS MSK IAM Auth** – IAM authentication to MSK
2. **BTDS Encryption SMT** – Field-level encryption/decryption for Kafka messages

## Required JARs

| Plugin | Purpose | Location in `plugin.path` |
|--------|---------|---------------------------|
| `aws-msk-iam-auth-*.jar` | SASL_SSL + IAM auth to MSK | `plugins/aws-msk-iam-auth/` |
| `btds-encryption-smt-*.jar` | `com.btds.Encryption` / `com.btds.Decryption` SMT | `plugins/btds-encryption/` |

## How to Obtain

### AWS MSK IAM Auth

- **Maven:** `software.amazon.msk:aws-msk-iam-auth`
- **GitHub:** [aws/aws-msk-iam-auth](https://github.com/aws/aws-msk-iam-auth/releases)
- **Maven Central:** [aws-msk-iam-auth](https://central.sonatype.com/artifact/software.amazon.msk/aws-msk-iam-auth)

Download the JAR and place it in `plugins/aws-msk-iam-auth/` (with its dependencies, or use the shaded/fat JAR if available).

### BTDS Encryption SMT

The encryption SMT (`com.btds.Encryption`, `com.btds.Decryption`) is a custom Kafka Connect Single Message Transform. Obtain the JAR from your provider and place it in `plugins/btds-encryption/`.

## Kafka Connect `plugin.path`

Configure Kafka Connect to use this folder:

```properties
plugin.path=/path/to/plugins
```

Each plugin must be in its own subdirectory. Example layout:

```
plugins/
├── aws-msk-iam-auth/
│   └── aws-msk-iam-auth-2.0.0.jar
├── btds-encryption/
│   └── btds-encryption-smt-1.0.0.jar
├── debezium-connector-postgres/
│   └── debezium-connector-postgres-2.x.jar
└── README.md
```

## Replicator (Azure VM)

The Replicator also needs these plugins in its Docker image or runtime:

- `aws-msk-iam-auth` – to consume from MSK
- `btds-encryption` – for the Decryption SMT

Copy the same JARs into the Replicator's plugin path.
