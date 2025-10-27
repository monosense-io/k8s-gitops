# 29 — STORY-STO-APPS-OPENEBS-BASE — Create OpenEBS LocalPV Manifests (apps)

Sequence: 29/50 | Prev: STORY-SEC-SPIRE-CILIUM-AUTH.md | Next: STORY-STO-APPS-ROOK-CEPH-OPERATOR.md
Sprint: 6 | Lane: Storage
Global Sequence: 29/50

Status: Draft (v3.0 Refinement)
Owner: Platform Engineering
Date: 2025-10-26
Links: kubernetes/infrastructure/storage/openebs/; kubernetes/clusters/apps/cluster-settings.yaml

## Story

As a platform engineer, I want to **create manifests for OpenEBS LocalPV on the apps cluster** so that workloads have access to high-performance node-local storage for databases, caches, and stateful applications, eliminating dependency on remote storage across the 1 Gbps L3 link to the infra cluster.

## Why / Outcome

- **High-performance local storage**: NVMe-backed storage for latency-sensitive workloads
- **Data locality**: Eliminate network overhead for storage access
- **Independence from infra cluster**: Apps cluster can operate independently for local storage needs
- **Dynamic provisioning**: Automatic PV creation for PVCs
- **Simple and lightweight**: Minimal overhead compared to distributed storage

## Scope

### This Story (Manifest Creation)

**CREATE** the following manifests (local-only work):

1. **OpenEBS Infrastructure** (`kubernetes/infrastructure/storage/openebs/`):
   - Namespace with PSA baseline
   - HelmRelease for OpenEBS LocalPV Provisioner
   - OCIRepository for Helm chart
   - StorageClass for dynamic provisioning
   - PodMonitor for metrics
   - PrometheusRule for alerting

2. **Flux Kustomizations**:
   - Infrastructure Kustomization for OpenEBS stack
   - Health checks for provisioner DaemonSet
   - Dependency ordering

3. **Documentation**:
   - Comprehensive README for OpenEBS deployment
   - StorageClass usage guide
   - Troubleshooting procedures

**DO NOT**:
- Deploy to apps cluster
- Run validation commands requiring cluster access
- Test PVC provisioning
- Verify DaemonSet status

### Deferred to Story 45 (Deployment & Validation)

Story 45 will handle:
- Applying manifests to apps cluster via Flux
- Verifying OpenEBS provisioner readiness
- Testing PVC dynamic provisioning
- Validating storage performance
- Smoke testing with sample workloads

## Acceptance Criteria

### Manifest Creation (This Story)

**AC1**: OpenEBS infrastructure manifests created under `kubernetes/infrastructure/storage/openebs/`:
- `namespace.yaml` with PSA baseline enforcement
- `helmrelease.yaml` for OpenEBS LocalPV Provisioner
- `ocirepository.yaml` for Helm chart source
- `storageclass.yaml` for dynamic provisioning
- `kustomization.yaml`

**AC2**: OpenEBS HelmRelease configured with:
- Chart: `openebs/localpv-provisioner` version 4.x
- Namespace: `openebs-system`
- LocalPV HostPath provisioner enabled
- Base path: `${OPENEBS_BASE_PATH}` (default: `/var/mnt/openebs`)
- Resource limits for provisioner DaemonSet
- Node selectors for storage nodes (if applicable)

**AC3**: StorageClass configured:
- Name: `${OPENEBS_STORAGE_CLASS}` (default: `openebs-hostpath`)
- Provisioner: `openebs.io/local`
- VolumeBindingMode: `WaitForFirstConsumer` (topology-aware)
- ReclaimPolicy: `Delete` (configurable for production)
- AllowVolumeExpansion: true
- Parameters: `basePath=${OPENEBS_BASE_PATH}`

**AC4**: Monitoring configured:
- PodMonitor scraping provisioner metrics
- PrometheusRule with alerts for:
  - Provisioner unavailable
  - PVC provisioning failures
  - Storage capacity warnings
  - Node storage errors

**AC5**: Flux Kustomization created:
- `kubernetes/infrastructure/storage/openebs/ks.yaml`
- Health checks for provisioner DaemonSet
- Dependency on Cilium (requires CNI)
- Timeout: 3 minutes

**AC6**: Security hardening applied:
- PSA baseline enforcement (HostPath requires privileged access)
- Provisioner runs with minimal required privileges
- ReadOnlyRootFilesystem where possible
- PodDisruptionBudget for high availability

**AC7**: All manifests pass local validation:
- `kubectl --dry-run=client` succeeds
- `flux build kustomization` succeeds
- `kubeconform` validation passes
- YAML linting passes

**AC8**: Documentation includes:
- OpenEBS LocalPV architecture overview
- StorageClass usage examples
- Node preparation requirements (directory creation)
- Troubleshooting guide (provisioner logs, PVC binding issues)
- Performance considerations
- Backup/migration strategies

### Deferred to Story 45 (NOT validated in this Story)

- OpenEBS provisioner DaemonSet running and Ready
- StorageClass available in cluster
- PVC provisioning working
- Storage performance validated
- Monitoring alerts firing correctly

## Dependencies / Inputs

**Local Tools Required**:
- `kubectl` (for dry-run validation)
- `flux` CLI (for `flux build kustomization`)
- `yq` (for YAML processing)
- `kubeconform` (for schema validation)

**Story Dependencies**:
- **STORY-NET-CILIUM-CORE-GITOPS** (Story 8): Cilium CNI required

**Configuration Inputs**:
- `${OPENEBS_BASE_PATH}`: Base directory for LocalPV storage (default: `/var/mnt/openebs`)
- `${OPENEBS_STORAGE_CLASS}`: StorageClass name (default: `openebs-hostpath`)
- `${OPENEBS_RECLAIM_POLICY}`: PV reclaim policy (default: `Delete`, `Retain` for production)
- `${OPENEBS_PROVISIONER_REPLICAS}`: DaemonSet replicas (typically all nodes)

## Tasks / Subtasks

### T1: Prerequisites and Strategy
- Review OpenEBS LocalPV architecture and limitations
- Determine base path location (NVMe mount points on nodes)
- Plan node preparation strategy (directory creation, permissions)
- Review storage capacity planning for apps cluster

### T2: OpenEBS Namespace
- Create `kubernetes/infrastructure/storage/openebs/namespace.yaml`:
  - Namespace: `openebs-system`
  - PSA labels: `pod-security.kubernetes.io/enforce=baseline` (HostPath requires privileged access)
  - Labels: `app.kubernetes.io/name=openebs`, `app.kubernetes.io/component=storage`

### T3: OpenEBS OCIRepository
- Create `kubernetes/infrastructure/storage/openebs/ocirepository.yaml`:
  - OCIRepository: `openebs`
  - URL: `oci://registry-1.docker.io/openebs` (or `ghcr.io/openebs/charts`)
  - Interval: 12h
  - LayerSelector: `latest` or specific version tag

### T4: OpenEBS HelmRelease
- Create `kubernetes/infrastructure/storage/openebs/helmrelease.yaml`:
  - HelmRelease: `openebs-localpv`
  - Namespace: `openebs-system`
  - Chart: `localpv-provisioner` version 4.x
  - Interval: 30m
  - Values:
    - `localpv-provisioner.enabled: true`
    - `localpv-provisioner.basePath: ${OPENEBS_BASE_PATH}`
    - `localpv-provisioner.hostpathClass.enabled: true`
    - `localpv-provisioner.hostpathClass.name: ${OPENEBS_STORAGE_CLASS}`
    - `localpv-provisioner.hostpathClass.basePath: ${OPENEBS_BASE_PATH}`
    - `localpv-provisioner.hostpathClass.reclaimPolicy: ${OPENEBS_RECLAIM_POLICY}`
    - Resource requests: 50m CPU, 64Mi memory
    - Resource limits: 100m CPU, 128Mi memory
    - Node selector: `openebs.io/storage-node: "true"` (optional, for dedicated storage nodes)
    - Tolerations: control plane taints (if needed)
  - DependsOn: OCIRepository/openebs

### T5: StorageClass
- Create `kubernetes/infrastructure/storage/openebs/storageclass.yaml`:
  - StorageClass: `${OPENEBS_STORAGE_CLASS}`
  - Provisioner: `openebs.io/local`
  - VolumeBindingMode: `WaitForFirstConsumer` (topology-aware scheduling)
  - ReclaimPolicy: `${OPENEBS_RECLAIM_POLICY}`
  - AllowVolumeExpansion: true (LocalPV supports expansion)
  - Parameters:
    - `storageType: "hostpath"`
    - `basePath: "${OPENEBS_BASE_PATH}"`
  - Annotations: `storageclass.kubernetes.io/is-default-class: "false"`

### T6: OpenEBS Monitoring
- Create `kubernetes/infrastructure/storage/openebs/podmonitor.yaml`:
  - PodMonitor: `openebs-localpv-provisioner`
  - Namespace selector: `openebs-system`
  - Port: metrics (9500 or as exposed by provisioner)
  - Path: `/metrics`
  - Labels for VictoriaMetrics discovery

### T7: OpenEBS Alerting
- Create `kubernetes/infrastructure/storage/openebs/prometheusrule.yaml`:
  - VMRule: `openebs-alerts`
  - Alert groups:
    - **OpenEBSProvisionerDown**: No provisioner pods ready for 5 minutes
    - **OpenEBSPVCProvisioningFailed**: PVC stuck in Pending state for >10 minutes
    - **OpenEBSStorageCapacityWarning**: Node storage usage >80%
    - **OpenEBSStorageCapacityCritical**: Node storage usage >90%
    - **OpenEBSNodeStorageError**: Storage errors detected on node
    - **OpenEBSHighMemoryUsage**: Provisioner memory usage >80% of limit

### T8: OpenEBS Kustomization
- Create `kubernetes/infrastructure/storage/openebs/kustomization.yaml`:
  - Resources: namespace, ocirepository, helmrelease, storageclass, podmonitor, prometheusrule
  - Namespace: `openebs-system`
  - CommonLabels: `app.kubernetes.io/part-of=openebs`

### T9: OpenEBS Flux Kustomization
- Create `kubernetes/infrastructure/storage/openebs/ks.yaml`:
  - Kustomization: `cluster-apps-openebs`
  - Source: GitRepository/flux-system
  - Path: `./kubernetes/infrastructure/storage/openebs`
  - Interval: 10m
  - Prune: true
  - Wait: true
  - Timeout: 3m
  - Health checks:
    - DaemonSet/openebs-localpv-provisioner
  - DependsOn:
    - cluster-apps-cilium-core (requires CNI)

### T10: Infrastructure Kustomization Update
- Update `kubernetes/infrastructure/storage/kustomization.yaml`:
  - Add `./openebs` to resources

### T11: OpenEBS Deployment README
- Create `kubernetes/infrastructure/storage/openebs/README.md`:
  - **Architecture Overview**:
    - LocalPV HostPath provisioner
    - Node-local storage via HostPath volumes
    - Dynamic provisioning with PVC binding
    - No data replication (single-node failure domain)
  - **Use Cases**:
    - High-performance databases (PostgreSQL, MySQL)
    - Redis/Memcached caches
    - Temporary storage for CI/CD workloads
    - Logs and metrics buffers
  - **Node Preparation**:
    - Create base directory: `mkdir -p ${OPENEBS_BASE_PATH}`
    - Set permissions: `chmod 755 ${OPENEBS_BASE_PATH}`
    - Ensure sufficient disk space (NVMe mounts)
    - Label nodes (optional): `kubectl label node <node> openebs.io/storage-node=true`
  - **StorageClass Usage**:
    - Example PVC with `storageClassName: ${OPENEBS_STORAGE_CLASS}`
    - VolumeBindingMode explained (pod scheduling affects PVC binding)
    - Reclaim policy behavior (Delete vs Retain)
  - **Troubleshooting**:
    - Check provisioner logs: `kubectl logs -n openebs-system ds/openebs-localpv-provisioner`
    - PVC stuck in Pending: verify node has space, base path exists, pod scheduled
    - Storage capacity issues: check node disk usage
    - Permission denied: verify base path permissions
  - **Performance Considerations**:
    - LocalPV uses host filesystem (ext4, xfs)
    - Performance = underlying disk performance (NVMe)
    - No network overhead
    - Single-node failure domain (no HA)
  - **Backup/Migration Strategies**:
    - Velero with restic/kopia for volume backups
    - Application-level backups (pg_dump, mysqldump)
    - PVC cloning for migrations
    - No built-in replication (use Rook-Ceph for HA)
  - **Comparison with Rook-Ceph**:
    - OpenEBS LocalPV: Fast, simple, no HA, single-node failure domain
    - Rook-Ceph: Slower, complex, HA, multi-node failure domain
    - Use LocalPV for performance, Rook-Ceph for durability

### T12: Cluster Settings Update
- Update `kubernetes/clusters/apps/cluster-settings.yaml`:
  - Add OpenEBS configuration:
    ```yaml
    OPENEBS_BASE_PATH: "/var/mnt/openebs"
    OPENEBS_STORAGE_CLASS: "openebs-hostpath"
    OPENEBS_RECLAIM_POLICY: "Delete"  # "Retain" for production
    ```

### T13: Local Validation
- Run validation commands:
  - `kubectl --dry-run=client apply -f kubernetes/infrastructure/storage/openebs/`
  - `flux build kustomization cluster-apps-openebs --path ./kubernetes/infrastructure/storage/openebs`
  - `kubeconform -summary -output pretty kubernetes/infrastructure/storage/openebs/*.yaml`
  - `yamllint kubernetes/infrastructure/storage/openebs/`
- Verify HelmRelease values syntax
- Validate StorageClass parameters

### T14: Git Commit
- Stage all changes
- Commit: "feat(storage): add OpenEBS LocalPV manifests for apps cluster (Story 29)"

## Runtime Validation (MOVED TO STORY 45)

**The following validation steps require a running cluster and are deferred to Story 45:**

### OpenEBS Provisioner Validation
```bash
# Check OpenEBS namespace
kubectl --context=apps get namespace openebs-system

# Check provisioner DaemonSet
kubectl --context=apps -n openebs-system get ds openebs-localpv-provisioner
kubectl --context=apps -n openebs-system get pod -l app=openebs-localpv-provisioner

# Check provisioner logs
kubectl --context=apps -n openebs-system logs ds/openebs-localpv-provisioner --tail=50

# Verify base path on nodes
kubectl --context=apps get nodes -o wide
kubectl --context=apps debug node/<node-name> -it --image=busybox -- ls -la /var/mnt/openebs
```

### StorageClass Validation
```bash
# Check StorageClass created
kubectl --context=apps get sc
kubectl --context=apps get sc ${OPENEBS_STORAGE_CLASS} -o yaml

# Verify provisioner and binding mode
kubectl --context=apps get sc ${OPENEBS_STORAGE_CLASS} -o jsonpath='{.provisioner}'
kubectl --context=apps get sc ${OPENEBS_STORAGE_CLASS} -o jsonpath='{.volumeBindingMode}'
```

### PVC Provisioning Test
```bash
# Create test PVC
cat <<EOF | kubectl --context=apps apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: openebs-test-pvc
  namespace: default
spec:
  storageClassName: ${OPENEBS_STORAGE_CLASS}
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
EOF

# Check PVC status (should be Pending until pod created)
kubectl --context=apps get pvc openebs-test-pvc

# Create test pod to bind PVC
cat <<EOF | kubectl --context=apps apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: openebs-test-pod
  namespace: default
spec:
  containers:
    - name: test
      image: busybox
      command: ["sh", "-c", "echo 'OpenEBS LocalPV test' > /data/test.txt && cat /data/test.txt && sleep 3600"]
      volumeMounts:
        - name: data
          mountPath: /data
  volumes:
    - name: data
      persistentVolumeClaim:
        claimName: openebs-test-pvc
EOF

# Wait for pod to schedule and PVC to bind
kubectl --context=apps wait --for=condition=Ready pod/openebs-test-pod --timeout=60s

# Verify PVC bound
kubectl --context=apps get pvc openebs-test-pvc
kubectl --context=apps get pv

# Verify data written
kubectl --context=apps exec openebs-test-pod -- cat /data/test.txt
# Expected: OpenEBS LocalPV test

# Check PV location on node
NODE=$(kubectl --context=apps get pod openebs-test-pod -o jsonpath='{.spec.nodeName}')
PV=$(kubectl --context=apps get pvc openebs-test-pvc -o jsonpath='{.spec.volumeName}')
echo "PV $PV on node $NODE"
kubectl --context=apps debug node/$NODE -it --image=busybox -- ls -la /var/mnt/openebs/$PV

# Cleanup test resources
kubectl --context=apps delete pod openebs-test-pod
kubectl --context=apps delete pvc openebs-test-pvc
```

### VolumeBindingMode Test
```bash
# Create PVC without pod (should stay Pending)
cat <<EOF | kubectl --context=apps apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: openebs-binding-test
  namespace: default
spec:
  storageClassName: ${OPENEBS_STORAGE_CLASS}
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
EOF

# Verify PVC is Pending (WaitForFirstConsumer)
kubectl --context=apps get pvc openebs-binding-test
# Expected: STATUS=Pending

# Create pod - PVC should bind
cat <<EOF | kubectl --context=apps apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: openebs-binding-pod
  namespace: default
spec:
  containers:
    - name: test
      image: busybox
      command: ["sleep", "3600"]
      volumeMounts:
        - name: data
          mountPath: /data
  volumes:
    - name: data
      persistentVolumeClaim:
        claimName: openebs-binding-test
EOF

# Verify PVC now Bound
kubectl --context=apps wait --for=condition=Ready pod/openebs-binding-pod --timeout=60s
kubectl --context=apps get pvc openebs-binding-test
# Expected: STATUS=Bound

# Cleanup
kubectl --context=apps delete pod openebs-binding-pod
kubectl --context=apps delete pvc openebs-binding-test
```

### Storage Performance Test
```bash
# Create performance test pod
cat <<EOF | kubectl --context=apps apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: openebs-perf-pvc
  namespace: default
spec:
  storageClassName: ${OPENEBS_STORAGE_CLASS}
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
---
apiVersion: v1
kind: Pod
metadata:
  name: openebs-perf-pod
  namespace: default
spec:
  containers:
    - name: fio
      image: dmonakhov/alpine-fio
      command: ["sleep", "3600"]
      volumeMounts:
        - name: data
          mountPath: /data
  volumes:
    - name: data
      persistentVolumeClaim:
        claimName: openebs-perf-pvc
EOF

# Wait for pod
kubectl --context=apps wait --for=condition=Ready pod/openebs-perf-pod --timeout=60s

# Run fio benchmark
kubectl --context=apps exec openebs-perf-pod -- fio \
  --name=randwrite \
  --ioengine=libaio \
  --iodepth=32 \
  --rw=randwrite \
  --bs=4k \
  --direct=1 \
  --size=1G \
  --numjobs=1 \
  --runtime=60 \
  --time_based \
  --filename=/data/testfile

# Cleanup
kubectl --context=apps delete pod openebs-perf-pod
kubectl --context=apps delete pvc openebs-perf-pvc
```

### Monitoring Validation
```bash
# Check PodMonitor discovered
kubectl --context=apps -n observability get podmonitor -l app.kubernetes.io/name=openebs

# Query OpenEBS metrics (if exposed)
# kubectl --context=apps port-forward -n openebs-system ds/openebs-localpv-provisioner 9500:9500
# curl -s http://localhost:9500/metrics | grep openebs

# Check alerts configured
kubectl --context=apps -n observability get vmrule openebs-alerts -o yaml
```

### Node Storage Capacity Check
```bash
# Check node filesystem usage
kubectl --context=apps get nodes -o wide
for node in $(kubectl --context=apps get nodes -o jsonpath='{.items[*].metadata.name}'); do
  echo "Node: $node"
  kubectl --context=apps debug node/$node -it --image=busybox -- df -h /var/mnt/openebs
done

# Check PV usage
kubectl --context=apps get pv -o custom-columns=NAME:.metadata.name,CAPACITY:.spec.capacity.storage,NODE:.spec.nodeAffinity.required.nodeSelectorTerms[0].matchExpressions[0].values[0]
```

## Definition of Done

### Manifest Creation Complete (This Story)

- [x] All acceptance criteria AC1-AC8 met
- [x] OpenEBS LocalPV manifests created under `kubernetes/infrastructure/storage/openebs/`
- [x] HelmRelease configured with HostPath provisioner
- [x] StorageClass created with WaitForFirstConsumer binding mode
- [x] Flux Kustomization created for OpenEBS stack
- [x] Monitoring configured (PodMonitor, PrometheusRules)
- [x] All manifests pass local validation (dry-run, flux build, kubeconform)
- [x] Comprehensive README documentation created
- [x] Cluster settings updated with OpenEBS configuration
- [x] Changes committed to git with descriptive message

### NOT Part of DoD (Moved to Story 45)

The following are **explicitly deferred** to Story 45:
- OpenEBS provisioner deployed and running
- StorageClass available in cluster
- PVC provisioning tested and working
- VolumeBindingMode behavior validated
- Storage performance benchmarked
- Node storage capacity verified
- Monitoring alerts firing correctly
- End-to-end smoke tests with sample workloads

## Design Notes

### OpenEBS LocalPV Architecture

**Components**:
1. **LocalPV Provisioner**: DaemonSet running on all nodes
   - Watches for PVCs with `openebs.io/local` provisioner
   - Creates PVs using HostPath volumes
   - Manages PV lifecycle (create, delete)
   - No data replication or distribution

2. **StorageClass**: Defines provisioning parameters
   - `WaitForFirstConsumer`: Delays PV creation until pod is scheduled
   - Enables topology-aware scheduling (pod and PV on same node)
   - Critical for node-local storage

3. **HostPath Volumes**: Directories on node filesystem
   - Base path: `/var/mnt/openebs` (configurable)
   - Per-PV directory: `${OPENEBS_BASE_PATH}/<pv-name>`
   - Permissions: 755 (directory), 644 (files)
   - Ownership: matches pod security context

### Use Cases

**Ideal For**:
- **High-performance databases**: PostgreSQL, MySQL (CNPG on apps cluster)
- **In-memory caches**: Redis, Memcached (DragonflyDB)
- **CI/CD workloads**: Build artifacts, test data
- **Logs and metrics**: Fluent Bit buffers, VictoriaMetrics cache
- **Temporary storage**: Job results, intermediate data

**Not Ideal For**:
- **Multi-replica stateful sets** needing shared storage (use Rook-Ceph)
- **Data durability across node failures** (single-node failure domain)
- **Cross-node pod migration** (data stays on original node)
- **Shared read-write-many** (LocalPV is RWO only)

### VolumeBindingMode: WaitForFirstConsumer

**How It Works**:
1. User creates PVC with OpenEBS StorageClass
2. PVC stays in `Pending` state (no PV created yet)
3. User creates pod referencing the PVC
4. Scheduler places pod on a node
5. Provisioner creates PV on that specific node
6. PVC binds to PV
7. Pod mounts the volume

**Benefits**:
- **Topology awareness**: PV created on same node as pod
- **Efficient scheduling**: Avoids pod placement conflicts
- **No wasted PVs**: PV only created when actually needed

**Gotcha**:
- PVC without pod stays Pending forever (expected behavior)
- Pod must be schedulable for PVC to bind

### Reclaim Policy

**Delete (Default)**:
- PV deleted when PVC deleted
- Data lost permanently
- Good for: ephemeral data, CI/CD, test environments

**Retain (Production)**:
- PV marked as Released when PVC deleted
- Data preserved on node
- Admin must manually clean up PV and data
- Good for: production databases, important data

**Configuration**:
```yaml
OPENEBS_RECLAIM_POLICY: "Delete"  # or "Retain"
```

### Storage Capacity Planning

**Per-Node Calculation**:
```
Available space = NVMe disk size - OS overhead - base path allocation
Example: 1TB NVMe - 100GB OS = 900GB for OpenEBS
```

**Apps Cluster (3 nodes)**:
- Node 1: 900GB available
- Node 2: 900GB available
- Node 3: 900GB available
- **Total**: 2700GB (but not pooled, per-node allocation)

**Workload Distribution**:
- CNPG PostgreSQL: ~100GB per instance (3 instances = 300GB across 3 nodes)
- DragonflyDB: ~10GB per pod (3 pods = 30GB across 3 nodes)
- CI/CD runners: ~50GB per node (150GB total)
- Reserve: ~500GB per node for growth

### Performance Characteristics

**Latency**:
- Read/Write latency = underlying disk latency (NVMe: ~100µs)
- No network overhead
- No replication overhead
- **Best case**: 1-2ms for 4K random writes

**Throughput**:
- Sequential read/write = NVMe throughput (~3GB/s)
- No network bottleneck
- **Best case**: Multi-GB/s for large sequential I/O

**IOPS**:
- Random IOPS = NVMe IOPS (~500K)
- No coordination overhead
- **Best case**: Hundreds of thousands IOPS

**Comparison with Rook-Ceph**:
| Metric | OpenEBS LocalPV | Rook-Ceph |
|--------|-----------------|-----------|
| Latency | <1ms | 5-10ms |
| Throughput | 3GB/s | 300MB/s |
| IOPS | 500K | 50K |
| Availability | Single-node | Multi-node |
| Data durability | Low | High |

### Node Preparation

**Pre-requisites**:
1. **Create base directory**:
   ```bash
   # On each node
   sudo mkdir -p /var/mnt/openebs
   sudo chmod 755 /var/mnt/openebs
   ```

2. **Optional: Dedicated NVMe mount**:
   ```bash
   # Format NVMe
   sudo mkfs.ext4 /dev/nvme0n1

   # Mount
   sudo mount /dev/nvme0n1 /var/mnt/openebs

   # Persistent mount
   echo "/dev/nvme0n1 /var/mnt/openebs ext4 defaults 0 2" | sudo tee -a /etc/fstab
   ```

3. **Optional: Label storage nodes**:
   ```bash
   kubectl label node apps-node-1 openebs.io/storage-node=true
   kubectl label node apps-node-2 openebs.io/storage-node=true
   kubectl label node apps-node-3 openebs.io/storage-node=true
   ```

**Talos Linux Considerations**:
- Talos is immutable, paths must be in allowed list
- `/var/mnt/openebs` typically allowed
- Verify with Talos machine config
- Use Talos disk mounts for NVMe

### Backup and Migration Strategies

**Application-Level Backups**:
- **PostgreSQL**: `pg_dump` to S3 (CNPG handles this)
- **MySQL**: `mysqldump` to S3
- **Redis**: RDB/AOF snapshots to S3
- **Generic**: Velero with restic/kopia for filesystem backups

**PVC Cloning**:
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: cloned-pvc
spec:
  storageClassName: openebs-hostpath
  dataSource:
    name: source-pvc
    kind: PersistentVolumeClaim
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
```

**Migration to Different Node**:
1. Scale down workload (StatefulSet to 0 replicas)
2. Create new PVC on target node
3. Copy data: `kubectl cp` or `rsync` via debug pod
4. Update workload to use new PVC
5. Scale up workload
6. Delete old PVC

**Disaster Recovery**:
- OpenEBS LocalPV has no built-in replication
- **Strategy 1**: Application-level replication (PostgreSQL sync replicas)
- **Strategy 2**: External backups (Velero, S3)
- **Strategy 3**: Use Rook-Ceph for critical data

### Monitoring and Alerting

**Key Metrics**:
- `openebs_volume_provisioning_duration_seconds`: PV creation time
- `openebs_volume_provisioning_failures_total`: Provisioning failures
- Node filesystem usage: `node_filesystem_avail_bytes{mountpoint="/var/mnt/openebs"}`

**Critical Alerts**:
1. **Provisioner Down**: No provisioner pods ready
2. **Provisioning Failures**: PVC stuck in Pending >10 minutes
3. **Capacity Warning**: Node storage >80% full
4. **Capacity Critical**: Node storage >90% full

### Troubleshooting

**PVC Stuck in Pending**:
1. Check if pod created: `kubectl get pod -A | grep <pvc-name>`
2. Check provisioner logs: `kubectl logs -n openebs-system ds/openebs-localpv-provisioner`
3. Verify base path exists: `kubectl debug node/<node> -- ls /var/mnt/openebs`
4. Check node capacity: `kubectl describe node <node> | grep -i capacity`

**PV Creation Failed**:
1. Check provisioner logs for errors
2. Verify base path permissions: `ls -la /var/mnt/openebs`
3. Check disk space: `df -h /var/mnt/openebs`
4. Verify node labels (if using node selectors)

**Pod Cannot Mount Volume**:
1. Check pod events: `kubectl describe pod <pod>`
2. Verify PVC is Bound: `kubectl get pvc <pvc>`
3. Check PV node affinity matches pod node
4. Verify kubelet logs on node

**Performance Issues**:
1. Check underlying disk performance: `fio` benchmarks
2. Verify filesystem type: `df -T /var/mnt/openebs`
3. Check for I/O contention: `iostat`, `iotop`
4. Review application I/O patterns

### Comparison: OpenEBS LocalPV vs Rook-Ceph

**When to Use OpenEBS LocalPV**:
- ✅ High-performance requirements (low latency, high IOPS)
- ✅ Single-replica databases with external backup
- ✅ Ephemeral or cache storage
- ✅ Cost-sensitive (no storage cluster overhead)
- ✅ Simple deployment and operations

**When to Use Rook-Ceph**:
- ✅ Multi-replica stateful sets needing shared storage
- ✅ Data durability across node failures critical
- ✅ HA databases (3+ replicas with auto-failover)
- ✅ RWX (ReadWriteMany) access mode needed
- ✅ Built-in replication and snapshots required

**Apps Cluster Strategy**:
- **OpenEBS LocalPV**: Default for most workloads (CNPG, DragonflyDB, CI/CD)
- **Rook-Ceph**: For critical multi-replica stateful sets (if needed later)
- **Hybrid approach**: Use both, select per-workload

### Future Enhancements

**Volume Expansion**:
- OpenEBS LocalPV supports online volume expansion
- Resize PVC: `kubectl patch pvc <pvc> -p '{"spec":{"resources":{"requests":{"storage":"20Gi"}}}}'`
- Filesystem expansion automatic (ext4/xfs)

**Volume Snapshots**:
- Requires CSI snapshot controller
- VolumeSnapshot CRD and snapshot class
- Filesystem-level snapshots (LVM thin provisioning)

**Multi-Disk Support**:
- Deploy multiple StorageClasses for different disks
- `openebs-nvme-fast` for NVMe
- `openebs-ssd` for SATA SSDs
- Node labels to control placement

**Capacity Management**:
- ResourceQuotas to limit PVC size per namespace
- LimitRanges to set default/max PVC sizes
- Monitoring dashboards for capacity planning

## Change Log

### v3.0 (2025-10-26) - Manifests-First Architecture Refinement

**Refined Story to Separate Manifest Creation from Deployment**:
1. **Updated header**: Changed title to "Create OpenEBS LocalPV Manifests (apps)", status to "Draft (v3.0 Refinement)", date to 2025-10-26
2. **Rewrote story**: Focus on creating manifests for high-performance node-local storage on apps cluster
3. **Split scope**:
   - This Story: Create OpenEBS infrastructure, StorageClass, monitoring, local validation
   - Story 45: Deploy to apps cluster, test provisioning, validate performance
4. **Created 8 acceptance criteria** for manifest creation (AC1-AC8):
   - AC1: OpenEBS infrastructure manifests (namespace, HelmRelease, OCIRepository, StorageClass)
   - AC2: HelmRelease configuration (chart version, base path, resource limits, node selectors)
   - AC3: StorageClass configuration (WaitForFirstConsumer, reclaim policy, expansion)
   - AC4: Monitoring (PodMonitor, PrometheusRules with 6 alerts)
   - AC5: Flux Kustomization (health checks, dependencies, timeout)
   - AC6: Security hardening (PSA baseline, minimal privileges, PDB)
   - AC7: Local validation (dry-run, flux build, kubeconform)
   - AC8: Comprehensive documentation (architecture, use cases, node prep, troubleshooting)
5. **Updated dependencies**: Local tools only (kubectl, flux CLI, yq, kubeconform), story dependencies (Cilium CNI)
6. **Restructured tasks** to T1-T14:
   - T1: Prerequisites and strategy (architecture review, base path planning)
   - T2: OpenEBS namespace with PSA baseline
   - T3: OpenEBS OCIRepository for Helm chart
   - T4: OpenEBS HelmRelease (LocalPV provisioner, base path, resources, node selectors)
   - T5: StorageClass (WaitForFirstConsumer, reclaim policy, expansion enabled)
   - T6: OpenEBS monitoring (PodMonitor)
   - T7: OpenEBS alerting (VMRule with 6 alerts)
   - T8: OpenEBS Kustomization
   - T9: OpenEBS Flux Kustomization (health checks, dependencies)
   - T10: Infrastructure Kustomization update
   - T11: OpenEBS deployment README (architecture, use cases, node prep, StorageClass usage, troubleshooting, performance, backup/migration, comparison with Rook-Ceph)
   - T12: Cluster settings update (base path, storage class, reclaim policy)
   - T13: Local validation (dry-run, flux build, kubeconform, yamllint)
   - T14: Git commit
7. **Added "Runtime Validation (MOVED TO STORY 45)" section** with comprehensive testing:
   - OpenEBS provisioner validation (DaemonSet status, logs, base path verification)
   - StorageClass validation (provisioner, binding mode)
   - PVC provisioning test (create PVC, pod, verify binding, data write)
   - VolumeBindingMode test (PVC stays Pending until pod created)
   - Storage performance test (fio benchmarks)
   - Monitoring validation (metrics, alerts)
   - Node storage capacity check (filesystem usage, PV distribution)
8. **Updated DoD** with clear separation:
   - "Manifest Creation Complete (This Story)": All manifests created, validated locally, documented, committed
   - "NOT Part of DoD (Moved to Story 45)": Deployment, PVC provisioning tests, performance benchmarks, monitoring alerts
9. **Added comprehensive design notes**:
   - OpenEBS LocalPV architecture (provisioner, StorageClass, HostPath volumes)
   - Use cases (databases, caches, CI/CD, logs) and anti-patterns (multi-replica shared storage)
   - VolumeBindingMode: WaitForFirstConsumer explained
   - Reclaim policy (Delete vs Retain)
   - Storage capacity planning (per-node allocation, workload distribution)
   - Performance characteristics (latency, throughput, IOPS, comparison with Rook-Ceph)
   - Node preparation (directory creation, NVMe mounts, Talos considerations)
   - Backup and migration strategies (app-level backups, PVC cloning, DR)
   - Monitoring and alerting (key metrics, critical alerts)
   - Troubleshooting (Pending PVCs, creation failures, mount issues, performance)
   - Comparison: OpenEBS LocalPV vs Rook-Ceph (when to use each)
   - Future enhancements (volume expansion, snapshots, multi-disk, capacity management)
10. **Preserved original context**: Sprint 6, Lane Storage, apps cluster focus

**Gaps Identified and Fixed**:
- Added PSA baseline enforcement (HostPath requires privileged access)
- Added WaitForFirstConsumer binding mode for topology awareness
- Added comprehensive monitoring (PodMonitor, 6 alerts)
- Added reclaim policy configuration (Delete vs Retain)
- Added volume expansion support
- Added node preparation documentation
- Added performance characteristics and benchmarking guidance
- Added backup/migration strategies
- Added detailed comparison with Rook-Ceph
- Added troubleshooting procedures for common issues

**Why v3.0**:
- Enforces clean separation: Story 29 = CREATE manifests (local), Story 45 = DEPLOY & VALIDATE (cluster)
- Enables parallel work: manifest creation can proceed without cluster access
- Improves testing: all manifests validated locally before any deployment
- Reduces risk: deployment issues don't block manifest refinement work
- Maintains GitOps principles: manifest creation is pure IaC work
