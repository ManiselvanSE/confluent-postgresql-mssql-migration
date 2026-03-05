# POC Setup: MSK (AWS) → Replicator (Azure VM) → Confluent Cloud

POC setup demonstrating how data is replicated from AWS MSK to Confluent Cloud via the Replicator running on an Azure VM, with end-to-end CDC from PostgreSQL RDS to Azure SQL.

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
