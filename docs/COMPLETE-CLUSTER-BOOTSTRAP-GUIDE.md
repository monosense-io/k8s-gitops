# Complete End-to-End Cluster Bootstrap Guide
## From Bare Metal to Production-Ready Kubernetes

**Author:** Alex - DevOps Infrastructure Specialist
**Date:** 2025-10-15
**Version:** 1.0

---

## Overview

This guide covers the **complete end-to-end cluster bootstrap process** from bare metal servers to fully operational Kubernetes clusters with Flux GitOps. The automation handles **5 layers** of infrastructure:

```
Layer 1: Talos Cluster (Operating System)
         ↓
Layer 2: Kubernetes (Control Plane)
         ↓
Layer 3: CRDs (Custom Resource Definitions)
         ↓
Layer 4: Core Infrastructure (CNI, DNS, Flux)
         ↓
Layer 5: Validation (Health Checks)
```

**Total Time:** ~15-20 minutes from bare metal to production-ready

---

## Quick Start

### Create Infra Cluster (Complete)

```bash
# One command - creates complete cluster from scratch
task cluster:create-infra
```

### Create Apps Cluster (Complete)

```bash
# One command - creates complete cluster from scratch
task cluster:create-apps
```

**That's it!** The automation handles everything.

---

## Table of Contents

- [Quick Start](#quick-start)
- [Prerequisites](#prerequisites)
- [Available Commands](#available-commands)
- [Layer-by-Layer Breakdown](#layer-by-layer-breakdown)
- [Complete Workflow](#complete-workflow)
- [Cluster Management](#cluster-management)
- [Troubleshooting](#troubleshooting)
- [Advanced Usage](#advanced-usage)

---

## Prerequisites

### Required Tools

```bash
# Install all required tools (macOS)
brew install kubectl helmfile yq talosctl minijinja-cli flux 1password-cli
```

**Tool versions:**
- `kubectl` >= 1.28
- `helmfile` >= 0.165.0
- `yq` >= 4.40.0
- `talosctl` >= 1.7.0
- `minijinja-cli` >= latest
- `flux` >= 2.4.0
- `op` (1Password CLI) >= 2.0 (optional)

### Network Requirements

**Infra Cluster:**
- 3 control plane nodes
- IP range: 10.25.11.11 - 10.25.11.13
- VIP for API server (configured in Cilium BGP)

**Apps Cluster:**
- 3 control plane nodes
- IP range: 10.25.11.14 - 10.25.11.16
- VIP for API server (configured in Cilium BGP)

### Hardware Requirements

**Per Node:**
- CPU: 4+ cores
- RAM: 16GB+
- Disk: 100GB+ NVMe
- Network: 10GbE bonded interfaces

### File Structure

```
talos/
├── machineconfig.yaml.j2      # Talos config template
├── schematic.yaml             # Talos system extensions
├── infra/                     # Infra cluster node configs
│   ├── 10.25.11.11.yaml      # Control plane 1
│   ├── 10.25.11.12.yaml      # Control plane 2
│   └── 10.25.11.13.yaml      # Control plane 3
└── apps/                      # Apps cluster node configs
    ├── 10.25.11.14.yaml      # Control plane 1
    ├── 10.25.11.15.yaml      # Control plane 2
    └── 10.25.11.16.yaml      # Control plane 3
```

---

## Available Commands

### Complete Cluster Creation

| Command | Description | Time |
|---------|-------------|------|
| `task cluster:create-infra` | Create complete infra cluster | ~15-20 min |
| `task cluster:create-apps` | Create complete apps cluster | ~15-20 min |

### Cluster Status & Monitoring

| Command | Description |
|---------|-------------|
| `task cluster:status CLUSTER=infra` | Show complete cluster status |
| `task cluster:status-infra` | Show infra cluster status |
| `task cluster:status-apps` | Show apps cluster status |
| `task cluster:health CLUSTER=infra` | Quick health check |

### Validation

| Command | Description |
|---------|-------------|
| `task cluster:validate:all CLUSTER=infra` | Validate all layers |
| `task cluster:validate:talos CLUSTER=infra` | Validate Talos only |
| `task cluster:validate:kubernetes CLUSTER=infra` | Validate Kubernetes only |

### Cluster Destruction

| Command | Description |
|---------|-------------|
| `task cluster:destroy-infra` | Destroy complete infra cluster (DANGEROUS!) |
| `task cluster:destroy-apps` | Destroy complete apps cluster (DANGEROUS!) |
| `task cluster:soft-destroy CLUSTER=infra` | Remove K8s apps (keep Talos) |

### Utility

| Command | Description |
|---------|-------------|
| `task cluster:list-nodes CLUSTER=infra` | List all nodes |
| `task cluster:dry-run CLUSTER=infra` | Preview what will be done |
| `task cluster:preflight CLUSTER=infra` | Run pre-flight checks |

---

## Layer-by-Layer Breakdown

### Layer 1: Talos Cluster Bootstrap (~5 min)

**What Happens:**
1. Apply Talos configuration to first control plane node (bootstrap node)
2. Wait for Talos API to be responsive
3. Bootstrap etcd on first node
4. Apply Talos configuration to remaining control planes
5. Wait for etcd cluster formation (quorum)
6. Wait for all nodes to be healthy
7. Generate kubeconfig

**Key Steps:**
```bash
# Bootstrap first node with etcd init
talosctl apply-config --nodes 10.25.11.11 --file machineconfig.yaml

# Bootstrap etcd
talosctl bootstrap --nodes 10.25.11.11

# Apply to remaining nodes (they join etcd cluster)
talosctl apply-config --nodes 10.25.11.12 --file machineconfig.yaml
talosctl apply-config --nodes 10.25.11.13 --file machineconfig.yaml

# Generate kubeconfig
talosctl kubeconfig
```

**Duration:** ~5 minutes

**Success Criteria:**
- All nodes report healthy via `talosctl health`
- Etcd cluster has quorum (3 members)
- Kubeconfig generated successfully

---

### Layer 2: Kubernetes Waiting (~2-3 min)

**What Happens:**
1. Wait for Kubernetes API server to respond
2. Wait for control plane nodes to reach Ready state
3. Verify etcd health via Talos
4. Display cluster node information

**Key Steps:**
```bash
# Wait for API server (up to 5 minutes)
until kubectl cluster-info; do sleep 5; done

# Wait for nodes Ready
kubectl wait --for=condition=Ready nodes --all --timeout=5m

# Verify etcd
talosctl etcd status --nodes 10.25.11.11
```

**Duration:** ~2-3 minutes

**Success Criteria:**
- API server responds to `kubectl cluster-info`
- All control plane nodes show Ready status
- Etcd cluster is healthy

---

### Layer 3: CRD Bootstrap (~1-2 min)

**What Happens:**
1. Apply prerequisites (namespaces, secrets)
2. Extract and install CRDs from Helm charts:
   - VictoriaMetrics Operator CRDs (14 CRDs)
   - cert-manager CRDs
   - external-secrets CRDs
3. Wait for CRDs to reach Established state

**Key Steps:**
```bash
# Prerequisites
kubectl apply -f bootstrap/prerequisites/resources.yaml

# Extract and apply CRDs
helmfile -f bootstrap/helmfile.d/00-crds.yaml -e infra template | kubectl apply -f -

# Wait for CRDs
kubectl wait --for condition=established crd/prometheusrules.monitoring.coreos.com
```

**Duration:** ~1-2 minutes

**Success Criteria:**
- Namespaces created (external-secrets, flux-system)
- 14+ VictoriaMetrics CRDs installed
- 9+ Prometheus monitoring CRDs installed
- All CRDs in Established state

---

### Layer 4: Core Infrastructure (~5-10 min)

**What Happens:**
1. Deploy Cilium CNI (Container Network Interface)
2. Deploy CoreDNS (DNS resolution)
3. Deploy Spegel (registry mirror)
4. Deploy cert-manager (certificate management)
5. Deploy external-secrets (secret management)
6. Deploy Flux Operator
7. Deploy Flux Instance (GitOps controllers)
8. Wait for Flux to be ready

**Key Steps:**
```bash
# Deploy via helmfile
helmfile -f bootstrap/helmfile.d/01-core.yaml -e infra sync

# Wait for Flux
kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=flux-instance -n flux-system
```

**Duration:** ~5-10 minutes

**Success Criteria:**
- Cilium pods running in kube-system
- CoreDNS pods running
- cert-manager pods running
- external-secrets pods running
- Flux pods running and healthy
- GitRepository sync configured

---

### Layer 5: Validation (~30 sec)

**What Happens:**
1. Validate Talos layer (nodes, etcd)
2. Validate Kubernetes layer (nodes, pods)
3. Validate CRDs (count, establishment)
4. Validate networking (Cilium health)
5. Validate Flux (Kustomizations ready)

**Key Steps:**
```bash
# Validate Talos
talosctl health --nodes 10.25.11.11,10.25.11.12,10.25.11.13

# Validate Kubernetes
kubectl get nodes
kubectl get pods -A

# Validate CRDs
kubectl get crd | grep victoriametrics

# Validate Flux
flux get kustomizations -A
```

**Duration:** ~30 seconds

**Success Criteria:**
- All Talos nodes healthy
- All Kubernetes nodes Ready
- 14+ VictoriaMetrics CRDs present
- Cilium pods running
- Flux Kustomizations reconciling

---

## Complete Workflow

### Step 1: Pre-Flight Checks

```bash
# Verify tools, configuration, and connectivity
task cluster:preflight CLUSTER=infra
```

**Output:**
```
🔍 Checking required tools...
  ✅ kubectl
  ✅ helmfile
  ✅ yq
  ✅ talosctl
  ✅ minijinja-cli
  ✅ flux
  ✅ op

🔍 Checking Talos configuration...
  ✅ Found 3 node configuration(s)
    - 10.25.11.11.yaml
    - 10.25.11.12.yaml
    - 10.25.11.13.yaml

🔍 Checking 1Password connectivity...
  ✅ 1Password CLI authenticated
```

---

### Step 2: Create Cluster

```bash
# Authenticate with 1Password (optional but recommended)
eval $(op signin)

# Create complete cluster
task cluster:create-infra
```

**Expected Output (abbreviated):**
```
🎯 Creating infra cluster from scratch...
  This will take approximately 15-20 minutes

==============================================
🔧 Layer 1: Bootstrapping Talos Cluster
==============================================
  Cluster: infra
  Bootstrap node: 10.25.11.11
  Additional nodes: 10.25.11.12 10.25.11.13

📦 Step 1/6: Bootstrapping first control plane...
  → Applying config to node: 10.25.11.11

⏳ Step 2/6: Waiting for Talos API to be ready...
  ✅ Talos API responding

🔧 Step 3/6: Bootstrapping etcd on first node...
  ✅ etcd bootstrapped

📦 Step 4/6: Configuring additional control plane nodes...
  → Applying config to node 1: 10.25.11.12
  → Applying config to node 2: 10.25.11.13

⏳ Step 5/6: Waiting for etcd cluster formation...
  ✅ etcd cluster formed (3 members)

⏳ Step 6/6: Waiting for all Talos nodes to be healthy...
  ✅ All nodes healthy

📝 Generating kubeconfig...
  ✅ kubeconfig generated

✅ Layer 1 Complete: Talos cluster is running

==============================================
⏳ Layer 2: Waiting for Kubernetes
==============================================
📡 Waiting for Kubernetes API server...
  ✅ API server is responding

🖥️  Waiting for control plane nodes to be Ready...
  ✅ Nodes ready

📋 Cluster nodes:
NAME       STATUS   ROLES           AGE   VERSION
infra-01   Ready    control-plane   2m    v1.30.0
infra-02   Ready    control-plane   1m    v1.30.0
infra-03   Ready    control-plane   1m    v1.30.0

✅ Layer 2 Complete: Kubernetes is ready

==============================================
🔧 Layer 3: Installing CRDs
==============================================
📦 Phase 0: Applying prerequisites...
  → Injecting 1Password secrets...
  ✅ Prerequisites applied

🔧 Phase 1: Installing CRDs...
  → Extracting and applying CRDs...
  → Waiting for CRDs to be established...
    ✅ Found 14 VictoriaMetrics CRDs
  ✅ CRDs installed and established

✅ Layer 3 Complete: CRDs installed

==============================================
🚀 Layer 4: Deploying Core Infrastructure
==============================================
🚀 Phase 2: Deploying core infrastructure...
  → Syncing core infrastructure via helmfile...
  → Waiting for Flux to be ready...
  ✅ Flux ready

✅ Layer 4 Complete: Core infrastructure deployed

==============================================
✅ Layer 5: Validating Complete Cluster
==============================================
🔍 Validating Talos layer...
  ✅ Talos health check passed

🔍 Validating Kubernetes layer...
  ✅ All pods are healthy

🔍 Validating CRDs...
  ✅ Found 14 VictoriaMetrics CRDs

🔍 Validating networking layer...
  ✅ Networking check passed

🔍 Validating Flux layer...
  ✅ All Flux Kustomizations ready

✅ Layer 5 Complete: All validations passed

✅ Cluster infra created successfully!

==============================================
📊 Complete Cluster Status: infra
==============================================

🔧 Talos Layer:
  Nodes:
    - 10.25.11.11: ✅ Online (Talos v1.7.0)
    - 10.25.11.12: ✅ Online (Talos v1.7.0)
    - 10.25.11.13: ✅ Online (Talos v1.7.0)

  Etcd:
    MEMBER                  HEALTHY   TOOK
    10.25.11.11:2379       true      3.5ms
    10.25.11.12:2379       true      3.8ms
    10.25.11.13:2379       true      3.2ms

🖥️  Kubernetes Layer:
NAME       STATUS   ROLES           AGE   VERSION
infra-01   Ready    control-plane   5m    v1.30.0
infra-02   Ready    control-plane   4m    v1.30.0
infra-03   Ready    control-plane   4m    v1.30.0

📦 Core Components:
NAMESPACE     NAME                    READY   STATUS
kube-system   cilium-xxxxx           1/1     Running
kube-system   cilium-xxxxx           1/1     Running
kube-system   cilium-xxxxx           1/1     Running
kube-system   coredns-xxxxx          1/1     Running
kube-system   coredns-xxxxx          1/1     Running

📊 Flux Layer:
NAME                          READY   MESSAGE
cluster-infra-infrastructure  True    Applied revision: main/abc123
cluster-infra-settings        True    Applied revision: main/abc123
flux-repositories             True    Applied revision: main/abc123

⚠️  CRDs:
  VictoriaMetrics CRDs: 14
  Prometheus CRDs: 9
==============================================
```

---

### Step 3: Monitor Cluster

```bash
# Watch Flux reconciliation
flux get kustomizations --watch

# Check cluster status
task cluster:status-infra

# Quick health check
task cluster:health CLUSTER=infra
```

---

## Cluster Management

### Checking Cluster Status

```bash
# Complete status (all layers)
task cluster:status CLUSTER=infra

# Quick health check
task cluster:health CLUSTER=infra

# Validate specific layer
task cluster:validate:talos CLUSTER=infra
task cluster:validate:kubernetes CLUSTER=infra
task cluster:validate:crds CLUSTER=infra
```

###Destroying Clusters

**Complete Destruction (wipe everything):**
```bash
# This will:
# - Delete all Kubernetes resources
# - Reset Talos (wipe disks)
# - Reboot nodes to maintenance mode
task cluster:destroy-infra
```

**Soft Destruction (keep Talos, remove K8s):**
```bash
# This will:
# - Delete Kubernetes applications
# - Uninstall Flux
# - Keep Talos cluster running
task cluster:soft-destroy CLUSTER=infra

# Re-bootstrap Kubernetes after soft destroy
task bootstrap:infra
```

---

## Troubleshooting

### Issue: etcd Bootstrap Fails

**Symptom:**
```
Error: context deadline exceeded waiting for etcd to be ready
```

**Solution:**
```bash
# Check Talos API health
talosctl --nodes 10.25.11.11 health

# Check etcd manually
talosctl --nodes 10.25.11.11 service etcd status

# Try bootstrap again
talosctl --nodes 10.25.11.11 bootstrap

# If still failing, check logs
talosctl --nodes 10.25.11.11 logs etcd
```

---

### Issue: Kubernetes API Not Responding

**Symptom:**
```
Error: Unable to connect to the server
```

**Solution:**
```bash
# Check if kubeconfig exists
ls -la kubernetes/kubeconfig

# Regenerate kubeconfig
task talos:generate-kubeconfig

# Verify Talos is healthy
talosctl --nodes 10.25.11.11 health

# Check API server logs
talosctl --nodes 10.25.11.11 logs kube-apiserver
```

---

### Issue: Nodes Not Ready

**Symptom:**
```
NAME       STATUS     ROLES           AGE   VERSION
infra-01   NotReady   control-plane   5m    v1.30.0
```

**Solution:**
```bash
# Check node status
kubectl describe node infra-01

# Usually caused by CNI not ready - check Cilium
kubectl get pods -n kube-system -l app.kubernetes.io/name=cilium

# Check Cilium logs
kubectl logs -n kube-system -l app.kubernetes.io/name=cilium

# Re-deploy Cilium if needed
helmfile -f bootstrap/helmfile.d/01-core.yaml -e infra sync
```

---

### Issue: CRDs Not Installing

**Symptom:**
```
Error: no matches for kind "PrometheusRule"
```

**Solution:**
```bash
# Verify CRDs exist
kubectl get crd | grep victoriametrics

# Re-run CRD phase
task bootstrap:phase:1 CLUSTER=infra

# Check CRD status
kubectl get crd prometheusrules.monitoring.coreos.com -o yaml
```

---

### Issue: Flux Not Reconciling

**Symptom:**
```
Kustomization/cluster-infra-infrastructure False dependency not ready
```

**Solution:**
```bash
# Check Flux status
flux get kustomizations -A

# Check specific Kustomization
flux get kustomization cluster-infra-infrastructure -n flux-system

# Force reconciliation
flux reconcile kustomization cluster-infra-infrastructure --with-source

# Check Flux logs
kubectl logs -n flux-system -l app.kubernetes.io/name=flux-instance
```

---

## Advanced Usage

### Custom Cluster Creation with Specific Layers

```bash
# Run specific layers only
task cluster:layer:1-talos CLUSTER=infra
task cluster:layer:2-kubernetes CLUSTER=infra
task cluster:layer:3-crds CLUSTER=infra
task cluster:layer:4-infrastructure CLUSTER=infra
task cluster:layer:5-validation CLUSTER=infra
```

### Adding New Nodes

```bash
# Create node configuration file
cat > talos/infra/10.25.11.17.yaml <<EOF
---
machine:
  network:
    hostname: infra-04
    interfaces:
      - interface: bond0
        addresses: [10.25.11.17/24]
EOF

# Apply configuration to new node
task talos:apply-node NODE=10.25.11.17 CLUSTER=infra MACHINE_TYPE=controlplane
```

### Upgrading Talos

```bash
# Upgrade single node
task talos:upgrade-node NODE=10.25.11.11

# Upgrade all nodes (one at a time)
for node in 10.25.11.11 10.25.11.12 10.25.11.13; do
  task talos:upgrade-node NODE=$node
  sleep 60  # Wait between upgrades
done
```

---

## Best Practices

### 1. Pre-Flight Checks Always First

```bash
# Always run pre-flight before cluster creation
task cluster:preflight CLUSTER=infra
```

### 2. Monitor During Bootstrap

```bash
# In separate terminal, watch status
watch -n 2 'task cluster:status CLUSTER=infra'
```

### 3. Backup etcd Regularly

```bash
# Backup etcd snapshot
talosctl --nodes 10.25.11.11 etcd snapshot etcd-backup-$(date +%Y%m%d).db
```

### 4. Test in Apps Cluster First

```bash
# Test changes in apps cluster before infra
task cluster:create-apps
# Validate, then apply to infra
task cluster:create-infra
```

### 5. Use Soft Destroy for Testing

```bash
# Soft destroy keeps Talos running (faster iteration)
task cluster:soft-destroy CLUSTER=infra
task bootstrap:infra
```

---

## Timeline

**Complete Cluster Creation (task cluster:create-infra):**

| Layer | Duration | Tasks |
|-------|----------|-------|
| Layer 1: Talos | ~5 min | Node config, etcd bootstrap, cluster formation |
| Layer 2: K8s Wait | ~2 min | API server, nodes ready |
| Layer 3: CRDs | ~1 min | Prerequisites, CRD installation |
| Layer 4: Core | ~5-8 min | CNI, DNS, Flux deployment |
| Layer 5: Validation | ~30 sec | Health checks |
| **Total** | **~15-20 min** | **Complete cluster from bare metal** |

---

## Related Documentation

- [Taskfile Bootstrap Guide](./TASKFILE-BOOTSTRAP-GUIDE.md) - CRD/K8s bootstrap details
- [CRD Bootstrap Implementation Plan](./CRD-BOOTSTRAP-IMPLEMENTATION-PLAN.md) - CRD architecture
- [Taskfile Quick Reference](./TASKFILE-QUICK-REFERENCE.md) - Command cheat sheet

---

## Summary

### What This Guide Covers

✅ **Complete cluster creation** from bare metal to production
✅ **5-layer automation** (Talos → K8s → CRDs → Core → Validation)
✅ **Multi-cluster support** (infra + apps clusters)
✅ **Comprehensive validation** across all layers
✅ **Cluster destruction** (complete and soft)
✅ **Status monitoring** and health checks
✅ **Troubleshooting** common issues

### Key Commands

```bash
# Create cluster
task cluster:create-infra

# Check status
task cluster:status-infra

# Health check
task cluster:health CLUSTER=infra

# Destroy cluster
task cluster:destroy-infra
```

---

**Document Version:** 1.0
**Last Updated:** 2025-10-15
**Maintained By:** Platform Engineering Team
