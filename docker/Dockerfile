# =============================================================================
# Confluent Replicator with AWS MSK IAM Authentication Support
# =============================================================================
# Base: Confluent Enterprise Replicator (Kafka Connect with Replicator plugin)
# Extras: aws-msk-iam-auth JAR, BTDS Decryption SMT
# =============================================================================

FROM confluentinc/cp-enterprise-replicator:7.7.1

USER root

# ---------------------------------------------------------------------------
# 1. Install the AWS MSK IAM Auth JAR (from plugins/)
# ---------------------------------------------------------------------------
COPY plugins/aws-msk-iam-auth/aws-msk-iam-auth-2.2.0-all.jar /tmp/msk-iam-auth.jar
RUN mkdir -p /usr/share/java/msk-iam-auth && \
    cp /tmp/msk-iam-auth.jar /usr/share/java/msk-iam-auth/ && \
    cp /tmp/msk-iam-auth.jar /usr/share/java/kafka/ && \
    cp /tmp/msk-iam-auth.jar /usr/share/java/kafka-connect-replicator/ && \
    rm /tmp/msk-iam-auth.jar

# ---------------------------------------------------------------------------
# 2. Install BTDS Decryption SMT (com.btds.Decryption)
# ---------------------------------------------------------------------------
COPY plugins/btds-encryption/smt-decryption-1.0-SNAPSHOT.jar /usr/share/confluent-hub-components/btds-encryption/

# ---------------------------------------------------------------------------
# 3. Install Debezium for ExtractNewRecordState SMT
# ---------------------------------------------------------------------------
RUN confluent-hub install --no-prompt debezium/debezium-connector-postgresql:2.5.4 || true

# ---------------------------------------------------------------------------
# 4. (Optional) AWS CLI for debugging
# ---------------------------------------------------------------------------
RUN microdnf install -y unzip && \
    curl -fSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip && \
    unzip -q /tmp/awscliv2.zip -d /tmp && \
    /tmp/aws/install && \
    rm -rf /tmp/awscliv2.zip /tmp/aws && \
    microdnf clean all

# ---------------------------------------------------------------------------
# 5. Entrypoint wrapper (patch bootstrap.servers for Confluent Cloud)
# ---------------------------------------------------------------------------
COPY docker/scripts/entrypoint-wrapper.sh /scripts/entrypoint-wrapper.sh
RUN chmod +x /scripts/entrypoint-wrapper.sh && \
    (chmod a+w /etc/kafka-connect/kafka-connect.properties /etc/kafka/connect-distributed.properties 2>/dev/null || true)

USER appuser
ENTRYPOINT ["/scripts/entrypoint-wrapper.sh"]
EXPOSE 8083

HEALTHCHECK --interval=30s --timeout=10s --retries=5 \
    CMD curl -f http://localhost:8083/connectors || exit 1
