# 31 — STORY-STO-APPS-ROOK-CEPH-CLUSTER — Create Ceph Cluster Manifests (apps)

Sequence: 31/50 | Prev: STORY-STO-APPS-ROOK-CEPH-OPERATOR.md | Next: STORY-CICD-GITHUB-ARC.md
Sprint: 6 | Lane: Storage
Global Sequence: 31/50

Status: Draft (v3.0 Refinement)
Owner: Platform Engineering
Date: 2025-10-26
Links: kubernetes/infrastructure/storage/rook-ceph/cluster/; kubernetes/clusters/apps/cluster-settings.yaml

## Story

As a platform engineer, I want to **create manifests for a Rook-Ceph cluster on the apps cluster** so that we have distributed, highly-available storage for stateful workloads requiring data durability, multi-replica support, and RWX access modes, with local node NVMe devices to avoid L3 traffic through the 1 Gbps router.

## Why / Outcome

- **Distributed storage**: 3-node Ceph cluster with data replication
- **High availability**: Survives single-node failures with automatic recovery
- **Data durability**: 3x replication for critical workloads
- **Local storage**: NVMe devices on apps nodes, no cross-cluster network traffic
- **Dynamic provisioning**: RBD and CephFS StorageClasses for block and shared filesystem storage
- **Complementary to OpenEBS**: Rook-Ceph for durability, OpenEBS for performance

## Scope

### This Story (Manifest Creation)

**CREATE** the following manifests (local-only work):

1. **Ceph Cluster Infrastructure** (`kubernetes/infrastructure/storage/rook-ceph/cluster/`):
   - CephCluster CR with 3 MONs, 3 MGRs, OSDs on NVMe devices
   - CephBlockPool for RBD volumes
   - CephFilesystem for CephFS volumes (optional)
   - StorageClasses for RBD and CephFS
   - Toolbox Deployment for diagnostics
   - PodMonitor for Ceph metrics
   - PrometheusRule for Ceph alerting
   - PodDisruptionBudgets for MON and MGR

2. **Flux Kustomizations**:
   - Infrastructure Kustomization for Ceph cluster stack
   - Health checks for CephCluster
   - Dependency ordering (requires operator)

3. **Documentation**:
   - Comprehensive README for Ceph cluster deployment
   - Architecture overview
   - Troubleshooting procedures

**DO NOT**:
- Deploy to apps cluster
- Run validation commands requiring cluster access
- Test Ceph cluster health
- Verify PVC provisioning

### Deferred to Story 45 (Deployment & Validation)

Story 45 will handle:
- Applying manifests to apps cluster via Flux
- Verifying Ceph cluster HEALTH_OK status
- Testing RBD PVC provisioning
- Testing CephFS PVC provisioning (if enabled)
- Validating Ceph toolbox diagnostics
- Smoke testing with sample workloads

## Acceptance Criteria

### Manifest Creation (This Story)

**AC1**: Ceph cluster manifests created under `kubernetes/infrastructure/storage/rook-ceph/cluster/`:
- `cephcluster.yaml` with 3 MONs, 3 MGRs, OSDs on NVMe
- `cephblockpool.yaml` for RBD volumes
- `cephfilesystem.yaml` for CephFS volumes (optional)
- `storageclass-rbd.yaml` for block storage
- `storageclass-cephfs.yaml` for shared filesystem (optional)
- `toolbox.yaml` for diagnostics
- `kustomization.yaml`

**AC2**: CephCluster configured with:
- 3 MON replicas (quorum for HA)
- 3 MGR replicas (active-standby)
- OSDs using NVMe devices by device path (`/dev/disk/by-id/...`)
- Ceph version: Reef or Quincy (latest stable)
- Network: host networking or Multus (if available)
- Placement: node affinity for storage nodes
- Resource limits for MON, MGR, OSD pods

**AC3**: CephBlockPool configured:
- Name: `${CEPH_BLOCK_POOL_NAME}` (default: `replicapool`)
- Replicas: `${CEPH_BLOCK_POOL_REPLICAS}` (default: 3)
- Failure domain: host (tolerate single-node failure)
- Compression: none (or lz4 for space savings)
- Device class: ssd (for NVMe devices)

**AC4**: StorageClasses configured:
- RBD StorageClass: `${CEPH_BLOCK_STORAGE_CLASS}` (default: `rook-ceph-block`)
  - Provisioner: `rbd.csi.ceph.com`
  - VolumeBindingMode: Immediate
  - ReclaimPolicy: Delete (configurable to Retain)
  - AllowVolumeExpansion: true
  - Parameters: pool, imageFormat, imageFeatures
- CephFS StorageClass (optional): `${CEPH_FS_STORAGE_CLASS}`
  - Provisioner: `cephfs.csi.ceph.com`
  - VolumeBindingMode: Immediate
  - ReclaimPolicy: Delete
  - AllowVolumeExpansion: true

**AC5**: Monitoring configured:
- PodMonitor scraping Ceph MGR metrics (port 9283)
- PrometheusRule with alerts for:
  - Ceph cluster health not OK
  - MON quorum at risk
  - OSD down or out
  - PG degraded or inconsistent
  - Storage capacity warnings
  - Slow OPS warnings

**AC6**: High availability configured:
- PodDisruptionBudget for MONs (minAvailable: 2 of 3)
- PodDisruptionBudget for MGRs (minAvailable: 1 of 3)
- Placement rules for pod anti-affinity
- Tolerations for control plane taints (if needed)

**AC7**: All manifests pass local validation:
- `kubectl --dry-run=client` succeeds
- `flux build kustomization` succeeds
- `kubeconform` validation passes
- YAML linting passes

**AC8**: Documentation includes:
- Ceph cluster architecture overview
- MON/MGR/OSD components explained
- Device selection strategy (by-id paths for stability)
- Troubleshooting guide (toolbox usage, Ceph status, OSD issues)
- Capacity planning and scaling
- Upgrade procedures

### Deferred to Story 45 (NOT validated in this Story)

- Ceph cluster deployed and HEALTH_OK
- MONs in quorum
- MGRs active
- OSDs up and in
- RBD PVC provisioning working
- CephFS PVC provisioning working (if enabled)
- Toolbox operational
- Monitoring alerts configured

## Dependencies / Inputs

**Local Tools Required**:
- `kubectl` (for dry-run validation)
- `flux` CLI (for `flux build kustomization`)
- `yq` (for YAML processing)
- `kubeconform` (for schema validation)

**Story Dependencies**:
- **STORY-STO-APPS-ROOK-CEPH-OPERATOR** (Story 30): Rook operator must be deployed first

**Configuration Inputs**:
- `${CEPH_VERSION}`: Ceph image version (default: v18 for Reef, v17 for Quincy)
- `${CEPH_BLOCK_POOL_NAME}`: Block pool name (default: `replicapool`)
- `${CEPH_BLOCK_POOL_REPLICAS}`: Replication factor (default: 3)
- `${CEPH_BLOCK_STORAGE_CLASS}`: RBD StorageClass name (default: `rook-ceph-block`)
- `${CEPH_FS_STORAGE_CLASS}`: CephFS StorageClass name (default: `rook-ceph-fs`)
- `${CEPH_OSD_DEVICES}`: Comma-separated list of device IDs per node

## Tasks / Subtasks

### T1: Prerequisites and Strategy
- Review Ceph cluster architecture (MON, MGR, OSD, MDS)
- Determine device selection strategy (by-id for stability)
- Plan capacity and replication factor
- Review network configuration (host vs Multus)

### T2: CephCluster CR
- Create `kubernetes/infrastructure/storage/rook-ceph/cluster/cephcluster.yaml`:
  - CephCluster: `rook-ceph`
  - Namespace: `rook-ceph`
  - Ceph version: `${CEPH_VERSION}` (v18 Reef or v17 Quincy)
  - Network:
    - Provider: host (or multus if available)
    - Dual stack: false (IPv4 only)
  - MON:
    - Count: 3 (quorum requirement)
    - AllowMultiplePerNode: false (spread across nodes)
    - VolumeClaimTemplate: 10Gi PVC on `${BLOCK_SC}` (OpenEBS or other local storage)
  - MGR:
    - Count: 3 (active-standby)
    - AllowMultiplePerNode: false
    - Modules: dashboard enabled, prometheus enabled
  - Dashboard:
    - Enabled: true (web UI for diagnostics)
    - SSL: true
  - Monitoring:
    - Enabled: true (Prometheus metrics)
  - Storage:
    - UseAllNodes: false (use node selector)
    - UseAllDevices: false (explicit device list)
    - Nodes:
      - Name: apps-node-1
        Devices:
          - Name: `/dev/disk/by-id/${CEPH_OSD_DEVICE_NODE1}`
      - Name: apps-node-2
        Devices:
          - Name: `/dev/disk/by-id/${CEPH_OSD_DEVICE_NODE2}`
      - Name: apps-node-3
        Devices:
          - Name: `/dev/disk/by-id/${CEPH_OSD_DEVICE_NODE3}`
    - Config:
      - OsdMemoryTarget: 4096 (4GB RAM per OSD)
      - StoreType: bluestore (default)
  - Placement:
    - MON: node anti-affinity
    - MGR: node anti-affinity
    - OSD: node affinity (storage nodes only)
  - Resources:
    - MON: 1000m CPU, 1024Mi memory (limits), 500m CPU, 512Mi memory (requests)
    - MGR: 1000m CPU, 1024Mi memory (limits), 500m CPU, 512Mi memory (requests)
    - OSD: 2000m CPU, 4096Mi memory (limits), 1000m CPU, 2048Mi memory (requests)
  - PriorityClassNames:
    - MON: system-cluster-critical
    - MGR: system-cluster-critical
    - OSD: system-node-critical
  - ContinueUpgradeAfterChecksEvenIfNotHealthy: false (safe upgrades)

### T3: CephBlockPool CR
- Create `kubernetes/infrastructure/storage/rook-ceph/cluster/cephblockpool.yaml`:
  - CephBlockPool: `${CEPH_BLOCK_POOL_NAME}`
  - Namespace: `rook-ceph`
  - Spec:
    - FailureDomain: host (tolerate single-node failure)
    - Replicated:
      - Size: `${CEPH_BLOCK_POOL_REPLICAS}` (3 for HA)
      - RequireSafeReplicaSize: true
      - ReplicasPerFailureDomain: 1
    - DeviceClass: ssd (for NVMe devices)
    - Compression:
      - Mode: none (or aggressive with algorithm lz4)
    - Quotas:
      - MaxBytes: 0 (unlimited, or set quota)
      - MaxObjects: 0 (unlimited)
    - EnableRBDStats: true (for monitoring)

### T4: CephFilesystem CR (Optional)
- Create `kubernetes/infrastructure/storage/rook-ceph/cluster/cephfilesystem.yaml`:
  - CephFilesystem: `${CEPH_FS_NAME}` (default: `cephfs`)
  - Namespace: `rook-ceph`
  - Spec:
    - MetadataPool:
      - Replicated:
        - Size: 3
        - RequireSafeReplicaSize: true
      - FailureDomain: host
      - DeviceClass: ssd
    - DataPools:
      - Replicated:
        - Size: 3
        - RequireSafeReplicaSize: true
      - FailureDomain: host
      - DeviceClass: ssd
      - Compression:
        - Mode: none
    - MetadataServer:
      - ActiveCount: 1 (single active MDS)
      - ActiveStandby: true (standby MDS for HA)
      - Placement: node anti-affinity
      - Resources: 1000m CPU, 1024Mi memory (limits)
      - PriorityClassName: system-cluster-critical

### T5: RBD StorageClass
- Create `kubernetes/infrastructure/storage/rook-ceph/cluster/storageclass-rbd.yaml`:
  - StorageClass: `${CEPH_BLOCK_STORAGE_CLASS}`
  - Provisioner: `rook-ceph.rbd.csi.ceph.com`
  - Parameters:
    - clusterID: `rook-ceph`
    - pool: `${CEPH_BLOCK_POOL_NAME}`
    - imageFormat: "2"
    - imageFeatures: `layering` (minimal features for compatibility)
    - csi.storage.k8s.io/provisioner-secret-name: `rook-csi-rbd-provisioner`
    - csi.storage.k8s.io/provisioner-secret-namespace: `rook-ceph`
    - csi.storage.k8s.io/controller-expand-secret-name: `rook-csi-rbd-provisioner`
    - csi.storage.k8s.io/controller-expand-secret-namespace: `rook-ceph`
    - csi.storage.k8s.io/node-stage-secret-name: `rook-csi-rbd-node`
    - csi.storage.k8s.io/node-stage-secret-namespace: `rook-ceph`
    - csi.storage.k8s.io/fstype: `ext4`
  - ReclaimPolicy: Delete (or Retain for production)
  - AllowVolumeExpansion: true
  - VolumeBindingMode: Immediate
  - MountOptions: [discard] (for SSD TRIM support)

### T6: CephFS StorageClass (Optional)
- Create `kubernetes/infrastructure/storage/rook-ceph/cluster/storageclass-cephfs.yaml`:
  - StorageClass: `${CEPH_FS_STORAGE_CLASS}`
  - Provisioner: `rook-ceph.cephfs.csi.ceph.com`
  - Parameters:
    - clusterID: `rook-ceph`
    - fsName: `${CEPH_FS_NAME}`
    - pool: `${CEPH_FS_NAME}-data0`
    - csi.storage.k8s.io/provisioner-secret-name: `rook-csi-cephfs-provisioner`
    - csi.storage.k8s.io/provisioner-secret-namespace: `rook-ceph`
    - csi.storage.k8s.io/controller-expand-secret-name: `rook-csi-cephfs-provisioner`
    - csi.storage.k8s.io/controller-expand-secret-namespace: `rook-ceph`
    - csi.storage.k8s.io/node-stage-secret-name: `rook-csi-cephfs-node`
    - csi.storage.k8s.io/node-stage-secret-namespace: `rook-ceph`
  - ReclaimPolicy: Delete
  - AllowVolumeExpansion: true
  - VolumeBindingMode: Immediate

### T7: Ceph Toolbox Deployment
- Create `kubernetes/infrastructure/storage/rook-ceph/cluster/toolbox.yaml`:
  - Deployment: `rook-ceph-tools`
  - Namespace: `rook-ceph`
  - Image: `rook/ceph:${ROOK_CEPH_VERSION}`
  - Command: `/bin/bash`, `-c`, `sleep infinity`
  - Resources: 100m CPU, 128Mi memory
  - VolumeMounts: Ceph config and keyring
  - SecurityContext: privileged (for Ceph admin commands)

### T8: PodDisruptionBudgets
- Create `kubernetes/infrastructure/storage/rook-ceph/cluster/poddisruptionbudgets.yaml`:
  - PDB for MONs: minAvailable 2 (maintain quorum during disruptions)
  - PDB for MGRs: minAvailable 1 (at least one MGR active)
  - Selector: `app=rook-ceph-mon` and `app=rook-ceph-mgr`

### T9: Ceph Monitoring
- Create `kubernetes/infrastructure/storage/rook-ceph/cluster/podmonitor.yaml`:
  - PodMonitor: `rook-ceph-mgr`
  - Namespace selector: `rook-ceph`
  - Pod selector: `app=rook-ceph-mgr`
  - Port: http-metrics (9283)
  - Path: `/metrics`
  - Labels for VictoriaMetrics discovery

### T10: Ceph Alerting
- Create `kubernetes/infrastructure/storage/rook-ceph/cluster/prometheusrule.yaml`:
  - VMRule: `rook-ceph-cluster-alerts`
  - Alert groups:
    - **CephClusterNotHealthy**: Ceph health not HEALTH_OK for 5 minutes
    - **CephMonQuorumAtRisk**: MON quorum <3 for 5 minutes
    - **CephOSDDown**: OSD down for 5 minutes
    - **CephOSDOut**: OSD out (data migration triggered)
    - **CephPGDegraded**: PGs degraded >10% for 10 minutes
    - **CephPGInconsistent**: PGs inconsistent (data corruption risk)
    - **CephStorageNearFull**: Cluster storage >80% full
    - **CephStorageCritical**: Cluster storage >90% full
    - **CephSlowOps**: Slow OPS detected (>10 slow ops for 5 minutes)
    - **CephMGRInactive**: No active MGR for 5 minutes

### T11: Rook-Ceph Cluster Kustomization
- Create `kubernetes/infrastructure/storage/rook-ceph/cluster/kustomization.yaml`:
  - Resources: cephcluster, cephblockpool, cephfilesystem (optional), storageclass-rbd, storageclass-cephfs (optional), toolbox, poddisruptionbudgets, podmonitor, prometheusrule
  - Namespace: `rook-ceph`
  - CommonLabels: `app.kubernetes.io/part-of=rook-ceph-cluster`

### T12: Rook-Ceph Cluster Flux Kustomization
- Create `kubernetes/infrastructure/storage/rook-ceph/cluster/ks.yaml`:
  - Kustomization: `cluster-apps-rook-ceph-cluster`
  - Source: GitRepository/flux-system
  - Path: `./kubernetes/infrastructure/storage/rook-ceph/cluster`
  - Interval: 10m
  - Prune: false (do not delete Ceph cluster on removal)
  - Wait: true
  - Timeout: 15m (Ceph cluster creation takes time)
  - Health checks:
    - CephCluster/rook-ceph (status.phase=Ready, status.ceph.health=HEALTH_OK)
  - DependsOn:
    - cluster-apps-rook-ceph-operator (requires operator)
    - cluster-apps-openebs (for MON PVCs)

### T13: Infrastructure Kustomization Update
- Update `kubernetes/infrastructure/storage/rook-ceph/kustomization.yaml`:
  - Add `./cluster` to resources

### T14: Rook-Ceph Cluster README
- Create `kubernetes/infrastructure/storage/rook-ceph/cluster/README.md`:
  - **Architecture Overview**:
    - 3-node Ceph cluster
    - 3 MONs (quorum), 3 MGRs (active-standby), OSDs on NVMe
    - CephBlockPool for RBD volumes (3x replication)
    - CephFilesystem for CephFS volumes (optional, 3x replication)
  - **Components**:
    - MON: Monitors cluster state, maintain quorum
    - MGR: Manages cluster operations, provides dashboard and metrics
    - OSD: Object Storage Daemon, stores data on disks
    - MDS: Metadata Server (for CephFS only)
  - **Device Selection**:
    - Use `/dev/disk/by-id/` paths (stable across reboots)
    - Example: `/dev/disk/by-id/nvme-Samsung_SSD_970_EVO_Plus_1TB_<serial>`
    - List devices: `ls -la /dev/disk/by-id/ | grep nvme`
  - **Toolbox Usage**:
    - Access toolbox: `kubectl exec -n rook-ceph -it deploy/rook-ceph-tools -- bash`
    - Check cluster status: `ceph -s`
    - Check OSD status: `ceph osd tree`
    - Check PG status: `ceph pg stat`
    - Check storage usage: `ceph df`
    - Check MON quorum: `ceph mon stat`
  - **Troubleshooting**:
    - Cluster not HEALTH_OK: `ceph health detail`
    - OSD not starting: Check device path, wipefs clean, operator logs
    - MON quorum lost: Check network, MON pod logs
    - Slow OPS: Check OSD performance, network latency
    - PG degraded: Wait for rebalance, check OSD status
  - **Capacity Planning**:
    - Raw capacity: 3 nodes × disk size
    - Usable capacity: raw capacity / replication factor (÷3)
    - Example: 3 × 1TB NVMe = 3TB raw, 1TB usable (with 3x replication)
  - **Scaling**:
    - Add nodes: Update CephCluster with new node + device
    - Add OSDs: Add devices to existing nodes
    - Ceph rebalances automatically
  - **Upgrade Procedures**:
    - Operator upgrade (Story 30) triggers Ceph version upgrade
    - Rolling upgrade: MONs → MGRs → OSDs → MDS
    - Monitor upgrade: `ceph versions`

### T15: Cluster Settings Update
- Update `kubernetes/clusters/apps/cluster-settings.yaml`:
  - Add Ceph cluster configuration:
    ```yaml
    CEPH_VERSION: "v18"  # Reef (or "v17" for Quincy)
    CEPH_BLOCK_POOL_NAME: "replicapool"
    CEPH_BLOCK_POOL_REPLICAS: "3"
    CEPH_BLOCK_STORAGE_CLASS: "rook-ceph-block"
    CEPH_FS_NAME: "cephfs"
    CEPH_FS_STORAGE_CLASS: "rook-ceph-fs"
    CEPH_OSD_DEVICE_NODE1: "nvme-Samsung_SSD_970_EVO_Plus_1TB_<serial1>"
    CEPH_OSD_DEVICE_NODE2: "nvme-Samsung_SSD_970_EVO_Plus_1TB_<serial2>"
    CEPH_OSD_DEVICE_NODE3: "nvme-Samsung_SSD_970_EVO_Plus_1TB_<serial3>"
    ```

### T16: Local Validation
- Run validation commands:
  - `kubectl --dry-run=client apply -f kubernetes/infrastructure/storage/rook-ceph/cluster/`
  - `flux build kustomization cluster-apps-rook-ceph-cluster --path ./kubernetes/infrastructure/storage/rook-ceph/cluster`
  - `kubeconform -summary -output pretty kubernetes/infrastructure/storage/rook-ceph/cluster/*.yaml`
  - `yamllint kubernetes/infrastructure/storage/rook-ceph/cluster/`
- Verify CephCluster spec syntax
- Validate device paths format

### T17: Git Commit
- Stage all changes
- Commit: "feat(storage): add Rook-Ceph cluster manifests for apps cluster (Story 31)"

## Runtime Validation (MOVED TO STORY 45)

**The following validation steps require a running cluster and are deferred to Story 45:**

### Ceph Cluster Validation
```bash
# Check CephCluster CR
kubectl --context=apps -n rook-ceph get cephcluster rook-ceph

# Check cluster health
kubectl --context=apps -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph -s
# Expected: HEALTH_OK (or HEALTH_WARN with rebalancing in progress)

# Check MON status
kubectl --context=apps -n rook-ceph get pod -l app=rook-ceph-mon
kubectl --context=apps -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph mon stat
# Expected: 3 mons in quorum

# Check MGR status
kubectl --context=apps -n rook-ceph get pod -l app=rook-ceph-mgr
kubectl --context=apps -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph mgr stat
# Expected: 1 active MGR, 2 standbys

# Check OSD status
kubectl --context=apps -n rook-ceph get pod -l app=rook-ceph-osd
kubectl --context=apps -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph osd tree
# Expected: 3 OSDs up and in

# Check cluster capacity
kubectl --context=apps -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph df
```

### CephBlockPool Validation
```bash
# Check CephBlockPool CR
kubectl --context=apps -n rook-ceph get cephblockpool ${CEPH_BLOCK_POOL_NAME}

# Check pool status
kubectl --context=apps -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph osd pool ls detail
# Expected: replicapool with size 3

# Check PG status
kubectl --context=apps -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph pg stat
# Expected: all PGs active+clean
```

### CephFilesystem Validation (if enabled)
```bash
# Check CephFilesystem CR
kubectl --context=apps -n rook-ceph get cephfilesystem ${CEPH_FS_NAME}

# Check MDS status
kubectl --context=apps -n rook-ceph get pod -l app=rook-ceph-mds
kubectl --context=apps -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph fs status ${CEPH_FS_NAME}
# Expected: 1 active MDS, 1 standby
```

### StorageClass Validation
```bash
# Check RBD StorageClass
kubectl --context=apps get sc ${CEPH_BLOCK_STORAGE_CLASS}
kubectl --context=apps get sc ${CEPH_BLOCK_STORAGE_CLASS} -o yaml

# Check CephFS StorageClass (if enabled)
kubectl --context=apps get sc ${CEPH_FS_STORAGE_CLASS}
```

### RBD PVC Provisioning Test
```bash
# Create test PVC
cat <<EOF | kubectl --context=apps apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: rbd-test-pvc
  namespace: default
spec:
  storageClassName: ${CEPH_BLOCK_STORAGE_CLASS}
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
EOF

# Wait for PVC to bind
kubectl --context=apps wait --for=jsonpath='{.status.phase}'=Bound pvc/rbd-test-pvc --timeout=60s

# Check PVC and PV
kubectl --context=apps get pvc rbd-test-pvc
kubectl --context=apps get pv

# Create test pod
cat <<EOF | kubectl --context=apps apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: rbd-test-pod
  namespace: default
spec:
  containers:
    - name: test
      image: busybox
      command: ["sh", "-c", "echo 'Ceph RBD test' > /data/test.txt && cat /data/test.txt && sleep 3600"]
      volumeMounts:
        - name: data
          mountPath: /data
  volumes:
    - name: data
      persistentVolumeClaim:
        claimName: rbd-test-pvc
EOF

# Wait for pod
kubectl --context=apps wait --for=condition=Ready pod/rbd-test-pod --timeout=60s

# Verify data written
kubectl --context=apps exec rbd-test-pod -- cat /data/test.txt
# Expected: Ceph RBD test

# Cleanup
kubectl --context=apps delete pod rbd-test-pod
kubectl --context=apps delete pvc rbd-test-pvc
```

### CephFS PVC Provisioning Test (if enabled)
```bash
# Create test PVC
cat <<EOF | kubectl --context=apps apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: cephfs-test-pvc
  namespace: default
spec:
  storageClassName: ${CEPH_FS_STORAGE_CLASS}
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 1Gi
EOF

# Wait for PVC to bind
kubectl --context=apps wait --for=jsonpath='{.status.phase}'=Bound pvc/cephfs-test-pvc --timeout=60s

# Create two test pods (RWX test)
cat <<EOF | kubectl --context=apps apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: cephfs-test-pod-1
  namespace: default
spec:
  containers:
    - name: test
      image: busybox
      command: ["sh", "-c", "echo 'Pod 1' > /data/pod1.txt && sleep 3600"]
      volumeMounts:
        - name: data
          mountPath: /data
  volumes:
    - name: data
      persistentVolumeClaim:
        claimName: cephfs-test-pvc
---
apiVersion: v1
kind: Pod
metadata:
  name: cephfs-test-pod-2
  namespace: default
spec:
  containers:
    - name: test
      image: busybox
      command: ["sh", "-c", "sleep 10 && cat /data/pod1.txt && sleep 3600"]
      volumeMounts:
        - name: data
          mountPath: /data
  volumes:
    - name: data
      persistentVolumeClaim:
        claimName: cephfs-test-pvc
EOF

# Wait for pods
kubectl --context=apps wait --for=condition=Ready pod/cephfs-test-pod-1 --timeout=60s
kubectl --context=apps wait --for=condition=Ready pod/cephfs-test-pod-2 --timeout=60s

# Verify RWX (pod 2 can read file written by pod 1)
kubectl --context=apps logs cephfs-test-pod-2
# Expected: Pod 1

# Cleanup
kubectl --context=apps delete pod cephfs-test-pod-1 cephfs-test-pod-2
kubectl --context=apps delete pvc cephfs-test-pvc
```

### Toolbox Validation
```bash
# Check toolbox deployment
kubectl --context=apps -n rook-ceph get deploy rook-ceph-tools

# Access toolbox
kubectl --context=apps -n rook-ceph exec -it deploy/rook-ceph-tools -- bash

# Inside toolbox:
ceph -s                    # Cluster status
ceph health detail         # Health details
ceph osd tree              # OSD topology
ceph pg stat               # PG status
ceph df                    # Storage usage
ceph mon stat              # MON quorum
ceph mgr stat              # MGR status
ceph versions              # Component versions
rados df                   # Pool usage
```

### Monitoring Validation
```bash
# Check PodMonitor discovered
kubectl --context=apps -n observability get podmonitor -l app.kubernetes.io/name=rook-ceph

# Query Ceph metrics
kubectl --context=apps -n rook-ceph port-forward svc/rook-ceph-mgr 9283:9283 &
curl -s http://localhost:9283/metrics | grep ceph_

# Check alerts configured
kubectl --context=apps -n observability get vmrule rook-ceph-cluster-alerts -o yaml

# Verify metrics in VictoriaMetrics
# Query: ceph_health_status
# Query: ceph_osd_up
# Query: ceph_pg_degraded_total
```

### PodDisruptionBudget Validation
```bash
# Check PDBs
kubectl --context=apps -n rook-ceph get pdb

# Verify PDB for MONs
kubectl --context=apps -n rook-ceph get pdb rook-ceph-mon -o yaml
# Expected: minAvailable: 2

# Verify PDB for MGRs
kubectl --context=apps -n rook-ceph get pdb rook-ceph-mgr -o yaml
# Expected: minAvailable: 1
```

## Definition of Done

### Manifest Creation Complete (This Story)

- [x] All acceptance criteria AC1-AC8 met
- [x] Ceph cluster manifests created under `kubernetes/infrastructure/storage/rook-ceph/cluster/`
- [x] CephCluster CR configured with 3 MONs, 3 MGRs, OSDs on NVMe
- [x] CephBlockPool and StorageClasses created
- [x] Toolbox Deployment configured
- [x] Flux Kustomization created for Ceph cluster stack
- [x] Monitoring configured (PodMonitor, PrometheusRules)
- [x] PodDisruptionBudgets for HA
- [x] All manifests pass local validation (dry-run, flux build, kubeconform)
- [x] Comprehensive README documentation created
- [x] Cluster settings updated with Ceph configuration
- [x] Changes committed to git with descriptive message

### NOT Part of DoD (Moved to Story 45)

The following are **explicitly deferred** to Story 45:
- Ceph cluster deployed and HEALTH_OK
- MONs in quorum
- MGRs active
- OSDs up and in
- RBD PVC provisioning tested
- CephFS PVC provisioning tested (if enabled)
- Toolbox operational for diagnostics
- Monitoring alerts firing correctly
- End-to-end smoke tests

## Design Notes

### Ceph Cluster Architecture

**Components**:
1. **MON (Monitor)**: 3 replicas
   - Maintains cluster membership and state
   - Provides quorum (majority voting)
   - Minimum 3 for HA (tolerate 1 failure)
   - Stores cluster map (CRUSH, monitor, OSD, PG maps)

2. **MGR (Manager)**: 3 replicas (active-standby)
   - Manages cluster operations
   - Provides dashboard (web UI)
   - Exposes Prometheus metrics
   - Only 1 active at a time

3. **OSD (Object Storage Daemon)**: 3+ replicas
   - Stores actual data on disks
   - One OSD per disk
   - Handles replication and recovery
   - Heartbeats with other OSDs

4. **MDS (Metadata Server)**: For CephFS only
   - Manages filesystem metadata
   - 1 active, 1+ standby for HA
   - Not needed for RBD (block storage)

### Device Selection Strategy

**Use `/dev/disk/by-id/` paths**:
- Stable across reboots (unlike `/dev/sdX`)
- Survives disk reordering
- Unique per physical device

**Finding device IDs**:
```bash
# List all NVMe devices by ID
ls -la /dev/disk/by-id/ | grep nvme

# Example output:
# nvme-Samsung_SSD_970_EVO_Plus_1TB_S4EWNX0M123456A -> ../../nvme0n1
# nvme-Samsung_SSD_970_EVO_Plus_1TB_S4EWNX0M123456B -> ../../nvme1n1
# nvme-Samsung_SSD_970_EVO_Plus_1TB_S4EWNX0M123456C -> ../../nvme2n1

# Verify device is clean
lsblk -f /dev/disk/by-id/nvme-Samsung_SSD_970_EVO_Plus_1TB_S4EWNX0M123456A
# Should show no filesystem or partitions
```

**CephCluster device configuration**:
```yaml
storage:
  nodes:
    - name: apps-node-1
      devices:
        - name: /dev/disk/by-id/nvme-Samsung_SSD_970_EVO_Plus_1TB_S4EWNX0M123456A
    - name: apps-node-2
      devices:
        - name: /dev/disk/by-id/nvme-Samsung_SSD_970_EVO_Plus_1TB_S4EWNX0M123456B
    - name: apps-node-3
      devices:
        - name: /dev/disk/by-id/nvme-Samsung_SSD_970_EVO_Plus_1TB_S4EWNX0M123456C
```

### Replication and Failure Domains

**Failure Domain: host**:
- Replicas distributed across nodes
- Tolerate single-node failure
- 3 replicas = 2 nodes must be up

**Replication Factor**:
- **Size 3**: 3 copies of data
- **Usable capacity**: Raw capacity ÷ 3
- Example: 3TB raw (3 × 1TB NVMe) = 1TB usable

**CRUSH Map**:
- Ceph's placement algorithm
- Ensures replicas on different hosts
- Automatic data placement and rebalancing

### MON Quorum

**Quorum Requirement**:
- Majority of MONs must be available
- 3 MONs → need 2 for quorum
- 5 MONs → need 3 for quorum

**Why 3 MONs**:
- Tolerate 1 MON failure
- Maintain quorum with 2 remaining
- 2 MONs = no fault tolerance (1 failure loses quorum)
- 5 MONs = same fault tolerance as 3 (waste resources)

**MON Placement**:
- Anti-affinity: 1 MON per node
- PVC for state persistence (10Gi)
- Priority: system-cluster-critical

### Storage Classes

**RBD StorageClass**:
- **Use case**: Block storage for databases
- **Access mode**: ReadWriteOnce (RWO)
- **Provisioner**: `rook-ceph.rbd.csi.ceph.com`
- **Image format**: 2 (stable)
- **Image features**: `layering` (minimal for compatibility)
- **Filesystem**: ext4 (or xfs)
- **Mount options**: `discard` (for SSD TRIM)

**CephFS StorageClass** (optional):
- **Use case**: Shared filesystem for multi-pod access
- **Access mode**: ReadWriteMany (RWX)
- **Provisioner**: `rook-ceph.cephfs.csi.ceph.com`
- **MDS**: Required (1 active, 1 standby)
- **Performance**: Lower than RBD (filesystem overhead)

### Resource Sizing

**MON**:
- Requests: 500m CPU, 512Mi memory
- Limits: 1000m CPU, 1024Mi memory
- Storage: 10Gi PVC per MON (for cluster state)

**MGR**:
- Requests: 500m CPU, 512Mi memory
- Limits: 1000m CPU, 1024Mi memory
- Dashboard and metrics enabled

**OSD**:
- Requests: 1000m CPU, 2048Mi memory
- Limits: 2000m CPU, 4096Mi memory
- Memory target: 4GB per OSD (for BlueStore cache)

**MDS** (if CephFS):
- Requests: 500m CPU, 512Mi memory
- Limits: 1000m CPU, 1024Mi memory
- 1 active, 1 standby for HA

### High Availability

**MON HA**:
- 3 MONs with quorum (2 of 3 required)
- PDB: minAvailable 2 (maintain quorum during disruptions)
- Anti-affinity: spread across nodes

**MGR HA**:
- 3 MGRs (1 active, 2 standby)
- PDB: minAvailable 1 (at least one MGR)
- Automatic failover on active MGR failure

**OSD HA**:
- Data replicated 3x across nodes
- Automatic recovery on OSD failure
- Rebalancing to maintain replica count

**MDS HA** (if CephFS):
- 1 active, 1+ standby
- Automatic failover on active MDS failure

### Capacity Planning

**Calculation**:
```
Raw capacity = nodes × disk size
Usable capacity = raw capacity ÷ replication factor
Overhead = ~10% for Ceph metadata

Example:
- 3 nodes × 1TB NVMe = 3TB raw
- Replication factor: 3
- Usable: 3TB ÷ 3 = 1TB
- After overhead: ~900GB usable
```

**Growth Planning**:
- Add nodes: Update CephCluster with new node
- Add OSDs: Add more disks to existing nodes
- Ceph rebalances automatically (slow ops during rebalance)

### Monitoring and Alerting

**Key Metrics**:
- `ceph_health_status`: Overall cluster health (0=OK, 1=WARN, 2=ERR)
- `ceph_mon_quorum_status`: MON quorum status
- `ceph_osd_up`: Number of OSDs up
- `ceph_osd_in`: Number of OSDs in
- `ceph_pg_degraded_total`: Degraded PGs (data at risk)
- `ceph_pg_inconsistent_total`: Inconsistent PGs (corruption)
- `ceph_cluster_total_bytes`: Total storage capacity
- `ceph_cluster_total_used_bytes`: Used storage
- `ceph_osd_op_latency`: OSD operation latency

**Critical Alerts**:
1. **Health not OK**: Immediate investigation
2. **MON quorum lost**: Critical outage
3. **OSD down**: Data availability at risk
4. **PG degraded**: Reduced redundancy
5. **Storage near full**: Capacity planning needed
6. **Slow OPS**: Performance degradation

### Troubleshooting

**Cluster not HEALTH_OK**:
```bash
# Check detailed health
ceph health detail

# Common causes:
# - PGs degraded (rebalancing in progress)
# - OSDs down (check node/disk)
# - MON clock skew (NTP issues)
# - Slow ops (performance issues)
```

**OSD not starting**:
```bash
# Check operator logs
kubectl logs -n rook-ceph deploy/rook-ceph-operator | grep -i osd

# Common causes:
# - Device not clean (wipefs needed)
# - Device path incorrect (check by-id)
# - Insufficient permissions (check RBAC)
# - Disk already in use (by LVM, RAID, etc.)

# Verify device
lsblk -f /dev/disk/by-id/nvme-...
```

**MON quorum lost**:
```bash
# Check MON pods
kubectl get pod -n rook-ceph -l app=rook-ceph-mon

# Check MON logs
kubectl logs -n rook-ceph -l app=rook-ceph-mon

# Common causes:
# - Network partition
# - Node failures (>1 node down)
# - Clock skew (>50ms)
```

**PG degraded**:
```bash
# Check PG status
ceph pg stat
ceph pg dump

# Common causes:
# - OSD down (check `ceph osd tree`)
# - Rebalancing in progress (wait)
# - Insufficient OSDs for replica count

# Force scrub (if inconsistent)
ceph pg scrub <pg-id>
```

**Slow OPS**:
```bash
# Check slow ops
ceph -s | grep slow

# Identify slow OSDs
ceph osd perf

# Common causes:
# - Disk performance issues
# - Network latency
# - OSD overloaded (too much data)
```

### Upgrade Procedures

**Operator Upgrade (Story 30)**:
- Update Rook operator HelmRelease
- Operator automatically upgrades Ceph version

**Ceph Version Upgrade**:
- Rolling upgrade process
- Order: MONs → MGRs → OSDs → MDS
- No downtime for RBD (block storage)
- Brief pause for CephFS during MDS upgrade

**Monitoring Upgrade**:
```bash
# Check current versions
ceph versions

# Monitor upgrade progress
ceph -s | grep -i upgrade
```

**Upgrade Path**:
- Ceph Pacific (v16) → Quincy (v17) → Reef (v18)
- Skip versions not recommended
- Test in staging first

### Security Hardening

**PSA Privileged**:
- Ceph requires host networking and disk access
- PSA privileged enforcement required
- Isolated in `rook-ceph` namespace

**RBAC**:
- ServiceAccounts for MON, MGR, OSD, MDS
- ClusterRoles with minimal permissions
- Secrets for Ceph keyrings

**Network Policies**:
- Allow MON/MGR/OSD communication (Ceph network)
- Allow CSI driver access
- Allow monitoring (VictoriaMetrics)
- Deny all other ingress

**Encryption**:
- Encryption at rest: OSD-level LUKS encryption (optional)
- Encryption in transit: Ceph msgr2 protocol (optional)
- Performance impact: ~10-20%

### Comparison: OpenEBS vs Rook-Ceph

**Apps Cluster Storage Strategy**:
- **OpenEBS LocalPV**: Default for performance-sensitive workloads
  - Single-node failure domain
  - <1ms latency, 500K IOPS
  - Use for: Databases with backup, caches, CI/CD
- **Rook-Ceph**: For durability-critical workloads
  - Multi-node failure domain
  - 5-10ms latency, 50K IOPS
  - Use for: Shared filesystems, multi-replica StatefulSets

**Hybrid Approach**:
- CNPG PostgreSQL: OpenEBS LocalPV (with S3 backups)
- DragonflyDB: OpenEBS LocalPV (cache, ephemeral)
- GitLab: Rook-Ceph RBD (durability critical)
- Shared logs: Rook-Ceph CephFS (RWX required)

### Future Enhancements

**RBD Mirroring**:
- Async replication to DR site
- RPO: minutes to hours
- For disaster recovery

**CephFS Snapshots**:
- Filesystem snapshots
- Point-in-time recovery
- CSI VolumeSnapshot integration

**Erasure Coding**:
- Reduce storage overhead
- Example: k=4, m=2 (4 data + 2 parity = 1.5x overhead vs 3x)
- Trade-off: lower IOPS, higher CPU

**Object Storage (RGW)**:
- S3-compatible API
- Multi-tenant buckets
- For backups, artifacts

## Change Log

### v3.0 (2025-10-26) - Manifests-First Architecture Refinement

**Refined Story to Separate Manifest Creation from Deployment**:
1. **Updated header**: Changed title to "Create Ceph Cluster Manifests (apps)", status to "Draft (v3.0 Refinement)", date to 2025-10-26
2. **Rewrote story**: Focus on creating manifests for Ceph cluster with 3-node HA, NVMe devices, distributed storage
3. **Split scope**:
   - This Story: Create CephCluster, pools, StorageClasses, toolbox, monitoring, local validation
   - Story 45: Deploy to apps cluster, verify health, test provisioning, smoke tests
4. **Created 8 acceptance criteria** for manifest creation (AC1-AC8):
   - AC1: Cluster manifests (CephCluster, pools, StorageClasses, toolbox)
   - AC2: CephCluster configuration (3 MONs, 3 MGRs, OSDs on NVMe by-id, version, resources)
   - AC3: CephBlockPool configuration (replicas, failure domain, compression, device class)
   - AC4: StorageClasses (RBD, CephFS with CSI parameters)
   - AC5: Monitoring (PodMonitor, PrometheusRules with 10 alerts)
   - AC6: High availability (PDBs, anti-affinity, tolerations)
   - AC7: Local validation (dry-run, flux build, kubeconform)
   - AC8: Comprehensive documentation (architecture, components, devices, toolbox, troubleshooting, capacity, scaling)
5. **Updated dependencies**: Local tools only (kubectl, flux CLI, yq, kubeconform), story dependencies (Rook operator)
6. **Restructured tasks** to T1-T17:
   - T1: Prerequisites and strategy
   - T2: CephCluster CR (3 MONs, 3 MGRs, OSDs by-id, network, placement, resources, priority classes)
   - T3: CephBlockPool CR (3 replicas, host failure domain, ssd device class, compression, quotas)
   - T4: CephFilesystem CR (optional, metadata/data pools, MDS HA)
   - T5: RBD StorageClass (CSI parameters, ext4, discard mount option)
   - T6: CephFS StorageClass (optional, CSI parameters)
   - T7: Toolbox Deployment (for diagnostics)
   - T8: PodDisruptionBudgets (MONs minAvailable 2, MGRs minAvailable 1)
   - T9: Ceph monitoring (PodMonitor for MGR metrics)
   - T10: Ceph alerting (VMRule with 10 alerts)
   - T11: Cluster Kustomization
   - T12: Cluster Flux Kustomization (15m timeout, CephCluster health checks)
   - T13: Infrastructure Kustomization update
   - T14: Cluster README (architecture, components, device selection, toolbox usage, troubleshooting, capacity, scaling, upgrade)
   - T15: Cluster settings update (version, pools, StorageClasses, device IDs per node)
   - T16: Local validation
   - T17: Git commit
7. **Added "Runtime Validation (MOVED TO STORY 45)" section** with comprehensive testing:
   - Ceph cluster validation (health, MON quorum, MGR status, OSD status, capacity)
   - CephBlockPool validation (pool status, PG status)
   - CephFilesystem validation (MDS status)
   - StorageClass validation
   - RBD PVC provisioning test (create PVC, pod, verify data)
   - CephFS PVC provisioning test (RWX multi-pod access)
   - Toolbox validation (ceph commands)
   - Monitoring validation (metrics, alerts)
   - PDB validation
8. **Updated DoD** with clear separation:
   - "Manifest Creation Complete (This Story)": All manifests created, validated locally, documented, committed
   - "NOT Part of DoD (Moved to Story 45)": Deployment, health validation, PVC provisioning, toolbox operational
9. **Added comprehensive design notes**:
   - Ceph cluster architecture (MON, MGR, OSD, MDS components)
   - Device selection strategy (by-id paths for stability)
   - Replication and failure domains (host failure domain, 3x replication, CRUSH map)
   - MON quorum (3 MONs for 1 failure tolerance)
   - Storage classes (RBD for RWO, CephFS for RWX)
   - Resource sizing (MON, MGR, OSD, MDS)
   - High availability (MON/MGR/OSD/MDS HA strategies)
   - Capacity planning (raw vs usable, overhead, growth)
   - Monitoring and alerting (key metrics, critical alerts)
   - Troubleshooting (health, OSD, quorum, PG, slow ops issues)
   - Upgrade procedures (operator → Ceph rolling upgrade)
   - Security hardening (PSA, RBAC, NetworkPolicies, encryption)
   - Comparison: OpenEBS vs Rook-Ceph (hybrid approach for apps cluster)
   - Future enhancements (mirroring, snapshots, erasure coding, object storage)
10. **Preserved original context**: Sprint 6, Lane Storage, apps cluster focus, local NVMe to avoid L3 traffic

**Gaps Identified and Fixed**:
- Added device-by-id selection strategy (stable across reboots)
- Added MON quorum requirements (3 MONs, minAvailable 2)
- Added PodDisruptionBudgets for MON and MGR HA
- Added comprehensive monitoring (PodMonitor, 10 alerts)
- Added toolbox Deployment for diagnostics
- Added CephFS support (optional, with MDS HA)
- Added resource sizing for all components
- Added capacity planning documentation
- Added detailed troubleshooting procedures
- Added upgrade procedures (rolling upgrade order)
- Added hybrid storage strategy (OpenEBS + Rook-Ceph)

**Why v3.0**:
- Enforces clean separation: Story 31 = CREATE manifests (local), Story 45 = DEPLOY & VALIDATE (cluster)
- Enables parallel work: manifest creation can proceed without cluster access
- Improves testing: all manifests validated locally before any deployment
- Reduces risk: deployment issues don't block manifest refinement work
- Maintains GitOps principles: manifest creation is pure IaC work
