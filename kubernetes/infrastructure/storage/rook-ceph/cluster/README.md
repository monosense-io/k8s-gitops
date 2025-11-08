# Rook-Ceph Cluster Configuration

This directory contains the Rook-Ceph cluster configuration for deploying a distributed, highly-available storage cluster on both **infra** and **apps** clusters.

## 📋 Overview

**Rook-Ceph** provides distributed storage for Kubernetes with:
- **High Availability**: Survives single-node failures with automatic recovery
- **Data Durability**: 3x replication across nodes
- **Dynamic Provisioning**: RBD (block) and CephFS (shared filesystem) StorageClasses
- **Local NVMe Performance**: Direct access to node-local NVMe devices

### Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     Rook-Ceph Cluster (3 nodes)                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Node 1              Node 2              Node 3                │
│  ┌─────────┐        ┌─────────┐        ┌─────────┐            │
│  │ MON-a   │        │ MON-b   │        │ MON-c   │  ◄─ Quorum │
│  └─────────┘        └─────────┘        └─────────┘            │
│                                                                 │
│  ┌─────────┐        ┌─────────┐                                │
│  │ MGR-a   │ ◄─     │ MGR-b   │                  ◄─ Active/    │
│  │ (active)│   │    │ (standby)│                    Standby    │
│  └─────────┘   │    └─────────┘                                │
│                │                                                │
│  ┌─────────┐  │    ┌─────────┐        ┌─────────┐            │
│  │ OSD.0   │  │    │ OSD.1   │        │ OSD.2   │  ◄─ 3x     │
│  │ (1TB)   │  │    │ (1TB)   │        │ (1TB)   │     Replica │
│  └─────────┘  │    └─────────┘        └─────────┘            │
│      │        │          │                  │                  │
│      │        │          │                  │                  │
│  [NVMe SSD]  Dashboard [NVMe SSD]      [NVMe SSD]            │
│                Metrics                                          │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘

                           │
                           ▼
                ┌──────────────────────┐
                │  CephBlockPool       │
                │  (rook-ceph-block)   │
                │  - 3 replicas        │
                │  - Host failure      │
                │    domain            │
                └──────────────────────┘
                           │
                           ▼
                ┌──────────────────────┐
                │  StorageClass        │
                │  (rook-ceph-block)   │
                │  - RBD CSI driver    │
                │  - Dynamic PVCs      │
                └──────────────────────┘
```

## 🎯 Components

### Monitor (MON)
- **Count**: 3 (one per node)
- **Purpose**: Maintains cluster state, quorum voting, cluster maps (CRUSH, OSD, PG)
- **Quorum**: Requires majority (2 of 3) to operate
- **High Availability**: Tolerates 1 MON failure
- **Resources**: 500m CPU / 1Gi RAM (requests), 2 CPU / 2Gi RAM (limits)
- **Priority**: `system-node-critical`

### Manager (MGR)
- **Count**: 2 (active-standby)
- **Purpose**: Cluster operations, dashboard, Prometheus metrics
- **Active**: Only 1 MGR active at a time
- **Dashboard**: Web UI at `https://<mgr-service>:8443`
- **Resources**: 500m CPU / 512Mi RAM (requests), 1 CPU / 1Gi RAM (limits)
- **Priority**: `system-cluster-critical`

### Object Storage Daemon (OSD)
- **Count**: 3 (one per node, one per disk)
- **Purpose**: Stores actual data on NVMe devices
- **Replication**: Data replicated 3x across nodes
- **BlueStore**: Direct block device access with RocksDB metadata (10GB)
- **Resources**: 1 CPU / 2Gi RAM (requests), 2 CPU / 4Gi RAM (limits)
- **Priority**: `system-node-critical`

## 💾 Storage Configuration

### Cluster-Specific Device Allocation

**Infra Cluster** (3 nodes):
- **infra-01**: `/dev/disk/by-id/nvme-eui.6479a7726a304b94` (1TB PNY CS1031)
- **infra-02**: `/dev/disk/by-id/nvme-eui.6479a77cda30650b` (1TB PNY CS2241)
- **infra-03**: `/dev/disk/by-id/nvme-eui.6479a7726a3054e5` (1TB PNY CS1031)

**Apps Cluster** (3 nodes):
- **apps-01**: `/dev/disk/by-id/nvme-TEAM_TM8FP6001T_TPBF2312120030301178` (1TB TEAM)
- **apps-02**: `/dev/disk/by-id/nvme-TEAM_TM8FP6001T_TPBF2312120030301595` (1TB TEAM)
- **apps-03**: `/dev/disk/by-id/nvme-eui.6479a7726a304bbf` (1TB PNY CS1031)

**Device Selection Strategy:**
- ✅ Use `/dev/disk/by-id/` paths (stable across reboots, unlike `/dev/sdX`)
- ✅ Prefer EUI identifiers when available (e.g., `nvme-eui.*`)
- ✅ Use model/serial when EUI not available (e.g., `nvme-TEAM_TM8FP6001T_*`)
- ✅ Devices must be clean (no partitions, no filesystems)

### Node Disk Layout

Each node has two NVMe drives:
```
┌────────────────────────────────────────┐
│ Node (apps-01, apps-02, apps-03)       │
├────────────────────────────────────────┤
│                                        │
│  📦 512GB NVMe (TEAM TM8FP6512G)      │
│     └─ OpenEBS LocalPV                │
│        (/var/mnt/openebs)             │
│                                        │
│  📦 1TB NVMe (TEAM/PNY)               │
│     └─ Rook-Ceph OSD                  │
│        (Ceph BlueStore)               │
│                                        │
└────────────────────────────────────────┘
```

## 📊 Capacity Planning

### Raw vs Usable Capacity

**Calculation:**
```
Raw capacity = nodes × disk size
Usable capacity = raw capacity ÷ replication factor
Overhead = ~10% for Ceph metadata

Infra Cluster:
- 3 nodes × 1TB NVMe = 3TB raw
- Replication factor: 3
- Usable: 3TB ÷ 3 = 1TB
- After overhead: ~900GB usable

Apps Cluster:
- 3 nodes × 1TB NVMe = 3TB raw
- Replication factor: 3
- Usable: 3TB ÷ 3 = 1TB
- After overhead: ~900GB usable
```

### Replication Strategy

**CephBlockPool Configuration:**
- **Replicas**: 3 (each data object stored on 3 different OSDs)
- **Failure Domain**: `host` (replicas distributed across nodes)
- **Tolerance**: Survives 1 node failure (2 of 3 replicas available)
- **CRUSH Rule**: Ensures replicas never on same node

**Trade-offs:**
- 3x replication = 1/3 usable capacity
- Better durability than RAID (each object independently replicated)
- Automatic recovery when nodes/disks fail

## 🔧 Toolbox Usage

The **Ceph Toolbox** provides CLI access for diagnostics and management.

### Access Toolbox

```bash
# Connect to toolbox pod
kubectl exec -n rook-ceph -it deploy/rook-ceph-tools -- bash

# Now inside toolbox shell:
ceph -s    # Cluster status
```

### Essential Commands

**Cluster Health:**
```bash
ceph -s                    # Overall cluster status
ceph health detail         # Detailed health information
ceph versions              # Component versions
```

**Monitor Status:**
```bash
ceph mon stat              # MON quorum status
ceph quorum_status -f json-pretty  # Detailed quorum info
```

**Manager Status:**
```bash
ceph mgr stat              # Active/standby MGRs
ceph mgr services          # Dashboard and metrics URLs
```

**OSD Status:**
```bash
ceph osd tree              # OSD topology (by host)
ceph osd status            # OSD up/down status
ceph osd df                # OSD disk usage
ceph osd perf              # OSD performance metrics
```

**Placement Group (PG) Status:**
```bash
ceph pg stat               # PG summary
ceph pg dump               # Detailed PG information
ceph pg ls                 # List all PGs
```

**Storage Usage:**
```bash
ceph df                    # Cluster storage usage
rados df                   # Pool storage usage
ceph osd pool ls detail    # Pool details
```

**Performance:**
```bash
ceph osd perf              # OSD latency
ceph -w                    # Watch cluster status (live)
```

## 🔍 Troubleshooting

### Cluster Not HEALTH_OK

**Check detailed health:**
```bash
ceph health detail
```

**Common causes:**
- **PGs degraded**: Rebalancing in progress (wait)
- **OSDs down**: Check node/disk status
- **MON clock skew**: NTP synchronization issues
- **Slow ops**: Performance bottleneck (check OSD perf)

**Resolution:**
```bash
# Check OSD status
ceph osd tree

# Check PG status
ceph pg stat

# Monitor recovery
ceph -w
```

### OSD Not Starting

**Check operator logs:**
```bash
kubectl logs -n rook-ceph deploy/rook-ceph-operator | grep -i osd
```

**Common causes:**
1. **Device not clean**: Device has existing filesystem/partitions
   ```bash
   # Verify device is clean
   talosctl -n <node-ip> ls -la /dev/disk/by-id/nvme-*

   # If device needs cleaning (DESTRUCTIVE):
   # This should be done via Talos machine config, not manually
   ```

2. **Device path incorrect**: Wrong `/dev/disk/by-id/` path
   ```bash
   # List available devices
   talosctl -n <node-ip> ls /dev/disk/by-id/ | grep nvme
   ```

3. **Disk already in use**: LVM, RAID, or other usage
   ```bash
   # Check disk usage
   talosctl -n <node-ip> get disks
   ```

### MON Quorum Lost

**Check MON pods:**
```bash
kubectl get pod -n rook-ceph -l app=rook-ceph-mon
kubectl logs -n rook-ceph -l app=rook-ceph-mon --tail=100
```

**Common causes:**
- **Network partition**: Nodes can't communicate
- **Multiple node failures**: >1 node down (need 2 of 3)
- **Clock skew**: Time difference >50ms between nodes

**Recovery:**
```bash
# Check node connectivity
kubectl get nodes

# Check time sync
talosctl -n <node-ip> time

# If quorum permanently lost, may need to redeploy cluster
```

### PG Degraded

**Check PG status:**
```bash
ceph pg stat
ceph pg dump | grep degraded
```

**Common causes:**
- **OSD down**: Check `ceph osd tree`
- **Rebalancing**: Wait for completion
- **Insufficient OSDs**: Need 3 OSDs for 3 replicas

**Force scrub if inconsistent:**
```bash
ceph pg scrub <pg-id>
```

### Slow Operations

**Identify slow ops:**
```bash
ceph -s | grep slow
ceph osd perf
```

**Common causes:**
- **Disk performance**: NVMe IOPS exhausted
- **Network latency**: Host networking issues
- **OSD overload**: Too much data on single OSD

**Monitor latency:**
```bash
ceph osd perf
# Look for apply_latency and commit_latency

# Check OSD resource usage
kubectl top pod -n rook-ceph -l app=rook-ceph-osd
```

## 📈 Monitoring

### Prometheus Metrics

**Ceph MGR exposes metrics on port 9283:**
```bash
# Port forward to access metrics
kubectl port-forward -n rook-ceph svc/rook-ceph-mgr 9283:9283

# Query metrics
curl http://localhost:9283/metrics | grep ceph_
```

**Key Metrics:**
- `ceph_health_status` - Overall cluster health (0=OK, 1=WARN, 2=ERR)
- `ceph_mon_quorum_status` - MON quorum status
- `ceph_osd_up` - Number of OSDs up
- `ceph_osd_in` - Number of OSDs in cluster
- `ceph_pg_degraded_total` - Degraded PGs (data at risk)
- `ceph_cluster_total_bytes` - Total capacity
- `ceph_cluster_total_used_bytes` - Used capacity

### Critical Alerts

**Configured in PrometheusRule:**
1. **CephClusterNotHealthy** - Cluster not HEALTH_OK for 5m
2. **CephMonQuorumAtRisk** - <2 MONs in quorum for 5m
3. **CephOSDDown** - OSD down for 5m
4. **CephPGDegraded** - >10% PGs degraded for 10m
5. **CephStorageNearFull** - >80% storage used
6. **CephSlowOps** - >10 slow ops for 5m

## 🔄 Scaling

### Adding Nodes

1. **Update CephCluster CR** with new node:
   ```yaml
   nodes:
     - name: "apps-04"  # New node
       devices:
         - name: "/dev/disk/by-id/nvme-..."
           config:
             deviceClass: ssd
   ```

2. **Apply changes** (GitOps - commit to git, Flux reconciles)

3. **Monitor OSD creation:**
   ```bash
   kubectl get pod -n rook-ceph -l app=rook-ceph-osd -w
   ceph osd tree  # Verify new OSD added
   ```

4. **Ceph automatically rebalances** data across all OSDs

### Adding OSDs to Existing Nodes

1. **Update node device list** in CephCluster CR
2. **Apply changes** via GitOps
3. **Monitor OSD creation** and rebalancing

**⚠️ Note:** Rebalancing can cause slow ops. Monitor cluster during scaling.

## 🚀 Upgrade Procedures

### Operator Upgrade

**Rook operator upgrades are managed via HelmRelease:**
```yaml
# kubernetes/bases/rook-ceph-operator/operator/helmrelease.yaml
spec:
  chart:
    spec:
      version: v1.18.6  # Update this version
```

**Process:**
1. Update operator version in HelmRelease
2. Commit to git (GitOps)
3. Flux reconciles and upgrades operator
4. Operator automatically upgrades Ceph daemons

### Ceph Version Upgrade

**Ceph image upgrades via cluster-settings:**
```yaml
# kubernetes/clusters/{infra,apps}/cluster-settings.yaml
ROOK_CEPH_IMAGE_TAG: v19.2.3  # Update Ceph version
```

**Rolling Upgrade Order:**
1. MONs (one at a time, maintaining quorum)
2. MGRs (standby first, then active)
3. OSDs (one at a time, maintaining data availability)

**Monitor upgrade:**
```bash
ceph versions           # Check version distribution
ceph -s | grep upgrade  # Monitor upgrade progress
```

**⚠️ Upgrade Path:**
- Ceph Reef (v18) → Squid (v19) ✅
- Skip versions NOT recommended
- Test in staging first

## 🔐 Security

### Pod Security Admission

**Namespace requires `privileged` enforcement:**
```yaml
pod-security.kubernetes.io/enforce: privileged
```

**Why privileged?**
- Operator needs cluster-admin for CRD management
- OSDs need host access for disk operations
- CSI drivers need privileged mounting
- Discovery daemon needs `/dev` access

### Network Policies

**Applied via Kustomize Components:**
- `deny-all` - Default deny all traffic
- `allow-dns` - Allow DNS resolution
- `allow-kube-api` - Allow Kubernetes API access
- `allow-internal` - Allow Ceph internal communication

**CiliumNetworkPolicy** provides additional layer for Cilium CNI.

### RBAC

- ServiceAccounts for MON, MGR, OSD, CSI drivers
- ClusterRoles with minimal permissions
- Secrets for Ceph keyrings and CSI credentials

## 📚 Storage Classes

### RBD StorageClass (Block Storage)

**Name:** `rook-ceph-block`

**Use Cases:**
- PostgreSQL databases
- Stateful applications requiring RWO volumes
- General-purpose block storage

**Features:**
- **Access Mode**: ReadWriteOnce (RWO)
- **Provisioner**: `rook-ceph.rbd.csi.ceph.com`
- **Volume Expansion**: Enabled
- **Reclaim Policy**: Delete
- **Filesystem**: ext4
- **Mount Options**: `discard` (SSD TRIM support)

**Example PVC:**
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-data
spec:
  storageClassName: rook-ceph-block
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 20Gi
```

### Storage Strategy: OpenEBS vs Rook-Ceph

**OpenEBS LocalPV** (`openebs-local-nvme`):
- ✅ Maximum performance (<1ms latency, 500K IOPS)
- ✅ Simple single-node deployment
- ❌ Single-node failure domain
- 🎯 **Use for**: Databases with backups, caches, CI/CD runners

**Rook-Ceph** (`rook-ceph-block`):
- ✅ Multi-node HA (survives node failures)
- ✅ 3x data replication
- ❌ Higher latency (5-10ms, 50K IOPS)
- 🎯 **Use for**: Shared storage, multi-replica workloads, durability-critical data

## 📖 References

- **Rook Documentation**: https://rook.io/docs/rook/latest-release/
- **Ceph Documentation**: https://docs.ceph.com/
- **Story 30**: Rook-Ceph Operator deployment
- **Story 31**: Rook-Ceph Cluster manifests (this implementation)
- **Story 45**: Rook-Ceph deployment validation

## 🔗 Related Files

- **Operator**: `kubernetes/bases/rook-ceph-operator/operator/`
- **Cluster**: `kubernetes/infrastructure/storage/rook-ceph/cluster/` (this directory)
- **Security**: `kubernetes/infrastructure/security/networkpolicy/rook-ceph/`
- **Monitoring**: `kubernetes/infrastructure/observability/dashboards/infrastructure/rook-ceph-cluster.yaml`
- **Cluster Settings**: `kubernetes/clusters/{infra,apps}/cluster-settings.yaml`

## 📝 Version History

- **v1.18.6** (Rook Operator) - Latest stable release
- **v19.2.3** (Ceph Squid) - Latest stable release (July 28, 2025)
- **v18.2.4** (Ceph Reef) - Previous stable (still supported)
