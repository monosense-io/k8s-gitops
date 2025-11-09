# Deployment Guide - k8s-gitops

> **Generated:** 2025-11-09
> **Project:** Multi-Cluster Kubernetes GitOps Infrastructure
> **For:** Cluster deployment and operations

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Automated Cluster Deployment (Recommended)](#automated-cluster-deployment-recommended)
4. [Manual Cluster Deployment](#manual-cluster-deployment)
5. [Bootstrap Process Explained](#bootstrap-process-explained)
6. [Operational Tasks](#operational-tasks)
7. [Cluster Management](#cluster-management)
8. [Backup & Recovery](#backup--recovery)
9. [Troubleshooting](#troubleshooting)

---

## Overview

This guide covers deploying and operating the multi-cluster Kubernetes infrastructure:
- **Infra Cluster:** 3-node cluster (10.25.11.11-13) for platform services
- **Apps Cluster:** 3-node cluster (10.25.11.14-16) for application workloads

**Deployment Architecture:**
```
Bare Metal Nodes (6x)
  ↓
Talos Linux OS (immutable, API-driven)
  ↓
Kubernetes Control Plane (3-node HA per cluster)
  ↓
Flux CD GitOps (automated reconciliation)
  ↓
Infrastructure & Workloads (from Git)
```

**Deployment Workflow:**
This repository uses a **5-layer cluster creation workflow** and **4-phase bootstrap process** managed by Task automation.

---

## Prerequisites

### Hardware Requirements

**Per Node:**
- CPU: Intel i7-8700t or equivalent (6 cores)
- RAM: 64GB
- OS Disk: 500GB SSD
- Data Disks: 1TB NVMe + 512GB NVMe
- Network: 10Gb network interface

**Networking:**
- Layer 3 network connectivity between all nodes
- Internet access for pulling container images
- Access to Cloudflare for DNS automation
- Access to 1Password for secrets

### Required Tools

Install on **workstation** (not cluster nodes):

```bash
# Core tools
brew install go-task/tap/go-task      # Task automation
brew install siderolabs/tap/talosctl  # Talos CLI
brew install kubectl                  # Kubernetes CLI
brew install fluxcd/tap/flux          # Flux CD CLI
brew install helm                     # Helm CLI
brew install kustomize                # Kustomize CLI

# Required for Talos config generation
brew install 1password-cli            # op CLI for secret injection
brew install minijinja-cli            # Jinja2 templating

# Optional tools
brew install k9s                      # Kubernetes TUI
brew install stern                    # Multi-pod log tailing
```

### Access Requirements

- **1Password:** Access to "Infra" vault with cluster secrets
- **Cloudflare:** API token for DNS management
- **GitHub:** Repository access for GitOps
- **Network:** Direct access to cluster network (VPN if remote)

### Environment Setup

```bash
# Clone repository
git clone https://github.com/trosvald/home-ops.git k8s-gitops
cd k8s-gitops

# Install mise for environment management
brew install mise
mise install

# Environment variables will be automatically set:
# - KUBECONFIG → kubernetes/kubeconfig
# - TALOSCONFIG → talos/talosconfig
# - MINIJINJA_CONFIG_FILE → .minijinja.toml
```

---

## Automated Cluster Deployment (Recommended)

The **easiest way** to deploy clusters is using the automated Task workflows.

### Deploy Infra Cluster (End-to-End)

```bash
# Create complete infra cluster from scratch
task cluster:create-infra
```

**This runs a 5-layer workflow:**
1. **Layer 1 - Talos:** Apply Talos configs to all nodes, bootstrap etcd
2. **Layer 2 - Kubernetes:** Wait for K8s API server and nodes to be ready
3. **Layer 3 - CRDs:** Install all CRDs (Phase 0 and Phase 1)
4. **Layer 4 - Infrastructure:** Deploy Cilium + Flux (Phase 2)
5. **Layer 5 - Validation:** Validate all layers completed successfully

### Deploy Apps Cluster (End-to-End)

```bash
# Create complete apps cluster from scratch
task cluster:create-apps
```

**Same 5-layer workflow** but for apps cluster nodes (10.25.11.14-16).

### Check Cluster Status

```bash
# View complete cluster status
task cluster:status

# Quick health check
task cluster:health
```

### Destroy Cluster (if needed)

```bash
# Destroy infra cluster
task cluster:destroy-infra

# Destroy apps cluster
task cluster:destroy-apps
```

---

## Manual Cluster Deployment

If you prefer manual step-by-step deployment or need to troubleshoot:

### Step 1: Boot Nodes with Talos

**For each node:**

1. **Download Talos ISO:**
   ```bash
   # Get latest Talos version
   curl -Lo talos.iso https://github.com/siderolabs/talos/releases/latest/download/talos-amd64.iso
   ```

2. **Boot from ISO:**
   - Use physical media, iLO/iDRAC, or KVM
   - Node will boot into maintenance mode

3. **Verify node is reachable:**
   ```bash
   ping 10.25.11.11  # Example for first node
   ```

### Step 2: Apply Talos Configuration to Nodes

**Using Task (Recommended):**

```bash
# Apply config to specific node (uses minijinja + op inject)
task talos:apply-node \
  CLUSTER=infra \
  MACHINE_TYPE=controlplane \
  NODE=10.25.11.11 \
  MODE=auto
```

**This command:**
- Renders `talos/machineconfig-multicluster.yaml.j2` with minijinja
- Injects secrets from 1Password using `op inject`
- Applies node-specific patch from `talos/infra/10.25.11.11.yaml`
- Sends config to node via talosctl

**Repeat for all nodes:**
```bash
# Infra cluster nodes
task talos:apply-node CLUSTER=infra MACHINE_TYPE=controlplane NODE=10.25.11.11 MODE=auto
task talos:apply-node CLUSTER=infra MACHINE_TYPE=controlplane NODE=10.25.11.12 MODE=auto
task talos:apply-node CLUSTER=infra MACHINE_TYPE=controlplane NODE=10.25.11.13 MODE=auto

# Apps cluster nodes
task talos:apply-node CLUSTER=apps MACHINE_TYPE=controlplane NODE=10.25.11.14 MODE=auto
task talos:apply-node CLUSTER=apps MACHINE_TYPE=controlplane NODE=10.25.11.15 MODE=auto
task talos:apply-node CLUSTER=apps MACHINE_TYPE=controlplane NODE=10.25.11.16 MODE=auto
```

**Manual talosctl (if not using Task):**

```bash
# Generate config from template using minijinja + op inject
minijinja-cli \
  --define "machinetype=controlplane" \
  --define "cluster=infra" \
  talos/machineconfig-multicluster.yaml.j2 \
  | op inject \
  | talosctl apply-config --mode auto \
    --config-patch @talos/infra/10.25.11.11.yaml \
    --nodes 10.25.11.11

# Repeat for all nodes...
```

### Step 3: Bootstrap Kubernetes

**For infra cluster:**

```bash
# Bootstrap Kubernetes on first control plane node
talosctl bootstrap --nodes 10.25.11.11 --endpoints 10.25.11.11

# Wait for bootstrap to complete (~3 minutes)
talosctl --nodes 10.25.11.11 health --server

# Generate kubeconfig
task talos:generate-kubeconfig CLUSTER=infra

# Or manual:
talosctl --nodes 10.25.11.11 kubeconfig ./kubernetes/kubeconfig

# Verify cluster
export KUBECONFIG=./kubernetes/kubeconfig
kubectl get nodes
```

**For apps cluster:**

```bash
# Bootstrap Kubernetes on first control plane node
talosctl bootstrap --nodes 10.25.11.14 --endpoints 10.25.11.14

# Generate kubeconfig
task talos:generate-kubeconfig CLUSTER=apps

# Verify cluster
kubectl get nodes
```

### Step 4: Bootstrap Infrastructure

**Using Task (Recommended - Fully Automated):**

```bash
# Bootstrap infra cluster (4-phase automated)
task bootstrap:infra

# Bootstrap apps cluster (4-phase automated)
task bootstrap:apps
```

**This runs all 4 phases automatically:**
- Phase 0: Apply prerequisites
- Phase 1: Install CRDs (helmfile extraction + Gateway API)
- Phase 2: Deploy Cilium + Flux
- Phase 3: Validate deployment

**Manual bootstrap (phase-by-phase):**

```bash
# Set kubeconfig
export KUBECONFIG=./kubernetes/kubeconfig

# Phase 0: Prerequisites
task bootstrap:phase:0 CLUSTER=infra

# Phase 1: Install CRDs
task bootstrap:phase:1 CLUSTER=infra

# Phase 2: Deploy Cilium + Flux
task bootstrap:phase:2 CLUSTER=infra

# Phase 3: Validate
task bootstrap:phase:3 CLUSTER=infra
```

---

## Bootstrap Process Explained

### 4-Phase Bootstrap Strategy

The repository uses a **4-phase bootstrap strategy** to prevent CRD dependency races and ensure correct component ordering.

#### Phase 0: Prerequisites

**Purpose:** Apply any prerequisite configurations before CRD installation

```bash
task bootstrap:phase:0 CLUSTER=infra
```

#### Phase 1: Install CRDs

**Purpose:** Install Custom Resource Definitions before operators

```bash
task bootstrap:phase:1 CLUSTER=infra
```

**What gets installed:**
- Extracts CRDs from Helm charts using helmfile
- Prometheus CRDs (ServiceMonitor, PrometheusRule, etc.)
- Gateway API CRDs (`gateway.networking.k8s.io`)
- cert-manager CRDs
- external-secrets CRDs

**How it works:**
```bash
# Helmfile extracts CRDs from charts
helmfile -f bootstrap/helmfile.d/00-crds.yaml -e infra template | \
  yq ea 'select(.kind == "CustomResourceDefinition")' | \
  kubectl apply --server-side --force-conflicts -f -

# Install Gateway API CRDs
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.0.0/standard-install.yaml
```

#### Phase 2: Deploy Core Infrastructure (Cilium + Flux)

**Purpose:** Install Cilium CNI via Helm, then bootstrap Flux GitOps

```bash
task bootstrap:phase:2 CLUSTER=infra
```

**What gets installed:**
1. **Cilium CNI** (via Helm directly):
   - Full eBPF networking stack
   - BGP control plane
   - ClusterMesh for multi-cluster
   - Gateway API support
   - WireGuard encryption

2. **Flux CD** (via `task kubernetes:bootstrap`):
   - flux-system namespace
   - Flux controllers (source, kustomize, helm, notification)
   - GitRepository pointing to this repo
   - Root Kustomization for cluster

**Flux will now reconcile everything from Git automatically.**

#### Phase 3: Validate Deployment

**Purpose:** Verify all components are healthy

```bash
task bootstrap:phase:3 CLUSTER=infra
```

**Validates:**
- Cilium status
- Flux reconciliation status
- All health checks pass

### 5-Layer Cluster Creation Workflow

The `task cluster:create-infra` and `task cluster:create-apps` commands use a comprehensive 5-layer workflow:

**Layer 1 - Talos:**
```bash
task cluster:layer:1-talos CLUSTER=infra
```
- Apply Talos configs to all nodes
- Bootstrap etcd on first control plane node
- Wait for etcd quorum

**Layer 2 - Kubernetes:**
```bash
task cluster:layer:2-kubernetes CLUSTER=infra
```
- Wait for Kubernetes API server to be ready
- Wait for all nodes to join cluster
- Verify nodes are in Ready state

**Layer 3 - CRDs:**
```bash
task cluster:layer:3-crds CLUSTER=infra
```
- Run `bootstrap:phase:0` (prerequisites)
- Run `bootstrap:phase:1` (CRD installation)

**Layer 4 - Infrastructure:**
```bash
task cluster:layer:4-infrastructure CLUSTER=infra
```
- Run `bootstrap:phase:2` (Cilium + Flux)
- Wait for Flux to reconcile infrastructure

**Layer 5 - Validation:**
```bash
task cluster:layer:5-validation CLUSTER=infra
```
- Run `bootstrap:phase:3` (validation)
- Verify all components are healthy

---

## Operational Tasks

### Available Task Modules

```bash
# List all available tasks
task --list
```

**Output shows 8 task modules:**
- `cluster:*` - Cluster lifecycle operations
- `bootstrap:*` - Bootstrap procedures
- `kubernetes:*` - Kubernetes/Flux operations
- `talos:*` - Talos node management
- `volsync:*` - Placeholder (not implemented)
- `workstation:*` - Local environment setup
- `op:*` - 1Password ClusterMesh operations
- `synergyflow:*` - Workflow orchestration

### Cluster Operations

```bash
# Create clusters
task cluster:create-infra          # Create complete infra cluster
task cluster:create-apps           # Create complete apps cluster

# Individual layers (for troubleshooting)
task cluster:layer:1-talos CLUSTER=infra
task cluster:layer:2-kubernetes CLUSTER=infra
task cluster:layer:3-crds CLUSTER=infra
task cluster:layer:4-infrastructure CLUSTER=infra
task cluster:layer:5-validation CLUSTER=infra

# Cluster status
task cluster:status                # Complete cluster status
task cluster:health                # Quick health check

# Destroy clusters
task cluster:destroy-infra         # Destroy infra cluster
task cluster:destroy-apps          # Destroy apps cluster
```

### Bootstrap Operations

```bash
# Automated bootstrap (all phases)
task bootstrap:infra               # Bootstrap infra cluster
task bootstrap:apps                # Bootstrap apps cluster

# Manual phase-by-phase
task bootstrap:phase:0 CLUSTER=infra    # Prerequisites
task bootstrap:phase:1 CLUSTER=infra    # Install CRDs
task bootstrap:phase:2 CLUSTER=infra    # Cilium + Flux
task bootstrap:phase:3 CLUSTER=infra    # Validate

# Core GitOps bootstrap (Cilium + Flux only)
task bootstrap:core:gitops CLUSTER=infra
```

### Kubernetes/Flux Operations

```bash
# Bootstrap Flux CD
task kubernetes:bootstrap CLUSTER=infra

# Trigger reconciliation
task kubernetes:reconcile CLUSTER=infra

# Reconcile Cilium mesh components
task kubernetes:reconcile-mesh CLUSTER=infra

# Validate manifests (kustomize template)
task kubernetes:validate CLUSTER=infra
```

### Talos Node Operations

```bash
# Apply Talos config to node
task talos:apply-node \
  CLUSTER=infra \
  MACHINE_TYPE=controlplane \
  NODE=10.25.11.11 \
  MODE=auto

# Re-apply config to existing node
task talos:re-apply-node \
  CLUSTER=infra \
  MACHINE_TYPE=controlplane \
  NODE=10.25.11.11

# Upgrade Talos version on node
task talos:upgrade-node \
  CLUSTER=infra \
  NODE=10.25.11.11 \
  VERSION=v1.8.0

# Reboot node
task talos:reboot-node \
  CLUSTER=infra \
  NODE=10.25.11.11

# Reset node (destructive)
task talos:reset-node \
  CLUSTER=infra \
  NODE=10.25.11.11

# Generate kubeconfig from cluster
task talos:generate-kubeconfig CLUSTER=infra
```

### 1Password ClusterMesh Operations

```bash
# Create ClusterMesh secret for infra cluster
task op:clustermesh:infra

# Create ClusterMesh secret for apps cluster
task op:clustermesh:apps

# Create ClusterMesh secrets for both clusters
task op:clustermesh:all
```

**Note:** 1Password integration is only used for ClusterMesh secret generation. Other secrets are managed via external-secrets operator.

### Volsync Operations

```bash
# Volsync is a placeholder - not yet implemented
# Check .taskfiles/volsync/Taskfile.yaml for status
```

### Manual Flux Operations

```bash
# Check Flux reconciliation status
flux get all -A

# Force reconciliation
flux reconcile source git flux-system
flux reconcile kustomization infra-infrastructure --with-source

# Suspend reconciliation (for maintenance)
flux suspend kustomization infra-infrastructure

# Resume reconciliation
flux resume kustomization infra-infrastructure

# Check for drift
flux diff kustomization infra-infrastructure --path ./kubernetes/clusters/infra/

# Export resources
flux export source git flux-system
flux export kustomization infra-infrastructure
```

### Manual Talos Node Management

```bash
# Check node health
talosctl --nodes 10.25.11.11 health

# View logs
talosctl --nodes 10.25.11.11 logs

# Get service status
talosctl --nodes 10.25.11.11 services

# Upgrade Talos
talosctl --nodes 10.25.11.11 upgrade \
  --image ghcr.io/siderolabs/installer:v1.8.0

# Reboot node
talosctl --nodes 10.25.11.11 reboot

# Graceful shutdown
talosctl --nodes 10.25.11.11 shutdown

# Check etcd status
talosctl --nodes 10.25.11.11 etcd status
```

### Manual Kubernetes Operations

```bash
# View cluster status
kubectl get nodes
kubectl top nodes
kubectl get pods -A

# Check component health
kubectl get componentstatuses

# View events
kubectl get events -A --sort-by='.lastTimestamp'

# Drain node for maintenance
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data

# Uncordon node after maintenance
kubectl uncordon <node-name>

# Cordon node (prevent new pods)
kubectl cordon <node-name>
```

---

## Cluster Management

### Updating Cluster Configuration

**1. Update cluster-settings ConfigMap:**

```bash
vim kubernetes/clusters/infra/cluster-settings.yaml
# or
vim kubernetes/clusters/apps/cluster-settings.yaml
```

**2. Commit and push:**

```bash
git add kubernetes/clusters/
git commit -m "chore(config): update cluster settings"
git push
```

**3. Flux automatically reconciles** (within 5 minutes) or force:

```bash
task kubernetes:reconcile CLUSTER=infra
# or manual:
flux reconcile kustomization flux-system --with-source
```

### Upgrading Components

**Operators (in bases/):**

```bash
# Edit HelmRelease version
vim kubernetes/bases/cnpg-operator/operator/helmrelease.yaml

# Update spec.chart.spec.version
version: 0.27.0  # New version

# Commit, push, let Flux reconcile
git add kubernetes/bases/cnpg-operator/
git commit -m "chore(databases): upgrade cnpg-operator to v0.27.0"
git push
```

**Infrastructure components:**

```bash
# Update HelmRelease or cluster-settings variable
vim kubernetes/infrastructure/networking/cilium/core/app/helmrelease.yaml

# Or update variable in cluster-settings
vim kubernetes/clusters/infra/cluster-settings.yaml
# Change CILIUM_VERSION: "1.15.0"

git commit -am "chore(networking): upgrade Cilium to v1.15.0"
git push
```

### Scaling Workloads

**Scale deployments/statefulsets:**

```bash
# Scale directly (temporary)
kubectl scale deployment <name> -n <namespace> --replicas=3

# Or update manifest in Git (permanent)
vim kubernetes/workloads/platform/<component>/deployment.yaml
# Update spec.replicas: 3

git commit -am "chore(<component>): scale to 3 replicas"
git push
```

### Adding New Nodes

**1. Prepare new node hardware**

**2. Create node-specific config patch:**

```bash
# Create patch file for new node
vim talos/infra/10.25.11.17.yaml

# Add node-specific configuration
# - hostname
# - install disk
# - network interfaces
```

**3. Boot node with Talos ISO**

**4. Apply config to new node:**

```bash
task talos:apply-node \
  CLUSTER=infra \
  MACHINE_TYPE=controlplane \
  NODE=10.25.11.17 \
  MODE=auto
```

**5. Verify node joins cluster:**

```bash
kubectl get nodes
```

---

## Backup & Recovery

### Secret Management (1Password + external-secrets)

Secrets are stored in **1Password** and automatically synced to clusters via **external-secrets** operator.

**Secret sync is automatic** - external-secrets controller watches 1Password vault and creates Kubernetes Secrets.

**Force secret re-sync:**

```bash
# Delete ExternalSecret (will be recreated)
kubectl delete externalsecret <name> -n <namespace>

# external-secrets controller recreates from 1Password
```

**ClusterMesh secrets** are managed separately:

```bash
# Generate ClusterMesh secrets in 1Password
task op:clustermesh:all
```

### ETCD Backup (Automatic)

Talos automatically manages etcd backups:

```bash
# View etcd health
talosctl --nodes 10.25.11.11 etcd status

# etcd is backed up automatically by Talos
# No manual intervention required
```

### Disaster Recovery

**Full cluster rebuild:**

1. **Prepare nodes with Talos:**
   ```bash
   # Boot all nodes with Talos ISO
   # Verify network connectivity
   ```

2. **Deploy complete cluster:**
   ```bash
   # Infra cluster
   task cluster:create-infra

   # Apps cluster
   task cluster:create-apps
   ```

3. **Flux reconciles infrastructure automatically** from Git

4. **Verify all components:**
   ```bash
   task cluster:status
   task cluster:health
   ```

**Single node recovery:**

```bash
# Reset failed node
task talos:reset-node CLUSTER=infra NODE=10.25.11.11

# Re-apply config
task talos:apply-node \
  CLUSTER=infra \
  MACHINE_TYPE=controlplane \
  NODE=10.25.11.11 \
  MODE=auto

# Node will rejoin cluster automatically
kubectl get nodes
```

---

## Troubleshooting

### Cluster Issues

#### Nodes Not Ready

```bash
# Check node status
kubectl describe node <node-name>

# Check Talos services
talosctl --nodes <node-ip> services

# View kubelet logs
talosctl --nodes <node-ip> logs kubelet

# Check for disk pressure, memory pressure, PID pressure
kubectl describe node <node-name> | grep -A 5 Conditions
```

#### Pods Not Starting

```bash
# Describe pod
kubectl describe pod <pod-name> -n <namespace>

# View logs
kubectl logs <pod-name> -n <namespace>

# Check events
kubectl get events -n <namespace> --sort-by='.lastTimestamp'

# Check image pull
kubectl get pods -n <namespace> -o wide
```

#### Network Issues

```bash
# Check Cilium status
cilium status
cilium connectivity test

# View Hubble flows
hubble observe --namespace <namespace>

# Check NetworkPolicies
kubectl get ciliumnetworkpolicy -n <namespace>
```

### Flux Issues

#### Kustomization Fails

```bash
# Check Kustomization status
flux get kustomizations -A

# Describe Kustomization for errors
kubectl describe kustomization <name> -n flux-system

# View kustomize-controller logs
kubectl logs -n flux-system deploy/kustomize-controller -f
```

#### HelmRelease Fails

```bash
# Check HelmRelease status
flux get helmreleases -A

# Describe HelmRelease
kubectl describe helmrelease <name> -n <namespace>

# View helm-controller logs
kubectl logs -n flux-system deploy/helm-controller -f

# Manual Helm debug
helm list -n <namespace>
helm history <release> -n <namespace>
```

#### Git Source Issues

```bash
# Check GitRepository status
flux get sources git -A

# Describe GitRepository
kubectl describe gitrepository flux-system -n flux-system

# View source-controller logs
kubectl logs -n flux-system deploy/source-controller -f
```

### Talos Issues

#### Node Won't Bootstrap

```bash
# Check Talos logs
talosctl --nodes <node-ip> logs

# Check service status
talosctl --nodes <node-ip> services

# Verify config was applied
talosctl --nodes <node-ip> get machineconfig

# Reset and retry
task talos:reset-node CLUSTER=infra NODE=<node-ip>
task talos:apply-node CLUSTER=infra MACHINE_TYPE=controlplane NODE=<node-ip> MODE=auto
```

#### etcd Issues

```bash
# Check etcd members
talosctl --nodes 10.25.11.11 etcd members

# Check etcd status
talosctl --nodes 10.25.11.11 etcd status

# View etcd logs
talosctl --nodes 10.25.11.11 logs etcd
```

### Bootstrap Issues

#### Phase 1 (CRDs) Fails

```bash
# Check helmfile template output
helmfile -f bootstrap/helmfile.d/00-crds.yaml -e infra template

# Manually install CRDs
helmfile -f bootstrap/helmfile.d/00-crds.yaml -e infra template | \
  yq ea 'select(.kind == "CustomResourceDefinition")' | \
  kubectl apply --server-side --force-conflicts -f -

# Verify CRDs installed
kubectl get crd
```

#### Phase 2 (Cilium + Flux) Fails

```bash
# Check Cilium Helm release
helm list -n kube-system

# Check Cilium status
cilium status

# Check Flux installation
flux check

# View bootstrap logs
kubectl logs -n kube-system -l app.kubernetes.io/name=cilium
```

### Storage Issues

#### Rook-Ceph Degraded

```bash
# Check Ceph status
kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph status

# Check OSD status
kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph osd status

# Check PG status
kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph pg stat
```

#### PVC Stuck in Pending

```bash
# Describe PVC
kubectl describe pvc <pvc-name> -n <namespace>

# Check StorageClass
kubectl get storageclass

# Check provisioner logs
kubectl logs -n rook-ceph -l app=rook-ceph-operator
```

### Getting Help

1. **Check component-specific READMEs** for detailed troubleshooting
2. **Review Flux documentation:** [fluxcd.io/docs](https://fluxcd.io/docs)
3. **Check Talos documentation:** [talos.dev/docs](https://www.talos.dev/docs)
4. **Consult Cilium docs:** [docs.cilium.io](https://docs.cilium.io)
5. **GitHub Issues:** Search repository issues for similar problems

---

## Next Steps

After successful deployment:

1. **Verify all components:** Check [Infrastructure Components](./infrastructure-components.md) inventory
2. **Configure monitoring:** Access Victoria Metrics dashboards
3. **Review security:** Verify NetworkPolicies are enforced
4. **Test GitOps workflow:** Make a change and watch Flux reconcile
5. **Explore Task automation:** Run `task --list` to see all available commands

For development and contributions, see [Development Guide](./development-guide.md).
