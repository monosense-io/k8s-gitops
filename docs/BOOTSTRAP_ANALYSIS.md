# Bootstrap Analysis: Reference Patterns vs Current Implementation

## Executive Summary

This document provides an in-depth analysis comparing the bootstrap patterns used by `buroa` and `onedrop` (reference implementations) with the current k8s-gitops implementation, with a focus on Cilium deployment and multi-cluster orchestration.

**Status**: Current implementation follows best practices but has potential issues with **apps cluster Cilium day-2 features** and **storage operator deployment patterns**.

---

## Part 1: Reference Implementation Patterns (buroa & onedrop)

### 1.1 Bootstrap Architecture

Both reference implementations use a **phased helmfile orchestration approach**:

```
Bootstrap Phase 0: CRD Extraction (00-crds.yaml)
  ↓
  Extract and install CustomResourceDefinitions ONLY
  - cert-manager CRDs
  - external-secrets CRDs
  - victoria-metrics-operator CRDs
  - prometheus-operator CRDs
  - cloudnative-pg CRDs
  - Gateway API CRDs (via kubectl)

Bootstrap Phase 1: Core Infrastructure (01-apps.yaml)
  ↓
  Install core services with explicit dependencies:
  1. Cilium (networking - must be first)
     └─ needs: none
  2. CoreDNS (DNS resolution)
     └─ needs: kube-system/cilium
  3. Spegel (image cache mirror)
     └─ needs: kube-system/coredns
  4. cert-manager (certificate management)
     └─ needs: kube-system/coredns
  5. external-secrets (secret management)
     └─ needs: cert-manager/cert-manager
  6. flux-operator (Flux lifecycle manager)
     └─ needs: cert-manager/cert-manager
  7. flux-instance (GitOps controller)
     └─ needs: flux-system/flux-operator
     └─ post-sync hook: Apply GitRepository + Kustomization

Flux Phase: Workload Management (Day 2 onwards)
  ↓
  flux-instance controller reconciles kubernetes/flux/cluster manifests
  - Day-2 features (Cilium BGP, ClusterMesh, Gateway API)
  - Storage operators
  - Applications and workloads
```

### 1.2 Key Patterns

#### Pattern 1: CRDs Installed Separately
```yaml
# Phase 0: Extract CRDs only
helmfile -f 00-crds.yaml template | yq 'select(.kind == "CustomResourceDefinition")' | kubectl apply -f -

# Phase 1: Deploy apps WITHOUT inline CRDs
helmfile -f 01-apps.yaml sync
  # Each release has: crds.enabled: false (cert-manager, external-secrets, etc.)
```

**Rationale**: Prevents CRD version conflicts and race conditions when multiple charts define the same CRD.

#### Pattern 2: Explicit Dependency Chain
```yaml
releases:
  - name: coredns
    needs: ['kube-system/cilium']  # Wait for Cilium before deploying
  - name: flux-instance
    needs: ['flux-system/flux-operator']  # Operator must exist first
```

**Rationale**: Helmfile enforces strict ordering without manual intervention or retries.

#### Pattern 3: Post-Sync Hooks for Flux Bootstrapping
```yaml
  - name: flux-instance
    hooks:
      - events: ['postsync']
        command: kubectl
        args:
          - apply
          - -f
          - ../../kubernetes/clusters/{{ .Environment.Name }}/flux-system/gotk-sync.yaml
```

**Rationale**: After flux-instance is ready, immediately apply GitRepository + Kustomization for GitOps control.

#### Pattern 4: Cluster-Specific Environment Values
```yaml
helmfiles:
  - path: helmfile.d/01-core.yaml
environments:
  infra:
    values:
      - clusters/infra/values.yaml  # infra-specific settings
  apps:
    values:
      - clusters/apps/values.yaml   # apps-specific settings
```

**Rationale**: Cilium IPAM, clustermesh IPs, storage device paths vary per cluster.

#### Pattern 5: Bootstrap vs Flux Separation
```
bootstrap/helmfile.d/
  ├── 00-crds.yaml (extract CRDs)
  └── 01-apps.yaml (deploy core infra)
         ↓
         flux-instance controller takes over
         ↓
kubernetes/clusters/{cluster}/
  ├── flux-system/gotk-sync.yaml (GitRepository + Kustomization)
  ├── infrastructure.yaml (Flux Kustomization for day-2 features)
  └── workloads.yaml (Application workloads)
```

**Rationale**: Bootstrap is one-time; Flux manages everything after that. Clear phase separation.

---

## Part 2: Current Implementation Analysis

### 2.1 Bootstrap Structure

**Exists**: ✓
```
bootstrap/
├── helmfile.yaml (orchestrator)
├── helmfile.d/
│   ├── 00-crds.yaml (CRD extraction)
│   ├── 01-core.yaml.gotmpl (core services)
│   └── README.md
├── clusters/
│   ├── infra/
│   │   ├── cilium-values.yaml
│   │   └── values.yaml
│   └── apps/
│       ├── cilium-values.yaml
│       └── values.yaml
└── prerequisites/resources.yaml
```

**Analysis**: ✓ Follows reference pattern

### 2.2 Bootstrap Phases

#### Phase 0: CRD Extraction (00-crds.yaml)
```yaml
helmDefaults:
  args: ['--include-crds', '--no-hooks']

releases:
  - cert-manager-crds (v1.19.0)
  - external-secrets-crds (0.20.3)
  - victoria-metrics-operator-crds (0.5.1)
  - prometheus-operator-crds (24.0.1)
  - cloudnative-pg-crds (0.26.0)
  # Gateway API: manually via kubectl
```

**Analysis**: ✓ Correct pattern

#### Phase 1: Core Infrastructure (01-core.yaml.gotmpl)
```yaml
releases:
  1. cilium/cilium (v1.18.2)
     - Load values: clusters/{{ .Environment.Name }}/cilium-values.yaml
     - Post-sync hook: rollout status daemonset/cilium -n kube-system

  2. coredns (1.44.3)
     - needs: ['kube-system/cilium']

  3. cert-manager (v1.19.0)
     - needs: ['kube-system/coredns']
     - Sets: crds.enabled: false (already installed)

  4. external-secrets (0.20.3)
     - needs: ['cert-manager/cert-manager']
     - Sets: crds.createClusterSecretStore: false

  5. flux-operator (0.32.0)
     - needs: ['cert-manager/cert-manager']

  6. flux-instance (0.32.0)
     - needs: ['flux-system/flux-operator']
     - Post-sync hook: apply gotk-sync.yaml
```

**Analysis**: ✓ Correct pattern with proper dependencies

### 2.3 Cluster-Specific Configurations

#### Infra Cluster: cilium-values.yaml
```yaml
cluster:
  name: infra
  id: 1
ipv4NativeRoutingCIDR: "10.244.0.0/16"  # Infra cluster pod CIDR
clustermesh:
  apiserver:
    service:
      annotations:
        io.cilium/lb-ipam-ips: "10.25.11.100"
gatewayAPI:
  envoy:
    service:
      annotations:
        io.cilium/lb-ipam-ips: "10.25.11.120"
```

#### Apps Cluster: cilium-values.yaml
```yaml
cluster:
  name: apps
  id: 2
ipv4NativeRoutingCIDR: "10.246.0.0/16"  # Apps cluster pod CIDR (DIFFERENT)
clustermesh:
  apiserver:
    service:
      annotations:
        io.cilium/lb-ipam-ips: "10.25.12.100"  # Different from infra
gatewayAPI:
  envoy:
    service:
      annotations:
        io.cilium/lb-ipam-ips: "10.25.12.120"  # Different from infra
```

**Analysis**: ✓ Correct - cluster IDs differ, IP allocations differ

### 2.4 Cilium Day-2 Features (Flux-Managed)

Located in: `kubernetes/infrastructure/networking/cilium/`

```
cilium/
├── ks.yaml (main kustomization)
├── kustomization.yaml
├── prometheusrule.yaml
├── ipam/
│   ├── ks.yaml
│   ├── lb-ippool-infra.yaml
│   └── lb-ippool-apps.yaml
├── bgp/
│   ├── ks.yaml
│   └── peering-policy.yaml
├── clustermesh/
│   ├── ks.yaml
│   └── externalsecret.yaml
└── gateway/
    ├── ks.yaml
    ├── gateway.yaml
    └── gatewayclass.yaml
```

**Analysis**: ✓ Day-2 features split by domain (BGP, ClusterMesh, Gateway API, IPAM)

### 2.5 Infrastructure Kustomization Composition

#### Infra Cluster: kubernetes/clusters/infra/infrastructure.yaml
```yaml
Kustomizations:
  1. cluster-infra-settings
  2. flux-repositories (depends on settings)
  3. storage (depends on repositories) ← STORAGE OPERATORS
  4. cluster-infra-infrastructure (depends on repositories)
     - Includes: networking/cilium/ks.yaml (day-2 features)
     - Includes: observability (Victoria Metrics, Grafana, etc.)
     - Includes: databases (CloudNative-PG)
     - Includes: security (cert-manager configs)
```

#### Apps Cluster: kubernetes/clusters/apps/infrastructure.yaml
```yaml
Kustomizations:
  1. cluster-apps-settings
  2. flux-repositories (depends on settings)
  3. openebs (depends on repositories)
  4. rook-ceph-operator (depends on repositories)
  5. rook-ceph-cluster (depends on rook-operator)
  6. cluster-apps-infrastructure (depends on repositories)
     - Includes: networking/cilium/ks.yaml (day-2 features)
     - Includes: other services
```

**Analysis**: ⚠️ POTENTIAL ISSUE - Storage operators appear on BOTH clusters
- Infra: storage (Rook-Ceph + OpenEBS)
- Apps: openebs + rook-ceph (separate Kustomizations)

---

## Part 3: Identified Issues & Gaps

### Issue 1: Storage Operator Deployment on Apps Cluster

**Problem**:
```yaml
# apps/infrastructure.yaml includes:
- openebs (OpenEBS local provisioner)
- rook-ceph-operator (Rook operator)
- rook-ceph-cluster (Rook cluster with device paths)
```

**Expected** (from reference pattern):
- Storage should be on **infra cluster only** (shared storage)
- Apps cluster should use **remote storage** from infra cluster via network

**Reference Evidence**:
- buroa: Storage in `infrastructure/storage/` (shared across clusters)
- onedrop: Storage in `infrastructure/storage/` (shared across clusters)
- Both deploy storage via bootstrap or infra-only kustomizations

**Impact**:
- ⚠️ Apps cluster duplicates storage infrastructure
- ⚠️ Device paths are hardcoded (different from infra)
- ⚠️ Rook-Ceph needs coordination between clusters

**Fix Required**: Move apps storage to infra-only or configure proper remote storage.

### Issue 2: Cilium Day-2 Features - Apps Cluster Pod CIDR Validation

**Problem**:
```yaml
# apps cilium-values.yaml
ipv4NativeRoutingCIDR: "10.246.0.0/16"  # Comment says: "verify with talosctl get members"
```

**Risk**:
- If Talos pod CIDR differs from cilium-values.yaml, cilium will misconfigure routing
- Apps cluster may have connectivity issues

**Fix Required**: Verify actual pod CIDR on apps cluster:
```bash
talosctl -n apps-01 get members  # Check actual pod CIDR
kubectl get nodes -o jsonpath='{range .items[*]}{.status.allocatable}{"\n"}{end}'
```

### Issue 3: Cilium ClusterMesh Configuration

**Current State**:
```yaml
clustermesh:
  useAPIServer: false
  config:
    enabled: false  # "Connected manually via CLI in Week 3"
```

**Problem**:
- ClusterMesh is configured but disabled for bootstrap
- No automated connection between infra and apps clusters
- Manual CLI connection required

**Reference Pattern**:
- Both buroa and onedrop have ClusterMesh disabled initially but configured
- Enable via Flux after storage is deployed

**Fix Required**: Document ClusterMesh connection procedure or automate via Flux.

### Issue 4: IPAM (Load Balancer IP Pools)

**Current State**:
```yaml
# cilium-values.yaml (bootstrap)
clustermesh:
  apiserver:
    service:
      annotations:
        io.cilium/lb-ipam-ips: "10.25.11.100"  # Static IP allocation

# kubernetes/infrastructure/cilium/ipam/lb-ippool-*.yaml
LB IP pools defined separately
```

**Potential Issue**:
- Static IPs in cilium-values.yaml vs dynamic pools in Flux manifests
- Unclear which takes precedence

**Fix Required**: Verify IPAM pool configuration and ensure consistency.

---

## Part 4: Bootstrap Sequence Validation

### Current Bootstrap Order (Correct)

```
1. CRD Installation (00-crds.yaml)
   └─ cert-manager-crds, external-secrets-crds, etc.

2. Cilium deployment
   └─ Needed for networking (everything depends on it)

3. CoreDNS deployment
   └─ Needed for service discovery

4. cert-manager deployment
   └─ Needed for certificate generation

5. external-secrets deployment
   └─ Needed for secret rotation

6. flux-operator deployment
   └─ Needed for flux-instance

7. flux-instance deployment (post-sync: apply gotk-sync.yaml)
   └─ Flux controller takes over from here

8. Flux reconciles kubernetes/clusters/{cluster}/infrastructure.yaml
   └─ Day-2 features (cilium networking policies, storage, observability)
```

**Analysis**: ✓ Sequence is correct

---

## Part 5: Recommendations

### Priority 1: Fix Apps Cluster Storage Architecture

**Current**: Apps cluster deploys its own OpenEBS + Rook-Ceph
**Recommended**:
1. Apps cluster should consume storage from infra cluster via Ceph RBD
2. Move Rook-Ceph cluster configuration to infra-only
3. Apps cluster configures Ceph client only (not cluster)

**Steps**:
```bash
# 1. Verify current storage status
kubectl --context apps get pvc -A
kubectl --context apps get cephclusters -A

# 2. Remove duplicated storage operators from apps/infrastructure.yaml
# 3. Update apps to use infra cluster's Ceph via remote cluster secret
# 4. Test cross-cluster storage access
```

### Priority 2: Validate Apps Cluster Cilium Networking

**Steps**:
```bash
# Verify pod CIDR matches cilium-values.yaml
talosctl -n apps-01 get members
# Compare output with: ipv4NativeRoutingCIDR: "10.246.0.0/16"

# Verify Cilium deployment
kubectl --context apps get daemonset -n kube-system cilium
kubectl --context apps get pods -n kube-system -l k8s-app=cilium

# Check Cilium network connectivity
kubectl --context apps exec -n kube-system cilium-xxx -- cilium status
```

### Priority 3: Document and Automate ClusterMesh Connection

**Current**: Manual CLI connection required
**Recommended**: Automate via Flux after bootstrap completes

```yaml
# kubernetes/clusters/apps/infrastructure.yaml (Day 3+)
- name: clustermesh-connection
  namespace: flux-system
  spec:
    dependsOn:
      - name: cluster-apps-infrastructure
    path: ./kubernetes/infrastructure/cilium/clustermesh
    # This would automate the connection
```

### Priority 4: Standardize IPAM Pool Configuration

**Recommended**:
1. Remove static IP annotations from cilium-values.yaml bootstrap
2. Let Cilium LB IPAM discover pools from `CiliumLoadBalancerIPPool` resources
3. Define all pools in `kubernetes/infrastructure/cilium/ipam/`

---

## Part 6: Comparison Matrix

| Pattern | buroa | onedrop | current | Status |
|---------|-------|---------|---------|--------|
| Phased CRD extraction | ✓ | ✓ | ✓ | OK |
| Helmfile orchestration | ✓ | ✓ | ✓ | OK |
| Explicit dependencies | ✓ | ✓ | ✓ | OK |
| Flux-instance post-sync hook | ✓ | ✓ | ✓ | OK |
| Cluster-specific values | ✓ | ✓ | ✓ | OK |
| Storage on infra-only | ✓ | ✓ | ✗ | **ISSUE** |
| Cilium day-2 via Flux | ✓ | ✓ | ✓ | OK |
| ClusterMesh automation | ✓ | ✓ | ✗ | TODO |
| Pod CIDR validation | ✓ | ✓ | ⚠️ | VERIFY |

---

## Conclusion

The current implementation **successfully follows the reference patterns** from buroa and onedrop for:
- Bootstrap phasing and orchestration
- Dependency management
- Flux integration

However, there are **critical issues with apps cluster storage architecture** that diverge from best practices:
1. Apps cluster should NOT deploy its own storage operators
2. Apps cluster should consume storage from infra cluster
3. Device paths should not be hardcoded in Flux configurations

**Recommended Next Steps**:
1. Diagnose actual cilium deployment issues on apps cluster
2. Fix storage architecture (remove redundant operators)
3. Automate ClusterMesh connection
4. Validate pod CIDR configurations
5. Run bootstrap sequence validation
