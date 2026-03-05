# Confluent – Migration using Connector: PostgreSQL to MSSQL

Migration setup using **Confluent managed connectors** to replicate data from **PostgreSQL** to **MSSQL** database.

This project demonstrates end-to-end CDC (Change Data Capture) from PostgreSQL to MSSQL via Confluent Cloud, including flows through AWS MSK and the Replicator when applicable.

## Docker (Azure VM Replicator)

```bash
# Start
docker-compose -f docker/docker-compose.yml up -d

# Connector: create, status, pause, resume
curl -s http://localhost:8083/connectors/msk-to-confluent-cloud-replicator-encrypted/status
```

See [docker/README.md](docker/README.md) for full Docker and connector commands.

## Documentation

**[CDC Replication Architecture](docs/CDC_REPLICATION_ARCHITECTURE.md)** – Complete architecture guide including:

- High-level flow (PostgreSQL → Debezium → MSK → Replicator → Confluent Cloud → FMC SQL Server Sink → Azure SQL)
- Source database and topic message formats
- Configuration reference (Debezium, Replicator, SQL Server Sink)
- Encrypted vs decrypted topic formats
- Quick reference commands

## Plugins

The `plugins/` folder contains JARs for:

- **AWS MSK IAM Auth** – IAM authentication to MSK
- **BTDS Encryption SMT** – Field-level encryption/decryption

See `plugins/README.md` for how to obtain and add these JARs.

## Screenshots

Place screenshots in `docs/images/` and reference them in the documentation. See `docs/images/README.md` for the filename mapping.

## License

Internal use. See your organization's policies for distribution.
# confluent-postgresql-mssql-migration
