# OpenEBS LocalPV Storage

OpenEBS LocalPV provides high-performance, node-local storage for Kubernetes workloads using NVMe-backed HostPath volumes. This implementation deploys to both **infra** and **apps** clusters via shared infrastructure manifests.

## 📊 Overview

**Chart Version**: 4.3.3 (August 2024)
**Storage Class**: `openebs-local-nvme`
**Base Path**: `/var/mnt/openebs`
**Provisioner**: `openebs.io/local`
**Binding Mode**: `WaitForFirstConsumer` (topology-aware)
**Reclaim Policy**: `Delete`
**Volume Expansion**: ✅ Enabled

## 🏗️ Architecture

### Components

1. **LocalPV Provisioner DaemonSet**
   - Runs on all nodes
   - Watches for PVCs with `openebs.io/local` provisioner
   - Creates PVs using HostPath volumes on the node where pod is scheduled
   - Resource limits: 50m CPU / 64Mi memory (requests), 200m CPU / 128Mi memory (limits)
   - No data replication or distribution

2. **StorageClass** (`openebs-local-nvme`)
   - WaitForFirstConsumer: Delays PV creation until pod is scheduled
   - Enables topology-aware scheduling (pod and PV on same node)
   - Critical for node-local storage performance
   - Supports online volume expansion

3. **HostPath Volumes**
   - Base directory: `/var/mnt/openebs` (on each node)
   - Per-PV directory: `/var/mnt/openebs/<pv-name>`
   - Permissions: 755 (directory), 644 (files)
   - Ownership: Matches pod security context

### How It Works

```
┌─────────────────────────────────────────────────────────┐
│ 1. User creates PVC with StorageClass: openebs-local-nvme │
└─────────────────────┬───────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────┐
│ 2. PVC stays PENDING (WaitForFirstConsumer)             │
└─────────────────────┬───────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────┐
│ 3. User creates Pod referencing PVC                     │
└─────────────────────┬───────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────┐
│ 4. Scheduler places Pod on Node (e.g., node-2)          │
└─────────────────────┬───────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────┐
│ 5. LocalPV Provisioner creates PV on node-2             │
│    at /var/mnt/openebs/pvc-xyz-abc                      │
└─────────────────────┬───────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────┐
│ 6. PVC binds to PV, Pod mounts volume                   │
└─────────────────────────────────────────────────────────┘
```

## ✅ Use Cases (When to Use OpenEBS LocalPV)

### Ideal For:
- ✅ **High-performance databases**: PostgreSQL, MySQL (CloudNativePG on both clusters)
- ✅ **In-memory caches**: Redis, Memcached, DragonflyDB
- ✅ **CI/CD workloads**: Build artifacts, test data
- ✅ **Logs and metrics**: Fluent Bit buffers, VictoriaMetrics cache
- ✅ **Temporary storage**: Job results, intermediate data
- ✅ **Single-replica StatefulSets** with external backups

### ❌ Not Ideal For:
- ❌ **Multi-replica StatefulSets** needing shared storage (use Rook-Ceph)
- ❌ **Data durability across node failures** (single-node failure domain)
- ❌ **Cross-node pod migration** (data stays on original node)
- ❌ **ReadWriteMany (RWX)** volumes (LocalPV is RWO only)
- ❌ **Data requiring built-in replication** (use Rook-Ceph)

## 🚀 Usage

### Creating a PVC

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-app-data
  namespace: my-namespace
spec:
  storageClassName: openebs-local-nvme
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
```

**Important**: PVC will remain in `Pending` state until a pod is created that references it (WaitForFirstConsumer behavior).

### Creating a Pod with PVC

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-app
  namespace: my-namespace
spec:
  containers:
    - name: app
      image: my-app:latest
      volumeMounts:
        - name: data
          mountPath: /data
  volumes:
    - name: data
      persistentVolumeClaim:
        claimName: my-app-data
```

### Expanding a Volume

OpenEBS LocalPV supports online volume expansion:

```bash
# Edit PVC to increase size
kubectl patch pvc my-app-data -p '{"spec":{"resources":{"requests":{"storage":"20Gi"}}}}'

# Filesystem expansion happens automatically (ext4/xfs)
# No pod restart required
```

## 🛠️ Node Preparation

### Talos Linux Nodes

OpenEBS requires the base path to exist on each node. For Talos Linux:

1. **Base path already configured**: `/var/mnt/openebs`
   - `/var` is persistent in Talos Linux
   - Compatible with immutable OS architecture

2. **Optional: Dedicated NVMe mount**:
   ```yaml
   # In Talos machine config
   machine:
     disks:
       - device: /dev/nvme0n1
         partitions:
           - mountpoint: /var/mnt/openebs
   ```

3. **Permissions**: Automatically managed by Talos (no manual setup required)

### Generic Kubernetes Nodes

For non-Talos nodes:

```bash
# On each node
sudo mkdir -p /var/mnt/openebs
sudo chmod 755 /var/mnt/openebs

# Optional: Mount dedicated disk
sudo mkfs.ext4 /dev/nvme0n1
sudo mount /dev/nvme0n1 /var/mnt/openebs
echo "/dev/nvme0n1 /var/mnt/openebs ext4 defaults 0 2" | sudo tee -a /etc/fstab
```

### Optional: Label Storage Nodes

```bash
kubectl label node <node-name> openebs.io/storage-node=true
```

## 📈 Performance Characteristics

### Latency
- **Read/Write latency**: ~100µs (underlying NVMe disk latency)
- **No network overhead**: Direct local filesystem access
- **No replication overhead**: Single-node storage
- **Best case**: 1-2ms for 4K random writes

### Throughput
- **Sequential read/write**: ~3GB/s (NVMe throughput)
- **No network bottleneck**: Local I/O only
- **Best case**: Multi-GB/s for large sequential I/O

### IOPS
- **Random IOPS**: ~500K (NVMe IOPS)
- **No coordination overhead**: Direct disk access
- **Best case**: Hundreds of thousands of IOPS

### Comparison: OpenEBS LocalPV vs Rook-Ceph

| Metric | OpenEBS LocalPV | Rook-Ceph |
|--------|-----------------|-----------|
| **Latency** | <1ms | 5-10ms |
| **Throughput** | 3GB/s | 300MB/s |
| **IOPS** | 500K | 50K |
| **Availability** | Single-node | Multi-node |
| **Data Durability** | Low | High |
| **Complexity** | Low | High |
| **Resource Overhead** | Minimal | Significant |
| **Use Case** | Performance | Durability |

**Decision Matrix**:
- Use **OpenEBS LocalPV** when: Performance > Durability
- Use **Rook-Ceph** when: Durability > Performance

## 🔍 Troubleshooting

### PVC Stuck in Pending

**Symptom**: PVC shows `Pending` status indefinitely

**Diagnosis**:
```bash
# Check if pod created
kubectl get pod -A | grep <pvc-name>

# Check provisioner logs
kubectl logs -n openebs-system ds/openebs-localpv-provisioner

# Verify base path exists
kubectl debug node/<node> -- ls -la /var/mnt/openebs
```

**Common Causes**:
1. ✅ **Expected behavior**: No pod created yet (WaitForFirstConsumer)
2. ❌ Base path doesn't exist on node
3. ❌ Node has insufficient disk space
4. ❌ Provisioner pod not running

### PV Creation Failed

**Symptom**: Provisioner logs show creation errors

**Diagnosis**:
```bash
# Check provisioner logs for errors
kubectl logs -n openebs-system ds/openebs-localpv-provisioner | grep -i error

# Verify base path permissions
kubectl debug node/<node> -- ls -la /var/mnt/openebs

# Check node disk space
kubectl debug node/<node> -- df -h /var/mnt/openebs
```

**Common Causes**:
1. ❌ Insufficient disk space on node
2. ❌ Permission denied on base path
3. ❌ Filesystem errors
4. ❌ Node selector mismatch (if configured)

### Pod Cannot Mount Volume

**Symptom**: Pod stuck in `ContainerCreating`, events show mount errors

**Diagnosis**:
```bash
# Check pod events
kubectl describe pod <pod>

# Verify PVC is Bound
kubectl get pvc <pvc>

# Check PV node affinity
kubectl get pv <pv> -o yaml | grep -A10 nodeAffinity
```

**Common Causes**:
1. ❌ PVC not bound (still Pending)
2. ❌ PV node affinity doesn't match pod's scheduled node
3. ❌ Kubelet errors on node
4. ❌ SELinux/AppArmor blocking mount

### Performance Issues

**Symptom**: Slow I/O performance, high latency

**Diagnosis**:
```bash
# Check underlying disk performance (run fio benchmark)
# See Story 29 for fio test commands

# Verify filesystem type
kubectl debug node/<node> -- df -T /var/mnt/openebs

# Check for I/O contention
kubectl debug node/<node> -- iostat -x 5
```

**Common Causes**:
1. ❌ I/O contention from other workloads on same node
2. ❌ Degraded disk (SMART errors)
3. ❌ Filesystem fragmentation
4. ❌ Application I/O pattern inefficient

## 💾 Backup and Migration Strategies

### Application-Level Backups (Recommended)

**PostgreSQL (CloudNativePG)**:
```bash
# CNPG handles automated backups to S3
# See: kubernetes/workloads/platform/databases/cloudnative-pg/
```

**MySQL**:
```bash
mysqldump --all-databases > backup.sql
# Upload to S3 or object storage
```

**Redis/DragonflyDB**:
```bash
# RDB/AOF snapshots automatically saved
# Configure snapshot schedule in DragonflyDB CR
```

### PVC Cloning

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: cloned-pvc
spec:
  storageClassName: openebs-local-nvme
  dataSource:
    name: source-pvc
    kind: PersistentVolumeClaim
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
```

**Limitation**: Clone created on same node as source (node affinity inherited).

### Velero with Restic/Kopia

For filesystem-level backups:

```bash
# Install Velero with restic/kopia
# Configure backup schedule
velero backup create openebs-backup --include-namespaces my-namespace

# Restore
velero restore create --from-backup openebs-backup
```

### Migration to Different Node

When pod needs to move to a different node:

```bash
# 1. Scale down workload
kubectl scale statefulset <name> --replicas=0

# 2. Create new PVC on target node (or use Velero restore)
# 3. Copy data via debug pod or kubectl cp
kubectl debug node/<target-node> -- rsync -av /var/mnt/openebs/<old-pv>/ /var/mnt/openebs/<new-pv>/

# 4. Update workload to use new PVC
# 5. Scale up workload
kubectl scale statefulset <name> --replicas=1
```

### Disaster Recovery

**Strategy 1**: Application-level replication
- PostgreSQL: Synchronous replication (CloudNativePG with minSyncReplicas: 1)
- DragonflyDB: Master-replica replication across nodes

**Strategy 2**: External backups
- Automated backups to S3/MinIO
- Velero scheduled backups
- Application-specific backup tools (pg_dump, mysqldump)

**Strategy 3**: Use Rook-Ceph for critical data
- Multi-node replication
- Built-in snapshots
- Self-healing storage cluster

## 📊 Monitoring and Alerting

### Available Metrics

- `openebs_volume_provisioning_duration_seconds`: PV creation time
- `openebs_volume_provisioning_failures_total`: Provisioning failures
- `openebs_actual_used`: Volume usage (bytes)
- `openebs_size_of_volume`: Volume capacity (bytes)
- `node_filesystem_avail_bytes{mountpoint="/var/mnt/openebs"}`: Node storage available

### Configured Alerts

1. **OpenEBSProvisionerDown** (Warning)
   - No provisioner pods ready for 5 minutes
   - Impact: Cannot provision new PVCs

2. **OpenEBSPVCBindingFailed** (Warning)
   - PVC stuck in Pending state for >5 minutes
   - Impact: Applications cannot start

3. **OpenEBSHighDiskUsage** (Warning)
   - Volume usage >85% for 10 minutes
   - Action: Expand volume or clean up data

4. **OpenEBSStorageCapacityWarning** (Warning)
   - Node storage usage >80% for 10 minutes
   - Action: Add capacity or clean up unused PVs

5. **OpenEBSStorageCapacityCritical** (Critical)
   - Node storage usage >90% for 5 minutes
   - Action: Immediate capacity expansion required

6. **OpenEBSHighMemoryUsage** (Warning)
   - Provisioner memory usage >80% of limit for 10 minutes
   - Action: Review provisioner resource limits

### Grafana Dashboards

- **Node Filesystem Usage**: Monitor `/var/mnt/openebs` capacity
- **PV Usage**: Track per-volume disk usage
- **Provisioner Health**: DaemonSet status and resource usage

## 🔒 Security

### Pod Security Admission

**Namespace**: `openebs-system`
- Enforcement level: **Privileged** (required for HostPath volumes)
- Audit level: Privileged
- Warn level: Privileged

**Why Privileged**:
- HostPath volumes require privileged access
- Provisioner needs to create directories on host filesystem
- Cannot run with restricted PSA

### Network Policies

Applied baseline policies:
- ✅ Default deny all ingress/egress
- ✅ Allow DNS resolution (kube-dns)
- ✅ Allow Kubernetes API access
- ✅ Allow internal pod-to-pod communication

## 🔄 Multi-Cluster Deployment

This OpenEBS configuration deploys to **both infra and apps clusters** via shared infrastructure:

```
kubernetes/infrastructure/storage/openebs/
├── app/                      # Shared manifests
│   ├── helmrelease.yaml      # Chart 4.3.3, resource limits
│   ├── storageclass.yaml     # WaitForFirstConsumer, expansion enabled
│   ├── prometheusrule.yaml   # 6 alerts
│   ├── pdb.yaml              # maxUnavailable: 1
│   └── kustomization.yaml
└── ks.yaml                   # Flux Kustomization

# Both clusters reference this path
kubernetes/clusters/infra/infrastructure.yaml  → ./kubernetes/infrastructure
kubernetes/clusters/apps/infrastructure.yaml   → ./kubernetes/infrastructure
```

**Cluster-specific configuration** via `cluster-settings.yaml`:
- `OPENEBS_LOCAL_SC`: "openebs-local-nvme" (both clusters)
- `OPENEBS_BASEPATH`: "/var/mnt/openebs" (both clusters)

## 📚 Additional Resources

- [OpenEBS Documentation](https://openebs.io/docs)
- [LocalPV Hostpath Guide](https://openebs.io/docs/user-guides/localpv-hostpath)
- [Story 14: STORY-STO-OPENEBS-BASE](../../../docs/stories/STORY-STO-OPENEBS-BASE.md)
- [Story 29: STORY-STO-APPS-OPENEBS-BASE](../../../docs/stories/STORY-STO-APPS-OPENEBS-BASE.md)

## 🔄 Upgrade Notes

### v4.3.2 → v4.3.3 (Story 29)

**Changes**:
- ✅ Chart version upgraded to 4.3.3 (latest stable)
- ✅ Added resource limits: 50m/64Mi → 200m/128Mi
- ✅ Added PodDisruptionBudget (maxUnavailable: 1)
- ✅ Enabled volume expansion in StorageClass
- ✅ Added 3 new PrometheusRules (6 total alerts)
- ✅ Created comprehensive README

**Impact**:
- **Both infra and apps clusters** receive enhancements
- No configuration changes required
- Existing PVCs unaffected
- Deployment and validation deferred to Story 45

---

**Maintained by**: Platform Engineering
**Last Updated**: 2025-11-08 (Story 29)
**Status**: Production-Ready (Manifests-First)
