#!/usr/bin/env bash

set -euo pipefail

# Talos Secrets Extractor for 1Password
# Extracts secrets from talosctl gen secrets output and formats for 1Password

if [[ $# -ne 2 ]]; then
    echo "Usage: $0 <secrets-file> <cluster-name>"
    echo ""
    echo "Example:"
    echo "  talosctl gen secrets -o /tmp/infra-secrets.yaml"
    echo "  $0 /tmp/infra-secrets.yaml infra"
    echo ""
    echo "This will output 1Password CLI commands to create secrets."
    exit 1
fi

SECRETS_FILE="$1"
CLUSTER_NAME="$2"

if [[ ! -f "${SECRETS_FILE}" ]]; then
    echo "Error: Secrets file not found: ${SECRETS_FILE}"
    exit 1
fi

if ! command -v yq &> /dev/null; then
    echo "Error: yq is required but not installed."
    echo "Install with: brew install yq"
    exit 1
fi

echo "===================================="
echo "Talos Secrets Extractor"
echo "===================================="
echo ""
echo "Cluster: ${CLUSTER_NAME}"
echo "Source: ${SECRETS_FILE}"
echo ""

# Extract secrets using yq
echo "Extracting secrets..."

MACHINE_TOKEN=$(yq eval '.trustdinfo.token' "${SECRETS_FILE}")
MACHINE_CA_CRT=$(yq eval '.certs.os.crt' "${SECRETS_FILE}")
MACHINE_CA_KEY=$(yq eval '.certs.os.key' "${SECRETS_FILE}")

CLUSTER_ID=$(yq eval '.cluster.id' "${SECRETS_FILE}")
CLUSTER_SECRET=$(yq eval '.cluster.secret' "${SECRETS_FILE}")
CLUSTER_TOKEN=$(yq eval '.secrets.bootstraptoken' "${SECRETS_FILE}")
CLUSTER_CA_CRT=$(yq eval '.certs.k8s.crt' "${SECRETS_FILE}")
CLUSTER_CA_KEY=$(yq eval '.certs.k8s.key' "${SECRETS_FILE}")
CLUSTER_AGGREGATORCA_CRT=$(yq eval '.certs.k8saggregator.crt' "${SECRETS_FILE}")
CLUSTER_AGGREGATORCA_KEY=$(yq eval '.certs.k8saggregator.key' "${SECRETS_FILE}")
CLUSTER_SERVICEACCOUNT_KEY=$(yq eval '.certs.k8sserviceaccount.key' "${SECRETS_FILE}")
CLUSTER_ETCD_CA_CRT=$(yq eval '.certs.etcd.crt' "${SECRETS_FILE}")
CLUSTER_ETCD_CA_KEY=$(yq eval '.certs.etcd.key' "${SECRETS_FILE}")
CLUSTER_SECRETBOXENCRYPTIONSECRET=$(yq eval '.secrets.secretboxencryptionsecret' "${SECRETS_FILE}")

echo "✓ Secrets extracted successfully"
echo ""

# Generate 1Password CLI commands
echo "===================================="
echo "1Password CLI Commands"
echo "===================================="
echo ""
echo "# Create 1Password item for ${CLUSTER_NAME}-talos"
echo "op item create \\"
echo "  --category=login \\"
echo "  --title=\"${CLUSTER_NAME}-talos\" \\"
echo "  --vault=\"Prod\" \\"
echo "  \"MACHINE_TOKEN[password]=${MACHINE_TOKEN}\" \\"
echo "  \"MACHINE_CA_CRT[password]=${MACHINE_CA_CRT}\" \\"
echo "  \"MACHINE_CA_KEY[password]=${MACHINE_CA_KEY}\" \\"
echo "  \"CLUSTER_ID[password]=${CLUSTER_ID}\" \\"
echo "  \"CLUSTER_SECRET[password]=${CLUSTER_SECRET}\" \\"
echo "  \"CLUSTER_TOKEN[password]=${CLUSTER_TOKEN}\" \\"
echo "  \"CLUSTER_CA_CRT[password]=${CLUSTER_CA_CRT}\" \\"
echo "  \"CLUSTER_CA_KEY[password]=${CLUSTER_CA_KEY}\" \\"
echo "  \"CLUSTER_AGGREGATORCA_CRT[password]=${CLUSTER_AGGREGATORCA_CRT}\" \\"
echo "  \"CLUSTER_AGGREGATORCA_KEY[password]=${CLUSTER_AGGREGATORCA_KEY}\" \\"
echo "  \"CLUSTER_ETCD_CA_CRT[password]=${CLUSTER_ETCD_CA_CRT}\" \\"
echo "  \"CLUSTER_ETCD_CA_KEY[password]=${CLUSTER_ETCD_CA_KEY}\" \\"
echo "  \"CLUSTER_SERVICEACCOUNT_KEY[password]=${CLUSTER_SERVICEACCOUNT_KEY}\" \\"
echo "  \"CLUSTER_SECRETBOXENCRYPTIONSECRET[password]=${CLUSTER_SECRETBOXENCRYPTIONSECRET}\""
echo ""

# Also output as JSON for manual import
echo "===================================="
echo "Secrets as JSON (for manual import)"
echo "===================================="
echo ""
cat <<EOF
{
  "cluster": "${CLUSTER_NAME}",
  "secrets": {
    "MACHINE_TOKEN": "${MACHINE_TOKEN}",
    "MACHINE_CA_CRT": "${MACHINE_CA_CRT}",
    "MACHINE_CA_KEY": "${MACHINE_CA_KEY}",
    "CLUSTER_ID": "${CLUSTER_ID}",
    "CLUSTER_SECRET": "${CLUSTER_SECRET}",
    "CLUSTER_TOKEN": "${CLUSTER_TOKEN}",
    "CLUSTER_CA_CRT": "${CLUSTER_CA_CRT}",
    "CLUSTER_CA_KEY": "${CLUSTER_CA_KEY}",
    "CLUSTER_AGGREGATORCA_CRT": "${CLUSTER_AGGREGATORCA_CRT}",
    "CLUSTER_AGGREGATORCA_KEY": "${CLUSTER_AGGREGATORCA_KEY}",
    "CLUSTER_ETCD_CA_CRT": "${CLUSTER_ETCD_CA_CRT}",
    "CLUSTER_ETCD_CA_KEY": "${CLUSTER_ETCD_CA_KEY}",
    "CLUSTER_SERVICEACCOUNT_KEY": "${CLUSTER_SERVICEACCOUNT_KEY}",
    "CLUSTER_SECRETBOXENCRYPTIONSECRET": "${CLUSTER_SECRETBOXENCRYPTIONSECRET}"
  }
}
EOF
echo ""
echo ""
echo "===================================="
echo "Next Steps"
echo "===================================="
echo ""
echo "Option 1 - Using op CLI (recommended):"
echo "  1. Copy the 'op item create' command above"
echo "  2. Run it in your terminal (requires op CLI and authentication)"
echo ""
echo "Option 2 - Manual entry:"
echo "  1. Open 1Password"
echo "  2. Create new Login item named '${CLUSTER_NAME}-talos' in 'Prod' vault"
echo "  3. Add each secret as a password field"
echo "  4. Use the JSON output above for reference"
echo ""
