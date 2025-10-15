#!/usr/bin/env bash
# Data Classification Compliance Audit
# Security BLOCKER #3 - Data Classification Framework
# Usage: ./audit-classification.sh

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Data Classification Compliance Audit ===${NC}"
echo "Date: $(date)"
echo ""

# Check if kubectl is available
if ! command -v kubectl &>/dev/null; then
  echo -e "${RED}Error: kubectl not found${NC}"
  exit 1
fi

# 1. Namespace Classification Status
echo -e "${GREEN}1. Namespace Classification Status${NC}"
echo "─────────────────────────────────────────"

unclassified=0
classified=0

while IFS= read -r ns; do
  classification=$(kubectl get namespace "$ns" -o jsonpath='{.metadata.labels.monosense\.io/data-classification}' 2>/dev/null || echo "")

  if [[ -z "$classification" ]]; then
    echo -e "${YELLOW}⚠ UNCLASSIFIED${NC}: $ns"
    ((unclassified++))
  else
    echo -e "${GREEN}✓${NC} $ns: $classification"
    ((classified++))
  fi
done < <(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' | grep -v -E '^(kube-|default)')

echo ""
echo "Summary: $classified classified, $unclassified unclassified"
echo ""

# 2. Confidential Data Encryption Status
echo -e "${GREEN}2. Confidential Namespace Encryption Status${NC}"
echo "─────────────────────────────────────────"

while IFS= read -r ns; do
  classification=$(kubectl get namespace "$ns" -o jsonpath='{.metadata.labels.monosense\.io/data-classification}' 2>/dev/null || echo "")

  if [[ "$classification" == "confidential" ]] || [[ "$classification" == "restricted" ]]; then
    encryption_required=$(kubectl get namespace "$ns" -o jsonpath='{.metadata.labels.monosense\.io/encryption-required}' 2>/dev/null || echo "false")

    if [[ "$encryption_required" == "true" ]]; then
      echo -e "${GREEN}✓${NC} $ns: Encryption required label set"
    else
      echo -e "${RED}✗${NC} $ns: Missing encryption-required label"
    fi
  fi
done < <(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n')

echo ""

# 3. Backup Configuration Status
echo -e "${GREEN}3. Backup Configuration Status${NC}"
echo "─────────────────────────────────────────"

if kubectl get crd replicationsources.volsync.backube &>/dev/null; then
  backup_count=$(kubectl get replicationsources -A --no-headers 2>/dev/null | wc -l)
  echo "Total ReplicationSources configured: $backup_count"
  echo ""

  if [[ $backup_count -gt 0 ]]; then
    echo "Backup sources by namespace:"
    kubectl get replicationsources -A -o custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name,SCHEDULE:.spec.trigger.schedule' --no-headers
  fi
else
  echo -e "${YELLOW}⚠ VolSync CRDs not installed${NC}"
fi

echo ""

# 4. Secret Access Audit (if Victoria Logs available)
echo -e "${GREEN}4. Secret Access Audit (Last 7 Days)${NC}"
echo "─────────────────────────────────────────"

if kubectl get svc victoria-logs -n monitoring &>/dev/null; then
  echo "Querying Victoria Logs for Secret access..."

  # Port-forward in background
  kubectl port-forward -n monitoring svc/victoria-logs 9428:9428 &>/dev/null &
  PF_PID=$!
  sleep 2

  # Query audit logs
  curl -s 'http://localhost:9428/select/logsql/query' \
    -d 'query={stream="audit.kube-apiserver"} | json | objectRef.resource="secrets" | last 7d | stats count() by user.username | sort by count desc | limit 10' 2>/dev/null | \
    jq -r '.data[] | "\(.value.count) accesses by \(.value.user_username)"' || \
    echo -e "${YELLOW}⚠ Unable to query Victoria Logs${NC}"

  # Cleanup
  kill $PF_PID 2>/dev/null || true
else
  echo -e "${YELLOW}⚠ Victoria Logs not deployed${NC}"
fi

echo ""

# 5. Compliance Summary
echo -e "${BLUE}=== Compliance Summary ===${NC}"
echo "─────────────────────────────────────────"

total_ns=$((classified + unclassified))
compliance_percent=$(( classified * 100 / total_ns ))

echo "Namespace Classification: $compliance_percent% compliant ($classified/$total_ns)"

if [[ $compliance_percent -ge 90 ]]; then
  echo -e "${GREEN}✓ Good compliance${NC}"
elif [[ $compliance_percent -ge 70 ]]; then
  echo -e "${YELLOW}⚠ Moderate compliance - action needed${NC}"
else
  echo -e "${RED}✗ Low compliance - immediate action required${NC}"
fi

echo ""

# 6. Recommendations
if [[ $unclassified -gt 0 ]]; then
  echo -e "${YELLOW}Recommendations:${NC}"
  echo "  • Classify $unclassified unclassified namespace(s)"
  echo "  • Use: ./scripts/security/classify-namespace.sh <namespace> <classification>"
  echo ""
fi

echo "For detailed classification guide: docs/security/data-classification.md"
echo ""
