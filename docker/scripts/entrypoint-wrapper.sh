#!/bin/bash
# Fix bootstrap.servers in Connect properties (cp-enterprise-replicator uses localhost:9092 by default)
# License validation needs correct bootstrap.servers; CONNECT_BOOTSTRAP_SERVERS from env
set -e
BOOTSTRAP="${CONNECT_BOOTSTRAP_SERVERS:-${BOOTSTRAP_SERVERS}}"
if [ -n "$BOOTSTRAP" ]; then
  for f in /etc/kafka-connect/kafka-connect.properties \
           /etc/kafka/connect-distributed.properties /etc/kafka/kafka.properties \
           /etc/confluent/docker/connect-distributed.properties; do
    if [ -f "$f" ] && grep -q "bootstrap.servers=" "$f"; then
      sed -i.bak "s|bootstrap.servers=.*|bootstrap.servers=$BOOTSTRAP|" "$f"
      echo "Patched bootstrap.servers=$BOOTSTRAP in $f"
    fi
  done
  for dir in /etc/kafka /etc/kafka-connect; do
    find "$dir" -maxdepth 1 -name "*.properties" 2>/dev/null | while read -r f; do
      if grep -q "bootstrap.servers=" "$f" 2>/dev/null; then
        sed -i.bak "s|bootstrap.servers=.*|bootstrap.servers=$BOOTSTRAP|" "$f"
        echo "Patched bootstrap.servers=$BOOTSTRAP in $f"
      fi
    done
  done
fi
exec /etc/confluent/docker/run
