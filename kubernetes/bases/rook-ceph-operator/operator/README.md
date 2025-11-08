# Rook-Ceph Operator

The Rook-Ceph operator manages Ceph storage clusters on Kubernetes, providing automated lifecycle management for distributed, highly-available storage. This implementation deploys to both **infra** and **apps** clusters via shared operator manifests.

## 📊 Overview

**Chart Version**: v1.18.6 (October 2024 - Latest Stable)
**Ceph Version**: v19.2.3 (Squid release)
**Repository**: https://charts.rook.io/release
**Namespace**: `rook-ceph`
**Operator Replicas**: 1 (single operator manages multiple clusters)

## 🏗️ Architecture

### Components

#### 1. **Rook-Ceph Operator Deployment**

The operator is the brain of the Rook-Ceph system, responsible for:

- **CRD Reconciliation**: Watches CephCluster, CephBlockPool, CephFilesystem CRs and orchestrates Ceph daemons
- **Daemon Lifecycle Management**: Creates and manages MON, MGR, OSD, MDS, RGW pods
- **Health Monitoring**: Continuously monitors Ceph cluster health and auto-heals issues
- **Upgrade Orchestration**: Manages rolling upgrades of Ceph daemons
- **Storage Provisioning**: Coordinates with CSI drivers for dynamic volume provisioning

**Resource Limits**:
- Requests: 100m CPU, 128Mi memory
- Limits: 500m CPU, 512Mi memory

**Deployment Pattern**:
- Single replica (leader election not needed - stateless operator)
- Runs on any node (no specific placement constraints)
- Cluster-wide watch scope (manages CephClusters in all namespaces)

#### 2. **CSI Drivers** (Container Storage Interface)

Rook deploys CSI drivers for dynamic volume provisioning:

##### **RBD Driver** (RADOS Block Device)
- **Use Case**: Block storage for databases, VMs, general workloads
- **Access Mode**: ReadWriteOnce (RWO)
- **Performance**: High IOPS, low latency
- **Provisioner Replicas**: 2 (HA configuration with leader election)
- **Features**: Snapshots, clones, volume expansion, encryption
- **CSI Plugin Components**:
  - `csi-provisioner`: Creates/deletes volumes
  - `csi-resizer`: Expands volumes online
  - `csi-snapshotter`: Creates volume snapshots
  - `csi-rbdplugin`: Node plugin for mounting volumes

**Resource Limits (per component)**:
- Requests: 100m CPU, 128Mi memory
- Limits: 200m CPU, 256Mi memory

##### **CephFS Driver** (Ceph Filesystem)
- **Use Case**: Shared filesystem for multi-pod access (ReadWriteMany)
- **Access Mode**: RWO, ROX, RWX
- **Performance**: Good for shared access, lower IOPS than RBD
- **Provisioner Replicas**: 2 (HA configuration)
- **Features**: POSIX-compliant filesystem, snapshots, quotas
- **CSI Plugin Components**:
  - `csi-provisioner`: Creates/deletes filesystems
  - `csi-resizer`: Expands filesystems
  - `csi-snapshotter`: Creates filesystem snapshots
  - `csi-cephfsplugin`: Node plugin for mounting filesystems

**When to Use**:
| Use Case | Recommended Driver |
|----------|-------------------|
| PostgreSQL, MySQL databases | **RBD** (block storage) |
| Redis, Memcached caches | **RBD** |
| GitLab shared repository storage | **CephFS** (shared access) |
| Harbor registry blob storage | **RBD** |
| Shared configuration files | **CephFS** |
| CI/CD build artifacts (shared) | **CephFS** |
| Single-pod persistent data | **RBD** |

#### 3. **Discovery Daemon** (DaemonSet)

The discover daemon runs on **every node** to automatically detect available storage devices:

- **Auto-Discovery**: Scans for unused disks (NVMe, SSD, HDD)
- **Device Metadata**: Collects disk size, type, serial number, health status
- **ConfigMap Updates**: Updates `rook-discover-devices` ConfigMap with discovered devices
- **OSD Preparation**: Prepares disks for OSD deployment
- **Hot-Plug Support**: Detects newly added disks without operator restart

**Resource Limits**:
- Requests: 50m CPU, 64Mi memory
- Limits: 200m CPU, 128Mi memory

**How It Works**:
```
┌────────────────────────────────────────────────────┐
│ 1. Discover daemon scans /dev for block devices    │
└──────────────────┬─────────────────────────────────┘
                   │
                   ▼
┌────────────────────────────────────────────────────┐
│ 2. Filters out in-use devices (mounted, partitions)│
└──────────────────┬─────────────────────────────────┘
                   │
                   ▼
┌────────────────────────────────────────────────────┐
│ 3. Updates ConfigMap with available devices        │
└──────────────────┬─────────────────────────────────┘
                   │
                   ▼
┌────────────────────────────────────────────────────┐
│ 4. Operator reads ConfigMap and creates OSDs       │
└────────────────────────────────────────────────────┘
```

#### 4. **Validating Webhook**

Rook creates a ValidatingWebhookConfiguration for admission control:

- **CephCluster Validation**: Validates CephCluster CR before admission
  - Checks required fields (MON count, storage selection, network config)
  - Validates resource limits and requests
  - Ensures compatible Ceph versions
- **CephBlockPool Validation**: Validates replication settings, failure domain
- **CephFilesystem Validation**: Validates MDS configuration, data pools
- **Prevents Misconfigurations**: Rejects invalid CRs before they're applied

**Webhook Port**: 9443 (HTTPS)
**Certificate Management**: Auto-generated TLS certificates, rotated by operator

---

## ✅ Use Cases

### **When to Use Rook-Ceph**

✅ **Multi-replica StatefulSets** requiring shared persistent storage
✅ **ReadWriteMany (RWX) volumes** for shared access across pods
✅ **High-availability databases** with built-in replication (3+ replicas)
✅ **Data durability across node failures** (replicated storage)
✅ **Object storage** (S3-compatible via RGW)
✅ **Filesystem storage** (POSIX-compliant shared filesystem)
✅ **Snapshots and clones** (volume snapshots, PVC cloning)
✅ **Cross-cluster data replication** (disaster recovery)

### **When NOT to Use Rook-Ceph** (Use OpenEBS LocalPV instead)

❌ **Single-replica workloads** needing maximum performance
❌ **Ultra-low latency requirements** (<1ms latency needed)
❌ **High IOPS workloads** (>100K IOPS on single volume)
❌ **Ephemeral storage** (CI/CD build caches, temporary data)
❌ **Small clusters** (3 nodes minimum for Ceph quorum)
❌ **Cost-sensitive deployments** (Ceph has overhead: MON, MGR, OSD pods)

---

## 🔧 Node Preparation

### Prerequisites

Rook-Ceph requires **clean, unused disks** on each storage node. Disks must have:

1. ❌ **No existing filesystem**
2. ❌ **No partition table**
3. ❌ **No LVM configuration**
4. ✅ **Sufficient size** (minimum 10GB recommended, 100GB+ for production)

### Disk Cleanup Commands

**⚠️ WARNING: These commands will DESTROY ALL DATA on the disk!**

#### Check Disk Status
```bash
# List all block devices
lsblk

# Check for existing filesystems
sudo blkid /dev/nvme0n1

# Check partition table
sudo fdisk -l /dev/nvme0n1

# Check for LVM
sudo pvdisplay
sudo vgdisplay
sudo lvdisplay
```

#### Clean Disk for Ceph Use

```bash
# Method 1: Wipe filesystem signatures
sudo wipefs --all /dev/nvme0n1

# Method 2: Zero out partition table
sudo sgdisk --zap-all /dev/nvme0n1

# Method 3: Zero out first 100MB (thorough)
sudo dd if=/dev/zero of=/dev/nvme0n1 bs=1M count=100

# Method 4: Full disk wipe (SLOW - use only if needed)
sudo dd if=/dev/zero of=/dev/nvme0n1 bs=1M status=progress
```

#### Verify Disk is Clean
```bash
# Should show no filesystem
sudo blkid /dev/nvme0n1

# Should show no partition table
sudo fdisk -l /dev/nvme0n1

# Disk should appear as "unused" in discover daemon ConfigMap
kubectl get configmap -n rook-ceph rook-discover-devices -o yaml
```

### Talos Linux Considerations

For **Talos Linux** nodes:

1. **Disk Access**: Talos is immutable, but disks are still accessible to Ceph OSDs
2. **Device Paths**: Use `/dev/disk/by-id/` for stable device naming
3. **Kernel Modules**: Talos includes required Ceph kernel modules (RBD, CephFS)
4. **No Manual Cleanup Needed**: Talos doesn't auto-mount data disks, safe for Ceph

**Talos CephCluster Configuration**:
```yaml
storage:
  useAllDevices: false  # Explicit device selection recommended
  devices:
    - name: "/dev/disk/by-id/nvme-Samsung_SSD_970_EVO_Plus_1TB_XXXXXXXXXXXX"
```

### Node Labeling (Optional)

Label storage nodes for targeted OSD placement:

```bash
# Label nodes that should run Ceph OSDs
kubectl label node node-1 ceph-osd=enabled
kubectl label node node-2 ceph-osd=enabled
kubectl label node node-3 ceph-osd=enabled

# Use in CephCluster CR
spec:
  placement:
    osd:
      nodeAffinity:
        requiredDuringSchedulingIgnoredDuringExecution:
          nodeSelectorTerms:
            - matchExpressions:
                - key: ceph-osd
                  operator: In
                  values:
                    - enabled
```

---

## ⚙️ Configuration

### Helm Values

The operator is configured via HelmRelease values:

#### CRD Installation
```yaml
crds:
  enabled: true  # Install CRDs via Helm (simplifies upgrades)
```

#### Operator Resources
```yaml
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 512Mi
```

#### CSI Driver Configuration
```yaml
csi:
  enableCSIHostNetwork: true  # Required for Talos Linux
  provisionerReplicas: 2      # HA for provisioner

  enableRbdDriver: true       # Block storage (RWO)
  enableCephfsDriver: true    # Filesystem storage (RWX)

  logLevel: 3                 # 0=errors, 5=debug

  # Resource limits for CSI components
  csiRBDProvisionerResource: |
    - name: csi-provisioner
      resource:
        requests: {memory: 128Mi, cpu: 100m}
        limits: {memory: 256Mi, cpu: 200m}
    - name: csi-resizer
      resource:
        requests: {memory: 128Mi, cpu: 100m}
        limits: {memory: 256Mi, cpu: 200m}
    - name: csi-snapshotter
      resource:
        requests: {memory: 128Mi, cpu: 100m}
        limits: {memory: 256Mi, cpu: 200m}
```

#### Discovery Daemon
```yaml
enableDiscoveryDaemon: true  # Auto-discover disks on all nodes

discoveryDaemonResources:
  requests:
    cpu: 50m
    memory: 64Mi
  limits:
    cpu: 200m
    memory: 128Mi
```

#### Monitoring
```yaml
monitoring:
  enabled: true  # Creates ServiceMonitor for Prometheus/VictoriaMetrics
```

#### Logging
```yaml
logLevel: INFO  # INFO (production) or DEBUG (troubleshooting)
```

### Cluster-Settings Variables

The following variables are used for per-cluster configuration:

```yaml
# Operator Configuration (apps cluster)
ROOK_CEPH_OPERATOR_VERSION: "v1.18.6"
ROOK_CEPH_OPERATOR_REPLICAS: "1"
ROOK_CEPH_LOG_LEVEL: "INFO"
ROOK_CEPH_CSI_ENABLE_RBD: "true"
ROOK_CEPH_CSI_ENABLE_CEPHFS: "true"
ROOK_CEPH_CSI_LOG_LEVEL: "3"

# Ceph Cluster Configuration
ROOK_CEPH_NAMESPACE: "rook-ceph"
ROOK_CEPH_CLUSTER_NAME: "rook-ceph"
ROOK_CEPH_IMAGE_TAG: "v19.2.3"  # Ceph Squid
ROOK_CEPH_MON_COUNT: "3"
ROOK_CEPH_OSD_DEVICE_CLASS: "ssd"
ROOK_CEPH_BLOCKPOOL_NAME: "rook-ceph-block"

# Storage Classes
BLOCK_SC: "rook-ceph-block"
```

---

## 🔍 Troubleshooting

### Operator Issues

#### Operator Pod Not Running

**Symptom**: Operator pod stuck in Pending, CrashLoopBackOff, or Error state

**Diagnosis**:
```bash
# Check operator pod status
kubectl get pod -n rook-ceph -l app=rook-ceph-operator

# Check pod events
kubectl describe pod -n rook-ceph -l app=rook-ceph-operator

# Check operator logs
kubectl logs -n rook-ceph deploy/rook-ceph-operator --tail=100

# Check HelmRelease status
kubectl get helmrelease -n rook-ceph rook-ceph-operator -o yaml
```

**Common Causes**:
1. ❌ **Insufficient resources**: Node doesn't have 128Mi memory available
2. ❌ **Image pull errors**: Registry unreachable or credentials missing
3. ❌ **CRD conflicts**: Old CRDs from previous Rook installation
4. ❌ **RBAC issues**: ServiceAccount missing or ClusterRole not bound

**Solutions**:
```bash
# Clean up old CRDs (if upgrading from old Rook)
kubectl delete crd cephclusters.ceph.rook.io
kubectl delete crd cephblockpools.ceph.rook.io
kubectl delete crd cephfilesystems.ceph.rook.io
# ... (delete all Rook CRDs)

# Reinstall HelmRelease
flux reconcile helmrelease -n rook-ceph rook-ceph-operator --with-source

# Check RBAC
kubectl get serviceaccount -n rook-ceph rook-ceph-system
kubectl get clusterrolebinding | grep rook
```

#### CRD Reconciliation Failures

**Symptom**: Alert `RookCephOperatorReconcileErrors` firing, CephCluster stuck in Progressing state

**Diagnosis**:
```bash
# Check operator logs for errors
kubectl logs -n rook-ceph deploy/rook-ceph-operator | grep -i error

# Check CephCluster status
kubectl get cephcluster -n rook-ceph -o yaml

# Check Ceph health
kubectl exec -n rook-ceph deploy/rook-ceph-tools -- ceph status
kubectl exec -n rook-ceph deploy/rook-ceph-tools -- ceph health detail
```

**Common Causes**:
1. ❌ **Invalid CephCluster CR**: Validation webhook failed to catch error
2. ❌ **Insufficient storage nodes**: Less than 3 nodes available for MON quorum
3. ❌ **Network issues**: Nodes can't communicate on Ceph network
4. ❌ **Disk issues**: Disks not clean, not detected, or failed

**Solutions**:
```bash
# Validate CephCluster CR
kubectl apply --dry-run=server -f cephcluster.yaml

# Check node readiness
kubectl get nodes -o wide

# Check discover daemon ConfigMap
kubectl get configmap -n rook-ceph rook-discover-devices -o yaml

# Force reconciliation
kubectl annotate cephcluster -n rook-ceph <cluster-name> rook.io/reconcile=$(date +%s)
```

#### Webhook Validation Failures

**Symptom**: CephCluster CR apply fails with "admission webhook denied request"

**Diagnosis**:
```bash
# Check ValidatingWebhookConfiguration
kubectl get validatingwebhookconfigurations | grep rook

# Check webhook service
kubectl get svc -n rook-ceph rook-ceph-webhook

# Check webhook pod
kubectl get pod -n rook-ceph -l app=rook-ceph-operator

# Test webhook endpoint
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl -k https://rook-ceph-webhook.rook-ceph.svc:9443/validate
```

**Common Causes**:
1. ❌ **Webhook service unreachable**: NetworkPolicy blocking webhook traffic
2. ❌ **Certificate issues**: TLS certificate expired or invalid
3. ❌ **Invalid CR**: CR violates validation rules

**Solutions**:
```bash
# Delete and recreate webhook config (operator will recreate)
kubectl delete validatingwebhookconfiguration rook-ceph-webhook

# Check NetworkPolicy allows webhook traffic
kubectl get networkpolicy -n rook-ceph

# Apply valid CephCluster CR
kubectl apply -f examples/cephcluster-minimal.yaml
```

### CSI Driver Issues

#### PVC Stuck in Pending

**Symptom**: PVC with `storageClassName: rook-ceph-block` remains Pending

**Diagnosis**:
```bash
# Check PVC status
kubectl describe pvc <pvc-name>

# Check CSI provisioner logs
kubectl logs -n rook-ceph deploy/csi-rbdplugin-provisioner -c csi-provisioner

# Check Ceph pool exists
kubectl exec -n rook-ceph deploy/rook-ceph-tools -- ceph osd lspools

# Check StorageClass exists
kubectl get storageclass rook-ceph-block
```

**Common Causes**:
1. ❌ **CSI provisioner not running**: Provisioner pods crashed or not scheduled
2. ❌ **CephBlockPool missing**: Pool referenced by StorageClass doesn't exist
3. ❌ **Insufficient Ceph capacity**: Cluster full or near full
4. ❌ **RBAC issues**: CSI provisioner can't create volumes

**Solutions**:
```bash
# Restart CSI provisioner
kubectl rollout restart deploy -n rook-ceph csi-rbdplugin-provisioner

# Check Ceph capacity
kubectl exec -n rook-ceph deploy/rook-ceph-tools -- ceph df

# Create CephBlockPool
kubectl apply -f cephblockpool.yaml

# Check CSI provisioner RBAC
kubectl get clusterrolebinding | grep rook-csi-rbd
```

#### Volume Mount Failures

**Symptom**: Pod stuck in ContainerCreating, events show mount errors

**Diagnosis**:
```bash
# Check pod events
kubectl describe pod <pod-name>

# Check CSI node plugin logs
kubectl logs -n rook-ceph ds/csi-rbdplugin -c csi-rbdplugin

# Check if RBD kernel module loaded
kubectl exec -n rook-ceph ds/csi-rbdplugin -c driver-registrar -- lsmod | grep rbd

# Check PV node affinity
kubectl get pv <pv-name> -o yaml | grep nodeAffinity
```

**Common Causes**:
1. ❌ **RBD kernel module missing**: Node doesn't have RBD module (rare on modern kernels)
2. ❌ **Network connectivity**: Node can't reach Ceph MONs
3. ❌ **PV on different node**: PV created on node-1, pod scheduled on node-2 (shouldn't happen with WaitForFirstConsumer)
4. ❌ **Ceph authentication**: Secret missing or invalid

**Solutions**:
```bash
# Load RBD module
kubectl exec -n rook-ceph ds/csi-rbdplugin -- modprobe rbd

# Test Ceph connectivity from node
kubectl exec -n rook-ceph deploy/rook-ceph-tools -- ceph mon dump

# Restart CSI node plugin
kubectl rollout restart ds -n rook-ceph csi-rbdplugin

# Check Ceph secrets
kubectl get secret -n rook-ceph rook-csi-rbd-node
```

### Discovery Daemon Issues

#### Disks Not Auto-Discovered

**Symptom**: Disks exist on node but not showing in `rook-discover-devices` ConfigMap

**Diagnosis**:
```bash
# Check discover daemon pods
kubectl get pod -n rook-ceph -l app=rook-discover

# Check daemon logs
kubectl logs -n rook-ceph ds/rook-discover --tail=100

# Check ConfigMap
kubectl get configmap -n rook-ceph rook-discover-devices -o yaml

# Check disks on node
kubectl debug node/<node-name> -it --image=busybox -- lsblk
```

**Common Causes**:
1. ❌ **Disk in use**: Disk has filesystem or partition table
2. ❌ **Disk too small**: Below minimum size threshold (10GB)
3. ❌ **Disk blacklisted**: Device name matches filter pattern
4. ❌ **Discovery daemon not running**: DaemonSet pods not scheduled

**Solutions**:
```bash
# Clean disk (see Node Preparation section)
sudo wipefs --all /dev/nvme0n1
sudo sgdisk --zap-all /dev/nvme0n1

# Restart discovery daemon
kubectl rollout restart ds -n rook-ceph rook-discover

# Check daemon filters
kubectl get helmrelease -n rook-ceph rook-ceph-operator -o yaml | grep -A10 discover

# Force rediscovery
kubectl delete pod -n rook-ceph -l app=rook-discover
```

---

## 📊 Monitoring and Alerting

### Metrics

The operator exposes Prometheus metrics on port 9090:

**Key Metrics**:
- `rook_ceph_operator_reconcile_errors_total`: CRD reconciliation failures
- `rook_ceph_operator_reconcile_duration_seconds`: CRD reconciliation latency
- `rook_ceph_operator_build_info`: Operator version info
- CSI provisioner metrics: Volume creation, deletion, expansion
- Discovery daemon metrics: Devices discovered, errors

**Metrics Endpoint**: `http://rook-ceph-operator:9090/metrics`

### Configured Alerts

| Alert Name | Severity | Trigger | For Duration | Description |
|-----------|----------|---------|--------------|-------------|
| **RookCephOperatorDown** | critical | `up{job="rook-ceph-operator"} == 0` | 5m | Operator pod unavailable |
| **RookCephOperatorReconcileErrors** | warning | `increase(rook_ceph_operator_reconcile_errors_total[5m]) > 0` | 10m | CRD reconciliation failures |
| **RookCephCRDMissing** | critical | `absent(apiserver_requested_deprecated_apis{resource="cephclusters.ceph.rook.io"})` | 5m | CRDs not registered |
| **RookCephDiscoveryDaemonDown** | warning | `up{job="rook-ceph-discovery"} == 0` | 10m | Discovery daemon issues |
| **RookCephOperatorCrashLooping** | warning | `rate(kube_pod_container_status_restarts_total{namespace="rook-ceph",pod=~"rook-ceph-operator.*"}[15m]) > 0` | 5m | Operator restarting frequently |
| **RookCephOperatorHighMemory** | warning | Memory usage >80% of limit | 10m | Operator memory pressure |

### Grafana Dashboards

Rook-Ceph dashboards available:
- **Rook-Ceph Cluster Overview**: Grafana dashboard 2842:18 (cluster health, not operator)
- **Custom operator metrics**: Via VictoriaMetrics queries

---

## 🔄 Upgrade Procedures

### Operator Upgrade Path

Rook and Ceph upgrades are **separate** processes:

#### 1. Upgrade Rook Operator

**Procedure**:
```bash
# Update HelmRelease version
# Edit kubernetes/bases/rook-ceph-operator/operator/helmrelease.yaml
#   spec.chart.spec.version: v1.18.6 → v1.19.0

# Commit and push
git add kubernetes/bases/rook-ceph-operator/operator/helmrelease.yaml
git commit -m "chore(storage): upgrade Rook operator v1.18.6 → v1.19.0"
git push

# Flux will reconcile automatically (or force)
flux reconcile helmrelease -n rook-ceph rook-ceph-operator --with-source

# Verify operator upgraded
kubectl get deployment -n rook-ceph rook-ceph-operator -o jsonpath='{.spec.template.spec.containers[0].image}'
```

**Compatibility**:
- Rook v1.18.x supports Ceph v18 (Reef) and v19 (Squid)
- Can upgrade operator without upgrading Ceph

#### 2. Upgrade Ceph Version

**Procedure** (after operator upgrade):
```bash
# Update CephCluster CR
# Edit kubernetes/infrastructure/storage/rook-ceph/cluster/cephcluster.yaml
#   spec.cephVersion.image: v19.2.3 → v19.2.4

# Commit and push
git add kubernetes/infrastructure/storage/rook-ceph/cluster/cephcluster.yaml
git commit -m "chore(storage): upgrade Ceph v19.2.3 → v19.2.4"
git push

# Operator will perform rolling upgrade of Ceph daemons
# Monitor upgrade progress
kubectl exec -n rook-ceph deploy/rook-ceph-tools -- ceph status
kubectl get cephcluster -n rook-ceph -o yaml | grep -A5 phase
```

**Upgrade Order** (operator handles automatically):
1. MON (monitors) - one at a time, wait for quorum
2. MGR (managers) - one at a time, wait for active mgr
3. OSD (storage daemons) - one at a time per failure domain
4. MDS (metadata servers) - if using CephFS
5. RGW (object gateways) - if using object storage

**Safety Checks**:
- ✅ Cluster must be HEALTH_OK before upgrade
- ✅ No backfilling or recovery operations in progress
- ✅ All PGs active+clean
- ✅ No OSDs down

---

## 🌍 Multi-Cluster Deployment

### Architecture

The Rook-Ceph operator is **shared across both infra and apps clusters**:

```
kubernetes/bases/rook-ceph-operator/operator/  # Shared operator manifests
├── helmrelease.yaml
├── prometheusrule.yaml
├── podmonitor.yaml
└── kustomization.yaml

kubernetes/infrastructure/storage/rook-ceph/operator/ks.yaml
  → Points to: ./kubernetes/bases/rook-ceph-operator/operator

kubernetes/clusters/{infra,apps}/infrastructure.yaml
  → Both reference: ./kubernetes/infrastructure
    → storage/rook-ceph/operator/ks.yaml
```

### Cluster Isolation

Each cluster has a **separate CephCluster CR** with isolated storage:

**Infra Cluster**:
- CephCluster: `rook-ceph` (namespace: `rook-ceph`)
- Storage pools: `rook-ceph-block` (for databases, observability)
- Use cases: Platform services (PostgreSQL, VictoriaMetrics, Grafana)

**Apps Cluster**:
- CephCluster: `rook-ceph` (namespace: `rook-ceph`)
- Storage pools: `rook-ceph-block` (for application workloads)
- Use cases: GitLab repositories, Harbor registry, Mattermost file storage

### No Cross-Cluster Sharing

- ❌ **No Ceph cluster federation** between infra and apps
- ❌ **No cross-cluster PV access** (each cluster is independent)
- ✅ **Operator pattern is shared** (DRY principle)
- ✅ **Configuration is consistent** (same chart version, values)

---

## 📊 Comparison: Rook-Ceph vs OpenEBS LocalPV

| Feature | Rook-Ceph | OpenEBS LocalPV |
|---------|-----------|-----------------|
| **Storage Type** | Distributed, replicated | Node-local, no replication |
| **Access Modes** | RWO, ROX, RWX | RWO only |
| **Latency** | 5-10ms | <1ms |
| **Throughput** | 300MB/s | 3GB/s |
| **IOPS** | 50K | 500K |
| **Data Durability** | High (3x replication) | Low (single node) |
| **Availability** | Multi-node failover | Single-node failure domain |
| **Complexity** | High (MON, MGR, OSD pods) | Low (single provisioner) |
| **Resource Overhead** | Significant (MON, MGR, OSD) | Minimal (provisioner DaemonSet) |
| **Use Case** | HA databases, shared storage | Performance, ephemeral data |
| **Snapshots** | ✅ Yes (CSI) | ✅ Yes (CSI) |
| **Cloning** | ✅ Yes | ✅ Yes |
| **Volume Expansion** | ✅ Yes | ✅ Yes |
| **Object Storage** | ✅ Yes (RGW S3) | ❌ No |
| **Minimum Nodes** | 3 (quorum) | 1 |

### Decision Matrix

**Use Rook-Ceph when**:
- ✅ Data durability critical (replicated storage)
- ✅ Multi-pod shared access needed (RWX volumes)
- ✅ Object storage needed (S3-compatible)
- ✅ HA databases with auto-failover
- ✅ Willing to accept latency/IOPS trade-off

**Use OpenEBS LocalPV when**:
- ✅ Performance is top priority (low latency, high IOPS)
- ✅ Single-replica workloads
- ✅ Ephemeral or cache storage
- ✅ Cost-sensitive (minimize overhead)
- ✅ Simple operations preferred

---

## 🔒 Security

### Pod Security Admission

**Namespace**: `rook-ceph`
- Enforcement level: **Privileged** (required for host access)
- Audit level: Privileged
- Warn level: Privileged

**Why Privileged**:
- Operator needs cluster-admin access for CRD management
- OSDs need host network, host PID, privileged containers
- Discovery daemon needs access to `/dev` for disk scanning
- CSI drivers need privileged access for volume mounting

### Network Policies

Applied baseline policies:
- ✅ Default deny all ingress/egress
- ✅ Allow DNS resolution (kube-dns)
- ✅ Allow Kubernetes API access
- ✅ Allow internal pod-to-pod communication

### RBAC

The operator creates multiple ServiceAccounts with least-privilege permissions:

| ServiceAccount | ClusterRole | Purpose |
|----------------|-------------|---------|
| `rook-ceph-system` | `rook-ceph-operator` | Operator permissions (CRD management) |
| `rook-ceph-osd` | `rook-ceph-osd` | OSD daemon permissions |
| `rook-ceph-mgr` | `rook-ceph-mgr` | MGR daemon permissions |
| `rook-csi-rbd-provisioner-sa` | `rook-csi-rbd-provisioner-clusterrole` | CSI RBD provisioner |
| `rook-csi-cephfs-provisioner-sa` | `rook-csi-cephfs-provisioner-clusterrole` | CSI CephFS provisioner |

---

## 📚 Additional Resources

- [Rook-Ceph Documentation](https://rook.io/docs/rook/latest-release/)
- [Ceph Documentation](https://docs.ceph.com/en/latest/)
- [Rook GitHub Repository](https://github.com/rook/rook)
- [Rook Helm Charts](https://charts.rook.io/release)
- [Story 15: STORY-STO-ROOK-CEPH-OPERATOR](../../../docs/stories/STORY-STO-ROOK-CEPH-OPERATOR.md) (infra cluster)
- [Story 30: STORY-STO-APPS-ROOK-CEPH-OPERATOR](../../../docs/stories/STORY-STO-APPS-ROOK-CEPH-OPERATOR.md) (apps cluster)
- [Story 16: STORY-STO-ROOK-CEPH-CLUSTER](../../../docs/stories/STORY-STO-ROOK-CEPH-CLUSTER.md) (CephCluster CR)

---

**Maintained by**: Platform Engineering
**Last Updated**: 2025-11-08 (Story 30)
**Status**: Production-Ready (Manifests-First)
**Chart Version**: v1.18.6 (Latest Stable)
