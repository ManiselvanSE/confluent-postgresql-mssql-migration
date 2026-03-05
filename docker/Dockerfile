# Azure VM Replicator - Kafka Connect with Replicator
# Replicates from AWS MSK to Confluent Cloud
# Includes: AWS MSK IAM Auth, BTDS Encryption/Decryption SMT
#
# Plugins are mounted at runtime via docker-compose (see plugins/README.md)

FROM confluentinc/cp-kafka-connect:7.6.0

# Plugin path: Confluent hub + custom plugins (mounted at /plugins)
ENV CONNECT_PLUGIN_PATH="/usr/share/java,/usr/share/confluent-hub-components,/plugins"

# Create plugin directories (JARs mounted at runtime)
RUN mkdir -p /plugins/aws-msk-iam-auth /plugins/btds-encryption

USER root
RUN chown -R appuser:appuser /plugins
USER appuser

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:8083/connectors || exit 1
