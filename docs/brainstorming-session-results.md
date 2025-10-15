# Brainstorming Session Results: Multi-Cluster Kubernetes Architecture

**Session Date:** 2025-10-14
**Facilitator:** Business Analyst Mary 📊
**Topic:** FluxCD Multi-Cluster GitOps Architecture for Greenfield Kubernetes Deployment

---

## Executive Summary

### Project Vision
Design and implement a production-ready, multi-cluster Kubernetes environment with:
- **Infra Cluster** (3 nodes): Platform services, storage, observability
- **Apps Cluster** (3 nodes): Application workloads
- **Technology Stack**: Talos Linux 1.11.2, Cilium 1.18+ with BGP, FluxCD GitOps
- **Network**: Same subnet (10.25.11.0/24), flat L2 network, no VLANs
- **Connectivity**: Juniper SRX320 router, 10GbE bonded interfaces (LACP)

### Research Summary
Conducted comprehensive analysis of:
- FluxCD multi-cluster deployment strategies (Standalone vs Hub-Spoke)
- Cilium ClusterMesh architecture for cross-cluster networking
- GitOps repository structure patterns (Monorepo vs Multirepo)
- Infrastructure vs Application separation best practices
- Dependency management for operators and CRDs

### Key Research Insights
1. **Standalone FluxCD per cluster** is recommended for production environments with independent cluster lifecycle
2. **Monorepo structure** with cluster-specific overlays provides best balance of DRY and flexibility
3. **Cilium ClusterMesh** supports same-subnet deployments with unique cluster IDs
4. **Layered dependency management** (CRDs → Operators → Resources) is critical for reliable reconciliation
5. **Infrastructure-first bootstrapping** ensures platform services are ready before apps

---

## Research Findings

### 1. FluxCD Multi-Cluster Architecture Patterns

#### Pattern A: Standalone Mode (Recommended for Production)
**Description**: Each Kubernetes cluster runs independent Flux controllers

**Advantages**:
- ✅ Reduced attack surface - no cross-cluster access
- ✅ Independent cluster operations and lifecycle
- ✅ Suitable for hard multi-tenancy requirements
- ✅ Air-gap capable (if needed)
- ✅ Blast radius containment
- ✅ Better for production isolation

**Disadvantages**:
- ❌ Requires separate bootstrap per cluster
- ❌ Duplicate Flux installation management
- ❌ More operational overhead for updates

**Best For**: Your use case with 2 production clusters (infra + apps)

#### Pattern B: Hub-and-Spoke Mode
**Description**: Central "hub" cluster manages continuous delivery for multiple "spoke" clusters

**Advantages**:
- ✅ Centralized management dashboard
- ✅ Single monitoring platform
- ✅ Simplified bootstrapping
- ✅ Easier fleet-wide updates

**Disadvantages**:
- ❌ Single point of failure
- ❌ Hub cluster needs access to all spoke clusters
- ❌ More complex security model
- ❌ Not suitable when clusters need independence

**Best For**: Dev/test environments, large cluster fleets (>10 clusters)

---

### 2. Repository Structure Best Practices

#### Recommended Monorepo Structure for Multi-Cluster

```
k8s-gitops/
├── clusters/
│   ├── infra/
│   │   ├── flux-system/           # Flux bootstrap configs
│   │   ├── infrastructure.yaml    # Infrastructure Kustomization
│   │   └── apps.yaml             # Apps Kustomization (if any infra apps)
│   └── apps/
│       ├── flux-system/           # Flux bootstrap configs
│       ├── infrastructure.yaml    # Minimal infra (if needed)
│       └── apps.yaml             # Application Kustomizations
├── infrastructure/
│   ├── base/                      # Shared base configs
│   │   ├── crds/                 # Custom Resource Definitions
│   │   ├── operators/            # Operators (cert-manager, external-secrets, etc)
│   │   ├── storage/              # Storage providers (Rook, OpenEBS)
│   │   ├── networking/           # Cilium, ingress controllers
│   │   └── observability/        # Victoria Metrics, Fluent-bit
│   ├── infra-cluster/            # Infra cluster overlays
│   │   ├── storage/
│   │   ├── databases/
│   │   └── observability/
│   └── apps-cluster/             # Apps cluster overlays (minimal)
│       └── storage/
├── apps/
│   ├── base/                      # Application base configs
│   └── production/               # Production overlays
├── components/                    # Reusable Kustomize components
│   ├── storage-class/
│   ├── monitoring/
│   └── network-policies/
└── bootstrap/                     # Cluster bootstrap automation
    ├── talos/
    └── flux/
```

#### Key Structure Principles

1. **Separation of Concerns**
   - `infrastructure/` - Platform services, operators, CRDs
   - `apps/` - Business applications
   - `clusters/` - Cluster-specific entry points

2. **Base + Overlay Pattern**
   - `base/` - Shared configurations (DRY)
   - `{cluster-name}/` - Cluster-specific overlays
   - Kustomize overlays for environment differences

3. **Dependency Ordering**
   - CRDs must be applied first
   - Operators second
   - Resources that depend on CRDs third
   - Use Flux `dependsOn` to enforce ordering

4. **Infrastructure-First Bootstrap**
   - Infrastructure Kustomization reconciles first
   - Apps Kustomization depends on infrastructure
   - Prevents race conditions during cluster bootstrap

---

### 3. Cilium ClusterMesh Architecture

#### Technical Requirements for ClusterMesh

**Network Prerequisites**:
- ✅ Node-level IP connectivity (your 10.25.11.0/24 subnet works!)
- ✅ Non-overlapping PodCIDR ranges between clusters
- ✅ Unique cluster names (max 32 chars)
- ✅ Unique cluster IDs (1-255)
- ✅ No firewall blocking inter-cluster traffic

**Configuration Requirements**:
```yaml
# Infra Cluster
cluster:
  name: infra
  id: 1

# Apps Cluster
cluster:
  name: apps
  id: 2
```

#### ClusterMesh Capabilities

**Cross-Cluster Service Discovery**:
- Annotate services with `io.cilium/global-service: "true"`
- Service endpoints automatically discovered across clusters
- Global load balancing across clusters

**Network Policy Enforcement**:
- Policies can span multiple clusters
- Filter by cluster name, namespace, pod labels
- Centralized security policy management

**Same Subnet Benefits**:
- No VPN/overlay required
- Direct pod-to-pod communication
- Lower latency
- Simplified routing (Juniper SRX handles inter-node)

#### ClusterMesh Setup Process

1. **Enable ClusterMesh on each cluster**:
   ```bash
   cilium clustermesh enable --context infra
   cilium clustermesh enable --context apps
   ```

2. **Connect clusters**:
   ```bash
   cilium clustermesh connect --context infra --destination-context apps
   ```

3. **Validate connectivity**:
   ```bash
   cilium clustermesh status --context infra
   cilium clustermesh status --context apps
   ```

---

### 4. Infrastructure Component Dependencies

#### Recommended Deployment Order

**Layer 0: CRDs** (First reconciliation)
- Rook Ceph CRDs
- OpenEBS CRDs
- Prometheus Operator CRDs
- CloudNativePG CRDs
- Cert-Manager CRDs
- External Secrets CRDs

**Layer 1: Operators** (Depends on Layer 0)
- Rook Ceph Operator
- OpenEBS Operator
- CloudNativePG Operator
- Cert-Manager Operator
- External Secrets Operator
- Victoria Metrics Operator

**Layer 2: Storage Clusters** (Depends on Layer 1)
- Rook Ceph Cluster (3 nodes, 1TB NVME each)
- OpenEBS LocalPV Hostpath (512GB NVME)
- Storage Classes

**Layer 3: Platform Services** (Depends on Layer 2)
- CloudNativePG PostgreSQL Cluster
- Victoria Metrics Stack
- Fluent-bit
- Kromgo
- Cert-Manager ClusterIssuers
- External Secrets ClusterSecretStore

**Layer 4: Applications** (Depends on Layer 3)
- Application workloads on apps cluster
- Use storage from infra cluster (Rook Ceph RBD/CephFS)

#### FluxCD Kustomization Dependencies

```yaml
# clusters/infra/infrastructure.yaml
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: crds
  namespace: flux-system
spec:
  interval: 10m
  path: ./infrastructure/base/crds
  prune: false  # Never prune CRDs
  sourceRef:
    kind: GitRepository
    name: flux-system
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: operators
  namespace: flux-system
spec:
  dependsOn:
    - name: crds
  interval: 10m
  path: ./infrastructure/infra-cluster/operators
  prune: true
  sourceRef:
    kind: GitRepository
    name: flux-system
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: storage
  namespace: flux-system
spec:
  dependsOn:
    - name: operators
  interval: 10m
  path: ./infrastructure/infra-cluster/storage
  prune: true
  sourceRef:
    kind: GitRepository
    name: flux-system
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: observability
  namespace: flux-system
spec:
  dependsOn:
    - name: storage
  interval: 10m
  path: ./infrastructure/infra-cluster/observability
  prune: true
  sourceRef:
    kind: GitRepository
    name: flux-system
```

---

### 5. Storage Architecture for Multi-Cluster

#### Infra Cluster Storage Responsibilities

**Rook Ceph Cluster** (Primary shared storage)
- **Purpose**: RBD (block), CephFS (shared filesystem), RGW (object)
- **Configuration**: 3 OSDs (1TB NVME per node)
- **Access**: Apps cluster mounts via CSI driver
- **Use Cases**:
  - Persistent volumes for stateful apps
  - Shared filesystem for multi-reader workloads
  - S3-compatible object storage

**OpenEBS LocalPV Hostpath**
- **Purpose**: Fast local storage for performance-critical workloads
- **Configuration**: 512GB NVME per node
- **Access**: Local to each cluster
- **Use Cases**:
  - Database WAL logs (PostgreSQL)
  - High-IOPS workloads
  - Temporary fast storage

**Synology NAS - MinIO**
- **Purpose**: Backup target, large object storage
- **Access**: S3 API from both clusters
- **Use Cases**:
  - Velero backups
  - Large file storage
  - Archive storage

#### Cross-Cluster Storage Access Pattern

**Option 1: Rook Ceph CSI on Apps Cluster** (Recommended)
- Install Rook Ceph CSI driver on apps cluster
- Point to infra cluster's Ceph monitors
- Apps consume storage as standard PVCs
- Centralized storage management

**Option 2: NFS from Infra to Apps**
- Export CephFS via NFS
- Mount on apps cluster nodes
- Simpler but less flexible

---

### 6. Observability Architecture

#### Victoria Metrics Stack Components

**On Infra Cluster**:
- **VMOperator**: Manages Victoria Metrics CRDs
- **VMCluster**: 3-node HA metrics storage
- **VMAgent**: Scrapes metrics from both clusters
- **VMAlert**: Alerting and recording rules
- **VMAuth**: Authentication proxy
- **Alertmanager**: Alert routing and notification
- **Fluent-bit**: Log collection from both clusters
- **Victoria Logs**: Centralized log storage
- **Kromgo**: Uptime monitoring and badge generation

**Multi-Cluster Monitoring Pattern**:
1. VMAgent on each cluster scrapes local metrics
2. VMAgent remote-writes to VMCluster on infra cluster
3. Single pane of glass for all metrics
4. Fluent-bit on each cluster forwards to Victoria Logs
5. Unified logging and metrics platform

---

## Architecture Decisions

### Decision 1: FluxCD Deployment Mode

**Recommendation: Standalone Mode**

**Rationale**:
- Production workload isolation
- Independent cluster lifecycle
- Better security posture
- Only 2 clusters (manageable operational overhead)
- Blast radius containment

**Implementation**:
- Bootstrap Flux independently on each cluster
- Shared Git repository with cluster-specific paths
- Leverage Kustomize overlays for differences

---

### Decision 2: Repository Structure

**Recommendation: Monorepo with Cluster Overlays**

**Rationale**:
- Single source of truth
- Easy to see entire system state
- Simplified change management
- DRY principle with base configs
- Clear separation of infra vs apps

**Implementation**:
- Use structure outlined in section 2
- Leverage Kustomize components for reusability
- Cluster-specific overlays only for differences

---

### Decision 3: Cilium ClusterMesh Configuration

**Recommendation: Enable ClusterMesh for Cross-Cluster Networking**

**Cluster Configuration**:
```yaml
# Infra Cluster
cluster:
  name: infra
  id: 1

ipam:
  mode: kubernetes

ipv4NativeRoutingCIDR: 10.25.11.0/24

bgpControlPlane:
  enabled: true

clustermesh:
  useAPIServer: true
  apiserver:
    service:
      type: LoadBalancer

# Apps Cluster
cluster:
  name: apps
  id: 2

ipam:
  mode: kubernetes

ipv4NativeRoutingCIDR: 10.25.11.0/24

bgpControlPlane:
  enabled: true

clustermesh:
  useAPIServer: true
  apiserver:
    service:
      type: LoadBalancer
```

**PodCIDR Separation** (Critical!):
```yaml
# Infra Cluster
clusterNetwork:
  podSubnet: 10.244.0.0/16
  serviceSubnet: 10.245.0.0/16

# Apps Cluster
clusterNetwork:
  podSubnet: 10.246.0.0/16
  serviceSubnet: 10.247.0.0/16
```

**Benefits**:
- Transparent cross-cluster service communication
- Shared platform services (PostgreSQL, Victoria Metrics)
- Global service load balancing
- Unified network policy enforcement

---

### Decision 4: Storage Strategy

**Recommendation: Centralized Rook Ceph on Infra Cluster**

**Configuration**:
- Rook Ceph Cluster on infra cluster (3 nodes)
- Each node: 1x 1TB NVME for Ceph OSD
- Apps cluster uses Rook Ceph CSI to consume storage
- OpenEBS LocalPV for local fast storage on both clusters

**Storage Classes**:
```yaml
# Shared block storage (Rook Ceph RBD)
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ceph-block
provisioner: rook-ceph.rbd.csi.ceph.com
parameters:
  clusterID: rook-ceph
  pool: replicapool
  replication: "3"

# Shared filesystem (Rook Ceph CephFS)
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ceph-filesystem
provisioner: rook-ceph.cephfs.csi.ceph.com
parameters:
  clusterID: rook-ceph
  fsName: cephfs

# Local fast storage (OpenEBS)
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-hostpath
provisioner: openebs.io/local
parameters:
  basePath: /var/local-hostpath
```

---

### Decision 5: Observability Placement

**Recommendation: Centralized Observability on Infra Cluster**

**Rationale**:
- Infra cluster is stable, long-lived platform
- Apps cluster can be torn down/rebuilt without losing metrics
- Centralized troubleshooting and monitoring
- Efficient resource utilization

**Components**:
- Victoria Metrics Cluster (infra)
- Victoria Logs (infra)
- Alertmanager (infra)
- Grafana (infra)
- VMAgent on each cluster (remote-write to infra)
- Fluent-bit on each cluster (forward to infra)

---

### Decision 6: Bootstrap Order and Dependencies

**Recommended Bootstrap Sequence**:

**Phase 1: Infra Cluster Foundation**
1. Talos Linux installation and cluster bootstrap
2. Cilium CNI (with ClusterMesh prep)
3. FluxCD bootstrap
4. CRDs (Layer 0)
5. Operators (Layer 1)

**Phase 2: Infra Cluster Storage**
6. Rook Ceph Cluster (wait for healthy)
7. OpenEBS LocalPV
8. Storage Classes

**Phase 3: Infra Cluster Platform Services**
9. Cert-Manager + ClusterIssuers
10. External Secrets + 1Password integration
11. CloudNativePG Operator + PostgreSQL Cluster
12. Victoria Metrics Stack
13. Fluent-bit + Victoria Logs
14. Kromgo

**Phase 4: Apps Cluster Foundation**
15. Talos Linux installation and cluster bootstrap
16. Cilium CNI (with ClusterMesh prep)
17. FluxCD bootstrap
18. Minimal CRDs (cert-manager, external-secrets)
19. Minimal operators

**Phase 5: ClusterMesh Connection**
20. Enable ClusterMesh on both clusters
21. Connect clusters
22. Validate connectivity

**Phase 6: Apps Cluster Storage Access**
23. Install Rook Ceph CSI driver on apps cluster
24. Configure access to infra cluster Ceph
25. Install OpenEBS LocalPV on apps cluster

**Phase 7: Apps Cluster Monitoring**
26. Deploy VMAgent on apps cluster (remote-write to infra)
27. Deploy Fluent-bit on apps cluster (forward to infra)
28. Validate metrics and logs flow

**Phase 8: Application Deployment**
29. Deploy applications to apps cluster
30. Validate storage, networking, monitoring

---

## Proposed Repository Structure

```
k8s-gitops/
│
├── README.md
├── .gitignore
├── .sops.yaml                     # SOPS encryption config
│
├── bootstrap/                     # Bootstrap automation scripts
│   ├── flux/
│   │   ├── bootstrap-infra.sh
│   │   └── bootstrap-apps.sh
│   └── talos/
│       ├── apply-infra.sh
│       └── apply-apps.sh
│
├── clusters/                      # Cluster entry points
│   ├── infra/
│   │   ├── flux-system/
│   │   │   ├── gotk-components.yaml
│   │   │   ├── gotk-sync.yaml
│   │   │   └── kustomization.yaml
│   │   ├── infrastructure.yaml    # Infrastructure Kustomization
│   │   └── README.md
│   └── apps/
│       ├── flux-system/
│       │   ├── gotk-components.yaml
│       │   ├── gotk-sync.yaml
│       │   └── kustomization.yaml
│       ├── infrastructure.yaml    # Minimal infra
│       ├── apps.yaml             # Apps Kustomization
│       └── README.md
│
├── infrastructure/                # Infrastructure definitions
│   ├── base/                      # Shared base configs
│   │   ├── crds/
│   │   │   ├── cert-manager/
│   │   │   ├── external-secrets/
│   │   │   ├── rook-ceph/
│   │   │   ├── openebs/
│   │   │   ├── cloudnative-pg/
│   │   │   ├── victoria-metrics/
│   │   │   └── kustomization.yaml
│   │   ├── operators/
│   │   │   ├── cert-manager/
│   │   │   ├── external-secrets/
│   │   │   ├── rook-ceph/
│   │   │   ├── openebs/
│   │   │   ├── cloudnative-pg/
│   │   │   ├── victoria-metrics/
│   │   │   └── kustomization.yaml
│   │   └── networking/
│   │       ├── cilium/
│   │       └── kustomization.yaml
│   │
│   ├── infra-cluster/             # Infra cluster overlays
│   │   ├── crds/
│   │   │   └── kustomization.yaml # Points to base
│   │   ├── operators/
│   │   │   └── kustomization.yaml
│   │   ├── storage/
│   │   │   ├── rook-ceph-cluster.yaml
│   │   │   ├── openebs-config.yaml
│   │   │   ├── storage-classes.yaml
│   │   │   └── kustomization.yaml
│   │   ├── databases/
│   │   │   ├── postgres-cluster.yaml
│   │   │   └── kustomization.yaml
│   │   ├── secrets/
│   │   │   ├── cluster-secret-store.yaml
│   │   │   └── kustomization.yaml
│   │   ├── observability/
│   │   │   ├── victoria-metrics/
│   │   │   ├── victoria-logs/
│   │   │   ├── fluent-bit/
│   │   │   ├── kromgo/
│   │   │   ├── grafana/
│   │   │   └── kustomization.yaml
│   │   └── networking/
│   │       ├── cilium-config.yaml
│   │       ├── bgp-config.yaml
│   │       └── kustomization.yaml
│   │
│   └── apps-cluster/              # Apps cluster overlays
│       ├── crds/
│       │   └── kustomization.yaml
│       ├── operators/
│       │   └── kustomization.yaml
│       ├── storage/
│       │   ├── rook-ceph-csi.yaml     # CSI driver only
│       │   ├── openebs-config.yaml
│       │   ├── storage-classes.yaml
│       │   └── kustomization.yaml
│       ├── secrets/
│       │   ├── cluster-secret-store.yaml
│       │   └── kustomization.yaml
│       ├── monitoring/
│       │   ├── vmagent.yaml           # Remote-write to infra
│       │   ├── fluent-bit.yaml        # Forward to infra
│       │   └── kustomization.yaml
│       └── networking/
│           ├── cilium-config.yaml
│           ├── bgp-config.yaml
│           └── kustomization.yaml
│
├── apps/                          # Application definitions
│   ├── base/
│   │   ├── example-app/
│   │   │   ├── deployment.yaml
│   │   │   ├── service.yaml
│   │   │   ├── ingress.yaml
│   │   │   └── kustomization.yaml
│   │   └── kustomization.yaml
│   └── production/
│       ├── example-app/
│       │   ├── kustomization.yaml     # Overlays base
│       │   └── patches.yaml
│       └── kustomization.yaml
│
├── components/                    # Reusable components
│   ├── network-policies/
│   │   └── default-deny.yaml
│   ├── monitoring/
│   │   ├── servicemonitor.yaml
│   │   └── prometheusrule.yaml
│   └── secrets/
│       └── external-secret.yaml
│
├── talos/                         # Talos configs (existing)
│   ├── schematic.yaml
│   └── controlplane/
│       ├── 10.25.11.11.yaml       # Infra node 1
│       ├── 10.25.11.12.yaml       # Infra node 2
│       ├── 10.25.11.13.yaml       # Infra node 3
│       ├── 10.25.11.14.yaml       # Apps node 1
│       ├── 10.25.11.15.yaml       # Apps node 2
│       └── 10.25.11.16.yaml       # Apps node 3
│
└── docs/                          # Documentation
    ├── architecture.md
    ├── bootstrap-guide.md
    ├── troubleshooting.md
    └── brainstorming-session-results.md
```

---

## Key Implementation Considerations

### 1. PodCIDR Planning

**Critical**: Ensure non-overlapping CIDRs across clusters for ClusterMesh

Recommended allocation:
```yaml
# Infra Cluster (nodes 10.25.11.11-13)
clusterNetwork:
  podSubnet: 10.244.0.0/16        # ~65k pods
  serviceSubnet: 10.245.0.0/16    # ~65k services

# Apps Cluster (nodes 10.25.11.14-16)
clusterNetwork:
  podSubnet: 10.246.0.0/16        # ~65k pods
  serviceSubnet: 10.247.0.0/16    # ~65k services

# Node network (shared)
nodeSubnet: 10.25.11.0/24         # 254 nodes max
```

### 2. Cilium BGP Configuration

**Juniper SRX320 BGP Setup**:
```
# On SRX320
set protocols bgp group cilium-infra neighbor 10.25.11.11 peer-as 65001
set protocols bgp group cilium-infra neighbor 10.25.11.12 peer-as 65001
set protocols bgp group cilium-infra neighbor 10.25.11.13 peer-as 65001
set protocols bgp group cilium-apps neighbor 10.25.11.14 peer-as 65002
set protocols bgp group cilium-apps neighbor 10.25.11.15 peer-as 65002
set protocols bgp group cilium-apps neighbor 10.25.11.16 peer-as 65002
```

**Cilium BGP Configuration**:
```yaml
# Infra Cluster
apiVersion: cilium.io/v2alpha1
kind: CiliumBGPPeeringPolicy
metadata:
  name: infra-cluster-bgp
spec:
  virtualRouters:
  - localASN: 65001
    neighbors:
    - peerAddress: 10.25.11.1/32
      peerASN: 65000
    serviceSelector:
      matchLabels:
        bgp-announce: "true"

# Apps Cluster
apiVersion: cilium.io/v2alpha1
kind: CiliumBGPPeeringPolicy
metadata:
  name: apps-cluster-bgp
spec:
  virtualRouters:
  - localASN: 65002
    neighbors:
    - peerAddress: 10.25.11.1/32
      peerASN: 65000
    serviceSelector:
      matchLabels:
        bgp-announce: "true"
```

### 3. Rook Ceph Storage Configuration

**Infra Cluster Ceph Cluster**:
```yaml
apiVersion: ceph.rook.io/v1
kind: CephCluster
metadata:
  name: rook-ceph
  namespace: rook-ceph
spec:
  cephVersion:
    image: quay.io/ceph/ceph:v18
  dataDirHostPath: /var/lib/rook
  mon:
    count: 3
    allowMultiplePerNode: false
  mgr:
    count: 2
    allowMultiplePerNode: false
  storage:
    useAllNodes: false
    useAllDevices: false
    nodes:
    - name: "prod-01"  # 10.25.11.11
      devices:
      - name: "/dev/nvme1n1"  # 1TB NVME
    - name: "prod-02"  # 10.25.11.12
      devices:
      - name: "/dev/nvme1n1"
    - name: "prod-03"  # 10.25.11.13
      devices:
      - name: "/dev/nvme1n1"
```

**Apps Cluster Ceph CSI Access**:
```yaml
# Use Rook's external cluster configuration
apiVersion: v1
kind: ConfigMap
metadata:
  name: rook-ceph-mon-endpoints
  namespace: rook-ceph
data:
  data: "prod-01=10.25.11.11:6789,prod-02=10.25.11.12:6789,prod-03=10.25.11.13:6789"
  mapping: |
    {
      "node": {
        "prod-01": {"Name": "10.25.11.11", "Hostname": "prod-01", "Address": "10.25.11.11"},
        "prod-02": {"Name": "10.25.11.12", "Hostname": "prod-02", "Address": "10.25.11.12"},
        "prod-03": {"Name": "10.25.11.13", "Hostname": "prod-03", "Address": "10.25.11.13"}
      }
    }
```

### 4. Victoria Metrics Multi-Cluster Setup

**VMAgent on Apps Cluster** (remote-write to Infra):
```yaml
apiVersion: operator.victoriametrics.com/v1beta1
kind: VMAgent
metadata:
  name: vmagent-apps
  namespace: monitoring
spec:
  selectAllByDefault: true
  replicaCount: 1
  remoteWrite:
  - url: "http://vminsert.monitoring.svc.infra.local:8480/insert/0/prometheus"
    # Cross-cluster service via ClusterMesh
```

### 5. External Secrets Configuration

**1Password Connect on External Docker**:
```yaml
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: onepassword
spec:
  provider:
    onepassword:
      connectHost: http://10.25.11.X:8080  # Your external docker host
      vaults:
        k8s-infra: 1
        k8s-apps: 2
      auth:
        secretRef:
          connectTokenSecretRef:
            name: onepassword-token
            namespace: external-secrets
            key: token
```

### 6. Disaster Recovery Considerations

**Backup Strategy**:
- Velero with Rook Ceph RBD snapshots
- Backup to Synology MinIO (S3)
- FluxCD Git as source of truth (immutable infra)
- Talos machine configs in Git

**Recovery Scenarios**:
1. **Apps cluster failure**: Rebuild from Talos configs, Flux bootstraps everything
2. **Infra cluster failure**:
   - Rebuild Talos + Flux
   - Restore Rook Ceph from Velero
   - Platform services reconcile from Git
3. **Data loss**: Restore from Velero backups on MinIO

---

## Next Steps and Action Plan

### Immediate Actions (Week 1-2)

1. **Finalize Repository Structure**
   - [ ] Create directory structure as outlined
   - [ ] Initialize FluxCD manifests
   - [ ] Set up SOPS encryption

2. **Talos Configuration Refinement**
   - [ ] Define PodCIDR and ServiceCIDR per cluster
   - [ ] Configure Cilium installation via Talos
   - [ ] Test node connectivity

3. **FluxCD Bootstrap Preparation**
   - [ ] Create bootstrap scripts
   - [ ] Prepare Git repository structure
   - [ ] Configure GitHub webhooks

### Phase 1: Infra Cluster (Week 3-4)

4. **Bootstrap Infra Cluster**
   - [ ] Install Talos on nodes 10.25.11.11-13
   - [ ] Bootstrap Flux on infra cluster
   - [ ] Apply CRDs (Layer 0)
   - [ ] Deploy operators (Layer 1)

5. **Storage Setup**
   - [ ] Deploy Rook Ceph Cluster
   - [ ] Wait for Ceph healthy status
   - [ ] Deploy OpenEBS LocalPV
   - [ ] Create and test storage classes

6. **Platform Services**
   - [ ] Deploy cert-manager + ClusterIssuers
   - [ ] Deploy external-secrets + 1Password integration
   - [ ] Test secret sync from 1Password

### Phase 2: Observability (Week 5)

7. **Victoria Metrics Stack**
   - [ ] Deploy VMOperator
   - [ ] Deploy VMCluster
   - [ ] Deploy Alertmanager
   - [ ] Deploy Grafana

8. **Logging Stack**
   - [ ] Deploy Victoria Logs
   - [ ] Deploy Fluent-bit
   - [ ] Configure log forwarding
   - [ ] Test log ingestion

9. **Monitoring Validation**
   - [ ] Deploy Kromgo
   - [ ] Validate metrics collection
   - [ ] Create initial dashboards
   - [ ] Test alerting

### Phase 3: Apps Cluster (Week 6-7)

10. **Bootstrap Apps Cluster**
    - [ ] Install Talos on nodes 10.25.11.14-16
    - [ ] Bootstrap Flux on apps cluster
    - [ ] Deploy minimal CRDs and operators
    - [ ] Deploy Rook Ceph CSI driver

11. **Storage Access Validation**
    - [ ] Configure Ceph external cluster access
    - [ ] Test PVC creation on apps cluster
    - [ ] Validate cross-cluster storage access
    - [ ] Deploy OpenEBS LocalPV

12. **Monitoring Integration**
    - [ ] Deploy VMAgent on apps cluster
    - [ ] Configure remote-write to infra cluster
    - [ ] Deploy Fluent-bit on apps cluster
    - [ ] Validate metrics and logs flow

### Phase 4: ClusterMesh (Week 8)

13. **Enable Cilium ClusterMesh**
    - [ ] Enable ClusterMesh on infra cluster
    - [ ] Enable ClusterMesh on apps cluster
    - [ ] Connect clusters
    - [ ] Validate connectivity

14. **Cross-Cluster Service Testing**
    - [ ] Deploy test service on infra cluster
    - [ ] Annotate with global-service label
    - [ ] Access from apps cluster
    - [ ] Test service discovery

15. **BGP Configuration**
    - [ ] Configure BGP on Juniper SRX320
    - [ ] Configure Cilium BGP policies
    - [ ] Test LoadBalancer service advertisement
    - [ ] Validate routing

### Phase 5: Database Services (Week 9)

16. **CloudNativePG Deployment**
    - [ ] Deploy CNPG Operator
    - [ ] Create PostgreSQL cluster
    - [ ] Configure backups to MinIO
    - [ ] Test failover

17. **Database Access from Apps**
    - [ ] Create database for test app
    - [ ] Configure access via ClusterMesh
    - [ ] Test connectivity from apps cluster
    - [ ] Validate performance

### Phase 6: Application Deployment (Week 10+)

18. **Deploy Sample Application**
    - [ ] Create app manifests in apps/ directory
    - [ ] Deploy to apps cluster
    - [ ] Validate storage access
    - [ ] Test cross-cluster services

19. **Production Readiness**
    - [ ] Configure backup schedules
    - [ ] Set up alerting rules
    - [ ] Create runbooks
    - [ ] Document architecture

20. **Optimization and Tuning**
    - [ ] Review resource utilization
    - [ ] Tune Ceph performance
    - [ ] Optimize monitoring retention
    - [ ] Security hardening

---

## Questions for Further Exploration

### Architecture & Design
1. Do you want apps cluster to have any local database instances, or all databases on infra cluster?
2. Should we implement Velero for backup/restore from day 1, or phase 2?
3. Do you need network policies between namespaces within each cluster?
4. Should we set up GitLab and Harbor on the infra cluster, or external?

### Storage & Data
5. What's your RPO (Recovery Point Objective) for backups to MinIO?
6. Do you need CephFS (shared filesystem) in addition to RBD (block)?
7. Should we configure Ceph RGW (S3) for object storage internally?
8. How should we handle storage for CI/CD artifacts (container images)?

### Security & Access
9. Do you want to implement Pod Security Standards (restricted/baseline)?
10. Should we set up OAuth/OIDC with external provider (or use Authentik/Keycloak)?
11. Do you need VPN access to the clusters, or all access via ingress?
12. What's your secret rotation strategy for 1Password?

### Networking
13. Do you need ingress on both clusters, or only on apps cluster?
14. Should we implement Service Mesh features beyond basic connectivity (retries, circuit breakers)?
15. Do you want to expose services externally via Cloudflare Tunnel?
16. Should we set up external-dns for automatic DNS management?

### Operations
17. Do you want to implement automated Talos/K8s upgrades via system-upgrade-controller?
18. Should we set up GitHub Actions runners on the cluster for CI/CD?
19. Do you need a development/staging cluster in addition to production?
20. What's your maintenance window strategy for cluster updates?

---

## Recommended Resources for Deep Dive

### Official Documentation
- [FluxCD Multi-Cluster Architecture](https://stefanprodan.com/blog/2024/fluxcd-multi-cluster-architecture/) - Stefan Prodan's comprehensive guide
- [Cilium ClusterMesh Documentation](https://docs.cilium.io/en/stable/network/clustermesh/)
- [Rook Ceph Documentation](https://rook.io/docs/rook/latest/Getting-Started/intro/)
- [Talos Production Notes](https://www.talos.dev/latest/introduction/prodnotes/)

### Reference Implementations
- [onedr0p/cluster-template](https://github.com/onedr0p/cluster-template) - Excellent Talos + Flux template
- [FluxCD Monorepo Example](https://github.com/fluxcd/flux2-kustomize-helm-example)

### Community Resources
- [Kubernetes@Home Discord](https://discord.gg/k8s-at-home)
- [FluxCD Slack](https://cloud-native.slack.com/messages/flux)
- [Rook Slack](https://rook.io/slack)

---

## Success Criteria

### Technical Milestones
- ✅ Both clusters operational with Talos + Cilium
- ✅ FluxCD reconciling all resources from Git
- ✅ Rook Ceph cluster healthy with 3 OSDs
- ✅ ClusterMesh enabled with validated connectivity
- ✅ Cross-cluster storage access working
- ✅ Centralized observability capturing metrics and logs
- ✅ Sample application deployed and functional
- ✅ Backup/restore tested and validated

### Operational Goals
- 🎯 Sub-5-minute deployment time for new applications
- 🎯 Zero-downtime updates for platform services
- 🎯 Automated dependency management via Renovate
- 🎯 Comprehensive monitoring and alerting
- 🎯 Documented runbooks for common operations

### Quality Attributes
- 🛡️ Security-first design with encrypted secrets
- 📈 Observable and debuggable system
- 🔄 Reproducible cluster rebuilds from Git
- 💪 Resilient to single-node failures
- 📚 Well-documented architecture and processes

---

## Conclusion

This research-driven brainstorming session has provided comprehensive insights into building a production-grade, multi-cluster Kubernetes environment using FluxCD and Cilium. The proposed architecture balances:

- **Simplicity**: Monorepo structure, shared subnet networking
- **Flexibility**: Cluster-specific overlays, reusable components
- **Security**: Standalone FluxCD, encrypted secrets, network policies
- **Reliability**: HA storage, centralized observability, disaster recovery
- **Maintainability**: GitOps automation, clear separation of concerns

The next step is to make architectural decisions based on your specific requirements and begin implementation following the phased approach outlined above.

---

*Session facilitated using the BMAD-METHOD™ brainstorming framework*
*Research conducted: 2025-10-14*
*Document version: 1.0*
