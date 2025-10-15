# Technical Deep Dive: Multi-Cluster Kubernetes Architecture

**Document Date:** 2025-10-14
**Version:** 1.0
**Purpose:** Comprehensive technical specifications and configurations

---

## Table of Contents

1. [Velero vs VolSync: Backup Strategy Comparison](#1-velero-vs-volsync-backup-strategy-comparison)
2. [Rook Ceph Production Configuration](#2-rook-ceph-production-configuration)
3. [Victoria Metrics Multi-Cluster Setup](#3-victoria-metrics-multi-cluster-setup)
4. [Cilium BGP + ClusterMesh Configuration](#4-cilium-bgp--clustermesh-configuration)
5. [FluxCD Kustomization Dependencies](#5-fluxcd-kustomization-dependencies)
6. [Disaster Recovery Strategy](#6-disaster-recovery-strategy)

---

## 1. Velero vs VolSync: Backup Strategy Comparison

### Overview

Both Velero and VolSync are open-source Kubernetes backup solutions, but they serve different purposes and use cases.

### Feature Comparison Matrix

| Feature | Velero | VolSync | Recommendation |
|---------|--------|---------|----------------|
| **Primary Purpose** | Cluster-wide backup/restore, disaster recovery | PV replication and backup | VolSync for your use case |
| **Scope** | Full cluster resources + PVs | PVC/PV data only | |
| **Backup Granularity** | Namespace/label-based | Per-PVC | VolSync (more granular) |
| **Storage Backend** | S3, Azure Blob, GCS, Restic | S3 (via Rclone/Restic), Rsync | Both support S3 |
| **Replication Methods** | Snapshot + object storage | Rsync, Rclone, Restic | VolSync (3 methods) |
| **1:Many Replication** | No (requires orchestration) | Yes (Rclone mode) | VolSync |
| **GitOps Integration** | Good | Excellent (per-PVC CRDs) | VolSync |
| **Multi-Cluster Support** | Requires separate backup per cluster | Native multi-cluster replication | VolSync |
| **Incremental Backups** | Yes (with Restic) | Yes (all methods) | Tie |
| **Configuration Complexity** | Medium | Higher (per-PVC) | Velero (simpler) |
| **Maturity** | High (CNCF graduated) | Medium (CNCF Sandbox) | Velero |
| **Resource Overhead** | Medium | Lower (per-PVC agents) | VolSync |
| **Kubernetes Resource Backup** | Yes | No | Velero |
| **Scheduled Snapshots** | Yes | Yes | Tie |
| **CSI Snapshot Integration** | Yes | Yes (preferred) | Tie |

### Detailed Analysis

#### Velero

**Strengths:**
- ✅ **Cluster-wide disaster recovery**: Backs up all Kubernetes resources (Deployments, ConfigMaps, Secrets, etc.)
- ✅ **Mature and widely adopted**: CNCF graduated project with large community
- ✅ **Simple to set up**: Single operator manages all backups
- ✅ **Plugin architecture**: Extensible for different storage providers
- ✅ **Cluster migration**: Can backup one cluster and restore to another

**Weaknesses:**
- ❌ **Less granular**: Typically backs up entire namespaces or label-based groups
- ❌ **Not designed for continuous replication**: Scheduled snapshots only
- ❌ **Restic integration can be slow**: File-level backup performance issues
- ❌ **Less GitOps-friendly**: Backup schedules not typically in Git

**Best For:**
- Disaster recovery scenarios (full cluster loss)
- Cluster migrations
- Compliance requirements (periodic backups)
- Teams needing full Kubernetes resource backup

#### VolSync

**Strengths:**
- ✅ **Per-PVC granularity**: Fine-grained control over what gets backed up
- ✅ **Multiple replication methods**:
  - **Rsync**: Direct sync between clusters (fast, low latency)
  - **Rclone**: 1:many replication via S3 (flexible)
  - **Restic**: Incremental, encrypted backups (efficient)
- ✅ **GitOps-native**: ReplicationSource/Destination CRDs managed in Git
- ✅ **Continuous replication**: Near real-time sync (Rsync mode)
- ✅ **CSI Snapshot integration**: Uses storage provider's native snapshots
- ✅ **Lower resource overhead**: Only runs when syncing

**Weaknesses:**
- ❌ **PV data only**: Does NOT backup Kubernetes resources
- ❌ **Higher configuration overhead**: Requires ReplicationSource/Destination per PVC
- ❌ **Less mature**: CNCF Sandbox project
- ❌ **Requires FluxCD or similar**: Best with GitOps automation

**Best For:**
- GitOps environments with FluxCD
- Continuous data replication between clusters
- Per-application backup strategies
- Multi-cluster data distribution
- Teams comfortable with CRD-based config

### Recommendation for Your Setup

**🎯 Use VolSync as Primary + Velero as Secondary**

#### Primary: VolSync for Application Data
- Manage ReplicationSource/Destination CRDs in Git (GitOps)
- Use **Rclone method** with Synology MinIO S3
- Continuous replication of critical PVCs to S3
- Per-application backup schedules

#### Secondary: Velero for Disaster Recovery
- Backup Kubernetes resources (not managed by Flux)
- Periodic full cluster backups (weekly)
- Cluster migration capability
- Compliance/audit trail

### VolSync Architecture for Your Setup

```
┌─────────────────────────────────────────────────────────────┐
│                    Infra Cluster                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Rook Ceph Volume (PostgreSQL)                      │   │
│  │    ↓                                                 │   │
│  │  [CSI Snapshot] ← VolumeSnapshot                    │   │
│  │    ↓                                                 │   │
│  │  [ReplicationSource]                                │   │
│  │    - copyMethod: Snapshot                           │   │
│  │    - restic.repository (MinIO S3)                   │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                            ↓
                    Synology MinIO S3
                 (s3://backups/infra-cluster/)
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                    Apps Cluster                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  [ReplicationDestination]                           │   │
│  │    - restic.repository (MinIO S3)                   │   │
│  │    - accessModes: ReadWriteOnce                     │   │
│  │    - capacity: 10Gi                                 │   │
│  │    ↓                                                 │   │
│  │  [Restored Volume] → App Pod                        │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

### VolSync Configuration Examples

#### 1. ReplicationSource (Infra Cluster)

```yaml
---
apiVersion: volsync.backube/v1alpha1
kind: ReplicationSource
metadata:
  name: postgres-backup
  namespace: databases
spec:
  sourcePVC: postgres-data
  trigger:
    schedule: "0 */6 * * *"  # Every 6 hours
  restic:
    repository: postgres-backup-secret
    retain:
      hourly: 6
      daily: 7
      weekly: 4
      monthly: 6
    copyMethod: Snapshot  # Use CSI snapshots (fast!)
    storageClassName: ceph-block
    volumeSnapshotClassName: ceph-block
    moverSecurityContext:
      runAsUser: 999
      runAsGroup: 999
      fsGroup: 999
```

#### 2. ReplicationDestination (Apps Cluster - Disaster Recovery)

```yaml
---
apiVersion: volsync.backube/v1alpha1
kind: ReplicationDestination
metadata:
  name: postgres-restore
  namespace: databases
spec:
  trigger:
    schedule: "15 */6 * * *"  # 15 min after source backup
  restic:
    repository: postgres-backup-secret
    destinationPVC: postgres-data-restored
    storageClassName: ceph-block
    accessModes:
      - ReadWriteOnce
    capacity: 20Gi
    moverSecurityContext:
      runAsUser: 999
      runAsGroup: 999
      fsGroup: 999
```

#### 3. Restic Repository Secret (MinIO S3)

```yaml
---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: postgres-backup-secret
  namespace: databases
spec:
  secretStoreRef:
    kind: ClusterSecretStore
    name: onepassword
  target:
    name: postgres-backup-secret
    template:
      engineVersion: v2
      data:
        RESTIC_REPOSITORY: "s3:https://minio.nas.monosense.io/volsync/postgres"
        RESTIC_PASSWORD: "{{ .RESTIC_PASSWORD }}"
        AWS_ACCESS_KEY_ID: "{{ .MINIO_ACCESS_KEY }}"
        AWS_SECRET_ACCESS_KEY: "{{ .MINIO_SECRET_KEY }}"
  dataFrom:
    - extract:
        key: volsync-restic
```

### Velero Configuration (Secondary)

#### Velero Installation with Restic

```yaml
---
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: velero
  namespace: velero-system
spec:
  interval: 30m
  chart:
    spec:
      chart: velero
      version: 8.x.x
      sourceRef:
        kind: HelmRepository
        name: vmware-tanzu
        namespace: flux-system
  values:
    configuration:
      backupStorageLocation:
        - name: default
          provider: aws
          bucket: velero-backups
          config:
            region: us-east-1
            s3ForcePathStyle: "true"
            s3Url: https://minio.nas.monosense.io
      volumeSnapshotLocation:
        - name: ceph-snapshots
          provider: csi
    credentials:
      existingSecret: velero-credentials
    initContainers:
      - name: velero-plugin-for-csi
        image: velero/velero-plugin-for-csi:v0.9.0
        volumeMounts:
          - mountPath: /target
            name: plugins
      - name: velero-plugin-for-aws
        image: velero/velero-plugin-for-aws:v1.11.0
        volumeMounts:
          - mountPath: /target
            name: plugins
    deployNodeAgent: true  # For Restic integration
    nodeAgent:
      resources:
        requests:
          memory: 512Mi
          cpu: 500m
        limits:
          memory: 2Gi
          cpu: 1000m
```

#### Velero Backup Schedule

```yaml
---
apiVersion: velero.io/v1
kind: Schedule
metadata:
  name: weekly-full-backup
  namespace: velero-system
spec:
  schedule: "0 2 * * 0"  # Every Sunday at 2 AM
  template:
    includedNamespaces:
      - "*"
    excludedNamespaces:
      - kube-system
      - kube-public
      - kube-node-lease
    snapshotVolumes: true
    defaultVolumesToFsBackup: false  # Use CSI snapshots
    storageLocation: default
    volumeSnapshotLocations:
      - ceph-snapshots
    ttl: 720h  # 30 days retention
```

### Summary: Backup Strategy

| What | Tool | Method | Frequency | Retention | Storage |
|------|------|--------|-----------|-----------|---------|
| **PostgreSQL Data** | VolSync | Restic + Snapshot | 6 hours | 6H/7D/4W/6M | MinIO S3 |
| **Application PVCs** | VolSync | Restic + Snapshot | Daily | 7D/4W/6M | MinIO S3 |
| **K8s Resources** | Velero | Object storage | Weekly | 30 days | MinIO S3 |
| **Cluster Snapshots** | Velero | CSI Snapshots | Weekly | 4 weeks | Rook Ceph |

---

## 2. Rook Ceph Production Configuration

### Hardware Specifications (Your Setup)

**Per Node:**
- **OS Disk**: 500GB SSD (Talos Linux)
- **Ceph OSD Disk**: 1TB NVMe (/dev/nvme1n1)
- **OpenEBS Disk**: 512GB NVMe (/dev/nvme0n1)
- **RAM**: 64GB
- **CPU**: Intel i7-8700T (6 cores, 12 threads)
- **Network**: 10GbE bonded (LACP), MTU 9000

**Total Cluster Capacity:**
- **Raw**: 3TB (3 nodes × 1TB)
- **Usable (3x replication)**: ~1TB
- **Usable (2x replication)**: ~1.5TB
- **Usable (Erasure Coding 2+1)**: ~2TB

### Recommended Ceph Configuration

#### CephCluster Resource (Production-Grade)

```yaml
---
apiVersion: ceph.rook.io/v1
kind: CephCluster
metadata:
  name: rook-ceph
  namespace: rook-ceph
spec:
  cephVersion:
    image: quay.io/ceph/ceph:v18.2.4  # Reef LTS
    allowUnsupported: false

  dataDirHostPath: /var/lib/rook

  # Skip upgrade checks (useful for home lab)
  skipUpgradeChecks: false
  continueUpgradeAfterChecksEvenIfNotHealthy: false

  # Wait for healthy state before upgrades
  waitTimeoutForHealthyOSDInMinutes: 10

  mon:
    count: 3
    allowMultiplePerNode: false
    volumeClaimTemplate:
      spec:
        storageClassName: local-hostpath  # OpenEBS
        resources:
          requests:
            storage: 10Gi

  mgr:
    count: 2
    allowMultiplePerNode: false
    modules:
      - name: pg_autoscaler
        enabled: true
      - name: rook
        enabled: true

  # Dashboard
  dashboard:
    enabled: true
    ssl: true
    port: 8443

  # Monitoring
  monitoring:
    enabled: true
    createPrometheusRules: true

  network:
    provider: host  # Use host network for performance
    connections:
      requireMsgr2: true
      encryption:
        enabled: false  # Disable for performance in trusted network
      compression:
        enabled: false  # Disable for performance

  # Crash collector for debugging
  crashCollector:
    disable: false

  # Log collector
  logCollector:
    enabled: true
    periodicity: daily
    maxLogSize: 500M

  # Resource limits
  resources:
    mon:
      requests:
        cpu: "1000m"
        memory: "2Gi"
      limits:
        cpu: "2000m"
        memory: "4Gi"
    mgr:
      requests:
        cpu: "500m"
        memory: "1Gi"
      limits:
        cpu: "1000m"
        memory: "2Gi"
    osd:
      requests:
        cpu: "2000m"
        memory: "4Gi"
      limits:
        cpu: "4000m"
        memory: "8Gi"
    prepareosd:
      requests:
        cpu: "500m"
        memory: "50Mi"
    crashcollector:
      requests:
        cpu: "100m"
        memory: "60Mi"
      limits:
        cpu: "500m"
        memory: "256Mi"
    logcollector:
      requests:
        cpu: "100m"
        memory: "100Mi"
      limits:
        cpu: "500m"
        memory: "1Gi"

  # Remove OSDs automatically when failed
  removeOSDsIfOutAndSafeToRemove: false  # Manual control for safety

  # Priority classes
  priorityClassNames:
    mon: system-node-critical
    osd: system-node-critical
    mgr: system-cluster-critical

  storage:
    useAllNodes: false
    useAllDevices: false
    config:
      # OSD tuning
      osdsPerDevice: "1"
      storeType: bluestore
      databaseSizeMB: "10240"  # 10GB DB size for 1TB OSD
      walSizeMB: "1024"  # 1GB WAL
      journalSizeMB: "5120"  # 5GB journal

      # BlueStore tuning for NVMe
      "osd_memory_target": "4294967296"  # 4GB per OSD
      "bluestore_cache_size": "4294967296"  # 4GB cache
      "bluestore_cache_size_hdd": "1073741824"  # Not used (NVMe only)
      "bluestore_cache_size_ssd": "4294967296"  # 4GB for SSD/NVMe

      # Performance tuning
      "osd_max_backfills": "1"
      "osd_recovery_max_active": "1"
      "osd_recovery_op_priority": "1"
      "osd_recovery_max_single_start": "1"
      "osd_max_scrubs": "1"
      "osd_scrub_during_recovery": "false"

      # Network optimization for 10GbE
      "ms_async_op_threads": "8"
      "ms_bind_retry_count": "3"
      "ms_bind_retry_delay": "3"

    nodes:
      - name: "prod-01"
        deviceFilter: "^nvme1n1$"
      - name: "prod-02"
        deviceFilter: "^nvme1n1$"
      - name: "prod-03"
        deviceFilter: "^nvme1n1$"

  # Disruption management
  disruptionManagement:
    managePodBudgets: true
    osdMaintenanceTimeout: 30
    pgHealthCheckTimeout: 0  # Use default
    manageMachineDisruptionBudgets: false

  # Health checks
  healthCheck:
    daemonHealth:
      mon:
        interval: 45s
        timeout: 10s
      osd:
        interval: 60s
        timeout: 10s
      status:
        interval: 60s
    livenessProbe:
      mon:
        disabled: false
      mgr:
        disabled: false
      osd:
        disabled: false
```

#### CephBlockPool (RBD)

```yaml
---
apiVersion: ceph.rook.io/v1
kind: CephBlockPool
metadata:
  name: replicapool
  namespace: rook-ceph
spec:
  # Replication configuration
  replicated:
    size: 3  # 3-way replication
    requireSafeReplicaSize: true
    replicasPerFailureDomain: 1
    subFailureDomain: host

  # Enable RBD mirroring for DR (optional)
  mirroring:
    enabled: false
    mode: image  # or 'pool'

  # Status check interval
  statusCheck:
    mirror:
      interval: 60s

  # Quota (optional)
  quotas:
    maxSize: "900Gi"  # ~90% of usable capacity

  # Enable compression (optional)
  compressionMode: none  # or 'aggressive', 'passive'

  # Parameters
  parameters:
    # Enable fast-diff for incremental backups
    imageFeatures: layering,fast-diff,object-map,deep-flatten,exclusive-lock
    imageFormat: "2"
```

#### CephFilesystem (CephFS)

```yaml
---
apiVersion: ceph.rook.io/v1
kind: CephFilesystem
metadata:
  name: cephfs
  namespace: rook-ceph
spec:
  metadataPool:
    replicated:
      size: 3
      requireSafeReplicaSize: true
    parameters:
      compression_mode: none

  dataPools:
    - name: replicated
      replicated:
        size: 3
        requireSafeReplicaSize: true
      parameters:
        compression_mode: none

  preserveFilesystemOnDelete: true

  metadataServer:
    activeCount: 1
    activeStandby: true
    priorityClassName: system-cluster-critical
    resources:
      requests:
        cpu: "1000m"
        memory: "2Gi"
      limits:
        cpu: "2000m"
        memory: "4Gi"
    livenessProbe:
      disabled: false
```

#### Storage Classes

```yaml
---
# RBD Block Storage
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ceph-block
provisioner: rook-ceph.rbd.csi.ceph.com
parameters:
  clusterID: rook-ceph
  pool: replicapool
  imageFormat: "2"
  imageFeatures: layering,fast-diff,object-map,deep-flatten,exclusive-lock

  # CSI provisioner secrets
  csi.storage.k8s.io/provisioner-secret-name: rook-csi-rbd-provisioner
  csi.storage.k8s.io/provisioner-secret-namespace: rook-ceph
  csi.storage.k8s.io/controller-expand-secret-name: rook-csi-rbd-provisioner
  csi.storage.k8s.io/controller-expand-secret-namespace: rook-ceph
  csi.storage.k8s.io/node-stage-secret-name: rook-csi-rbd-node
  csi.storage.k8s.io/node-stage-secret-namespace: rook-ceph

  # Filesystem type
  csi.storage.k8s.io/fstype: ext4
allowVolumeExpansion: true
reclaimPolicy: Delete
volumeBindingMode: Immediate
---
# CephFS Shared Filesystem
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ceph-filesystem
provisioner: rook-ceph.cephfs.csi.ceph.com
parameters:
  clusterID: rook-ceph
  fsName: cephfs
  pool: cephfs-replicated

  # CSI provisioner secrets
  csi.storage.k8s.io/provisioner-secret-name: rook-csi-cephfs-provisioner
  csi.storage.k8s.io/provisioner-secret-namespace: rook-ceph
  csi.storage.k8s.io/controller-expand-secret-name: rook-csi-cephfs-provisioner
  csi.storage.k8s.io/controller-expand-secret-namespace: rook-ceph
  csi.storage.k8s.io/node-stage-secret-name: rook-csi-cephfs-node
  csi.storage.k8s.io/node-stage-secret-namespace: rook-ceph
allowVolumeExpansion: true
reclaimPolicy: Delete
volumeBindingMode: Immediate
---
# VolumeSnapshotClass for backups
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshotClass
metadata:
  name: ceph-block
driver: rook-ceph.rbd.csi.ceph.com
parameters:
  clusterID: rook-ceph
  csi.storage.k8s.io/snapshotter-secret-name: rook-csi-rbd-provisioner
  csi.storage.k8s.io/snapshotter-secret-namespace: rook-ceph
deletionPolicy: Delete
```

### Performance Tuning Recommendations

#### 1. OSD Memory Targets

For your 64GB RAM nodes with 1 OSD each:
```
Total RAM: 64GB
- OS + K8s: ~8GB
- Ceph MON: 4GB
- Ceph MGR: 2GB
- Available for OSD: ~50GB
- OSD target: 4GB (conservative)
- Cache: 4GB
- Remaining for apps/buffers: ~38GB
```

#### 2. BlueStore Configuration

Optimal for 1TB NVMe OSDs:
- **DB size**: 10GB (1% of OSD size)
- **WAL size**: 1GB
- **Cache size**: 4GB
- **Total overhead**: ~15GB per OSD

#### 3. Network Optimization

Your 10GbE bonded setup with MTU 9000:
```yaml
# In Talos machine config
network:
  interfaces:
    - interface: bond0
      mtu: 9000  # Jumbo frames

# Ceph tuning
"ms_async_op_threads": "8"  # Match CPU cores
"osd_op_threads": "8"  # Match CPU cores
```

#### 4. Recovery and Backfill Tuning

```yaml
# Conservative settings to avoid impacting production
"osd_max_backfills": "1"
"osd_recovery_max_active": "1"
"osd_recovery_max_single_start": "1"
"osd_recovery_op_priority": "1"  # Low priority
```

### Monitoring and Alerting

#### Prometheus Rules

```yaml
---
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: rook-ceph-alerts
  namespace: rook-ceph
spec:
  groups:
    - name: ceph.rules
      interval: 30s
      rules:
        - alert: CephHealthWarning
          expr: ceph_health_status == 1
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "Ceph cluster health is WARNING"
            description: "Ceph cluster {{ $labels.cluster }} health is in WARNING state"

        - alert: CephHealthError
          expr: ceph_health_status == 2
          for: 1m
          labels:
            severity: critical
          annotations:
            summary: "Ceph cluster health is ERROR"
            description: "Ceph cluster {{ $labels.cluster }} health is in ERROR state"

        - alert: CephOSDDown
          expr: ceph_osd_up == 0
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "Ceph OSD is down"
            description: "OSD {{ $labels.osd }} on cluster {{ $labels.cluster }} is down"

        - alert: CephStorageNearFull
          expr: ceph_cluster_total_used_bytes / ceph_cluster_total_bytes > 0.80
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "Ceph cluster storage is 80% full"
            description: "Ceph cluster {{ $labels.cluster }} is {{ $value | humanizePercentage }} full"

        - alert: CephStorageCriticallyFull
          expr: ceph_cluster_total_used_bytes / ceph_cluster_total_bytes > 0.90
          for: 1m
          labels:
            severity: critical
          annotations:
            summary: "Ceph cluster storage is 90% full"
            description: "Ceph cluster {{ $labels.cluster }} is {{ $value | humanizePercentage }} full"
```

---

## 3. Victoria Metrics Multi-Cluster Setup

### Architecture Overview

```
┌──────────────────────────────────────────────────────────────┐
│                      Infra Cluster                            │
│                                                               │
│  ┌─────────────────────────────────────────────────────┐    │
│  │            VMCluster (HA Storage)                    │    │
│  │  ┌─────────────┐  ┌──────────────┐  ┌────────────┐ │    │
│  │  │  VMInsert   │  │  VMStorage   │  │  VMSelect  │ │    │
│  │  │  (2 replicas│  │  (3 replicas)│  │(2 replicas)│ │    │
│  │  └─────────────┘  └──────────────┘  └────────────┘ │    │
│  └─────────────────────────────────────────────────────┘    │
│         ↑                                                     │
│         │                                                     │
│  ┌──────┴────────┐                                          │
│  │   VMAgent     │ ← Scrapes infra cluster                  │
│  │  (remote-write)│                                          │
│  └───────────────┘                                          │
│                                                               │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  VMAuth (auth proxy)                                  │   │
│  │  VMAlert (alerting)                                   │   │
│  │  Alertmanager                                         │   │
│  │  Grafana                                              │   │
│  └──────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────┘
                           ↑
                           │ remote-write
┌──────────────────────────┼───────────────────────────────────┐
│                      Apps Cluster                             │
│  ┌──────────────────────────────────────────────────────┐   │
│  │   VMAgent (scrape + remote-write)                     │   │
│  │     - Scrapes apps cluster workloads                  │   │
│  │     - Remote-writes to VMCluster on infra             │   │
│  └──────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────┘
```

### Infra Cluster: VMCluster (Storage Backend)

#### Victoria Metrics Operator

```yaml
---
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: victoria-metrics-operator
  namespace: monitoring
spec:
  interval: 30m
  chart:
    spec:
      chart: victoria-metrics-operator
      version: 0.x.x
      sourceRef:
        kind: HelmRepository
        name: victoria-metrics
        namespace: flux-system
  values:
    operator:
      disable_prometheus_converter: false
      enable_converter_ownership: true

    resources:
      requests:
        cpu: 100m
        memory: 128Mi
      limits:
        cpu: 500m
        memory: 512Mi
```

#### VMCluster (Multi-Node HA)

```yaml
---
apiVersion: operator.victoriametrics.com/v1beta1
kind: VMCluster
metadata:
  name: vmcluster
  namespace: monitoring
spec:
  retentionPeriod: "90d"  # 90 days retention
  replicationFactor: 2  # 2x replication for HA

  vmstorage:
    replicaCount: 3
    storageDataPath: /vm-data
    storage:
      volumeClaimTemplate:
        spec:
          storageClassName: ceph-block
          accessModes:
            - ReadWriteOnce
          resources:
            requests:
              storage: 100Gi  # Per replica
    resources:
      requests:
        cpu: "1000m"
        memory: "2Gi"
      limits:
        cpu: "2000m"
        memory: "4Gi"

    extraArgs:
      dedup.minScrapeInterval: 30s  # Deduplicate metrics

  vmselect:
    replicaCount: 2
    cacheMountPath: /select-cache
    storage:
      volumeClaimTemplate:
        spec:
          storageClassName: local-hostpath  # Fast local cache
          accessModes:
            - ReadWriteOnce
          resources:
            requests:
              storage: 10Gi
    resources:
      requests:
        cpu: "500m"
        memory: "1Gi"
      limits:
        cpu: "2000m"
        memory: "4Gi"

    extraArgs:
      search.latencyOffset: 30s
      search.maxQueryDuration: 5m

  vminsert:
    replicaCount: 2
    resources:
      requests:
        cpu: "500m"
        memory: "512Mi"
      limits:
        cpu: "2000m"
        memory: "2Gi"

    extraArgs:
      maxLabelsPerTimeseries: "50"
      replicationFactor: "2"
```

#### VMAgent (Infra Cluster)

```yaml
---
apiVersion: operator.victoriametrics.com/v1beta1
kind: VMAgent
metadata:
  name: vmagent-infra
  namespace: monitoring
spec:
  selectAllByDefault: true
  replicaCount: 1

  # Remote write to local VMCluster
  remoteWrite:
    - url: "http://vminsert-vmcluster.monitoring.svc:8480/insert/0/prometheus/api/v1/write"

  # Scrape interval
  scrapeInterval: 30s

  # External labels
  externalLabels:
    cluster: infra
    region: home

  # Resource limits
  resources:
    requests:
      cpu: "500m"
      memory: "512Mi"
    limits:
      cpu: "2000m"
      memory: "2Gi"

  # Service scraping
  serviceScrapeSelector: {}
  podScrapeSelector: {}
  nodeScrapeSelector: {}
  staticScrapeSelector: {}
  probeScrapeSelector: {}

  # Relabeling
  relabelConfig:
    configs:
      - action: labeldrop
        regex: (pod|service|endpoint|namespace)_uid
```

### Apps Cluster: VMAgent (Remote Write)

```yaml
---
apiVersion: operator.victoriametrics.com/v1beta1
kind: VMAgent
metadata:
  name: vmagent-apps
  namespace: monitoring
spec:
  selectAllByDefault: true
  replicaCount: 1

  # Remote write to infra cluster VMCluster
  remoteWrite:
    - url: "http://vminsert-vmcluster.monitoring.svc.infra.local:8480/insert/0/prometheus/api/v1/write"
      # Cross-cluster via Cilium ClusterMesh global service

      # Basic auth (optional)
      # basicAuth:
      #   username:
      #     name: vmcluster-auth
      #     key: username
      #   password:
      #     name: vmcluster-auth
      #     key: password

      # Queue config for reliability
      queueConfig:
        capacity: 100000
        maxSamplesPerSend: 10000
        maxShards: 10

  # Scrape interval
  scrapeInterval: 30s

  # External labels (IMPORTANT for multi-cluster)
  externalLabels:
    cluster: apps
    region: home

  # Resource limits
  resources:
    requests:
      cpu: "500m"
      memory: "512Mi"
    limits:
      cpu: "2000m"
      memory: "2Gi"

  # Service scraping
  serviceScrapeSelector: {}
  podScrapeSelector: {}
  nodeScrapeSelector: {}
```

### Cilium Global Service for Cross-Cluster Access

```yaml
---
apiVersion: v1
kind: Service
metadata:
  name: vminsert-vmcluster
  namespace: monitoring
  annotations:
    io.cilium/global-service: "true"  # Enable ClusterMesh
spec:
  type: ClusterIP
  ports:
    - name: http
      port: 8480
      targetPort: 8480
      protocol: TCP
  selector:
    app.kubernetes.io/name: vminsert
    app.kubernetes.io/instance: vmcluster
```

### VMAlert (Alerting Rules)

```yaml
---
apiVersion: operator.victoriametrics.com/v1beta1
kind: VMAlert
metadata:
  name: vmalert
  namespace: monitoring
spec:
  replicaCount: 1

  # Data source
  datasource:
    url: "http://vmselect-vmcluster.monitoring.svc:8481/select/0/prometheus"

  # Alertmanager
  notifiers:
    - url: "http://alertmanager.monitoring.svc:9093"

  # Remote write for recording rules
  remoteWrite:
    url: "http://vminsert-vmcluster.monitoring.svc:8480/insert/0/prometheus/api/v1/write"

  # Remote read for query execution
  remoteRead:
    url: "http://vmselect-vmcluster.monitoring.svc:8481/select/0/prometheus"

  # Rule selectors
  ruleSelector: {}

  # Resources
  resources:
    requests:
      cpu: "200m"
      memory: "256Mi"
    limits:
      cpu: "1000m"
      memory: "1Gi"

  # External labels
  externalLabels:
    cluster: infra
```

### Grafana Configuration

```yaml
---
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: grafana
  namespace: monitoring
spec:
  interval: 30m
  chart:
    spec:
      chart: grafana
      version: 8.x.x
      sourceRef:
        kind: HelmRepository
        name: grafana
        namespace: flux-system
  values:
    replicas: 1

    # Datasources
    datasources:
      datasources.yaml:
        apiVersion: 1
        datasources:
          - name: VictoriaMetrics
            type: prometheus
            url: http://vmselect-vmcluster.monitoring.svc:8481/select/0/prometheus
            access: proxy
            isDefault: true
            jsonData:
              timeInterval: 30s

    # Persistence
    persistence:
      enabled: true
      storageClassName: ceph-block
      size: 10Gi

    # Admin credentials from secret
    admin:
      existingSecret: grafana-admin
      userKey: admin-user
      passwordKey: admin-password

    # Resources
    resources:
      requests:
        cpu: 250m
        memory: 512Mi
      limits:
        cpu: 1000m
        memory: 2Gi
```

### Retention and Capacity Planning

**Metrics Estimation:**
- **Clusters**: 2 (infra + apps)
- **Nodes**: 6 total (3 per cluster)
- **Pods**: ~200 total estimate
- **Metrics per pod**: ~100 time series
- **Total time series**: ~20,000
- **Sample rate**: 30s (2 samples/min)
- **Data points/day**: 20,000 × 2 × 60 × 24 = 57.6M
- **Storage per day**: ~1-2GB (compressed)
- **90-day retention**: ~180GB

**VMStorage Sizing:**
- 3 replicas × 100GB = 300GB raw
- With 2x replication = 150GB usable
- **Sufficient for 90 days** ✅

---

## 4. Cilium BGP + ClusterMesh Configuration

### Network Planning

#### IP Addressing

```
# Node Network (Shared between clusters)
Node CIDR: 10.25.11.0/24
Gateway: 10.25.11.1 (Juniper SRX320)

Infra Cluster Nodes:
  - prod-01: 10.25.11.11
  - prod-02: 10.25.11.12
  - prod-03: 10.25.11.13

Apps Cluster Nodes:
  - prod-04: 10.25.11.14
  - prod-05: 10.25.11.15
  - prod-06: 10.25.11.16

# Pod Networks (Non-overlapping)
Infra Cluster:
  - Pod CIDR: 10.244.0.0/16
  - Service CIDR: 10.245.0.0/16

Apps Cluster:
  - Pod CIDR: 10.246.0.0/16
  - Service CIDR: 10.247.0.0/16

# LoadBalancer IP Pools
Infra Cluster LB Pool: 10.25.11.100-10.25.11.149
Apps Cluster LB Pool: 10.25.11.150-10.25.11.199

# BGP ASNs
Juniper SRX320: 65000
Infra Cluster: 65001
Apps Cluster: 65002
```

### Talos Configuration (Per Cluster)

#### Infra Cluster Talos Patch

```yaml
# talos/patches/infra-cluster.yaml
---
cluster:
  clusterName: infra
  network:
    cni:
      name: none  # Cilium managed externally
    podSubnets:
      - 10.244.0.0/16
    serviceSubnets:
      - 10.245.0.0/16

machine:
  network:
    interfaces:
      - interface: bond0
        mtu: 9000  # Jumbo frames
        dhcp: false
        addresses:
          - <NODE_IP>/24
        routes:
          - network: 0.0.0.0/0
            gateway: 10.25.11.1
```

#### Apps Cluster Talos Patch

```yaml
# talos/patches/apps-cluster.yaml
---
cluster:
  clusterName: apps
  network:
    cni:
      name: none
    podSubnets:
      - 10.246.0.0/16
    serviceSubnets:
      - 10.247.0.0/16

machine:
  network:
    interfaces:
      - interface: bond0
        mtu: 9000
        dhcp: false
        addresses:
          - <NODE_IP>/24
        routes:
          - network: 0.0.0.0/0
            gateway: 10.25.11.1
```

### Cilium Installation (Infra Cluster)

```yaml
---
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: cilium
  namespace: kube-system
spec:
  interval: 30m
  chart:
    spec:
      chart: cilium
      version: 1.18.x
      sourceRef:
        kind: HelmRepository
        name: cilium
        namespace: flux-system
  values:
    cluster:
      name: infra
      id: 1

    ipam:
      mode: kubernetes

    k8sServiceHost: 10.25.11.1  # API server VIP
    k8sServicePort: 6443

    # BGP Control Plane
    bgpControlPlane:
      enabled: true

    # Enable host networking for performance
    hostServices:
      enabled: true
      protocols: tcp,udp

    # BPF settings
    bpf:
      masquerade: true
      tproxy: true

    # Kube-proxy replacement
    kubeProxyReplacement: true
    kubeProxyReplacementHealthzBindAddr: "0.0.0.0:10256"

    # Enable ClusterMesh
    clustermesh:
      useAPIServer: true
      apiserver:
        service:
          type: LoadBalancer
          annotations:
            io.cilium/lb-ipam-ips: "10.25.11.101"
        replicas: 2
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi

    # L2 Announcements (optional, for non-BGP LoadBalancer)
    l2announcements:
      enabled: false

    # LoadBalancer IP management
    loadBalancer:
      acceleration: native
      mode: dsr

    # Native routing
    routingMode: native
    autoDirectNodeRoutes: false  # Using BGP
    ipv4NativeRoutingCIDR: 10.25.11.0/24

    # Encryption (disable for performance in trusted network)
    encryption:
      enabled: false
      type: wireguard

    # Monitoring
    prometheus:
      enabled: true
      serviceMonitor:
        enabled: true

    # Hubble (observability)
    hubble:
      enabled: true
      relay:
        enabled: true
        replicas: 1
      ui:
        enabled: true
        replicas: 1
        ingress:
          enabled: false

    # Operator
    operator:
      replicas: 2
      prometheus:
        enabled: true
        serviceMonitor:
          enabled: true

    # Resources
    resources:
      requests:
        cpu: 250m
        memory: 512Mi
      limits:
        cpu: 2000m
        memory: 2Gi
```

### Cilium LB IPAM (IP Pool)

#### Infra Cluster

```yaml
---
apiVersion: cilium.io/v2alpha1
kind: CiliumLoadBalancerIPPool
metadata:
  name: infra-lb-pool
spec:
  blocks:
    - start: "10.25.11.100"
      stop: "10.25.11.149"
  serviceSelector:
    matchLabels:
      io.kubernetes.service/cluster: infra
```

#### Apps Cluster

```yaml
---
apiVersion: cilium.io/v2alpha1
kind: CiliumLoadBalancerIPPool
metadata:
  name: apps-lb-pool
spec:
  blocks:
    - start: "10.25.11.150"
      stop: "10.25.11.199"
  serviceSelector:
    matchLabels:
      io.kubernetes.service/cluster: apps
```

### Cilium BGP Configuration

#### BGP Cluster Config (Infra)

```yaml
---
apiVersion: cilium.io/v2alpha1
kind: CiliumBGPClusterConfig
metadata:
  name: bgp-infra
spec:
  nodeSelector:
    matchLabels:
      kubernetes.io/os: linux
  bgpInstances:
    - name: "bgp-65001"
      localASN: 65001
      localPort: 179
      peers:
        - name: "juniper-srx320"
          peerASN: 65000
          peerAddress: "10.25.11.1"
          peerConfigRef:
            name: "cilium-peer"
```

#### BGP Peer Config

```yaml
---
apiVersion: cilium.io/v2alpha1
kind: CiliumBGPPeerConfig
metadata:
  name: cilium-peer
spec:
  # BGP timers
  timers:
    connectRetryTimeSeconds: 120
    holdTimeSeconds: 90
    keepAliveTimeSeconds: 30

  # Graceful restart
  gracefulRestart:
    enabled: true
    restartTimeSeconds: 120

  # Address families
  families:
    - afi: ipv4
      safi: unicast
      advertisements:
        matchLabels:
          advertise: "bgp"
```

#### BGP Advertisement

```yaml
---
apiVersion: cilium.io/v2alpha1
kind: CiliumBGPAdvertisement
metadata:
  name: bgp-advertisements
  labels:
    advertise: bgp
spec:
  advertisements:
    - advertisementType: "Service"
      service:
        addresses:
          - LoadBalancerIP
      selector:
        matchExpressions:
          - key: io.cilium/bgp-announce
            operator: In
            values: ["true"]

    - advertisementType: "PodCIDR"
      selector:
        matchExpressions:
          - key: node-role.kubernetes.io/control-plane
            operator: DoesNotExist
```

### Juniper SRX320 BGP Configuration

```junos
# Configure BGP on Juniper SRX320
set routing-options autonomous-system 65000
set routing-options router-id 10.25.11.1

# BGP group for infra cluster
set protocols bgp group cilium-infra type external
set protocols bgp group cilium-infra multihop ttl 2
set protocols bgp group cilium-infra local-address 10.25.11.1
set protocols bgp group cilium-infra neighbor 10.25.11.11 peer-as 65001
set protocols bgp group cilium-infra neighbor 10.25.11.12 peer-as 65001
set protocols bgp group cilium-infra neighbor 10.25.11.13 peer-as 65001
set protocols bgp group cilium-infra export bgp-export-policy

# BGP group for apps cluster
set protocols bgp group cilium-apps type external
set protocols bgp group cilium-apps multihop ttl 2
set protocols bgp group cilium-apps local-address 10.25.11.1
set protocols bgp group cilium-apps neighbor 10.25.11.14 peer-as 65002
set protocols bgp group cilium-apps neighbor 10.25.11.15 peer-as 65002
set protocols bgp group cilium-apps neighbor 10.25.11.16 peer-as 65002
set protocols bgp group cilium-apps export bgp-export-policy

# Export policy (accept all from Cilium)
set policy-options policy-statement bgp-export-policy term accept-all then accept

# Allow BGP in security zones
set security zones security-zone trust host-inbound-traffic protocols bgp
```

### ClusterMesh Setup

#### Enable ClusterMesh (Both Clusters)

```bash
# On infra cluster
cilium clustermesh enable --context infra --service-type LoadBalancer

# On apps cluster
cilium clustermesh enable --context apps --service-type LoadBalancer

# Connect clusters
cilium clustermesh connect --context infra --destination-context apps

# Check status
cilium clustermesh status --context infra
cilium clustermesh status --context apps
```

#### Global Service Example

```yaml
---
# PostgreSQL service on infra cluster (accessible from apps)
apiVersion: v1
kind: Service
metadata:
  name: postgres
  namespace: databases
  annotations:
    io.cilium/global-service: "true"  # Enable cross-cluster
    service.cilium.io/global: "true"
spec:
  type: ClusterIP
  ports:
    - name: postgres
      port: 5432
      targetPort: 5432
      protocol: TCP
  selector:
    app: postgres
---
# Access from apps cluster:
# postgres.databases.svc.infra.local:5432
```

---

## 5. FluxCD Kustomization Dependencies

### Dependency Management Strategy

**Key Principles:**
1. **CRDs must be applied first** (before resources that use them)
2. **Operators must be ready** before deploying Custom Resources
3. **Storage must be available** before deploying stateful apps
4. **Use `dependsOn` to enforce ordering**
5. **Use `wait: true` for health checks**
6. **Use `retryInterval` for transient failures**

### Dependency Layers

```
Layer 0 (CRDs)
  ↓ dependsOn
Layer 1 (Operators)
  ↓ dependsOn
Layer 2 (Infrastructure Resources)
  ↓ dependsOn
Layer 3 (Platform Services)
  ↓ dependsOn
Layer 4 (Applications)
```

### Infra Cluster Kustomization Stack

#### Layer 0: CRDs

```yaml
---
# clusters/infra/infrastructure.yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: crds
  namespace: flux-system
spec:
  interval: 30m
  path: ./infrastructure/infra-cluster/crds
  prune: false  # NEVER prune CRDs!
  wait: false  # CRDs don't have status
  sourceRef:
    kind: GitRepository
    name: flux-system
  timeout: 5m
```

#### Layer 1: Operators

```yaml
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
  wait: true  # Wait for operators to be ready
  timeout: 10m
  retryInterval: 2m
  sourceRef:
    kind: GitRepository
    name: flux-system
  healthChecks:
    - apiVersion: apps/v1
      kind: Deployment
      name: rook-ceph-operator
      namespace: rook-ceph
    - apiVersion: apps/v1
      kind: Deployment
      name: cert-manager
      namespace: cert-manager
    - apiVersion: apps/v1
      kind: Deployment
      name: external-secrets
      namespace: external-secrets
```

#### Layer 2: Storage

```yaml
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: storage
  namespace: flux-system
spec:
  dependsOn:
    - name: operators
  interval: 15m
  path: ./infrastructure/infra-cluster/storage
  prune: true
  wait: true
  timeout: 20m  # Storage can take time to initialize
  retryInterval: 5m
  sourceRef:
    kind: GitRepository
    name: flux-system
  healthChecks:
    - apiVersion: ceph.rook.io/v1
      kind: CephCluster
      name: rook-ceph
      namespace: rook-ceph
  # Custom health check for Ceph cluster
  healthCheckExprs:
    - apiVersion: ceph.rook.io/v1
      kind: CephCluster
      current: status.phase == 'Ready' && status.ceph.health == 'HEALTH_OK'
      failed: status.phase == 'Failed'
```

#### Layer 3: Platform Services

```yaml
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: platform-services
  namespace: flux-system
spec:
  dependsOn:
    - name: storage
  interval: 10m
  path: ./infrastructure/infra-cluster/services
  prune: true
  wait: true
  timeout: 15m
  retryInterval: 3m
  sourceRef:
    kind: GitRepository
    name: flux-system
  postBuild:
    substitute:
      CLUSTER_NAME: "infra"
      CLUSTER_DOMAIN: "monosense.io"
    substituteFrom:
      - kind: ConfigMap
        name: cluster-vars
        optional: false
```

#### Layer 4: Databases

```yaml
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: databases
  namespace: flux-system
spec:
  dependsOn:
    - name: platform-services
  interval: 10m
  path: ./infrastructure/infra-cluster/databases
  prune: true
  wait: true
  timeout: 10m
  retryInterval: 2m
  sourceRef:
    kind: GitRepository
    name: flux-system
  healthChecks:
    - apiVersion: postgresql.cnpg.io/v1
      kind: Cluster
      name: postgres
      namespace: databases
```

#### Layer 5: Observability

```yaml
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: observability
  namespace: flux-system
spec:
  dependsOn:
    - name: storage
    - name: platform-services
  interval: 10m
  path: ./infrastructure/infra-cluster/observability
  prune: true
  wait: true
  timeout: 10m
  retryInterval: 2m
  sourceRef:
    kind: GitRepository
    name: flux-system
```

### Apps Cluster Kustomization Stack

```yaml
---
# clusters/apps/infrastructure.yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: infra-minimal
  namespace: flux-system
spec:
  interval: 10m
  path: ./infrastructure/apps-cluster
  prune: true
  wait: true
  timeout: 10m
  sourceRef:
    kind: GitRepository
    name: flux-system
---
# clusters/apps/apps.yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: apps
  namespace: flux-system
spec:
  dependsOn:
    - name: infra-minimal
  interval: 5m
  path: ./apps/production
  prune: true
  wait: true
  timeout: 5m
  retryInterval: 1m
  sourceRef:
    kind: GitRepository
    name: flux-system
```

### Advanced Health Check Examples

#### Custom CEL Expressions

```yaml
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: rook-ceph-cluster
  namespace: flux-system
spec:
  # ... other fields ...
  healthCheckExprs:
    # Ceph cluster must be Ready and Healthy
    - apiVersion: ceph.rook.io/v1
      kind: CephCluster
      current: |
        status.phase == 'Ready' &&
        status.ceph.health == 'HEALTH_OK' &&
        status.ceph.lastChecked != ""
      failed: |
        status.phase == 'Failed' ||
        status.ceph.health == 'HEALTH_ERR'

    # CephBlockPool must be Ready
    - apiVersion: ceph.rook.io/v1
      kind: CephBlockPool
      current: status.phase == 'Ready'
      failed: status.phase == 'Failed'
```

### Handling Circular Dependencies

**Problem**: Cert-Manager needs ClusterIssuer, but ClusterIssuer needs Cert-Manager operator.

**Solution**: Split into layers

```yaml
---
# Layer 1: Cert-Manager Operator
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: cert-manager-operator
  namespace: flux-system
spec:
  path: ./infrastructure/base/operators/cert-manager
  wait: true
  # ...
---
# Layer 2: ClusterIssuer (depends on operator)
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: cert-manager-issuers
  namespace: flux-system
spec:
  dependsOn:
    - name: cert-manager-operator
  path: ./infrastructure/infra-cluster/cert-manager/issuers
  wait: true
  # ...
```

### Retry and Timeout Strategies

| Component | Timeout | Retry Interval | Rationale |
|-----------|---------|----------------|-----------|
| CRDs | 5m | - | Quick, no status |
| Operators | 10m | 2m | Can take time to pull images |
| Storage (Ceph) | 20m | 5m | Cluster initialization is slow |
| Databases | 10m | 2m | Depends on storage readiness |
| Applications | 5m | 1m | Should be quick |

---

## 6. Disaster Recovery Strategy

### Recovery Scenarios and Procedures

#### Scenario 1: Single Node Failure

**Impact**: Minimal (HA configuration)

**Recovery**:
1. Talos will automatically reschedule pods
2. Ceph will mark OSDs as down after 10min
3. No data loss (3x replication)
4. Replace node hardware if needed
5. Bootstrap Talos on new node
6. Ceph will automatically recover

#### Scenario 2: Apps Cluster Total Loss

**Impact**: Application downtime, no data loss

**Recovery Steps**:
```bash
# 1. Reinstall Talos on all apps nodes
talosctl apply-config --nodes 10.25.11.14 --file talos/controlplane/10.25.11.14.yaml
talosctl apply-config --nodes 10.25.11.15 --file talos/controlplane/10.25.11.15.yaml
talosctl apply-config --nodes 10.25.11.16 --file talos/controlplane/10.25.11.16.yaml

# 2. Bootstrap Flux
flux bootstrap github \
  --owner=<your-org> \
  --repository=k8s-gitops \
  --branch=main \
  --path=clusters/apps \
  --personal

# 3. Flux will reconcile everything from Git
# 4. Apps will mount existing Ceph volumes (no data loss)
# 5. Verify ClusterMesh connectivity
cilium clustermesh status --context apps
```

**RTO**: ~30 minutes
**RPO**: 0 (no data loss)

#### Scenario 3: Infra Cluster Total Loss

**Impact**: Complete platform outage

**Recovery Steps**:
```bash
# 1. Reinstall Talos on all infra nodes
talosctl apply-config --nodes 10.25.11.11 --file talos/controlplane/10.25.11.11.yaml
talosctl apply-config --nodes 10.25.11.12 --file talos/controlplane/10.25.11.12.yaml
talosctl apply-config --nodes 10.25.11.13 --file talos/controlplane/10.25.11.13.yaml

# 2. Bootstrap Flux
flux bootstrap github \
  --owner=<your-org> \
  --repository=k8s-gitops \
  --branch=main \
  --path=clusters/infra \
  --personal

# 3. Wait for Rook Ceph to initialize (20-30min)
kubectl -n rook-ceph get cephcluster

# 4. Restore PostgreSQL data from VolSync backups
kubectl apply -f infrastructure/infra-cluster/databases/postgres-restore.yaml

# 5. Verify Victoria Metrics data retention
# (Data will be lost if Ceph volumes are gone)
```

**RTO**: ~2 hours
**RPO**: 6 hours (VolSync backup interval)

#### Scenario 4: Both Clusters Lost

**Impact**: Complete infrastructure loss

**Recovery Steps**:
1. Follow "Scenario 3" for infra cluster
2. Restore databases from VolSync (MinIO S3)
3. Follow "Scenario 2" for apps cluster
4. Reconnect ClusterMesh
5. Verify all services

**RTO**: ~3 hours
**RPO**: 6 hours (VolSync)

#### Scenario 5: Ceph Data Corruption

**Impact**: Data loss risk

**Recovery**:
```bash
# 1. Check Ceph health
ceph health detail

# 2. If repairable, run scrub
ceph pg repair <pg-id>

# 3. If irreparable, restore from VolSync
kubectl apply -f volsync/restore/postgres-restore.yaml

# 4. Worst case: Rebuild Ceph cluster
kubectl -n rook-ceph delete cephcluster rook-ceph
# Wait for cleanup
kubectl apply -f infrastructure/infra-cluster/storage/rook-ceph-cluster.yaml
```

### Backup Verification Schedule

```yaml
---
apiVersion: batch/v1
kind: CronJob
metadata:
  name: backup-verification
  namespace: volsync-system
spec:
  schedule: "0 3 * * 1"  # Every Monday at 3 AM
  jobTemplate:
    spec:
      template:
        spec:
          containers:
            - name: verify
              image: restic/restic:latest
              command:
                - /bin/sh
                - -c
                - |
                  # Verify all Restic repositories
                  restic -r $RESTIC_REPOSITORY check --read-data-subset=5%
              envFrom:
                - secretRef:
                    name: volsync-restic-config
```

### Disaster Recovery Testing Schedule

| Test | Frequency | Last Tested | Next Test |
|------|-----------|-------------|-----------|
| Single pod failure | Weekly | Auto | Auto |
| Single node failure | Monthly | - | - |
| Restore single PVC | Monthly | - | - |
| Apps cluster rebuild | Quarterly | - | - |
| Full DR drill | Annually | - | - |

---

## Summary and Recommendations

### Key Takeaways

1. **Backup Strategy**: Use **VolSync** for continuous PVC replication + **Velero** for cluster-wide DR
2. **Rook Ceph**: Configure 3-way replication, 4GB OSD memory, BlueStore optimization for NVMe
3. **Victoria Metrics**: Centralized on infra cluster, VMAgent remote-write from apps cluster
4. **Cilium**: BGP Control Plane for LoadBalancer, ClusterMesh for cross-cluster services
5. **FluxCD**: Layer dependencies (CRDs → Operators → Storage → Services → Apps)
6. **DR**: RTO 30min-3hr, RPO 0-6hr depending on scenario

### Next Steps

1. **Implement VolSync** for critical PVCs (PostgreSQL, etc.)
2. **Configure Cilium BGP** on Juniper SRX320
3. **Deploy Victoria Metrics** on infra cluster
4. **Set up FluxCD** Kustomization dependencies
5. **Test disaster recovery** procedures monthly

---

*Document version: 1.0*
*Last updated: 2025-10-14*
