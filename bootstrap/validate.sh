#!/usr/bin/env bash
set -euo pipefail

# Bootstrap Validation Script
# Verifies that the flux-operator bootstrap was successful

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Counters
PASS=0
FAIL=0
WARN=0

# Helper functions
pass() {
    echo -e "${GREEN}✓${NC} $1"
    ((PASS++))
}

fail() {
    echo -e "${RED}✗${NC} $1"
    ((FAIL++))
}

warn() {
    echo -e "${YELLOW}⚠${NC} $1"
    ((WARN++))
}

info() {
    echo -e "  $1"
}

section() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  $1"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# Check if command exists
check_command() {
    if command -v "$1" &> /dev/null; then
        pass "$1 is installed"
    else
        fail "$1 is not installed"
        return 1
    fi
}

# Check if namespace exists
check_namespace() {
    if kubectl get namespace "$1" &> /dev/null; then
        pass "Namespace $1 exists"
    else
        fail "Namespace $1 does not exist"
        return 1
    fi
}

# Check if deployment is ready
check_deployment() {
    local ns=$1
    local name=$2
    local replicas=$(kubectl get deployment -n "$ns" "$name" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    local desired=$(kubectl get deployment -n "$ns" "$name" -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "1")

    if [[ "$replicas" == "$desired" ]] && [[ "$replicas" != "0" ]]; then
        pass "Deployment $ns/$name is ready ($replicas/$desired)"
    else
        fail "Deployment $ns/$name is not ready ($replicas/$desired)"
        return 1
    fi
}

# Check if daemonset is ready
check_daemonset() {
    local ns=$1
    local name=$2
    local ready=$(kubectl get daemonset -n "$ns" "$name" -o jsonpath='{.status.numberReady}' 2>/dev/null || echo "0")
    local desired=$(kubectl get daemonset -n "$ns" "$name" -o jsonpath='{.status.desiredNumberScheduled}' 2>/dev/null || echo "1")

    if [[ "$ready" == "$desired" ]] && [[ "$ready" != "0" ]]; then
        pass "DaemonSet $ns/$name is ready ($ready/$desired)"
    else
        fail "DaemonSet $ns/$name is not ready ($ready/$desired)"
        return 1
    fi
}

# Check if custom resource exists and is ready
check_cr_ready() {
    local kind=$1
    local ns=$2
    local name=$3

    if kubectl get "$kind" -n "$ns" "$name" &> /dev/null; then
        local ready=$(kubectl get "$kind" -n "$ns" "$name" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "Unknown")
        if [[ "$ready" == "True" ]]; then
            pass "$kind $ns/$name is ready"
        else
            local reason=$(kubectl get "$kind" -n "$ns" "$name" -o jsonpath='{.status.conditions[?(@.type=="Ready")].reason}' 2>/dev/null || echo "Unknown")
            local message=$(kubectl get "$kind" -n "$ns" "$name" -o jsonpath='{.status.conditions[?(@.type=="Ready")].message}' 2>/dev/null || echo "No message")
            fail "$kind $ns/$name is not ready (Status: $ready, Reason: $reason)"
            info "Message: $message"
            return 1
        fi
    else
        fail "$kind $ns/$name does not exist"
        return 1
    fi
}

# Main validation
main() {
    section "Greenfield Bootstrap Validation - Flux Operator"

    # Check prerequisites
    section "1. Prerequisites"
    check_command kubectl || exit 1
    check_command helmfile || warn "helmfile not installed (optional for validation)"
    check_command flux || warn "flux CLI not installed (optional for validation)"

    # Check cluster access
    if kubectl cluster-info &> /dev/null; then
        pass "Cluster is accessible"
        info "Cluster: $(kubectl config current-context)"
    else
        fail "Cannot access cluster"
        exit 1
    fi

    # Check namespaces
    section "2. Bootstrap Namespaces"
    check_namespace "kube-system"
    check_namespace "cert-manager"
    check_namespace "external-secrets"
    check_namespace "flux-system"

    # Check CNI (Cilium)
    section "3. CNI (Cilium)"
    check_daemonset "kube-system" "cilium" || warn "Cilium DaemonSet not ready"
    check_deployment "kube-system" "cilium-operator" || warn "Cilium Operator not ready"

    # Check CoreDNS
    section "4. DNS (CoreDNS)"
    check_deployment "kube-system" "coredns" || warn "CoreDNS not ready"

    # Check Spegel (optional)
    section "5. Registry Mirror (Spegel)"
    if kubectl get daemonset -n kube-system spegel &> /dev/null; then
        check_daemonset "kube-system" "spegel" || warn "Spegel not ready"
    else
        warn "Spegel not installed (optional)"
    fi

    # Check cert-manager
    section "6. Certificate Manager (cert-manager)"
    check_deployment "cert-manager" "cert-manager" || fail "cert-manager not ready"
    check_deployment "cert-manager" "cert-manager-webhook" || warn "cert-manager webhook not ready"
    check_deployment "cert-manager" "cert-manager-cainjector" || warn "cert-manager cainjector not ready"

    # Check External Secrets
    section "7. Secret Management (External Secrets)"
    check_deployment "external-secrets" "external-secrets" || warn "external-secrets not ready"
    check_deployment "external-secrets" "external-secrets-webhook" || warn "external-secrets webhook not ready"

    # Check Flux Operator
    section "8. Flux Operator"
    check_deployment "flux-system" "flux-operator" || fail "flux-operator not ready"

    # Check Flux Instance
    section "9. Flux Instance"
    if kubectl get fluxinstance -n flux-system flux &> /dev/null; then
        local instance_ready=$(kubectl get fluxinstance -n flux-system flux -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "Unknown")
        if [[ "$instance_ready" == "True" ]]; then
            pass "FluxInstance is ready"
        else
            fail "FluxInstance is not ready (Status: $instance_ready)"
        fi
    else
        fail "FluxInstance not found"
    fi

    # Check Flux Controllers
    section "10. Flux Controllers"
    check_deployment "flux-system" "source-controller" || fail "source-controller not ready"
    check_deployment "flux-system" "kustomize-controller" || fail "kustomize-controller not ready"
    check_deployment "flux-system" "helm-controller" || fail "helm-controller not ready"
    check_deployment "flux-system" "notification-controller" || fail "notification-controller not ready"

    # Check optional controllers
    if kubectl get deployment -n flux-system image-reflector-controller &> /dev/null; then
        check_deployment "flux-system" "image-reflector-controller" || warn "image-reflector-controller not ready"
    fi
    if kubectl get deployment -n flux-system image-automation-controller &> /dev/null; then
        check_deployment "flux-system" "image-automation-controller" || warn "image-automation-controller not ready"
    fi

    # Check GitRepository
    section "11. Git Source"
    check_cr_ready "gitrepository" "flux-system" "flux-system" || fail "GitRepository not ready"

    # Check Kustomizations
    section "12. Kustomizations"
    check_cr_ready "kustomization" "flux-system" "cluster-config" || fail "cluster-config Kustomization not ready"

    # Check for infrastructure kustomizations
    if kubectl get kustomization -n flux-system cluster-infra-infrastructure &> /dev/null; then
        check_cr_ready "kustomization" "flux-system" "cluster-infra-infrastructure" || warn "cluster-infra-infrastructure not ready"
    fi

    if kubectl get kustomization -n flux-system cluster-infra-workloads &> /dev/null; then
        check_cr_ready "kustomization" "flux-system" "cluster-infra-workloads" || warn "cluster-infra-workloads not ready"
    fi

    # Check for any failing Kustomizations
    section "13. Health Check"
    local failing_kustomizations=$(kubectl get kustomizations -A -o json | jq -r '.items[] | select(.status.conditions[]? | select(.type=="Ready" and .status=="False")) | "\(.metadata.namespace)/\(.metadata.name)"' 2>/dev/null || echo "")

    if [[ -z "$failing_kustomizations" ]]; then
        pass "No failing Kustomizations"
    else
        fail "Failing Kustomizations detected:"
        echo "$failing_kustomizations" | while read -r ks; do
            info "  - $ks"
        done
    fi

    # Check for failing HelmReleases
    local failing_helmreleases=$(kubectl get helmreleases -A -o json | jq -r '.items[] | select(.status.conditions[]? | select(.type=="Ready" and .status=="False")) | "\(.metadata.namespace)/\(.metadata.name)"' 2>/dev/null || echo "")

    if [[ -z "$failing_helmreleases" ]]; then
        pass "No failing HelmReleases"
    else
        warn "Failing HelmReleases detected:"
        echo "$failing_helmreleases" | while read -r hr; do
            info "  - $hr"
        done
    fi

    # Summary
    section "Summary"
    echo ""
    echo "  Passed: ${GREEN}${PASS}${NC}"
    echo "  Failed: ${RED}${FAIL}${NC}"
    echo "  Warnings: ${YELLOW}${WARN}${NC}"
    echo ""

    if [[ $FAIL -eq 0 ]]; then
        echo -e "${GREEN}✓ Bootstrap validation successful!${NC}"
        echo ""
        echo "Next steps:"
        echo "  1. Review infrastructure deployment: flux get kustomizations"
        echo "  2. Monitor reconciliation: flux get all -A --watch"
        echo "  3. Configure GitHub webhook (see BOOTSTRAP-GUIDE.md)"
        echo ""
        exit 0
    else
        echo -e "${RED}✗ Bootstrap validation failed!${NC}"
        echo ""
        echo "Troubleshooting:"
        echo "  1. Check logs: kubectl logs -n flux-system deployment/flux-operator"
        echo "  2. Check Flux status: flux check"
        echo "  3. See BOOTSTRAP-GUIDE.md for detailed troubleshooting"
        echo ""
        exit 1
    fi
}

# Run validation
main "$@"
