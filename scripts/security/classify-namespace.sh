#!/usr/bin/env bash
# Namespace Data Classification Helper
# Security BLOCKER #3 - Data Classification Framework
# Usage: ./classify-namespace.sh <namespace> <classification>

set -euo pipefail

NAMESPACE="${1:-}"
CLASSIFICATION="${2:-}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

usage() {
  cat <<EOF
Usage: $0 <namespace> <classification>

Classifications:
  public        - Data intended for public disclosure
  internal      - Internal use only, low risk if disclosed
  confidential  - Sensitive data requiring protection
  restricted    - Highly sensitive, maximum protection required

Examples:
  $0 my-app internal
  $0 databases confidential
  $0 keycloak confidential

For more information, see: docs/security/data-classification.md
EOF
  exit 1
}

# Validate inputs
if [[ -z "$NAMESPACE" ]] || [[ -z "$CLASSIFICATION" ]]; then
  echo -e "${RED}Error: Missing required arguments${NC}"
  usage
fi

# Validate classification level
case "$CLASSIFICATION" in
  public|internal|confidential|restricted)
    ;;
  *)
    echo -e "${RED}Error: Invalid classification level: $CLASSIFICATION${NC}"
    usage
    ;;
esac

# Check if namespace exists
if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
  echo -e "${RED}Error: Namespace '$NAMESPACE' does not exist${NC}"
  exit 1
fi

echo -e "${GREEN}=== Data Classification for Namespace: $NAMESPACE ===${NC}"
echo ""

# Apply classification label
echo "Applying classification label: $CLASSIFICATION"
kubectl label namespace "$NAMESPACE" \
  "monosense.io/data-classification=$CLASSIFICATION" \
  --overwrite

# Apply additional labels based on classification
case "$CLASSIFICATION" in
  confidential|restricted)
    echo "Applying additional labels for $CLASSIFICATION data..."
    kubectl label namespace "$NAMESPACE" \
      "monosense.io/encryption-required=true" \
      "monosense.io/backup-required=true" \
      "monosense.io/audit-level=request" \
      --overwrite
    ;;
  internal)
    kubectl label namespace "$NAMESPACE" \
      "monosense.io/backup-required=true" \
      "monosense.io/audit-level=metadata" \
      --overwrite
    ;;
  public)
    kubectl label namespace "$NAMESPACE" \
      "monosense.io/audit-level=none" \
      --overwrite
    ;;
esac

echo ""
echo -e "${GREEN}✓ Classification applied successfully${NC}"
echo ""

# Show current labels
echo "Current namespace labels:"
kubectl get namespace "$NAMESPACE" -o json | jq -r '.metadata.labels | to_entries[] | select(.key | startswith("monosense.io/")) | "  \(.key): \(.value)"'

echo ""
echo -e "${YELLOW}Next Steps:${NC}"

case "$CLASSIFICATION" in
  confidential|restricted)
    cat <<EOF
  1. Configure backup with encryption:
     - Copy kubernetes/components/volsync/ templates
     - Set Age encryption for backups
     - RPO: 6 hours (confidential), 1 hour (restricted)

  2. Enable Rook Ceph encryption for PVCs:
     - Add annotation: encrypted: "true"
     - Use storageClass: ceph-block-encrypted

  3. Restrict RBAC access:
     - Only service accounts, no human read access
     - Review kubernetes/bases/rbac/developer-role-template.yaml

  4. Verify audit logging:
     - Check Victoria Logs for Secret access
     - Ensure Request-level logging enabled

  For details: docs/security/data-classification.md
EOF
    ;;
  internal)
    cat <<EOF
  1. Configure standard backup (optional):
     - 24-hour RPO
     - 30-day retention

  2. Set up RBAC:
     - Copy kubernetes/bases/rbac/developer-role-template.yaml
     - Bind to developer users/groups

  For details: docs/security/data-classification.md
EOF
    ;;
  public)
    echo "  No additional security controls required for public data."
    ;;
esac

echo ""
