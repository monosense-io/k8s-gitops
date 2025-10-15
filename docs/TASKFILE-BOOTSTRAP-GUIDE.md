# Taskfile Bootstrap Automation Guide
## Automated 3-Phase CRD Bootstrap for Multi-Cluster Kubernetes

**Author:** Alex - DevOps Infrastructure Specialist
**Date:** 2025-10-15
**Version:** 1.0

---

## Overview

This guide covers the automated Taskfile-based bootstrap system for deploying Kubernetes clusters with proper CRD management. The system implements the 3-phase bootstrap pattern with comprehensive validation and pre-flight checks.

**Key Features:**
- ✅ Automated 3-phase bootstrap (Prerequisites → CRDs → Core → Validation)
- ✅ Pre-flight checks (tools, cluster connectivity, files)
- ✅ Multi-cluster support (infra, apps)
- ✅ 1Password secret injection
- ✅ Comprehensive validation
- ✅ Status monitoring and health checks
- ✅ Dry-run capability
- ✅ Idempotent execution

---

## Quick Start

### Bootstrap Infra Cluster

```bash
# One-command automated bootstrap
task bootstrap:infra
```

### Bootstrap Apps Cluster

```bash
# One-command automated bootstrap
task bootstrap:apps
```

That's it! The Taskfile handles all phases automatically.

---

## Available Commands

### High-Level Commands

| Command | Description | Use Case |
|---------|-------------|----------|
| `task bootstrap:infra` | 🚀 Bootstrap infra cluster (all phases) | First-time cluster setup |
| `task bootstrap:apps` | 🚀 Bootstrap apps cluster (all phases) | First-time cluster setup |
| `task bootstrap:status` | 📊 Show cluster status | Check deployment health |
| `task bootstrap:list-crds` | 📋 List VictoriaMetrics CRDs | Verify CRDs installed |
| `task bootstrap:dry-run` | 🔍 Show what would be done | Test before applying |
| `task bootstrap:preflight` | 🔍 Run pre-flight checks only | Validate environment |

### Phase-Specific Commands

| Command | Description | Use Case |
|---------|-------------|----------|
| `task bootstrap:phase:0 CLUSTER=infra` | 📦 Apply prerequisites only | Manual phase control |
| `task bootstrap:phase:1 CLUSTER=infra` | 🔧 Install CRDs only | Manual phase control |
| `task bootstrap:phase:2 CLUSTER=infra` | 🚀 Deploy core infrastructure | Manual phase control |
| `task bootstrap:phase:3 CLUSTER=infra` | ✅ Validate deployment | Manual phase control |

### Utility Commands

| Command | Description | Use Case |
|---------|-------------|----------|
| `task bootstrap:clean CLUSTER=infra` | 🧹 Delete CRDs (DANGEROUS!) | Emergency cleanup |
| `task --list-all` | Show all available tasks | Discovery |

---

## Usage Examples

### Example 1: Standard Bootstrap

```bash
# Bootstrap infra cluster
task bootstrap:infra

# Output:
# 🔍 Checking required tools...
#   ✅ kubectl
#   ✅ helmfile
#   ✅ yq
#   ✅ flux
#   ⚠️  op (optional)
#
# 🔍 Checking cluster connectivity...
#   ✅ Cluster infra (context: infra) is reachable
#   ℹ️  Kubernetes version: v1.30.0
#
# 🔍 Checking bootstrap files...
#   ✅ resources.yaml
#   ✅ 00-crds.yaml
#   ✅ 01-core.yaml
#   ✅ values.yaml
#
# 🎯 Bootstrapping infra cluster...
#
# 📦 Phase 0: Applying prerequisites...
#   → Applying prerequisites (without secret injection)...
#   → Waiting for namespaces...
# ✅ Prerequisites applied
#
# 🔧 Phase 1: Installing CRDs...
#   → Extracting and applying CRDs...
#   → Waiting for CRDs to be established...
# ✅ CRDs installed and established
#
# 🚀 Phase 2: Deploying core infrastructure...
#   → Syncing core infrastructure via helmfile...
#   → Waiting for Flux to be ready...
# ✅ Core infrastructure deployed
#
# ✅ Phase 3: Validating deployment...
#   → Checking VictoriaMetrics CRDs...
#     ✅ Found 14 VictoriaMetrics CRDs
#   → Checking Flux Kustomizations...
#     ✅ All Flux Kustomizations ready
#   → Checking PrometheusRules...
#     ✅ Found 17 PrometheusRule resources
# ✅ Validation complete
#
# ✅ Bootstrap complete for infra cluster!
```

### Example 2: Check Status Before Bootstrap

```bash
# Check cluster status
task bootstrap:status CLUSTER=infra

# Output:
# ==============================================
# 📊 Cluster Status: infra
# ==============================================
#
# 📋 CRD Status:
#   VictoriaMetrics CRDs: 14
#   Prometheus CRDs: 9
#
# 🔧 Core Components:
#   Cilium pods: 6
#   cert-manager pods: 3
#   Flux pods: 5
#
# 📊 Flux Kustomizations:
# NAME                          READY   MESSAGE
# cluster-infra-infrastructure  True    Applied revision: main/abc123
# cluster-infra-settings        True    Applied revision: main/abc123
# cluster-infra-workloads       True    Applied revision: main/abc123
# flux-repositories             True    Applied revision: main/abc123
#
# ⚠️  PrometheusRules:
#   Total PrometheusRules: 17
# ==============================================
```

### Example 3: Dry-Run Before Applying

```bash
# See what bootstrap would do without applying
task bootstrap:dry-run CLUSTER=infra

# Output:
# === Bootstrap Dry-Run for infra ===
#
# Phase 0: Would apply prerequisites
# ---
# apiVersion: v1
# kind: Namespace
# metadata:
#   name: external-secrets
# ...
#
# Phase 1: Would extract and apply CRDs
# kind: CustomResourceDefinition
# kind: CustomResourceDefinition
# kind: CustomResourceDefinition
# ...
#
# Phase 2: Would sync core infrastructure
# NAME              CHART                   VERSION
# cilium            oci://quay.io/cilium    1.16.5
# cert-manager      oci://quay.io/jetstack  v1.16.2
# ...
#
# Phase 3: Would validate deployment
```

### Example 4: Manual Phase Control

```bash
# Run individual phases with control
task bootstrap:phase:0 CLUSTER=infra  # Prerequisites
task bootstrap:phase:1 CLUSTER=infra  # CRDs
task bootstrap:phase:2 CLUSTER=infra  # Core infrastructure
task bootstrap:phase:3 CLUSTER=infra  # Validation
```

### Example 5: With 1Password Secret Injection

```bash
# Ensure 1Password CLI is authenticated
eval $(op signin)

# Bootstrap with automatic secret injection
task bootstrap:infra

# Output will show:
#   → Injecting 1Password secrets...
# (instead of "without secret injection")
```

### Example 6: List Installed CRDs

```bash
# List all VictoriaMetrics and Prometheus CRDs
task bootstrap:list-crds CLUSTER=infra

# Output:
# VictoriaMetrics CRDs:
#      1  vmagents.operator.victoriametrics.com
#      2  vmalertmanagerconfigs.operator.victoriametrics.com
#      3  vmalertmanagers.operator.victoriametrics.com
#      4  vmalerts.operator.victoriametrics.com
#      5  vmauths.operator.victoriametrics.com
#      6  vmclusters.operator.victoriametrics.com
#      7  vmnodescrapes.operator.victoriametrics.com
#      8  vmpodscrapes.operator.victoriametrics.com
#      9  vmprobes.operator.victoriametrics.com
#     10  vmrules.operator.victoriametrics.com
#     11  vmscrapeconfigs.operator.victoriametrics.com
#     12  vmservicescrapes.operator.victoriametrics.com
#     13  vmsingles.operator.victoriametrics.com
#     14  vmstaticscrapes.operator.victoriametrics.com
#     15  vmusers.operator.victoriametrics.com
#
# Prometheus Monitoring CRDs:
#      1  alertmanagerconfigs.monitoring.coreos.com
#      2  alertmanagers.monitoring.coreos.com
#      3  podmonitors.monitoring.coreos.com
#      4  probes.monitoring.coreos.com
#      5  prometheuses.monitoring.coreos.com
#      6  prometheusrules.monitoring.coreos.com
#      7  scrapeconfigs.monitoring.coreos.com
#      8  servicemonitors.monitoring.coreos.com
#      9  thanosrulers.monitoring.coreos.com
```

---

## Bootstrap Workflow

### Phase 0: Prerequisites

**What it does:**
- Applies namespace definitions (external-secrets, flux-system)
- Creates 1Password Connect secrets (if `op` CLI available)
- Waits for namespaces to be Active

**Files applied:**
- `bootstrap/prerequisites/resources.yaml`

**Duration:** ~30 seconds

### Phase 1: CRD Installation

**What it does:**
- Extracts CRDs from Helm charts using helmfile
- Filters only CustomResourceDefinition kinds using yq
- Applies CRDs to cluster
- Waits for CRDs to reach Established status

**CRDs installed:**
- VictoriaMetrics Operator CRDs (14 CRDs)
- cert-manager CRDs
- external-secrets CRDs

**Duration:** ~1-2 minutes

### Phase 2: Core Infrastructure

**What it does:**
- Deploys Cilium CNI
- Deploys CoreDNS
- Deploys Spegel (registry mirror)
- Deploys cert-manager (without CRDs)
- Deploys external-secrets (without CRDs)
- Deploys Flux Operator
- Deploys Flux Instance (with GitRepository sync)
- Waits for Flux to be ready

**Duration:** ~5-10 minutes

### Phase 3: Validation

**What it does:**
- Verifies VictoriaMetrics CRDs are installed (expects 14+)
- Checks Flux Kustomizations are Ready
- Counts PrometheusRule resources

**Exit codes:**
- 0 = All validations passed
- 1 = Validation failed (check output)

**Duration:** ~10-30 seconds

---

## Pre-Flight Checks

Before bootstrap begins, the following checks are performed automatically:

### Tool Checks

**Required Tools:**
- `kubectl` - Kubernetes CLI
- `helmfile` - Helmfile CLI
- `yq` - YAML processor

**Optional Tools:**
- `flux` - Flux CLI (for monitoring)
- `op` - 1Password CLI (for secret injection)

**Installation:**
```bash
# macOS
brew install kubectl helmfile yq flux 1password-cli

# Linux
# See individual tool documentation
```

### Cluster Connectivity

**Checks:**
- kubectl context exists
- Cluster is reachable
- API server responds
- Kubernetes version retrieval

**Fix issues:**
```bash
# List available contexts
kubectl config get-contexts

# Set current context
kubectl config use-context infra

# Test connectivity
kubectl cluster-info
```

### File Checks

**Verified Files:**
- `bootstrap/prerequisites/resources.yaml`
- `bootstrap/helmfile.d/00-crds.yaml`
- `bootstrap/helmfile.d/01-core.yaml`
- `bootstrap/clusters/{CLUSTER}/values.yaml`

**Fix issues:**
```bash
# Verify files exist
ls -la bootstrap/prerequisites/resources.yaml
ls -la bootstrap/helmfile.d/
ls -la bootstrap/clusters/infra/values.yaml
```

---

## Troubleshooting

### Issue: Pre-flight Check Fails

**Symptom:**
```
❌ Missing required tools: helmfile yq
Install with: brew install helmfile yq
```

**Solution:**
```bash
brew install helmfile yq
```

---

### Issue: Cluster Not Reachable

**Symptom:**
```
❌ Cannot connect to cluster infra
```

**Solution:**
```bash
# Check available contexts
kubectl config get-contexts

# Switch to correct context
kubectl config use-context infra

# Verify connectivity
kubectl cluster-info
```

---

### Issue: CRD Wait Timeout

**Symptom:**
```
error: timed out waiting for the condition on customresourcedefinitions/prometheusrules.monitoring.coreos.com
```

**Solution:**
```bash
# Check CRD status manually
kubectl get crd prometheusrules.monitoring.coreos.com

# If CRD exists but not Established, check API server logs
kubectl logs -n kube-system -l component=kube-apiserver

# Re-apply CRDs
task bootstrap:phase:1 CLUSTER=infra
```

---

### Issue: Flux Not Ready

**Symptom:**
```
error: timed out waiting for the condition on pods
```

**Solution:**
```bash
# Check Flux pods
kubectl get pods -n flux-system

# Check Flux operator logs
kubectl logs -n flux-system -l app.kubernetes.io/name=flux-operator

# Check Flux instance logs
kubectl logs -n flux-system -l app.kubernetes.io/name=flux-instance

# Retry phase 2
task bootstrap:phase:2 CLUSTER=infra
```

---

### Issue: PrometheusRule Validation Fails

**Symptom:**
```
⚠️  No PrometheusRule resources found yet
```

**Solution:**
This is normal immediately after bootstrap. PrometheusRules are created by Flux during infrastructure reconciliation.

```bash
# Wait for Flux to reconcile
flux reconcile kustomization cluster-infra-infrastructure --with-source

# Check PrometheusRules after a few minutes
kubectl get prometheusrules -A
```

---

### Issue: 1Password Secret Injection Fails

**Symptom:**
```
[ERROR] 2024/10/15 12:00:00 failed to fetch item: 401 Unauthorized
```

**Solution:**
```bash
# Authenticate with 1Password
eval $(op signin)

# Verify authentication
op account list

# Re-run bootstrap
task bootstrap:infra
```

---

## Advanced Usage

### Custom Kubernetes Context

```bash
# Bootstrap with specific context name
task bootstrap:bootstrap CLUSTER=infra CONTEXT=my-custom-context
```

### Skip Pre-flight Checks

```bash
# Not recommended, but possible by calling phases directly
task bootstrap:phase:0 CLUSTER=infra
# (pre-flight checks are dependency of bootstrap task)
```

### Re-bootstrap Existing Cluster

```bash
# Taskfile is idempotent - safe to re-run
task bootstrap:infra

# CRDs will be updated (not recreated)
# Helmfile will upgrade existing releases
# No data loss
```

### Bootstrap with Different Values

```bash
# Create custom values file
cp bootstrap/clusters/infra/values.yaml bootstrap/clusters/infra/values-custom.yaml

# Edit values
vim bootstrap/clusters/infra/values-custom.yaml

# Update helmfile.d/00-crds.yaml and 01-core.yaml to reference custom file
# Then run bootstrap
task bootstrap:infra
```

---

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Bootstrap Cluster

on:
  workflow_dispatch:
    inputs:
      cluster:
        description: 'Cluster to bootstrap'
        required: true
        type: choice
        options:
          - infra
          - apps

jobs:
  bootstrap:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Install Tools
        run: |
          brew install kubectl helmfile yq flux 1password-cli

      - name: Configure kubectl
        env:
          KUBECONFIG_DATA: ${{ secrets.KUBECONFIG }}
        run: |
          echo "$KUBECONFIG_DATA" | base64 -d > $KUBECONFIG

      - name: Authenticate 1Password
        env:
          OP_SERVICE_ACCOUNT_TOKEN: ${{ secrets.OP_SERVICE_ACCOUNT_TOKEN }}
        run: |
          eval $(op signin)

      - name: Run Pre-flight Checks
        run: |
          task bootstrap:preflight CLUSTER=${{ github.event.inputs.cluster }}

      - name: Bootstrap Cluster
        run: |
          task bootstrap:${{ github.event.inputs.cluster }}

      - name: Validate Bootstrap
        run: |
          task bootstrap:status CLUSTER=${{ github.event.inputs.cluster }}
```

---

## Best Practices

### 1. Run Pre-flight Checks First

```bash
# Always verify environment before bootstrap
task bootstrap:preflight CLUSTER=infra
```

### 2. Use Dry-Run for Testing

```bash
# Test changes without applying
task bootstrap:dry-run CLUSTER=infra
```

### 3. Monitor Status During Bootstrap

```bash
# In separate terminal, watch status
watch -n 2 'task bootstrap:status CLUSTER=infra'
```

### 4. Authenticate 1Password Before Bootstrap

```bash
# Prevent secret injection failures
eval $(op signin)
task bootstrap:infra
```

### 5. Backup Before Major Changes

```bash
# Backup CRDs
kubectl get crd -o yaml > crds-backup-$(date +%Y%m%d).yaml

# Backup custom resources
kubectl get prometheusrules -A -o yaml > prometheusrules-backup-$(date +%Y%m%d).yaml
```

---

## Task Variables

| Variable | Default | Description | Example |
|----------|---------|-------------|---------|
| `CLUSTER` | (required) | Cluster name | `infra`, `apps` |
| `CONTEXT` | `${CLUSTER}` | kubectl context | `my-custom-context` |

**Usage:**
```bash
task bootstrap:infra                           # Uses CLUSTER=infra, CONTEXT=infra
task bootstrap:bootstrap CLUSTER=apps          # Uses CLUSTER=apps, CONTEXT=apps
task bootstrap:bootstrap CLUSTER=infra CONTEXT=prod-infra  # Custom context
```

---

## Directory Structure

```
.
├── .taskfiles/
│   └── bootstrap/
│       └── Taskfile.yaml          # Bootstrap automation tasks
├── bootstrap/
│   ├── prerequisites/
│   │   └── resources.yaml         # Prerequisites (namespaces, secrets)
│   ├── helmfile.d/
│   │   ├── 00-crds.yaml          # CRD extraction helmfile
│   │   └── 01-core.yaml          # Core infrastructure helmfile
│   └── clusters/
│       ├── infra/
│       │   └── values.yaml       # Infra-specific values
│       └── apps/
│           └── values.yaml       # Apps-specific values
└── Taskfile.yaml                  # Main taskfile (includes bootstrap)
```

---

## Integration with Existing Workflows

### Flux Post-Bootstrap

After bootstrap completes, Flux automatically reconciles:

```
Phase 3 Complete
     ↓
Flux Reconciliation (automatic)
     ↓
cluster-settings → flux-repositories → infrastructure → workloads
```

**Monitor Flux:**
```bash
# Watch Flux Kustomizations
flux get kustomizations --watch

# Check specific Kustomization
flux get kustomization cluster-infra-infrastructure

# Force reconciliation
flux reconcile kustomization cluster-infra-infrastructure --with-source
```

---

## FAQ

### Q: Can I run bootstrap multiple times?

**A:** Yes! The Taskfile is idempotent. Running bootstrap multiple times is safe and will:
- Update CRDs if versions changed
- Upgrade Helm releases
- Not destroy existing resources

### Q: What if I only want to update CRDs?

**A:** Run phase 1 only:
```bash
task bootstrap:phase:1 CLUSTER=infra
```

### Q: How do I add a new cluster?

**A:**
1. Create `bootstrap/clusters/{new-cluster}/values.yaml`
2. Add cluster to environments in `bootstrap/helmfile.d/*.yaml`
3. Add task in `.taskfiles/bootstrap/Taskfile.yaml`:
```yaml
new-cluster:
  desc: 🚀 Bootstrap new-cluster
  cmds:
    - task: bootstrap
      vars: {CLUSTER: new-cluster, CONTEXT: new-cluster}
```

### Q: Can I bootstrap without 1Password?

**A:** Yes! The Taskfile automatically detects if `op` CLI is available and authenticated. If not, it applies prerequisites without secret injection. You'll need to manually create secrets:
```bash
kubectl create secret generic onepassword-connect \
  -n external-secrets \
  --from-literal=token=your-token \
  --from-file=1password-credentials.json
```

### Q: What's the difference between task and helmfile?

**A:**
- **Taskfile** orchestrates the overall bootstrap process (phases, validation, checks)
- **Helmfile** deploys Helm charts within phases

### Q: How do I rollback?

**A:** Taskfile doesn't provide automatic rollback. Manual rollback:
```bash
# Restore CRDs from backup
kubectl apply -f crds-backup-20241015.yaml

# Rollback Helm releases
helmfile -f bootstrap/helmfile.d/01-core.yaml -e infra destroy
```

---

## Related Documentation

- [CRD Bootstrap Implementation Plan](./CRD-BOOTSTRAP-IMPLEMENTATION-PLAN.md)
- [CRD Bootstrap Best Practices](./CRD-BOOTSTRAP-BEST-PRACTICES.md)
- [Main Taskfile](../Taskfile.yaml)
- [Bootstrap Taskfile](../.taskfiles/bootstrap/Taskfile.yaml)

---

## Support

For issues or questions:
- Check troubleshooting section above
- Review implementation plan and best practices docs
- Check Taskfile task definitions for details
- Verify pre-flight checks pass

---

**Document Version:** 1.0
**Last Updated:** 2025-10-15
**Maintained By:** Platform Engineering Team
