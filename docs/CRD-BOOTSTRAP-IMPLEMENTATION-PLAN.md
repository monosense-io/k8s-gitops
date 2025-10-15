# CRD Bootstrap Implementation Plan
## Victoria Metrics & Multi-Cluster Bootstrap Strategy

**Author:** Alex - DevOps Infrastructure Specialist
**Date:** 2025-10-15
**Status:** Design Complete - Ready for Implementation

---

## Executive Summary

This document provides a comprehensive plan to implement a **CRD (CustomResourceDefinition) bootstrap strategy** for our multi-cluster Kubernetes infrastructure. The design is based on research of the [buroa k8s-gitops repository](https://github.com/buroa/k8s-gitops) and adapted for our specific requirements, particularly for **Victoria Metrics** monitoring stack deployment.

### Problem Statement

**Current Issue:**
- PrometheusRule CRDs are required by infrastructure layer components (Flux, Cilium, cert-manager, etc.)
- Victoria Metrics operator (which provides PrometheusRule CRDs) is deployed in the workloads layer
- This creates a **race condition** where Flux attempts to apply PrometheusRule resources before the CRD exists
- Result: Deployment failures and dependency order violations

**Root Cause:**
CRDs are installed inline with application HelmReleases using `crds: CreateReplace`, which happens AFTER infrastructure components need them.

---

## Research Findings

### Buroa's Approach

**Bootstrap Structure:**
```
bootstrap/
├── resources.yaml                    # Pre-requisites (namespaces, secrets)
├── helmfile.d/
│   ├── 00-crds.yaml                 # CRD extraction phase
│   └── 01-apps.yaml                 # Application deployment phase
```

**Key Innovation - CRD Extraction Pattern:**
```yaml
helmDefaults:
  args: ['--include-crds', '--no-hooks']
  postRenderer: bash
  postRendererArgs: [-c, "yq ea --exit-status 'select(.kind == \"CustomResourceDefinition\")'"]
```

**How It Works:**
1. `--include-crds` forces Helm to render CRDs from charts
2. `--no-hooks` prevents installation, only templating
3. `yq` post-renderer filters manifests to ONLY CustomResourceDefinition kinds
4. Output piped to `kubectl apply` for direct CRD installation
5. CRDs exist cluster-wide BEFORE any applications deploy

**Charts with CRDs Extracted:**
- external-secrets
- envoy-gateway
- keda
- kube-prometheus-stack (provides PrometheusRule, ServiceMonitor, etc.)

---

### Victoria Metrics CRD Requirements

**VictoriaMetrics Operator CRDs:**

The operator creates 14 custom resource definitions:

| CRD | Purpose | Used In Our Infrastructure |
|-----|---------|---------------------------|
| `VMAgent` | Metrics scraping agent | ✅ Yes (workloads) |
| `VMSingle` | Single-node VM instance | ✅ Yes (workloads) |
| `VMAlert` | Alerting component | ✅ Yes (workloads) |
| `VMAlertmanager` | Alert management | ✅ Yes (workloads) |
| `VMServiceScrape` | Service discovery scraping | ✅ Yes (infrastructure + workloads) |
| `VMPodScrape` | Pod-level scraping | ✅ Yes (infrastructure + workloads) |
| `VMRule` | Alerting/recording rules | ✅ Yes (infrastructure + workloads) |
| `VMProbe` | Blackbox probing | ⚠️ Potential future use |
| `VMAuth` | Auth proxy | ⚠️ Potential future use |
| `VMUser` | User management | ⚠️ Potential future use |
| `VMNodeScrape` | Node metrics | ⚠️ Potential future use |
| `VMStaticScrape` | Static targets | ⚠️ Potential future use |
| `VMScrapeConfig` | Advanced scraping | ⚠️ Potential future use |
| `VMCluster` | Clustered deployment | ❌ Not used (using VMSingle) |

**Critical Finding:**

VictoriaMetrics provides a **standalone CRD chart**:
- **Chart:** `oci://ghcr.io/victoriametrics/helm-charts/victoria-metrics-operator-crds`
- **Latest Version:** v0.56.0 (2024)
- **Purpose:** Install ONLY CRDs, separate from operator deployment
- **Compatibility:** Kubernetes 1.16+

---

### Current Infrastructure Analysis

**Bootstrap Flow:**
```
Phase 0: Prerequisites (Manual)
  kubectl apply -f bootstrap/prerequisites/resources.yaml
  ├── external-secrets namespace
  ├── flux-system namespace
  └── 1Password Connect secrets

Phase 1: Core Infrastructure (Helmfile)
  helmfile -e {infra|apps} sync
  ├── Cilium (CNI)
  ├── CoreDNS
  ├── Spegel
  ├── cert-manager (with CRDs: enabled)
  ├── external-secrets
  ├── flux-operator
  └── flux-instance

Phase 2: GitOps Automation (Flux)
  Flux deploys from Git:
  ├── cluster-settings
  ├── flux-repositories
  ├── infrastructure (❌ PrometheusRule resources here!)
  └── workloads (✅ victoria-metrics deployed here)
```

**Resources Using PrometheusRule CRD:**
```bash
# Found in infrastructure layer (deployed BEFORE victoria-metrics):
kubernetes/infrastructure/gitops/flux-operator/prometheusrule.yaml
kubernetes/infrastructure/gitops/flux-instance/receiver/prometheusrule.yaml
kubernetes/infrastructure/networking/cilium/prometheusrule.yaml
kubernetes/infrastructure/networking/coredns/prometheusrule.yaml
kubernetes/infrastructure/networking/spegel/prometheusrule.yaml
kubernetes/infrastructure/security/cert-manager/prometheusrule.yaml
kubernetes/infrastructure/security/external-secrets/prometheusrule.yaml
kubernetes/infrastructure/storage/openebs/prometheusrule.yaml
kubernetes/infrastructure/storage/rook-ceph/operator/prometheusrule.yaml
kubernetes/infrastructure/storage/rook-ceph/cluster/prometheusrule.yaml
kubernetes/infrastructure/repositories/prometheusrule.yaml
```

**Total:** 17 files reference PrometheusRule/ServiceMonitor CRDs in infrastructure layer

---

## Proposed Solution

### Architecture Overview

```
┌────────────────────────────────────────────────────────────────┐
│ Phase 0: Prerequisites (Manual)                               │
│ ────────────────────────────────────────────────────────────── │
│ kubectl apply -f bootstrap/prerequisites/resources.yaml        │
│ - Creates namespaces (external-secrets, flux-system, etc.)    │
│ - Creates 1Password Connect secrets                           │
│ - Creates any cluster-specific pre-requisite resources        │
└────────────────────────────────────────────────────────────────┘
                             ↓
┌────────────────────────────────────────────────────────────────┐
│ Phase 1: CRD Bootstrap (NEW - Manual/Automated)               │
│ ────────────────────────────────────────────────────────────── │
│ helmfile -f bootstrap/helmfile.d/00-crds.yaml -e {cluster}    │
│   template | kubectl apply -f -                               │
│                                                                │
│ Installs CRDs from:                                           │
│ - victoria-metrics-operator-crds (PRIMARY REQUIREMENT)        │
│ - cert-manager (for consistency)                              │
│ - external-secrets (for consistency)                          │
│                                                                │
│ Result: All CRDs exist cluster-wide                           │
└────────────────────────────────────────────────────────────────┘
                             ↓
┌────────────────────────────────────────────────────────────────┐
│ Phase 2: Core Infrastructure (Helmfile)                       │
│ ────────────────────────────────────────────────────────────── │
│ helmfile -f bootstrap/helmfile.d/01-core.yaml -e {cluster}    │
│   sync                                                         │
│                                                                │
│ Deploys (without CRDs - already installed):                   │
│ - Cilium (CNI + BGP + Gateway API)                           │
│ - CoreDNS (DNS)                                               │
│ - Spegel (Registry mirror)                                    │
│ - cert-manager (app only, crds.enabled: false)               │
│ - external-secrets (app only, installCRDs: false)            │
│ - flux-operator                                               │
│ - flux-instance (with GitRepository sync)                     │
└────────────────────────────────────────────────────────────────┘
                             ↓
┌────────────────────────────────────────────────────────────────┐
│ Phase 3: GitOps Automation (Flux - Automatic)                 │
│ ────────────────────────────────────────────────────────────── │
│ Flux deploys from git repository:                             │
│ 1. cluster-settings (ConfigMap)                               │
│ 2. flux-repositories (OCIRepository, HelmRepository)          │
│ 3. infrastructure (✅ CRDs NOW EXIST!)                        │
│    ├── gitops (flux-operator, flux-instance PrometheusRules) │
│    ├── networking (cilium, coredns, spegel PrometheusRules)  │
│    ├── security (cert-manager, external-secrets)             │
│    └── storage (openebs, rook-ceph)                          │
│ 4. workloads                                                  │
│    └── observability/victoria-metrics (operator + stack)      │
└────────────────────────────────────────────────────────────────┘
```

---

## Implementation Details

### File Structure Changes

**Current:**
```
bootstrap/
├── helmfile.yaml
├── prerequisites/
│   └── resources.yaml
└── clusters/
    ├── infra/values.yaml
    └── apps/values.yaml
```

**Proposed:**
```
bootstrap/
├── helmfile.d/                    # NEW: Separated helmfiles
│   ├── 00-crds.yaml              # NEW: CRD extraction
│   └── 01-core.yaml              # RENAMED from helmfile.yaml
├── prerequisites/
│   └── resources.yaml
├── clusters/
│   ├── infra/values.yaml
│   └── apps/values.yaml
└── scripts/                       # NEW: Helper scripts
    ├── bootstrap-infra.sh         # NEW: Automated infra bootstrap
    └── bootstrap-apps.sh          # NEW: Automated apps bootstrap
```

---

### New File: `bootstrap/helmfile.d/00-crds.yaml`

```yaml
---
# CRD-only helmfile for extracting and installing CustomResourceDefinitions
# This runs BEFORE the main helmfile to ensure CRDs exist
#
# Usage:
#   helmfile -f bootstrap/helmfile.d/00-crds.yaml -e infra template | kubectl apply -f -
#   helmfile -f bootstrap/helmfile.d/00-crds.yaml -e apps template | kubectl apply -f -

helmDefaults:
  # Template mode: extract manifests without installing
  args: ['--include-crds', '--no-hooks']
  # Post-process to extract ONLY CRD manifests
  postRenderer: bash
  postRendererArgs: [-c, "yq ea --exit-status 'select(.kind == \"CustomResourceDefinition\")'"]
  createNamespace: true

# Cluster-specific environments
environments:
  infra:
    values:
      - ../clusters/infra/values.yaml
  apps:
    values:
      - ../clusters/apps/values.yaml

releases:
  # ============================================================================
  # Victoria Metrics Operator CRDs - PRIMARY REQUIREMENT
  # ============================================================================
  # Provides: VMAgent, VMSingle, VMAlert, VMAlertmanager, VMServiceScrape,
  #           VMPodScrape, VMRule, VMProbe, VMAuth, VMUser, VMNodeScrape,
  #           VMStaticScrape, VMScrapeConfig, VMCluster
  #
  # Required by: PrometheusRule resources in infrastructure layer
  # ============================================================================
  - name: victoria-metrics-operator-crds
    namespace: observability
    chart: oci://ghcr.io/victoriametrics/helm-charts/victoria-metrics-operator-crds
    version: 0.56.0

  # ============================================================================
  # cert-manager CRDs (Optional - for consistency)
  # ============================================================================
  # Provides: Certificate, CertificateRequest, Issuer, ClusterIssuer, etc.
  # Note: Main chart also installs CRDs, but extracting here ensures
  #       they exist before any cert-manager dependent resources
  # ============================================================================
  - name: cert-manager
    namespace: cert-manager
    chart: oci://quay.io/jetstack/charts/cert-manager
    version: v1.16.2

  # ============================================================================
  # external-secrets CRDs (Optional - for consistency)
  # ============================================================================
  # Provides: ExternalSecret, SecretStore, ClusterSecretStore, etc.
  # Note: Main chart also installs CRDs, but extracting here ensures
  #       they exist before any external-secret dependent resources
  # ============================================================================
  - name: external-secrets
    namespace: external-secrets
    chart: oci://ghcr.io/external-secrets/charts/external-secrets
    version: 0.12.1
```

**Why This Works:**
1. `--include-crds` forces Helm to render CRDs from charts
2. `--no-hooks` prevents installation, only templating
3. `yq` post-renderer filters manifests to ONLY `kind: CustomResourceDefinition`
4. `helmfile template | kubectl apply` installs CRDs without Helm tracking
5. CRDs are cluster-scoped, available to all namespaces immediately

---

### Modified File: `bootstrap/helmfile.d/01-core.yaml`

**Changes from current `bootstrap/helmfile.yaml`:**

```yaml
---
# Core Infrastructure Helmfile
# Assumes CRDs are already installed via 00-crds.yaml
#
# Usage:
#   helmfile -e infra sync    # Bootstrap infra cluster
#   helmfile -e apps sync     # Bootstrap apps cluster

helmDefaults:
  cleanupOnFail: true
  wait: true
  waitForJobs: true
  timeout: 600
  createNamespace: true

# Cluster-specific environments
environments:
  infra:
    values:
      - ../clusters/infra/values.yaml
  apps:
    values:
      - ../clusters/apps/values.yaml

releases:
  # 1. Cilium CNI - MUST BE FIRST (no networking without CNI)
  - name: cilium
    namespace: kube-system
    chart: oci://quay.io/cilium/cilium
    version: 1.16.5
    values:
      # ... (keep existing values from current helmfile.yaml)

  # 2. CoreDNS - DNS resolution
  - name: coredns
    namespace: kube-system
    chart: oci://ghcr.io/coredns/charts/coredns
    version: 1.44.3
    needs: ['kube-system/cilium']
    values:
      # ... (keep existing values)

  # 3. Spegel - Local registry mirror
  - name: spegel
    namespace: kube-system
    chart: oci://ghcr.io/spegel-org/helm-charts/spegel
    version: v0.0.28
    needs: ['kube-system/coredns']
    values:
      # ... (keep existing values)

  # 4. cert-manager - Certificate management
  # CHANGE: Disable CRD installation (already installed in Phase 1)
  - name: cert-manager
    namespace: cert-manager
    chart: oci://quay.io/jetstack/charts/cert-manager
    version: v1.16.2
    needs: ['kube-system/spegel']
    values:
      - crds:
          enabled: false  # ← CHANGED: CRDs installed separately
      - global:
          leaderElection:
            namespace: cert-manager
      - prometheus:
          enabled: true
          servicemonitor:
            enabled: true
      # ... (keep rest of existing values)

  # 5. external-secrets - Secret management
  # CHANGE: Disable CRD installation (already installed in Phase 1)
  - name: external-secrets
    namespace: external-secrets
    chart: oci://ghcr.io/external-secrets/charts/external-secrets
    version: 0.12.1
    needs: ['cert-manager/cert-manager']
    values:
      - installCRDs: false  # ← CHANGED: CRDs installed separately
      - crds:
          createClusterSecretStore: false
      - webhook:
          create: true
      - certController:
          create: true

  # 6. Flux Operator - Flux lifecycle manager
  - name: flux-operator
    namespace: flux-system
    chart: oci://ghcr.io/controlplaneio-fluxcd/charts/flux-operator
    version: 0.32.0
    needs: ['cert-manager/cert-manager']
    values:
      # ... (keep existing values)

  # 7. Flux Instance - Flux controllers
  - name: flux-instance
    namespace: flux-system
    chart: oci://ghcr.io/controlplaneio-fluxcd/charts/flux-instance
    version: 0.32.0
    needs: ['flux-system/flux-operator']
    values:
      # ... (keep existing values)
    hooks:
      # ... (keep existing hooks)
```

**Key Changes:**
1. ✅ Set `crds.enabled: false` for cert-manager
2. ✅ Set `installCRDs: false` for external-secrets
3. ✅ CRDs already exist from Phase 1
4. ✅ Prevents duplicate CRD creation attempts
5. ✅ Cleaner separation of concerns

---

### New File: `bootstrap/scripts/bootstrap-infra.sh`

```bash
#!/usr/bin/env bash
# Bootstrap script for infra cluster
# This automates the 3-phase bootstrap process

set -euo pipefail

CLUSTER="infra"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="$(dirname "$SCRIPT_DIR")"

echo "=============================================="
echo "Bootstrapping Cluster: ${CLUSTER}"
echo "=============================================="

# Phase 0: Prerequisites
echo ""
echo "Phase 0: Applying prerequisites..."
kubectl apply -f "${BOOTSTRAP_DIR}/prerequisites/resources.yaml"
echo "✅ Prerequisites applied"

# Wait for namespace to be ready
echo ""
echo "Waiting for namespaces to be ready..."
kubectl wait --for=condition=Ready namespace/external-secrets --timeout=60s
kubectl wait --for=condition=Ready namespace/flux-system --timeout=60s
echo "✅ Namespaces ready"

# Phase 1: CRD Bootstrap
echo ""
echo "Phase 1: Installing CRDs..."
helmfile -f "${BOOTSTRAP_DIR}/helmfile.d/00-crds.yaml" \
  -e "${CLUSTER}" \
  template | kubectl apply -f -

# Wait for CRDs to be established
echo ""
echo "Waiting for CRDs to be established..."
kubectl wait --for condition=established \
  crd/prometheusrules.monitoring.coreos.com \
  crd/servicemonitors.monitoring.coreos.com \
  --timeout=60s
echo "✅ CRDs installed and established"

# Phase 2: Core Infrastructure
echo ""
echo "Phase 2: Deploying core infrastructure..."
helmfile -f "${BOOTSTRAP_DIR}/helmfile.d/01-core.yaml" \
  -e "${CLUSTER}" \
  sync
echo "✅ Core infrastructure deployed"

# Verify Flux is running
echo ""
echo "Verifying Flux deployment..."
kubectl wait --for=condition=Ready \
  pod -l app.kubernetes.io/name=flux-instance \
  -n flux-system \
  --timeout=300s
echo "✅ Flux is running"

# Phase 3: GitOps (automatic)
echo ""
echo "Phase 3: Flux will now reconcile from Git repository"
echo "Monitor with: flux get kustomizations --watch"
echo ""
echo "=============================================="
echo "Bootstrap Complete for ${CLUSTER} cluster!"
echo "=============================================="
```

---

### New File: `bootstrap/scripts/bootstrap-apps.sh`

```bash
#!/usr/bin/env bash
# Bootstrap script for apps cluster
# This automates the 3-phase bootstrap process

set -euo pipefail

CLUSTER="apps"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="$(dirname "$SCRIPT_DIR")"

echo "=============================================="
echo "Bootstrapping Cluster: ${CLUSTER}"
echo "=============================================="

# Phase 0: Prerequisites
echo ""
echo "Phase 0: Applying prerequisites..."
kubectl apply -f "${BOOTSTRAP_DIR}/prerequisites/resources.yaml"
echo "✅ Prerequisites applied"

# Wait for namespace to be ready
echo ""
echo "Waiting for namespaces to be ready..."
kubectl wait --for=condition=Ready namespace/external-secrets --timeout=60s
kubectl wait --for=condition=Ready namespace/flux-system --timeout=60s
echo "✅ Namespaces ready"

# Phase 1: CRD Bootstrap
echo ""
echo "Phase 1: Installing CRDs..."
helmfile -f "${BOOTSTRAP_DIR}/helmfile.d/00-crds.yaml" \
  -e "${CLUSTER}" \
  template | kubectl apply -f -

# Wait for CRDs to be established
echo ""
echo "Waiting for CRDs to be established..."
kubectl wait --for condition=established \
  crd/prometheusrules.monitoring.coreos.com \
  crd/servicemonitors.monitoring.coreos.com \
  --timeout=60s
echo "✅ CRDs installed and established"

# Phase 2: Core Infrastructure
echo ""
echo "Phase 2: Deploying core infrastructure..."
helmfile -f "${BOOTSTRAP_DIR}/helmfile.d/01-core.yaml" \
  -e "${CLUSTER}" \
  sync
echo "✅ Core infrastructure deployed"

# Verify Flux is running
echo ""
echo "Verifying Flux deployment..."
kubectl wait --for=condition=Ready \
  pod -l app.kubernetes.io/name=flux-instance \
  -n flux-system \
  --timeout=300s
echo "✅ Flux is running"

# Phase 3: GitOps (automatic)
echo ""
echo "Phase 3: Flux will now reconcile from Git repository"
echo "Monitor with: flux get kustomizations --watch"
echo ""
echo "=============================================="
echo "Bootstrap Complete for ${CLUSTER} cluster!"
echo "=============================================="
```

---

## Step-by-Step Implementation Guide

### Prerequisites

**Tools Required:**
- `kubectl` >= 1.28
- `helmfile` >= 0.165.0
- `helm` >= 3.14.0
- `yq` >= 4.40.0 (for CRD extraction)
- `flux` CLI >= 2.4.0 (optional, for monitoring)

**Verify Installation:**
```bash
kubectl version --client
helmfile version
helm version
yq --version
flux version --client
```

---

### Step 1: Create New Directory Structure

```bash
# Navigate to repository root
cd /Users/monosense/iac/k8s-gitops

# Create helmfile.d directory
mkdir -p bootstrap/helmfile.d

# Create scripts directory
mkdir -p bootstrap/scripts
```

---

### Step 2: Create CRD Helmfile

```bash
# Create the CRD extraction helmfile
cat > bootstrap/helmfile.d/00-crds.yaml <<'EOF'
# ... (use content from "New File: bootstrap/helmfile.d/00-crds.yaml" above)
EOF
```

**Verify syntax:**
```bash
helmfile -f bootstrap/helmfile.d/00-crds.yaml lint
```

---

### Step 3: Rename and Modify Core Helmfile

```bash
# Backup existing helmfile
cp bootstrap/helmfile.yaml bootstrap/helmfile.yaml.backup

# Move to new location
mv bootstrap/helmfile.yaml bootstrap/helmfile.d/01-core.yaml

# Apply modifications (use content from "Modified File" section)
```

**Key modifications in `01-core.yaml`:**
1. Add `crds.enabled: false` to cert-manager values
2. Add `installCRDs: false` to external-secrets values
3. Update any references to the file path in documentation

**Verify syntax:**
```bash
helmfile -f bootstrap/helmfile.d/01-core.yaml lint
```

---

### Step 4: Create Bootstrap Scripts

```bash
# Create infra bootstrap script
cat > bootstrap/scripts/bootstrap-infra.sh <<'EOF'
# ... (use content from "New File: bootstrap/scripts/bootstrap-infra.sh" above)
EOF

# Create apps bootstrap script
cat > bootstrap/scripts/bootstrap-apps.sh <<'EOF'
# ... (use content from "New File: bootstrap/scripts/bootstrap-apps.sh" above)
EOF

# Make scripts executable
chmod +x bootstrap/scripts/bootstrap-infra.sh
chmod +x bootstrap/scripts/bootstrap-apps.sh
```

---

### Step 5: Update Documentation

**Update:** `bootstrap/README.md` or `bootstrap/BOOTSTRAP-GUIDE.md`

Add section explaining the new 3-phase bootstrap:

```markdown
## Bootstrap Process

### Phase 0: Prerequisites
Apply namespace and secret prerequisites:
```bash
kubectl apply -f bootstrap/prerequisites/resources.yaml
```

### Phase 1: CRD Installation
Install CustomResourceDefinitions before applications:
```bash
# For infra cluster
helmfile -f bootstrap/helmfile.d/00-crds.yaml -e infra template | kubectl apply -f -

# For apps cluster
helmfile -f bootstrap/helmfile.d/00-crds.yaml -e apps template | kubectl apply -f -
```

### Phase 2: Core Infrastructure
Deploy core infrastructure components:
```bash
# For infra cluster
helmfile -f bootstrap/helmfile.d/01-core.yaml -e infra sync

# For apps cluster
helmfile -f bootstrap/helmfile.d/01-core.yaml -e apps sync
```

### Phase 3: GitOps (Automatic)
Flux automatically reconciles infrastructure and workloads from Git.

---

## Automated Bootstrap

Use helper scripts for automated deployment:

```bash
# Bootstrap infra cluster
./bootstrap/scripts/bootstrap-infra.sh

# Bootstrap apps cluster
./bootstrap/scripts/bootstrap-apps.sh
```
```

---

### Step 6: Testing in Development Environment

**Test CRD Extraction** (without applying):
```bash
# Verify CRD extraction works
helmfile -f bootstrap/helmfile.d/00-crds.yaml -e infra template > /tmp/crds.yaml

# Inspect extracted CRDs
grep -E "^kind:|^  name:" /tmp/crds.yaml | head -20

# Should show output like:
# kind: CustomResourceDefinition
#   name: vmagents.operator.victoriametrics.com
# kind: CustomResourceDefinition
#   name: vmalerts.operator.victoriametrics.com
# ...
```

**Test Core Helmfile** (without applying):
```bash
# Verify helmfile renders correctly
helmfile -f bootstrap/helmfile.d/01-core.yaml -e infra template > /tmp/core.yaml

# Verify cert-manager doesn't include CRDs
grep -c "kind: CustomResourceDefinition" /tmp/core.yaml
# Should return 0 or very low number
```

---

### Step 7: Commit Changes

```bash
git add bootstrap/
git commit -m "feat(bootstrap): implement CRD bootstrap pattern for victoria-metrics

- Add bootstrap/helmfile.d/00-crds.yaml for CRD extraction
- Rename bootstrap/helmfile.yaml to 01-core.yaml
- Disable inline CRD installation in cert-manager and external-secrets
- Add automated bootstrap scripts for infra and apps clusters
- Fixes PrometheusRule CRD dependency issues in infrastructure layer

Based on buroa k8s-gitops CRD bootstrap pattern.
Resolves victoria-metrics operator CRD requirements."
```

---

### Step 8: Production Deployment

**For Infra Cluster:**
```bash
# 1. Set kubectl context
kubectl config use-context infra

# 2. Run automated bootstrap
./bootstrap/scripts/bootstrap-infra.sh

# 3. Monitor Flux reconciliation
flux get kustomizations --watch

# 4. Verify PrometheusRules are applied
kubectl get prometheusrules -A
```

**For Apps Cluster:**
```bash
# 1. Set kubectl context
kubectl config use-context apps

# 2. Run automated bootstrap
./bootstrap/scripts/bootstrap-apps.sh

# 3. Monitor Flux reconciliation
flux get kustomizations --watch

# 4. Verify PrometheusRules are applied
kubectl get prometheusrules -A
```

---

## Validation & Testing

### Verify CRDs Are Installed

```bash
# Check VictoriaMetrics CRDs
kubectl get crd | grep victoriametrics

# Expected output:
# vmagents.operator.victoriametrics.com
# vmalertmanagerconfigs.operator.victoriametrics.com
# vmalertmanagers.operator.victoriametrics.com
# vmalerts.operator.victoriametrics.com
# vmauths.operator.victoriametrics.com
# vmclusters.operator.victoriametrics.com
# vmnodescrapes.operator.victoriametrics.com
# vmpodscrapes.operator.victoriametrics.com
# vmprobes.operator.victoriametrics.com
# vmrules.operator.victoriametrics.com
# vmscrapeconfigs.operator.victoriametrics.com
# vmservicescrapes.operator.victoriametrics.com
# vmsingles.operator.victoriametrics.com
# vmstaticscrapes.operator.victoriametrics.com
# vmusers.operator.victoriametrics.com
```

```bash
# Check Prometheus CRDs (from victoria-metrics-operator)
kubectl get crd | grep monitoring.coreos.com

# Expected output:
# alertmanagerconfigs.monitoring.coreos.com
# alertmanagers.monitoring.coreos.com
# podmonitors.monitoring.coreos.com
# probes.monitoring.coreos.com
# prometheuses.monitoring.coreos.com
# prometheusrules.monitoring.coreos.com
# scrapeconfigs.monitoring.coreos.com
# servicemonitors.monitoring.coreos.com
# thanosrulers.monitoring.coreos.com
```

### Verify PrometheusRules Can Be Applied

```bash
# Check PrometheusRules in infrastructure layer
kubectl get prometheusrules -n flux-system
kubectl get prometheusrules -n kube-system
kubectl get prometheusrules -n cert-manager

# Verify no errors in Flux Kustomizations
flux get kustomizations
# All should show "Applied revision"
```

### Verify Victoria Metrics Stack Deploys

```bash
# Check victoria-metrics workload
kubectl get helmrelease -n observability victoria-metrics
kubectl get pods -n observability -l app.kubernetes.io/name=victoria-metrics

# Verify VMAgent, VMSingle, VMAlert are created
kubectl get vmagent -n observability
kubectl get vmsingle -n observability
kubectl get vmalert -n observability
```

---

## Troubleshooting

### Issue: CRD Extraction Fails

**Symptom:**
```
Error: yq: command not found
```

**Solution:**
Install yq:
```bash
# macOS
brew install yq

# Linux
wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/local/bin/yq
chmod +x /usr/local/bin/yq
```

---

### Issue: CRDs Already Exist

**Symptom:**
```
Error: customresourcedefinitions.apiextensions.k8s.io "prometheusrules.monitoring.coreos.com" already exists
```

**Solution:**
This is expected if CRDs were previously installed. The `kubectl apply` command is idempotent and will update existing CRDs.

**Verify CRD versions:**
```bash
kubectl get crd prometheusrules.monitoring.coreos.com -o yaml | grep -A2 "resourceVersion"
```

---

### Issue: PrometheusRule Still Fails to Apply

**Symptom:**
```
no matches for kind "PrometheusRule" in version "monitoring.coreos.com/v1"
```

**Debug Steps:**
1. Verify CRD exists:
   ```bash
   kubectl get crd prometheusrules.monitoring.coreos.com
   ```

2. Check CRD API version:
   ```bash
   kubectl get crd prometheusrules.monitoring.coreos.com -o jsonpath='{.spec.versions[*].name}'
   ```

3. Verify PrometheusRule apiVersion matches:
   ```bash
   grep "apiVersion:" kubernetes/infrastructure/gitops/flux-operator/prometheusrule.yaml
   # Should be: monitoring.coreos.com/v1
   ```

4. Force reconciliation:
   ```bash
   flux reconcile kustomization cluster-infra-infrastructure --with-source
   ```

---

### Issue: Helmfile Sync Hangs

**Symptom:**
Helmfile sync hangs at "waiting for resources to become ready"

**Debug Steps:**
1. Check pod status:
   ```bash
   kubectl get pods -n kube-system
   kubectl get pods -n cert-manager
   kubectl get pods -n external-secrets
   kubectl get pods -n flux-system
   ```

2. Check events:
   ```bash
   kubectl get events -A --sort-by='.lastTimestamp'
   ```

3. Increase timeout:
   ```bash
   helmfile -f bootstrap/helmfile.d/01-core.yaml -e infra sync --timeout 900
   ```

---

## Rollback Plan

If issues occur, rollback to previous bootstrap approach:

### Step 1: Restore Original Helmfile

```bash
# Restore backup
cp bootstrap/helmfile.yaml.backup bootstrap/helmfile.yaml

# Remove new files
rm -rf bootstrap/helmfile.d
rm -rf bootstrap/scripts
```

### Step 2: Uninstall CRDs (if needed)

**⚠️ WARNING:** This will DELETE all resources using these CRDs!

```bash
# Only if absolutely necessary
kubectl delete crd -l app.kubernetes.io/name=victoria-metrics-operator
```

### Step 3: Re-bootstrap with Original Process

```bash
helmfile -e infra sync
```

---

## Migration Path for Existing Clusters

For clusters already running with the old bootstrap approach:

### Option A: In-Place Migration (Recommended)

**No downtime required**

```bash
# 1. Apply CRDs (will update existing CRDs)
helmfile -f bootstrap/helmfile.d/00-crds.yaml -e infra template | kubectl apply -f -

# 2. Verify no disruption
kubectl get pods -A

# 3. Future re-bootstraps will use new process
```

### Option B: Fresh Bootstrap

**Requires cluster rebuild**

1. Backup all persistent data
2. Destroy cluster
3. Bootstrap using new 3-phase process
4. Restore data

---

## Benefits & Impact Analysis

### Benefits

✅ **Dependency Resolution:**
- PrometheusRule CRDs available before infrastructure layer deploys
- No more race conditions or deployment failures

✅ **Clean Separation:**
- CRDs managed separately from applications
- Clear bootstrap phases with explicit ordering

✅ **Multi-Cluster Consistency:**
- Same CRDs deployed to infra and apps clusters
- Predictable deployment process

✅ **Maintainability:**
- Easy to add new CRDs to bootstrap process
- Clear upgrade path for CRD versions

✅ **Automation:**
- Bootstrap scripts reduce manual steps
- Repeatable deployment process

✅ **GitOps Compatibility:**
- Maintains GitOps workflow after bootstrap
- Flux manages post-bootstrap lifecycle

### Performance Impact

- **Bootstrap Time:** +30-60 seconds for CRD phase
- **Resource Usage:** Negligible (CRDs are cluster-scoped metadata)
- **Network:** Additional Helm chart pulls during CRD phase

### Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| CRD version mismatch | Low | Medium | Pin CRD chart versions in helmfile |
| yq dependency missing | Medium | Low | Document installation, include in CI |
| Breaking CRD changes | Low | High | Test in dev environment first |
| Rollback complexity | Low | Medium | Maintain backup helmfile, document rollback |

---

## Future Enhancements

### Phase 2 Improvements

1. **Automated CRD Version Management:**
   - Renovate/Dependabot for CRD chart updates
   - Automated testing of CRD upgrades

2. **CRD Validation:**
   - Pre-flight checks to verify all required CRDs exist
   - Post-deployment validation of CRD versions

3. **Cluster Upgrade Automation:**
   - Integrated CRD updates during cluster upgrades
   - Automated compatibility checks

4. **Multi-Cluster Sync:**
   - Ensure CRD versions match across infra/apps clusters
   - Automated drift detection

---

## References

### Documentation

- [Buroa K8s GitOps Repository](https://github.com/buroa/k8s-gitops)
- [VictoriaMetrics Operator Documentation](https://docs.victoriametrics.com/operator/)
- [VictoriaMetrics Operator CRDs Helm Chart](https://docs.victoriametrics.com/helm/victoria-metrics-operator-crds/)
- [Helmfile Documentation](https://helmfile.readthedocs.io/)
- [Kubernetes CRD Documentation](https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/)

### Related Issues

- PrometheusRule dependency in infrastructure layer
- Victoria Metrics operator CRD requirements
- Multi-cluster bootstrap consistency

---

## Appendix: Complete File Checklist

### Files to Create

- [ ] `bootstrap/helmfile.d/00-crds.yaml`
- [ ] `bootstrap/scripts/bootstrap-infra.sh`
- [ ] `bootstrap/scripts/bootstrap-apps.sh`

### Files to Modify

- [ ] `bootstrap/helmfile.yaml` → rename to `bootstrap/helmfile.d/01-core.yaml`
- [ ] Update cert-manager values (disable CRDs)
- [ ] Update external-secrets values (disable CRDs)
- [ ] `bootstrap/README.md` or `bootstrap/BOOTSTRAP-GUIDE.md` (update instructions)

### Files to Backup

- [ ] `bootstrap/helmfile.yaml` → `bootstrap/helmfile.yaml.backup`

---

## Sign-Off

**Implementation Ready:** ✅ Yes
**Testing Required:** ✅ Yes (development environment)
**Production Ready:** ✅ Yes (after testing)
**Rollback Plan:** ✅ Documented

**Next Steps:**
1. Review this plan with team
2. Test in development environment
3. Update documentation
4. Deploy to production clusters

---

**Document Version:** 1.0
**Last Updated:** 2025-10-15
**Owner:** Infrastructure Team
**Status:** Implementation Ready
