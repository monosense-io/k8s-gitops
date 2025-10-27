# 30 — STORY-STO-APPS-ROOK-CEPH-OPERATOR — Create Rook-Ceph Operator Manifests (apps)

Sequence: 30/50 | Prev: STORY-STO-APPS-OPENEBS-BASE.md | Next: STORY-STO-APPS-ROOK-CEPH-CLUSTER.md
Sprint: 6 | Lane: Storage
Global Sequence: 30/50

Status: Draft (v3.0 Refinement)
Owner: Platform Engineering
Date: 2025-10-26
Links: kubernetes/infrastructure/storage/rook-ceph/operator/; kubernetes/clusters/apps/cluster-settings.yaml

## Story

As a platform engineer, I want to **create manifests for the Rook-Ceph operator on the apps cluster** so that we have the foundation to deploy a distributed Ceph storage cluster for stateful workloads requiring high availability, multi-replica support, and RWX access modes.

## Why / Outcome

- **Operator-based Ceph management**: Declarative Ceph cluster lifecycle management
- **Foundation for distributed storage**: Enables RWX volumes, multi-replica databases, HA stateful sets
- **Complementary to OpenEBS LocalPV**: Rook-Ceph for durability, OpenEBS for performance
- **Cross-cluster consistency**: Same operator pattern used on infra cluster
- **Automated operations**: Operator handles Ceph cluster scaling, upgrades, healing

## Scope

### This Story (Manifest Creation)

**CREATE** the following manifests (local-only work):

1. **Rook-Ceph Operator Infrastructure** (`kubernetes/infrastructure/storage/rook-ceph/operator/`):
   - Namespace with PSA privileged
   - HelmRelease for Rook-Ceph operator
   - HelmRepository for Rook-Ceph charts
   - RBAC (ServiceAccounts, ClusterRoles, ClusterRoleBindings)
   - PodMonitor for metrics
   - PrometheusRule for alerting

2. **Flux Kustomizations**:
   - Infrastructure Kustomization for operator stack
   - Health checks for operator Deployment
   - Dependency ordering

3. **Documentation**:
   - Comprehensive README for Rook-Ceph operator
   - Architecture overview
   - Troubleshooting procedures

**DO NOT**:
- Deploy to apps cluster
- Run validation commands requiring cluster access
- Test operator functionality
- Verify Deployment status

### Deferred to Story 45 (Deployment & Validation)

Story 45 will handle:
- Applying manifests to apps cluster via Flux
- Verifying Rook-Ceph operator readiness
- Testing operator CRD installation
- Validating operator logs and health
- Smoke testing with sample CephCluster CR

## Acceptance Criteria

### Manifest Creation (This Story)

**AC1**: Rook-Ceph operator manifests created under `kubernetes/infrastructure/storage/rook-ceph/operator/`:
- `namespace.yaml` with PSA privileged enforcement
- `helmrelease.yaml` for Rook-Ceph operator
- `helmrepository.yaml` for chart source
- `kustomization.yaml`

**AC2**: Rook-Ceph operator HelmRelease configured with:
- Chart: `rook-ceph/rook-ceph` version 1.14.x or 1.15.x
- Namespace: `rook-ceph`
- Operator replicas: 1 (single operator, manages multiple clusters)
- Resource limits for operator Deployment
- Cluster-wide watch scope (manages CephClusters in all namespaces)
- CSI plugin configuration (RBD, CephFS drivers)
- Webhook configuration for validation

**AC3**: Operator configured with:
- Discover daemon enabled (auto-discovers node disks)
- CSI driver deployment (rbd, cephfs provisioners)
- Node affinity for storage nodes (optional)
- Tolerations for control plane taints (if needed)
- Log level: INFO (DEBUG for troubleshooting)

**AC4**: Monitoring configured:
- PodMonitor scraping operator metrics (port 9090)
- PrometheusRule with alerts for:
  - Operator unavailable
  - Operator crashlooping
  - CRD reconciliation failures
  - CSI driver issues
  - Webhook failures

**AC5**: Flux Kustomization created:
- `kubernetes/infrastructure/storage/rook-ceph/operator/ks.yaml`
- Health checks for operator Deployment
- Dependency on Cilium (requires CNI)
- Timeout: 5 minutes

**AC6**: Security hardening applied:
- PSA privileged enforcement (Ceph requires host access)
- RBAC limited to required permissions (nodes, PVs, storage classes)
- Service accounts for operator, discover, CSI drivers
- PodDisruptionBudget for operator (minAvailable: 1 if HA)

**AC7**: All manifests pass local validation:
- `kubectl --dry-run=client` succeeds
- `flux build kustomization` succeeds
- `kubeconform` validation passes
- YAML linting passes

**AC8**: Documentation includes:
- Rook-Ceph architecture overview
- Operator responsibilities (CRD reconciliation, CSI drivers, discover daemon)
- Node preparation requirements (disk cleanup, partitions)
- Troubleshooting guide (operator logs, CRD status, CSI issues)
- Upgrade procedures

### Deferred to Story 45 (NOT validated in this Story)

- Rook-Ceph operator Deployment running and Ready
- CRDs installed (CephCluster, CephBlockPool, CephFilesystem, etc.)
- CSI drivers deployed (rbd-provisioner, cephfs-provisioner)
- Discover daemon running on nodes
- Monitoring alerts firing correctly

## Dependencies / Inputs

**Local Tools Required**:
- `kubectl` (for dry-run validation)
- `flux` CLI (for `flux build kustomization`)
- `yq` (for YAML processing)
- `kubeconform` (for schema validation)

**Story Dependencies**:
- **STORY-NET-CILIUM-CORE-GITOPS** (Story 8): Cilium CNI required
- **STORY-STO-APPS-OPENEBS-BASE** (Story 29): OpenEBS provides local storage for Ceph metadata

**Configuration Inputs**:
- `${ROOK_CEPH_OPERATOR_REPLICAS}`: Operator replicas (default: 1)
- `${ROOK_CEPH_LOG_LEVEL}`: Operator log level (default: INFO)
- `${ROOK_CEPH_CSI_ENABLE_RBD}`: Enable RBD CSI driver (default: true)
- `${ROOK_CEPH_CSI_ENABLE_CEPHFS}`: Enable CephFS CSI driver (default: true)

## Tasks / Subtasks

### T1: Prerequisites and Strategy
- Review Rook-Ceph operator architecture
- Determine operator watch scope (cluster-wide vs namespace-scoped)
- Plan node preparation strategy (disk cleanup, partitioning)
- Review CSI driver configuration (RBD, CephFS)

### T2: Rook-Ceph Namespace
- Create `kubernetes/infrastructure/storage/rook-ceph/operator/namespace.yaml`:
  - Namespace: `rook-ceph`
  - PSA labels: `pod-security.kubernetes.io/enforce=privileged` (Ceph requires host access)
  - Labels: `app.kubernetes.io/name=rook-ceph`, `app.kubernetes.io/component=storage`

### T3: Rook-Ceph HelmRepository
- Create `kubernetes/infrastructure/storage/rook-ceph/operator/helmrepository.yaml`:
  - HelmRepository: `rook-ceph`
  - URL: `https://charts.rook.io/release`
  - Interval: 12h

### T4: Rook-Ceph Operator HelmRelease
- Create `kubernetes/infrastructure/storage/rook-ceph/operator/helmrelease.yaml`:
  - HelmRelease: `rook-ceph-operator`
  - Namespace: `rook-ceph`
  - Chart: `rook-ceph` version 1.14.x or 1.15.x (stable)
  - Interval: 30m
  - Values:
    - `crds.enabled: true` (install CRDs with chart)
    - `resources.limits.cpu: 500m`
    - `resources.limits.memory: 512Mi`
    - `resources.requests.cpu: 100m`
    - `resources.requests.memory: 128Mi`
    - `logLevel: ${ROOK_CEPH_LOG_LEVEL}` (INFO or DEBUG)
    - `currentNamespaceOnly: false` (cluster-wide watch)
    - `csi.enableRbdDriver: ${ROOK_CEPH_CSI_ENABLE_RBD}`
    - `csi.enableCephfsDriver: ${ROOK_CEPH_CSI_ENABLE_CEPHFS}`
    - `csi.provisionerReplicas: 2` (HA for CSI provisioners)
    - `csi.logLevel: 3` (0=errors only, 5=debug)
    - `discover.enabled: true` (auto-discover node disks)
    - `discover.tolerations: []` (add control plane taints if needed)
    - `monitoring.enabled: true` (enable Prometheus metrics)
    - `pspEnable: false` (PSP deprecated, use PSA)
  - DependsOn: HelmRepository/rook-ceph

### T5: Rook-Ceph Operator RBAC
- Note: RBAC is included in HelmRelease chart, but document required permissions:
  - ServiceAccount: `rook-ceph-system`, `rook-ceph-osd`, `rook-ceph-mgr`
  - ClusterRole permissions:
    - nodes: get, list, watch (for node discovery)
    - persistentvolumes: get, list, watch, create, delete (for PV management)
    - storageclasses: get, list, watch (for provisioning)
    - events: create, update, patch (for event logging)
    - secrets: get, list, watch, create, update, delete (for Ceph secrets)
  - ClusterRoleBindings: bind service accounts to cluster roles

### T6: Rook-Ceph Discover DaemonSet
- Note: Discover DaemonSet is included in HelmRelease chart
- Configured via values:
  - `discover.enabled: true`
  - Runs on all nodes (or subset with node selector)
  - Discovers available disks (raw, unformatted)
  - Creates ConfigMaps with disk inventory
  - Tolerations for control plane taints

### T7: CSI Driver Configuration
- Note: CSI drivers are included in HelmRelease chart
- Configured via values:
  - RBD driver: `csi.enableRbdDriver: true`
    - Provisioner: `rbd.csi.ceph.com`
    - Supports ReadWriteOnce (RWO) volumes
    - Block storage for databases
  - CephFS driver: `csi.enableCephfsDriver: true`
    - Provisioner: `cephfs.csi.ceph.com`
    - Supports ReadWriteMany (RWX) volumes
    - Shared filesystem storage
  - CSI provisioner replicas: 2 (HA)
  - CSI log level: 3 (INFO)

### T8: Rook-Ceph Monitoring
- Create `kubernetes/infrastructure/storage/rook-ceph/operator/podmonitor.yaml`:
  - PodMonitor: `rook-ceph-operator`
  - Namespace selector: `rook-ceph`
  - Port: http-metrics (9090)
  - Path: `/metrics`
  - Labels for VictoriaMetrics discovery

### T9: Rook-Ceph Alerting
- Create `kubernetes/infrastructure/storage/rook-ceph/operator/prometheusrule.yaml`:
  - VMRule: `rook-ceph-operator-alerts`
  - Alert groups:
    - **RookCephOperatorDown**: No operator pods ready for 5 minutes
    - **RookCephOperatorCrashLooping**: Operator crashlooping for 5 minutes
    - **RookCephCRDReconciliationFailed**: CRD reconciliation errors detected
    - **RookCephCSIDriverNotReady**: CSI driver pods not ready for 5 minutes
    - **RookCephDiscoverDaemonNotReady**: Discover daemon not running on nodes
    - **RookCephOperatorHighMemory**: Operator memory usage >80% of limit

### T10: Rook-Ceph Operator Kustomization
- Create `kubernetes/infrastructure/storage/rook-ceph/operator/kustomization.yaml`:
  - Resources: namespace, helmrepository, helmrelease, podmonitor, prometheusrule
  - Namespace: `rook-ceph`
  - CommonLabels: `app.kubernetes.io/part-of=rook-ceph`

### T11: Rook-Ceph Operator Flux Kustomization
- Create `kubernetes/infrastructure/storage/rook-ceph/operator/ks.yaml`:
  - Kustomization: `cluster-apps-rook-ceph-operator`
  - Source: GitRepository/flux-system
  - Path: `./kubernetes/infrastructure/storage/rook-ceph/operator`
  - Interval: 10m
  - Prune: true
  - Wait: true
  - Timeout: 5m
  - Health checks:
    - Deployment/rook-ceph-operator
  - DependsOn:
    - cluster-apps-cilium-core (requires CNI)
    - cluster-apps-openebs (optional, for Ceph metadata storage)

### T12: Infrastructure Kustomization Update
- Update `kubernetes/infrastructure/storage/rook-ceph/kustomization.yaml`:
  - Add `./operator` to resources

### T13: Rook-Ceph Operator README
- Create `kubernetes/infrastructure/storage/rook-ceph/operator/README.md`:
  - **Architecture Overview**:
    - Rook operator as Kubernetes controller
    - Manages CephCluster CRs declaratively
    - Deploys and manages Ceph daemons (mon, mgr, osd, mds, rgw)
    - CSI drivers for dynamic provisioning
  - **Operator Responsibilities**:
    - CRD reconciliation (CephCluster, CephBlockPool, CephFilesystem, etc.)
    - Ceph daemon lifecycle (deploy, scale, upgrade, heal)
    - CSI driver deployment (RBD, CephFS provisioners)
    - Discover daemon management (node disk discovery)
    - Webhook validation (CephCluster spec validation)
  - **Node Preparation**:
    - Disks must be raw and unformatted (no partitions, no filesystems)
    - Clean disks: `wipefs -a /dev/sdX` or `sgdisk --zap-all /dev/sdX`
    - Verify with: `lsblk -f` (should show empty TYPE)
    - Label nodes (optional): `kubectl label node <node> ceph-storage=enabled`
  - **CSI Drivers**:
    - RBD driver: Block storage, RWO volumes, for databases
    - CephFS driver: Shared filesystem, RWX volumes, for shared data
    - CSI provisioner HA: 2 replicas for each driver
  - **Troubleshooting**:
    - Check operator logs: `kubectl logs -n rook-ceph deploy/rook-ceph-operator`
    - Check CRD status: `kubectl get cephclusters -A`
    - Check CSI drivers: `kubectl get pod -n rook-ceph -l app=csi-rbdplugin`
    - Check discover daemon: `kubectl get pod -n rook-ceph -l app=rook-discover`
    - Operator events: `kubectl get events -n rook-ceph --sort-by='.lastTimestamp'`
  - **Upgrade Procedures**:
    - Operator upgrade: update HelmRelease chart version
    - Ceph version upgrade: handled by operator after operator upgrade
    - Rolling upgrade process (Mons → MGRs → OSDs → MDS → RGW)
  - **Comparison with Infra Cluster**:
    - Same operator pattern (Rook-Ceph)
    - Different Ceph cluster (isolated storage)
    - Apps cluster: local storage for apps workloads
    - Infra cluster: storage for platform services

### T14: Cluster Settings Update
- Update `kubernetes/clusters/apps/cluster-settings.yaml`:
  - Add Rook-Ceph operator configuration:
    ```yaml
    ROOK_CEPH_OPERATOR_REPLICAS: "1"
    ROOK_CEPH_LOG_LEVEL: "INFO"  # "DEBUG" for troubleshooting
    ROOK_CEPH_CSI_ENABLE_RBD: "true"
    ROOK_CEPH_CSI_ENABLE_CEPHFS: "true"
    ```

### T15: Local Validation
- Run validation commands:
  - `kubectl --dry-run=client apply -f kubernetes/infrastructure/storage/rook-ceph/operator/`
  - `flux build kustomization cluster-apps-rook-ceph-operator --path ./kubernetes/infrastructure/storage/rook-ceph/operator`
  - `kubeconform -summary -output pretty kubernetes/infrastructure/storage/rook-ceph/operator/*.yaml`
  - `yamllint kubernetes/infrastructure/storage/rook-ceph/operator/`
- Verify HelmRelease values syntax
- Validate HelmRepository URL

### T16: Git Commit
- Stage all changes
- Commit: "feat(storage): add Rook-Ceph operator manifests for apps cluster (Story 30)"

## Runtime Validation (MOVED TO STORY 45)

**The following validation steps require a running cluster and are deferred to Story 45:**

### Rook-Ceph Operator Validation
```bash
# Check Rook-Ceph namespace
kubectl --context=apps get namespace rook-ceph

# Check operator Deployment
kubectl --context=apps -n rook-ceph get deploy rook-ceph-operator
kubectl --context=apps -n rook-ceph get pod -l app=rook-ceph-operator

# Check operator logs
kubectl --context=apps -n rook-ceph logs deploy/rook-ceph-operator --tail=50

# Verify operator is ready
kubectl --context=apps -n rook-ceph wait --for=condition=Available deploy/rook-ceph-operator --timeout=300s
```

### CRD Installation Validation
```bash
# Check Rook-Ceph CRDs installed
kubectl --context=apps get crd | grep ceph

# Expected CRDs:
# - cephblockpools.ceph.rook.io
# - cephbucketnotifications.ceph.rook.io
# - cephbuckettopics.ceph.rook.io
# - cephclients.ceph.rook.io
# - cephclusters.ceph.rook.io
# - cephfilesystemmirrors.ceph.rook.io
# - cephfilesystems.ceph.rook.io
# - cephfilesystemsubvolumegroups.ceph.rook.io
# - cephnfses.ceph.rook.io
# - cephobjectrealms.ceph.rook.io
# - cephobjectstores.ceph.rook.io
# - cephobjectstoreusers.ceph.rook.io
# - cephobjectzonegroups.ceph.rook.io
# - cephobjectzones.ceph.rook.io
# - cephrbdmirrors.ceph.rook.io

# Check CRD versions
kubectl --context=apps get crd cephclusters.ceph.rook.io -o jsonpath='{.spec.versions[*].name}'
```

### CSI Driver Validation
```bash
# Check RBD CSI driver pods
kubectl --context=apps -n rook-ceph get pod -l app=csi-rbdplugin
kubectl --context=apps -n rook-ceph get pod -l app=csi-rbdplugin-provisioner

# Check CephFS CSI driver pods
kubectl --context=apps -n rook-ceph get pod -l app=csi-cephfsplugin
kubectl --context=apps -n rook-ceph get pod -l app=csi-cephfsplugin-provisioner

# Verify CSI provisioner replicas (should be 2 for HA)
kubectl --context=apps -n rook-ceph get deploy csi-rbdplugin-provisioner
kubectl --context=apps -n rook-ceph get deploy csi-cephfsplugin-provisioner

# Check CSI driver logs
kubectl --context=apps -n rook-ceph logs -l app=csi-rbdplugin-provisioner --tail=20
```

### Discover Daemon Validation
```bash
# Check discover DaemonSet
kubectl --context=apps -n rook-ceph get ds rook-discover

# Verify discover daemon running on all nodes
kubectl --context=apps -n rook-ceph get pod -l app=rook-discover -o wide

# Check discovered disks (ConfigMaps)
kubectl --context=apps -n rook-ceph get cm -l app=rook-discover

# Inspect disk inventory for a node
NODE=apps-node-1
kubectl --context=apps -n rook-ceph get cm rook-discover-${NODE}-config -o yaml
```

### Operator RBAC Validation
```bash
# Check service accounts created
kubectl --context=apps -n rook-ceph get sa | grep rook

# Expected service accounts:
# - rook-ceph-system
# - rook-ceph-osd
# - rook-ceph-mgr
# - rook-ceph-cmd-reporter
# - rook-csi-rbd-provisioner-sa
# - rook-csi-cephfs-provisioner-sa

# Check ClusterRoles
kubectl --context=apps get clusterrole | grep rook

# Check ClusterRoleBindings
kubectl --context=apps get clusterrolebinding | grep rook
```

### Operator Webhook Validation
```bash
# Check webhook configuration
kubectl --context=apps get validatingwebhookconfigurations | grep rook

# Test webhook (if CephCluster CR created)
# Webhook validates CephCluster spec before admission
```

### Monitoring Validation
```bash
# Check PodMonitor discovered
kubectl --context=apps -n observability get podmonitor -l app.kubernetes.io/name=rook-ceph

# Query operator metrics
kubectl --context=apps -n rook-ceph port-forward deploy/rook-ceph-operator 9090:9090 &
curl -s http://localhost:9090/metrics | grep rook_ceph

# Check alerts configured
kubectl --context=apps -n observability get vmrule rook-ceph-operator-alerts -o yaml

# Verify metrics in VictoriaMetrics
# Query: up{job="rook-ceph-operator"}
# Query: rook_ceph_operator_reconcile_total
```

### Operator Health Check
```bash
# Check operator ready conditions
kubectl --context=apps -n rook-ceph get deploy rook-ceph-operator -o jsonpath='{.status.conditions[?(@.type=="Available")].status}'
# Expected: True

# Check for crashloops
kubectl --context=apps -n rook-ceph get pod -l app=rook-ceph-operator -o jsonpath='{.items[*].status.containerStatuses[*].restartCount}'
# Expected: 0

# Check operator version
kubectl --context=apps -n rook-ceph get deploy rook-ceph-operator -o jsonpath='{.spec.template.spec.containers[0].image}'
```

## Definition of Done

### Manifest Creation Complete (This Story)

- [x] All acceptance criteria AC1-AC8 met
- [x] Rook-Ceph operator manifests created under `kubernetes/infrastructure/storage/rook-ceph/operator/`
- [x] HelmRelease configured with operator and CSI drivers
- [x] Flux Kustomization created for operator stack
- [x] Monitoring configured (PodMonitor, PrometheusRules)
- [x] All manifests pass local validation (dry-run, flux build, kubeconform)
- [x] Comprehensive README documentation created
- [x] Cluster settings updated with operator configuration
- [x] Changes committed to git with descriptive message

### NOT Part of DoD (Moved to Story 45)

The following are **explicitly deferred** to Story 45:
- Rook-Ceph operator deployed and running
- CRDs installed in cluster
- CSI drivers deployed and ready
- Discover daemon running on nodes
- Operator RBAC functional
- Monitoring alerts firing correctly
- End-to-end operator health validation

## Design Notes

### Rook-Ceph Operator Architecture

**Components**:
1. **Rook Operator**: Kubernetes controller
   - Watches CephCluster CRs
   - Deploys Ceph daemons as pods
   - Manages Ceph cluster lifecycle
   - Single operator manages multiple CephClusters

2. **CSI Drivers**: Dynamic provisioning
   - RBD driver: Block storage (RWO)
   - CephFS driver: Shared filesystem (RWX)
   - Provisioner pods: Create/delete PVs
   - Attacher pods: Attach/detach volumes to nodes

3. **Discover Daemon**: Disk discovery
   - DaemonSet on all nodes
   - Discovers raw, unformatted disks
   - Creates ConfigMaps with disk inventory
   - Used by CephCluster for OSD placement

4. **Webhooks**: Admission control
   - Validates CephCluster CRs before admission
   - Prevents invalid configurations
   - Ensures schema compliance

### Operator vs Cluster

**Operator (This Story)**:
- Deploys the Rook operator controller
- Installs CRDs (CephCluster, CephBlockPool, etc.)
- Deploys CSI drivers
- Deploys discover daemon
- Does NOT create a Ceph cluster

**Cluster (Next Story)**:
- Creates a CephCluster CR
- Operator deploys Ceph daemons (mon, mgr, osd)
- Creates block pool, filesystem
- Creates StorageClasses
- Provisions actual storage

### CSI Drivers

**RBD Driver** (`rbd.csi.ceph.com`):
- **Use case**: Block storage for databases
- **Access mode**: ReadWriteOnce (RWO)
- **Performance**: High (direct block access)
- **Provisioner**: csi-rbdplugin-provisioner (2 replicas)
- **Attacher**: csi-rbdplugin (DaemonSet on all nodes)
- **StorageClass**: Created in next story (cluster deployment)

**CephFS Driver** (`cephfs.csi.ceph.com`):
- **Use case**: Shared filesystem for multi-pod access
- **Access mode**: ReadWriteMany (RWX)
- **Performance**: Medium (filesystem overhead)
- **Provisioner**: csi-cephfsplugin-provisioner (2 replicas)
- **Attacher**: csi-cephfsplugin (DaemonSet on all nodes)
- **StorageClass**: Created in next story (cluster deployment)

### Discover Daemon

**Purpose**:
- Auto-discovers disks on nodes
- Creates ConfigMaps with disk inventory
- Operator uses inventory for OSD placement

**Disk Requirements**:
- Raw disks (no partitions)
- Unformatted (no filesystem)
- No LVM, RAID, or other volume management
- Minimum size: typically 5GB (configurable)

**Discovery Process**:
1. Discover daemon scans node devices (`/dev/sd*`, `/dev/nvme*`)
2. Filters out partitioned or formatted disks
3. Creates ConfigMap: `rook-discover-<node-name>-config`
4. Operator reads ConfigMaps for OSD placement

**Example ConfigMap**:
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: rook-discover-apps-node-1-config
  namespace: rook-ceph
data:
  devices: |
    [
      {
        "name": "nvme0n1",
        "parent": "",
        "hasChildren": false,
        "devLinks": "/dev/disk/by-id/nvme-...",
        "size": 1000204886016,
        "uuid": "",
        "serial": "...",
        "type": "disk",
        "rotational": false,
        "readOnly": false,
        "filesystem": "",
        "vendor": "Samsung",
        "model": "SSD 970 EVO Plus 1TB",
        "wwn": "",
        "empty": true
      }
    ]
```

### Node Preparation

**Disk Cleanup**:
```bash
# List disks and partitions
lsblk -f

# Wipe filesystem signatures
sudo wipefs -a /dev/nvme0n1

# Zap partition table (GPT/MBR)
sudo sgdisk --zap-all /dev/nvme0n1

# Alternative: dd method (destructive!)
sudo dd if=/dev/zero of=/dev/nvme0n1 bs=1M count=100

# Verify disk is clean
lsblk -f /dev/nvme0n1
# Should show empty TYPE and FSTYPE
```

**Talos Linux Considerations**:
- Talos manages disks declaratively
- Use Talos machine config to specify storage disks
- Disks not claimed by Talos are available for Ceph
- Avoid system disk (used by Talos for OS and state)

**Example Talos Config**:
```yaml
machine:
  disks:
    - device: /dev/nvme0n1
      partitions:
        - mountpoint: /var/mnt/storage
```

### Operator Watch Scope

**Cluster-Wide (Recommended)**:
- `currentNamespaceOnly: false`
- Operator watches CephClusters in all namespaces
- Single operator manages multiple clusters
- More flexible for multi-tenancy

**Namespace-Scoped**:
- `currentNamespaceOnly: true`
- Operator watches CephClusters only in `rook-ceph` namespace
- More restricted, better for single-cluster deployments
- Simpler RBAC

**This Deployment**: Cluster-wide for consistency with infra cluster.

### Resource Sizing

**Operator**:
- Requests: 100m CPU, 128Mi memory
- Limits: 500m CPU, 512Mi memory
- Single replica (operator is stateless, can be restarted)

**CSI Provisioners**:
- 2 replicas each (HA for RBD and CephFS)
- Requests: 100m CPU, 128Mi memory per replica
- Limits: 500m CPU, 512Mi memory per replica

**CSI Plugins**:
- DaemonSet (one pod per node)
- Requests: 50m CPU, 64Mi memory per pod
- Limits: 200m CPU, 256Mi memory per pod

**Discover Daemon**:
- DaemonSet (one pod per node)
- Requests: 50m CPU, 64Mi memory per pod
- Limits: 100m CPU, 128Mi memory per pod

### High Availability

**Operator HA**:
- Single operator replica (stateless controller)
- Can be scaled to 2+ replicas with leader election
- Restart is fast (no state to recover)

**CSI Provisioner HA**:
- 2 replicas for RBD provisioner
- 2 replicas for CephFS provisioner
- Leader election ensures only one active
- Failover on pod/node failure

**CSI Plugin HA**:
- DaemonSet ensures plugin on every node
- Node failure means pods on that node cannot access storage
- Kubernetes reschedules pods to healthy nodes

### Monitoring and Alerting

**Key Metrics**:
- `rook_ceph_operator_reconcile_total`: CRD reconciliation count
- `rook_ceph_operator_reconcile_duration_seconds`: Reconciliation latency
- `csi_provisioner_operations_total`: CSI provisioning operations
- `csi_provisioner_operations_duration_seconds`: CSI provisioning latency

**Critical Alerts**:
1. **Operator Down**: No operator pods ready
2. **Operator Crashlooping**: Restart count increasing
3. **CRD Reconciliation Failed**: Errors in reconciliation
4. **CSI Driver Not Ready**: Provisioner/plugin pods not ready
5. **Discover Daemon Not Ready**: Missing on nodes

### Troubleshooting

**Operator Not Starting**:
1. Check logs: `kubectl logs -n rook-ceph deploy/rook-ceph-operator`
2. Common issues:
   - RBAC permissions missing
   - CRD installation failed
   - Invalid HelmRelease values
3. Verify RBAC: `kubectl auth can-i --list --as=system:serviceaccount:rook-ceph:rook-ceph-system`

**CSI Driver Not Deploying**:
1. Check operator logs for CSI deployment errors
2. Verify CSI enabled in HelmRelease values
3. Check CSI provisioner logs: `kubectl logs -n rook-ceph -l app=csi-rbdplugin-provisioner`

**Discover Daemon Not Running**:
1. Check DaemonSet status: `kubectl get ds -n rook-ceph rook-discover`
2. Common issues:
   - Node taints preventing scheduling
   - RBAC permissions for discover daemon
3. Check pod logs: `kubectl logs -n rook-ceph -l app=rook-discover`

**CRD Installation Failed**:
1. Check if CRDs exist: `kubectl get crd | grep ceph`
2. HelmRelease setting: `crds.enabled: true`
3. Manual CRD installation: `kubectl apply -f https://raw.githubusercontent.com/rook/rook/release-1.14/deploy/examples/crds.yaml`

### Upgrade Procedures

**Operator Upgrade**:
1. Update HelmRelease chart version
2. Flux reconciles HelmRelease
3. Operator Deployment updated (rolling update)
4. Operator manages Ceph cluster upgrade

**Ceph Version Upgrade**:
- Handled automatically by operator after operator upgrade
- Rolling upgrade: Mons → MGRs → OSDs → MDS → RGW
- No downtime for block storage (RBD)
- Minimal downtime for shared filesystem (CephFS)

**Upgrade Path**:
- Rook 1.13.x → 1.14.x → 1.15.x
- Ceph Pacific → Quincy → Reef
- Always test in staging first

### Security Hardening

**PSA Privileged**:
- Ceph requires host access (networking, disks)
- PSA privileged enforcement required
- Alternative: custom PSA profile with specific exceptions

**RBAC**:
- Least privilege principle
- Service accounts for operator, OSD, MGR, etc.
- ClusterRoles limited to required permissions
- No wildcard permissions

**Network Policies**:
- Apply NetworkPolicies to rook-ceph namespace
- Allow CNI access (Cilium)
- Allow monitoring (VictoriaMetrics)
- Deny all other ingress

**Secrets Management**:
- Ceph keyring stored in Kubernetes Secrets
- RADOS gateway credentials via ExternalSecrets (if using RGW)
- Encryption at rest (Ceph OSD encryption)

### Comparison with Infra Cluster

**Similarities**:
- Same Rook operator version
- Same CSI drivers (RBD, CephFS)
- Same operator pattern

**Differences**:
- **Infra cluster**: Storage for platform services (databases, observability)
- **Apps cluster**: Storage for application workloads (user apps, CI/CD)
- **Isolation**: Separate Ceph clusters, no shared storage
- **Performance**: Infra cluster may use HDDs, apps cluster uses SSDs/NVMe

**Why Separate Clusters**:
- Fault isolation (apps cluster failure doesn't affect infra)
- Performance isolation (noisy neighbor avoidance)
- Data locality (apps data stays on apps cluster)
- Independent scaling (grow each cluster independently)

### Future Enhancements

**Multi-Site Replication**:
- RBD mirroring (async replication to DR site)
- CephFS snapshot mirroring
- Object storage geo-replication (RGW)

**Encryption at Rest**:
- OSD-level encryption (LUKS)
- Ceph native encryption
- Performance impact (~10-20%)

**Advanced CSI Features**:
- Volume snapshots (CSI VolumeSnapshot)
- Volume cloning (CSI VolumeClone)
- Volume expansion (online resize)
- Topology-aware provisioning

**Object Storage**:
- Deploy Ceph RADOS Gateway (RGW)
- S3-compatible object storage
- Multi-tenant buckets
- Lifecycle policies

## Change Log

### v3.0 (2025-10-26) - Manifests-First Architecture Refinement

**Refined Story to Separate Manifest Creation from Deployment**:
1. **Updated header**: Changed title to "Create Rook-Ceph Operator Manifests (apps)", status to "Draft (v3.0 Refinement)", date to 2025-10-26
2. **Rewrote story**: Focus on creating manifests for Rook-Ceph operator to manage distributed Ceph storage
3. **Split scope**:
   - This Story: Create operator infrastructure, CSI drivers, discover daemon, monitoring, local validation
   - Story 45: Deploy to apps cluster, verify operator readiness, test CSI drivers, validate CRDs
4. **Created 8 acceptance criteria** for manifest creation (AC1-AC8):
   - AC1: Operator manifests (namespace, HelmRelease, HelmRepository)
   - AC2: HelmRelease configuration (chart version, replicas, watch scope, CSI drivers)
   - AC3: Operator configuration (discover daemon, CSI drivers, node affinity, log level)
   - AC4: Monitoring (PodMonitor, PrometheusRules with 6 alerts)
   - AC5: Flux Kustomization (health checks, dependencies, timeout)
   - AC6: Security hardening (PSA privileged, RBAC, service accounts, PDB)
   - AC7: Local validation (dry-run, flux build, kubeconform)
   - AC8: Comprehensive documentation (architecture, operator responsibilities, node prep, troubleshooting)
5. **Updated dependencies**: Local tools only (kubectl, flux CLI, yq, kubeconform), story dependencies (Cilium, OpenEBS)
6. **Restructured tasks** to T1-T16:
   - T1: Prerequisites and strategy
   - T2: Rook-Ceph namespace with PSA privileged
   - T3: HelmRepository for Rook charts
   - T4: Operator HelmRelease (chart 1.14.x/1.15.x, CSI drivers, discover daemon, monitoring)
   - T5: RBAC documentation (included in chart)
   - T6: Discover DaemonSet configuration (included in chart)
   - T7: CSI driver configuration (RBD, CephFS)
   - T8: Operator monitoring (PodMonitor)
   - T9: Operator alerting (VMRule with 6 alerts)
   - T10: Operator Kustomization
   - T11: Operator Flux Kustomization
   - T12: Infrastructure Kustomization update
   - T13: Operator README (architecture, responsibilities, node prep, CSI drivers, troubleshooting, upgrade, comparison with infra)
   - T14: Cluster settings update
   - T15: Local validation
   - T16: Git commit
7. **Added "Runtime Validation (MOVED TO STORY 45)" section** with comprehensive testing:
   - Operator validation (Deployment status, logs, readiness)
   - CRD installation validation (list CRDs, versions)
   - CSI driver validation (RBD, CephFS provisioners/plugins)
   - Discover daemon validation (DaemonSet, disk inventory ConfigMaps)
   - Operator RBAC validation (service accounts, ClusterRoles, bindings)
   - Webhook validation
   - Monitoring validation (metrics, alerts)
   - Operator health check (ready conditions, crashloops, version)
8. **Updated DoD** with clear separation:
   - "Manifest Creation Complete (This Story)": All manifests created, validated locally, documented, committed
   - "NOT Part of DoD (Moved to Story 45)": Deployment, CRD installation, CSI drivers running, discover daemon, RBAC functional
9. **Added comprehensive design notes**:
   - Rook-Ceph operator architecture (operator, CSI drivers, discover daemon, webhooks)
   - Operator vs Cluster (operator deploys infrastructure, cluster story creates Ceph cluster)
   - CSI drivers (RBD for RWO, CephFS for RWX)
   - Discover daemon (disk discovery, ConfigMaps, requirements)
   - Node preparation (disk cleanup, Talos considerations)
   - Operator watch scope (cluster-wide vs namespace-scoped)
   - Resource sizing (operator, CSI provisioners, CSI plugins, discover daemon)
   - High availability (operator, CSI provisioner, CSI plugin)
   - Monitoring and alerting (key metrics, critical alerts)
   - Troubleshooting (operator, CSI, discover, CRD issues)
   - Upgrade procedures (operator upgrade, Ceph version upgrade)
   - Security hardening (PSA, RBAC, NetworkPolicies, secrets)
   - Comparison with infra cluster (similarities, differences, isolation)
   - Future enhancements (replication, encryption, advanced CSI, object storage)
10. **Preserved original context**: Sprint 6, Lane Storage, apps cluster focus

**Gaps Identified and Fixed**:
- Added PSA privileged enforcement (Ceph requires host access)
- Added CSI driver HA configuration (2 replicas for provisioners)
- Added discover daemon configuration and disk requirements
- Added comprehensive monitoring (PodMonitor, 6 alerts)
- Added operator watch scope (cluster-wide for multi-tenancy)
- Added node preparation documentation (disk cleanup, wipefs, sgdisk)
- Added CSI driver documentation (RBD vs CephFS use cases)
- Added detailed troubleshooting procedures
- Added upgrade procedures (operator and Ceph version)
- Added comparison with infra cluster deployment

**Why v3.0**:
- Enforces clean separation: Story 30 = CREATE manifests (local), Story 45 = DEPLOY & VALIDATE (cluster)
- Enables parallel work: manifest creation can proceed without cluster access
- Improves testing: all manifests validated locally before any deployment
- Reduces risk: deployment issues don't block manifest refinement work
- Maintains GitOps principles: manifest creation is pure IaC work
