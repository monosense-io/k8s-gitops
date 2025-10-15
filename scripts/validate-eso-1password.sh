#!/usr/bin/env bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CONNECT_HOST="http://opconnect.monosense.dev"
SECRET_NAME="onepassword-connect-token"
SECRET_NAMESPACE="external-secrets"
CLUSTER_SECRET_STORE="onepassword"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}1Password Connect + ESO Validation${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Function to print status
print_status() {
    local status=$1
    local message=$2
    if [ "$status" = "ok" ]; then
        echo -e "${GREEN}✅ ${message}${NC}"
    elif [ "$status" = "warn" ]; then
        echo -e "${YELLOW}⚠️  ${message}${NC}"
    else
        echo -e "${RED}❌ ${message}${NC}"
    fi
}

# Test 1: Check Connect Server Connectivity
echo -e "${BLUE}[1/7] Testing Connect Server Connectivity...${NC}"
if curl -s -f -m 5 "${CONNECT_HOST}/health" > /dev/null 2>&1; then
    print_status "ok" "Connect Server is reachable at ${CONNECT_HOST}"
else
    print_status "error" "Cannot reach Connect Server at ${CONNECT_HOST}"
    echo -e "${YELLOW}   → Check if your Docker service is running${NC}"
    echo -e "${YELLOW}   → Verify DNS resolution: nslookup opconnect.monosense.dev${NC}"
fi
echo ""

# Test 2: Check External Secrets namespace
echo -e "${BLUE}[2/7] Checking External Secrets namespace...${NC}"
if kubectl get namespace "${SECRET_NAMESPACE}" > /dev/null 2>&1; then
    print_status "ok" "Namespace '${SECRET_NAMESPACE}' exists"
else
    print_status "error" "Namespace '${SECRET_NAMESPACE}' not found"
    echo -e "${YELLOW}   → Run: kubectl apply -f bootstrap/prerequisites/resources.yaml${NC}"
fi
echo ""

# Test 3: Check 1Password Connect Token secret
echo -e "${BLUE}[3/7] Checking 1Password Connect Token secret...${NC}"
if kubectl get secret "${SECRET_NAME}" -n "${SECRET_NAMESPACE}" > /dev/null 2>&1; then
    print_status "ok" "Secret '${SECRET_NAME}' exists in namespace '${SECRET_NAMESPACE}'"

    # Check if token has content
    TOKEN_LENGTH=$(kubectl get secret "${SECRET_NAME}" -n "${SECRET_NAMESPACE}" -o jsonpath='{.data.token}' | base64 -d | wc -c)
    if [ "$TOKEN_LENGTH" -gt 0 ]; then
        print_status "ok" "Token has content (${TOKEN_LENGTH} bytes)"
    else
        print_status "error" "Token is empty"
        echo -e "${YELLOW}   → Update secret with actual token from 1Password${NC}"
    fi
else
    print_status "error" "Secret '${SECRET_NAME}' not found"
    echo -e "${YELLOW}   → Create secret: kubectl apply -f bootstrap/prerequisites/resources.yaml${NC}"
    echo -e "${YELLOW}   → Then inject token: op inject -i bootstrap/prerequisites/resources.yaml | kubectl apply -f -${NC}"
fi
echo ""

# Test 4: Test authentication to Connect Server
echo -e "${BLUE}[4/7] Testing authentication to Connect Server...${NC}"
if kubectl get secret "${SECRET_NAME}" -n "${SECRET_NAMESPACE}" > /dev/null 2>&1; then
    TOKEN=$(kubectl get secret "${SECRET_NAME}" -n "${SECRET_NAMESPACE}" -o jsonpath='{.data.token}' | base64 -d 2>/dev/null || echo "")
    if [ -n "$TOKEN" ]; then
        if curl -s -f -m 5 -H "Authorization: Bearer ${TOKEN}" "${CONNECT_HOST}/v1/health" > /dev/null 2>&1; then
            print_status "ok" "Successfully authenticated to Connect Server"
        else
            print_status "error" "Authentication failed - check token validity"
            echo -e "${YELLOW}   → Verify token is valid in 1Password${NC}"
            echo -e "${YELLOW}   → Check Connect Server logs for errors${NC}"
        fi
    else
        print_status "warn" "Cannot test authentication - token not available"
    fi
else
    print_status "warn" "Skipping authentication test - secret not found"
fi
echo ""

# Test 5: Check ClusterSecretStore
echo -e "${BLUE}[5/7] Checking ClusterSecretStore status...${NC}"
if kubectl get clustersecretstore "${CLUSTER_SECRET_STORE}" > /dev/null 2>&1; then
    print_status "ok" "ClusterSecretStore '${CLUSTER_SECRET_STORE}' exists"

    # Check status
    STATUS=$(kubectl get clustersecretstore "${CLUSTER_SECRET_STORE}" -o jsonpath='{.status.conditions[0].type}' 2>/dev/null || echo "Unknown")
    if [ "$STATUS" = "Ready" ]; then
        print_status "ok" "ClusterSecretStore is Ready"
    else
        print_status "warn" "ClusterSecretStore status: ${STATUS}"
        echo -e "${YELLOW}   → Check: kubectl describe clustersecretstore ${CLUSTER_SECRET_STORE}${NC}"
    fi
else
    print_status "error" "ClusterSecretStore '${CLUSTER_SECRET_STORE}' not found"
    echo -e "${YELLOW}   → Deploy: kubectl apply -k kubernetes/infrastructure/security/external-secrets/${NC}"
fi
echo ""

# Test 6: Check External Secrets Operator pods
echo -e "${BLUE}[6/7] Checking External Secrets Operator status...${NC}"
POD_COUNT=$(kubectl get pods -n external-secrets -l app.kubernetes.io/name=external-secrets -o json 2>/dev/null | jq -r '.items | length' || echo "0")
if [ "$POD_COUNT" -gt 0 ]; then
    print_status "ok" "ESO pods running (${POD_COUNT} replicas)"

    # Check if pods are ready
    READY_COUNT=$(kubectl get pods -n external-secrets -l app.kubernetes.io/name=external-secrets -o json 2>/dev/null | jq -r '[.items[].status.conditions[] | select(.type=="Ready" and .status=="True")] | length' || echo "0")
    if [ "$READY_COUNT" = "$POD_COUNT" ]; then
        print_status "ok" "All ESO pods are ready"
    else
        print_status "warn" "Only ${READY_COUNT}/${POD_COUNT} pods are ready"
        echo -e "${YELLOW}   → Check: kubectl get pods -n external-secrets${NC}"
    fi
else
    print_status "error" "No ESO pods found"
    echo -e "${YELLOW}   → Deploy ESO: see bootstrap documentation${NC}"
fi
echo ""

# Test 7: Sample ExternalSecret test
echo -e "${BLUE}[7/7] Checking existing ExternalSecrets...${NC}"
ES_COUNT=$(kubectl get externalsecrets -A -o json 2>/dev/null | jq -r '.items | length' || echo "0")
if [ "$ES_COUNT" -gt 0 ]; then
    print_status "ok" "Found ${ES_COUNT} ExternalSecret resources"

    # Check sync status
    SYNCED_COUNT=$(kubectl get externalsecrets -A -o json 2>/dev/null | jq -r '[.items[].status.conditions[] | select(.type=="Ready" and .status=="True")] | length' || echo "0")
    if [ "$SYNCED_COUNT" = "$ES_COUNT" ]; then
        print_status "ok" "All ExternalSecrets are synced"
    else
        print_status "warn" "${SYNCED_COUNT}/${ES_COUNT} ExternalSecrets are synced"
        echo -e "${YELLOW}   → Check failed syncs: kubectl get externalsecrets -A${NC}"
        echo -e "${YELLOW}   → View details: kubectl describe externalsecret <name> -n <namespace>${NC}"
    fi
else
    print_status "warn" "No ExternalSecrets found (yet)"
    echo -e "${YELLOW}   → This is normal if you haven't deployed workloads yet${NC}"
fi
echo ""

# Summary
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Validation Summary${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "Configuration:"
echo -e "  Connect Host: ${CONNECT_HOST}"
echo -e "  Secret Name: ${SECRET_NAME}"
echo -e "  Namespace: ${SECRET_NAMESPACE}"
echo -e "  ClusterSecretStore: ${CLUSTER_SECRET_STORE}"
echo ""
echo -e "Next steps:"
echo -e "  1. Fix any ${RED}❌ errors${NC} shown above"
echo -e "  2. Monitor ESO logs: ${BLUE}kubectl logs -n external-secrets -l app.kubernetes.io/name=external-secrets -f${NC}"
echo -e "  3. Check for rate limiting: ${BLUE}kubectl logs -n external-secrets -l app.kubernetes.io/name=external-secrets | grep -i rate${NC}"
echo -e "  4. Test a sample ExternalSecret deployment"
echo ""
