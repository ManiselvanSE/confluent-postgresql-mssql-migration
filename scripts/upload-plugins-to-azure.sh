#!/bin/bash
# Upload plugins to Azure VM for Replicator
# Usage: SSH_KEY=/path/to/key.pem VM_HOST=azureuser@<VM_IP> ./scripts/upload-plugins-to-azure.sh

SSH_KEY="${SSH_KEY:?Set SSH_KEY=/path/to/key.pem}"
VM_HOST="${VM_HOST:?Set VM_HOST=azureuser@<VM_IP>}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "Uploading plugins to $VM_HOST..."
scp -i "$SSH_KEY" -o StrictHostKeyChecking=no -r "$PROJECT_ROOT/plugins" "$VM_HOST:~/"
echo "Done. Verify with: ssh -i $SSH_KEY $VM_HOST 'find ~/plugins -name \"*.jar\"'"
