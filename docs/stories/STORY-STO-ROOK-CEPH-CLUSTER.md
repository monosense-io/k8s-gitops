# 16 — STORY-STO-ROOK-CEPH-CLUSTER — Create Rook-Ceph Cluster Manifests

Sequence: 16/50 | Prev: STORY-STO-ROOK-CEPH-OPERATOR.md | Next: STORY-OBS-VM-STACK.md
Sprint: 3 | Lane: Storage
Global Sequence: 16/50

Status: Draft (v3.0 Refinement)
Owner: Platform Engineering
Date: 2025-10-26 (v3.0 Refinement)
Links: docs/architecture.md §10; kubernetes/infrastructure/storage/rook-ceph/cluster/

---

## Story

As a platform engineer, I want to **create Rook-Ceph cluster manifests** for deploying a production-grade Ceph storage cluster, so that when deployed in Story 45, the infra cluster provides highly available, durable distributed storage (RBD block storage) for databases, observability, and platform services with data replication and self-healing.

This story creates the declarative Ceph cluster configuration manifests (CephCluster, CephBlockPool, StorageClass, toolbox). Actual deployment and storage validation happen in Story 45 (VALIDATE-NETWORKING).

## Why / Outcome

- Create Ceph cluster manifests for GitOps deployment
- Define MON/MGR/OSD topology and resource allocation
- Configure block storage pool with replication
- Enable RBD StorageClass for dynamic PVC provisioning
- Support highly available storage for critical workloads
- Foundation for database persistence and backup storage

## Scope

**This Story (Manifest Creation):**
- Create Ceph cluster manifests in `kubernetes/infrastructure/storage/rook-ceph/cluster/`
- Create CephCluster resource with MON/MGR/OSD configuration
- Create CephBlockPool for replicated block storage
- Create StorageClass for RBD provisioner
- Create Ceph toolbox deployment for debugging
- Create PrometheusRule for Ceph health monitoring
- Update cluster-settings with Ceph variables (if needed)
- Local validation (flux build, kubectl dry-run)

**Deferred to Story 45 (Deployment & Validation):**
- Deploying Ceph cluster to infra nodes
- Verifying Ceph MON/MGR/OSD pods running
- Testing Ceph health status (HEALTH_OK)
- Validating dynamic PVC provisioning with RBD
- Testing data replication and failover
- Metrics scraping validation

---

## Acceptance Criteria

**Manifest Creation (This Story):**

1. **CephCluster Manifest Created:**
   - `kubernetes/infrastructure/storage/rook-ceph/cluster/cephcluster.yaml` exists
   - MON count: 3 (quorum)
   - MGR count: 2 (active-standby HA)
   - OSD configuration: device class `ssd`, device filter or node-specific
   - Data directory: `/var/lib/rook`
   - Dashboard enabled

2. **CephBlockPool Manifest Created:**
   - `kubernetes/infrastructure/storage/rook-ceph/cluster/cephblockpool.yaml` exists
   - Pool name: `${CEPH_BLOCK_POOL_NAME}` (e.g., `rook-ceph-block`)
   - Replication: 3 replicas
   - Failure domain: host (separate nodes)

3. **StorageClass Manifest Created:**
   - `kubernetes/infrastructure/storage/rook-ceph/cluster/storageclass.yaml` exists
   - StorageClass name: `${CEPH_BLOCK_STORAGE_CLASS}` (e.g., `rook-ceph-block`)
   - Provisioner: `rook-ceph.rbd.csi.ceph.com`
   - Volume binding mode: Immediate
   - Reclaim policy: Delete
   - References CephBlockPool

4. **Toolbox Deployment Created:**
   - `kubernetes/infrastructure/storage/rook-ceph/cluster/toolbox.yaml` exists
   - Ceph toolbox pod for `ceph` CLI access

5. **PrometheusRule Manifest Created:**
   - `kubernetes/infrastructure/storage/rook-ceph/cluster/prometheusrule.yaml` exists
   - Alert rules for Ceph health warnings
   - Alert rules for OSD failures
   - Alert rules for storage capacity

6. **Cluster Settings Alignment:**
   - Cluster-settings include Ceph variables:
     - `CEPH_BLOCK_POOL_NAME: "rook-ceph-block"`
     - `CEPH_BLOCK_STORAGE_CLASS: "rook-ceph-block"`
     - `ROOK_CEPH_MON_COUNT: "3"`
     - `ROOK_CEPH_MGR_COUNT: "2"`

7. **Local Validation Passes:**
   - `flux build kustomization cluster-infra-infrastructure --path ./kubernetes/infrastructure` succeeds
   - Output shows CephCluster resources
   - `kubectl --dry-run=client` validates manifests

**Deferred to Story 45 (Deployment & Validation):**
- ❌ Ceph cluster HEALTH_OK
- ❌ MON/MGR/OSD pods running
- ❌ StorageClass available
- ❌ Dynamic PVC provisioning working
- ❌ Data replication verified
- ❌ PrometheusRule loaded
- ❌ Metrics scraped by VictoriaMetrics

---

## Dependencies

**Prerequisites (v3.0):**
- Story 15 (STORY-STO-ROOK-CEPH-OPERATOR) complete (Rook operator manifests created)
- Cluster-settings ConfigMaps with Ceph variables
- Node storage device planning documented (NVMe devices for OSDs)
- Tools: kubectl (for dry-run), flux CLI, yq

**NOT Required (v3.0):**
- ❌ Cluster access (validation is local-only)
- ❌ Rook operator deployed (deployment in Story 45)
- ❌ Node storage devices attached (Story 45)
- ❌ Running clusters (Story 45 handles deployment)

---

## Implementation Tasks

### T1: Verify Prerequisites (Local Validation Only)

- [ ] Verify Story 15 complete (Rook operator manifests created):
  ```bash
  ls -la kubernetes/infrastructure/storage/rook-ceph/operator/
  ```

- [ ] Review node storage device plan:
  ```bash
  # Document expected devices (example):
  # - Node 1: /dev/nvme0n1 (SSD)
  # - Node 2: /dev/nvme0n1 (SSD)
  # - Node 3: /dev/nvme0n1 (SSD)
  # Verification happens in Story 45
  ```

---

### T2: Create Ceph Cluster Manifests

- [ ] Create directory structure:
  ```bash
  mkdir -p kubernetes/infrastructure/storage/rook-ceph/cluster
  ```

- [ ] Create `cephcluster.yaml`:
  ```yaml
  ---
  apiVersion: ceph.rook.io/v1
  kind: CephCluster
  metadata:
    name: rook-ceph
    namespace: rook-ceph
  spec:
    cephVersion:
      image: quay.io/ceph/ceph:v18.2.4
      allowUnsupported: false

    dataDirHostPath: /var/lib/rook

    # Skip initial cluster upgrade check
    skipUpgradeChecks: false
    continueUpgradeAfterChecksEvenIfNotHealthy: false

    # Wait for healthy OSDs before proceeding
    waitTimeoutForHealthyOSDInMinutes: 10

    mon:
      count: 3
      allowMultiplePerNode: false

    mgr:
      count: 2
      allowMultiplePerNode: false
      modules:
        - name: pg_autoscaler
          enabled: true
        - name: rook
          enabled: true

    dashboard:
      enabled: true
      ssl: true

    monitoring:
      enabled: true

    network:
      # Use host networking for performance
      provider: host

    crashCollector:
      disable: false

    logCollector:
      enabled: true
      periodicity: daily
      maxLogSize: 500M

    cleanupPolicy:
      confirmation: ""
      sanitizeDisks:
        method: quick
        dataSource: zero
        iteration: 1

    removeOSDsIfOutAndSafeToRemove: false

    # Priority class for Ceph daemons
    priorityClassNames:
      mon: system-node-critical
      osd: system-node-critical
      mgr: system-cluster-critical

    storage:
      useAllNodes: false
      useAllDevices: false
      deviceFilter: ""

      # Device class for OSDs
      config:
        osdsPerDevice: "1"
        encryptedDevice: "false"
        databaseSizeMB: "1024"
        walSizeMB: "576"

      nodes:
        - name: "infra-node-1"
          devices:
            - name: "/dev/nvme0n1"
              config:
                deviceClass: ssd
        - name: "infra-node-2"
          devices:
            - name: "/dev/nvme0n1"
              config:
                deviceClass: ssd
        - name: "infra-node-3"
          devices:
            - name: "/dev/nvme0n1"
              config:
                deviceClass: ssd

    # Resource limits for Ceph daemons
    resources:
      mon:
        limits:
          cpu: "2"
          memory: "2Gi"
        requests:
          cpu: "500m"
          memory: "1Gi"
      mgr:
        limits:
          cpu: "1"
          memory: "1Gi"
        requests:
          cpu: "500m"
          memory: "512Mi"
      osd:
        limits:
          cpu: "2"
          memory: "4Gi"
        requests:
          cpu: "1"
          memory: "2Gi"

    # Health check configuration
    healthCheck:
      daemonHealth:
        mon:
          interval: 45s
          timeout: 600s
        osd:
          interval: 60s
          timeout: 600s
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

- [ ] Create `cephblockpool.yaml`:
  ```yaml
  ---
  apiVersion: ceph.rook.io/v1
  kind: CephBlockPool
  metadata:
    name: ${CEPH_BLOCK_POOL_NAME}
    namespace: rook-ceph
  spec:
    # Replication factor
    replicated:
      size: 3
      requireSafeReplicaSize: true
      replicasPerFailureDomain: 1
      subFailureDomain: host

    # Failure domain (separate nodes)
    failureDomain: host

    # Device class filter (use SSD devices only)
    deviceClass: ssd

    # Enable compression
    compressionMode: none

    # Mirroring disabled (single cluster)
    mirroring:
      enabled: false

    # Quotas (optional - set per pool limits)
    # quotas:
    #   maxBytes: 107374182400  # 100 GB
    #   maxObjects: 100000

    # Status check
    statusCheck:
      mirror:
        disabled: false
        interval: 60s
  ```

- [ ] Create `storageclass.yaml`:
  ```yaml
  ---
  apiVersion: storage.k8s.io/v1
  kind: StorageClass
  metadata:
    name: ${CEPH_BLOCK_STORAGE_CLASS}
    annotations:
      storageclass.kubernetes.io/is-default-class: "false"
  provisioner: rook-ceph.rbd.csi.ceph.com
  parameters:
    clusterID: rook-ceph
    pool: ${CEPH_BLOCK_POOL_NAME}
    imageFormat: "2"
    imageFeatures: layering
    csi.storage.k8s.io/provisioner-secret-name: rook-csi-rbd-provisioner
    csi.storage.k8s.io/provisioner-secret-namespace: rook-ceph
    csi.storage.k8s.io/controller-expand-secret-name: rook-csi-rbd-provisioner
    csi.storage.k8s.io/controller-expand-secret-namespace: rook-ceph
    csi.storage.k8s.io/node-stage-secret-name: rook-csi-rbd-node
    csi.storage.k8s.io/node-stage-secret-namespace: rook-ceph
    csi.storage.k8s.io/fstype: ext4
  allowVolumeExpansion: true
  reclaimPolicy: Delete
  volumeBindingMode: Immediate
  ```

- [ ] Create `toolbox.yaml`:
  ```yaml
  ---
  apiVersion: apps/v1
  kind: Deployment
  metadata:
    name: rook-ceph-tools
    namespace: rook-ceph
    labels:
      app: rook-ceph-tools
  spec:
    replicas: 1
    selector:
      matchLabels:
        app: rook-ceph-tools
    template:
      metadata:
        labels:
          app: rook-ceph-tools
      spec:
        dnsPolicy: ClusterFirstWithHostNet
        containers:
          - name: rook-ceph-tools
            image: quay.io/ceph/ceph:v18.2.4
            command:
              - /bin/bash
              - -c
              - |
                # Wait for the cluster to be ready
                while ! ceph status; do
                  echo "Waiting for Ceph cluster..."
                  sleep 5
                done
                # Keep container running
                sleep infinity
            env:
              - name: ROOK_CEPH_USERNAME
                valueFrom:
                  secretKeyRef:
                    name: rook-ceph-mon
                    key: ceph-username
              - name: ROOK_CEPH_SECRET
                valueFrom:
                  secretKeyRef:
                    name: rook-ceph-mon
                    key: ceph-secret
            volumeMounts:
              - name: ceph-config
                mountPath: /etc/ceph
              - name: mon-endpoint-volume
                mountPath: /etc/rook
        volumes:
          - name: ceph-config
            emptyDir: {}
          - name: mon-endpoint-volume
            configMap:
              name: rook-ceph-mon-endpoints
              items:
                - key: data
                  path: mon-endpoints
        tolerations:
          - key: node-role.kubernetes.io/control-plane
            operator: Exists
            effect: NoSchedule
  ```

- [ ] Create `prometheusrule.yaml`:
  ```yaml
  ---
  apiVersion: monitoring.coreos.com/v1
  kind: PrometheusRule
  metadata:
    name: rook-ceph-cluster
    namespace: rook-ceph
  spec:
    groups:
      - name: rook-ceph-cluster
        interval: 30s
        rules:
          - alert: CephClusterHealthWarning
            expr: ceph_health_status == 1
            for: 10m
            labels:
              severity: warning
            annotations:
              summary: "Ceph cluster health is WARN"
              description: "Ceph cluster health is WARN for more than 10 minutes"

          - alert: CephClusterHealthError
            expr: ceph_health_status == 2
            for: 5m
            labels:
              severity: critical
            annotations:
              summary: "Ceph cluster health is ERROR"
              description: "Ceph cluster health is ERROR for more than 5 minutes"

          - alert: CephOSDDown
            expr: ceph_osd_up == 0
            for: 5m
            labels:
              severity: warning
            annotations:
              summary: "Ceph OSD down"
              description: "Ceph OSD {{ $labels.ceph_daemon }} is down"

          - alert: CephOSDNearFull
            expr: ceph_osd_stat_bytes_used / ceph_osd_stat_bytes > 0.85
            for: 10m
            labels:
              severity: warning
            annotations:
              summary: "Ceph OSD near full"
              description: "Ceph OSD {{ $labels.ceph_daemon }} is {{ $value | humanizePercentage }} full"

          - alert: CephPGDegraded
            expr: ceph_pg_degraded > 0
            for: 15m
            labels:
              severity: warning
            annotations:
              summary: "Ceph PGs degraded"
              description: "{{ $value }} Ceph PGs are degraded for more than 15 minutes"

          - alert: CephPoolNearFull
            expr: ceph_pool_bytes_used / ceph_pool_max_avail > 0.85
            for: 10m
            labels:
              severity: warning
            annotations:
              summary: "Ceph pool near full"
              description: "Ceph pool {{ $labels.name }} is {{ $value | humanizePercentage }} full"
  ```

- [ ] Create `kustomization.yaml` (glue file):
  ```yaml
  ---
  apiVersion: kustomize.config.k8s.io/v1beta1
  kind: Kustomization
  resources:
    - cephcluster.yaml
    - cephblockpool.yaml
    - storageclass.yaml
    - toolbox.yaml
    - prometheusrule.yaml
  ```

---

### T3: Create Flux Kustomization

- [ ] Create `ks.yaml`:
  ```yaml
  ---
  apiVersion: kustomize.toolkit.fluxcd.io/v1
  kind: Kustomization
  metadata:
    name: rook-ceph-cluster
    namespace: flux-system
  spec:
    interval: 10m
    retryInterval: 1m
    timeout: 15m  # Ceph cluster takes time to initialize
    sourceRef:
      kind: GitRepository
      name: flux-system
    path: ./kubernetes/infrastructure/storage/rook-ceph/cluster
    prune: true
    wait: true
    dependsOn:
      - name: rook-ceph-operator
    postBuild:
      substitute: {}
      substituteFrom:
        - kind: ConfigMap
          name: cluster-settings
    targetNamespace: rook-ceph
    healthChecks:
      - apiVersion: ceph.rook.io/v1
        kind: CephCluster
        name: rook-ceph
        namespace: rook-ceph
      - apiVersion: ceph.rook.io/v1
        kind: CephBlockPool
        name: rook-ceph-block
        namespace: rook-ceph
  ```

---

### T4: Local Validation (NO Cluster Access)

- [ ] Validate manifest syntax:
  ```bash
  kubectl --dry-run=client -f kubernetes/infrastructure/storage/rook-ceph/cluster/
  ```

- [ ] Validate with kustomize:
  ```bash
  kustomize build kubernetes/infrastructure/storage/rook-ceph/cluster
  ```

- [ ] Validate Flux build for infra cluster:
  ```bash
  flux build kustomization cluster-infra-infrastructure --path ./kubernetes/infrastructure | \
    yq 'select(.kind == "CephCluster" and .metadata.name == "rook-ceph")'

  # Verify MON count substitution
  flux build kustomization cluster-infra-infrastructure --path ./kubernetes/infrastructure | \
    yq 'select(.kind == "CephCluster") | .spec.mon.count'
  # Expected: 3

  # Verify pool name substitution
  flux build kustomization cluster-infra-infrastructure --path ./kubernetes/infrastructure | \
    yq 'select(.kind == "CephBlockPool") | .metadata.name'
  # Expected: rook-ceph-block (or value from cluster-settings)
  ```

---

### T5: Update Storage Infrastructure Kustomization

- [ ] Update `kubernetes/infrastructure/storage/kustomization.yaml`:
  ```yaml
  ---
  apiVersion: kustomize.config.k8s.io/v1beta1
  kind: Kustomization
  resources:
    - openebs/ks.yaml
    - rook-ceph/operator/ks.yaml
    - rook-ceph/cluster/ks.yaml  # ADD THIS LINE
  ```

---

### T6: Update Cluster Settings (If Needed)

- [ ] Verify infra cluster-settings have Ceph variables:
  ```yaml
  # kubernetes/clusters/infra/cluster-settings.yaml
  CEPH_BLOCK_POOL_NAME: "rook-ceph-block"
  CEPH_BLOCK_STORAGE_CLASS: "rook-ceph-block"
  ROOK_CEPH_MON_COUNT: "3"
  ROOK_CEPH_MGR_COUNT: "2"
  ```

- [ ] If variables missing, add them to cluster-settings ConfigMap

---

### T7: Commit Manifests to Git

- [ ] Commit and push:
  ```bash
  git add kubernetes/infrastructure/storage/rook-ceph/cluster/
  git commit -m "feat(storage): add Rook-Ceph cluster manifests

  - Create CephCluster with 3 MONs, 2 MGRs, SSD OSDs
  - Create CephBlockPool with 3x replication and host failure domain
  - Create StorageClass for RBD provisioner with volume expansion
  - Create Ceph toolbox for CLI access and debugging
  - Create PrometheusRule for cluster health and capacity monitoring
  - Configure resource limits for Ceph daemons
  - Enable dashboard and monitoring

  Part of Story 16 (v3.0 manifests-first approach)
  Deployment deferred to Story 45 (VALIDATE-NETWORKING)"
  git push origin main
  ```

---

### Runtime Validation (MOVED TO STORY 45)

The following validation happens in **Story 45 (VALIDATE-NETWORKING)** after cluster bootstrap:

```bash
# Deploy Ceph cluster (Story 45 only)
flux reconcile kustomization rook-ceph-cluster --with-source

# Monitor Ceph cluster creation (takes 5-10 minutes)
kubectl -n rook-ceph get cephcluster rook-ceph -w

# Verify CephCluster phase
kubectl -n rook-ceph get cephcluster rook-ceph -o jsonpath='{.status.phase}'
# Expected: Ready

# Verify Ceph MONs running
kubectl -n rook-ceph get pods -l app=rook-ceph-mon
# Expected: 3 MON pods in Running state

# Verify Ceph MGRs running
kubectl -n rook-ceph get pods -l app=rook-ceph-mgr
# Expected: 2 MGR pods in Running state

# Verify Ceph OSDs running
kubectl -n rook-ceph get pods -l app=rook-ceph-osd
# Expected: OSD pods based on available devices (1 per device)

# Check Ceph cluster health via toolbox
kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph status
# Expected output showing:
# - cluster: HEALTH_OK (or HEALTH_WARN during initial rebalance)
# - mon: 3 daemons
# - mgr: active + standby
# - osd: X osds: X up, X in

# Check Ceph cluster details
kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph -s
kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph osd status
kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph df

# Verify CephBlockPool created
kubectl -n rook-ceph get cephblockpool rook-ceph-block
kubectl -n rook-ceph get cephblockpool rook-ceph-block -o jsonpath='{.status.phase}'
# Expected: Ready

# Check pool details
kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph osd pool ls detail
# Expected: rook-ceph-block pool with size=3, min_size=2

# Verify StorageClass created
kubectl get sc rook-ceph-block
kubectl get sc rook-ceph-block -o yaml
# Expected: provisioner: rook-ceph.rbd.csi.ceph.com

# Test dynamic PVC provisioning
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ceph-test-pvc
  namespace: default
spec:
  storageClassName: rook-ceph-block
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
EOF

# Verify PVC bound
kubectl -n default get pvc ceph-test-pvc
# Expected: Status Bound

# Verify PV created
kubectl get pv
# Expected: PV bound to ceph-test-pvc

# Create test pod to use PVC
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: ceph-test-pod
  namespace: default
spec:
  containers:
    - name: test
      image: busybox:latest
      command: ["sh", "-c", "echo 'Ceph test' > /data/test.txt && sleep 3600"]
      volumeMounts:
        - name: data
          mountPath: /data
  volumes:
    - name: data
      persistentVolumeClaim:
        claimName: ceph-test-pvc
EOF

# Wait for pod to be running
kubectl -n default wait --for=condition=ready pod/ceph-test-pod --timeout=60s

# Verify data written
kubectl -n default exec ceph-test-pod -- cat /data/test.txt
# Expected: "Ceph test"

# Check RBD image created
kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- rbd ls -p rook-ceph-block
# Expected: RBD image for PVC

# Verify data replication (3 replicas)
kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph osd map rook-ceph-block <image-name>
# Expected: Shows 3 OSDs

# Test pod restart with data persistence
kubectl -n default delete pod ceph-test-pod
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: ceph-test-pod-2
  namespace: default
spec:
  containers:
    - name: test
      image: busybox:latest
      command: ["sh", "-c", "cat /data/test.txt && sleep 3600"]
      volumeMounts:
        - name: data
          mountPath: /data
  volumes:
    - name: data
      persistentVolumeClaim:
        claimName: ceph-test-pvc
EOF

kubectl -n default wait --for=condition=ready pod/ceph-test-pod-2 --timeout=60s
kubectl -n default logs ceph-test-pod-2
# Expected: "Ceph test" (data persisted)

# Test volume expansion
kubectl patch pvc ceph-test-pvc -n default -p '{"spec":{"resources":{"requests":{"storage":"2Gi"}}}}'
kubectl -n default get pvc ceph-test-pvc -w
# Expected: PVC expanded to 2Gi

# Verify PrometheusRule
kubectl -n rook-ceph get prometheusrule rook-ceph-cluster
kubectl -n rook-ceph get prometheusrule rook-ceph-cluster -o yaml | grep -A 5 "alert:"
# Expected: Alert rules present

# Verify Ceph metrics
kubectl -n rook-ceph port-forward svc/rook-ceph-mgr 9283:9283 &
sleep 2
curl -s http://localhost:9283/metrics | grep ceph_health_status
# Expected: ceph_health_status metric (0=OK, 1=WARN, 2=ERROR)

# Verify Ceph dashboard (optional)
kubectl -n rook-ceph get svc rook-ceph-mgr-dashboard
# Get dashboard password:
kubectl -n rook-ceph get secret rook-ceph-dashboard-password -o jsonpath='{.data.password}' | base64 -d
# Dashboard accessible via service (requires ingress or port-forward)

# Cleanup test resources
kubectl -n default delete pod ceph-test-pod-2
kubectl -n default delete pvc ceph-test-pvc
kubectl get pv | grep ceph-test-pvc
# Expected: PV deleted (reclaimPolicy: Delete)

pkill -f "port-forward.*rook-ceph"
```

---

## Definition of Done

**Manifest Creation Complete (This Story):**
- [ ] Directory created: `kubernetes/infrastructure/storage/rook-ceph/cluster/`
- [ ] CephCluster manifest created with:
  - [ ] 3 MONs, 2 MGRs
  - [ ] OSD configuration for SSD device class
  - [ ] Resource limits for daemons
  - [ ] Dashboard and monitoring enabled
- [ ] CephBlockPool manifest created with 3x replication
- [ ] StorageClass manifest created with RBD provisioner
- [ ] Toolbox deployment created for CLI access
- [ ] PrometheusRule manifest created with health and capacity alerts
- [ ] Kustomization glue file created
- [ ] Flux Kustomization created with dependencies and health checks
- [ ] Storage infrastructure kustomization updated to include Ceph cluster
- [ ] Cluster-settings have Ceph variables
- [ ] Local validation passes:
  - [ ] `kubectl --dry-run=client` succeeds
  - [ ] `kustomize build` succeeds
  - [ ] `flux build` shows CephCluster resources
  - [ ] Pool and StorageClass name substitution verified
- [ ] Manifests committed to git
- [ ] Story 45 can proceed with deployment

**NOT Part of DoD (Moved to Story 45):**
- ❌ Ceph cluster HEALTH_OK
- ❌ MON/MGR/OSD pods running
- ❌ StorageClass available
- ❌ Dynamic PVC provisioning working
- ❌ Data replication verified
- ❌ Volume expansion tested
- ❌ PrometheusRule loaded
- ❌ Metrics scraped by VictoriaMetrics
- ❌ Ceph dashboard accessible

---

## Design Notes

### Ceph Cluster Architecture

Production Ceph cluster components:
- **MONs (3)**: Maintain cluster membership and state (quorum)
- **MGRs (2)**: Cluster management and metrics (active-standby HA)
- **OSDs (1 per device)**: Store actual data with replication
- **Dashboard**: Web UI for cluster monitoring

### Replication Strategy

CephBlockPool replication configuration:
- **Size: 3**: Each object replicated to 3 OSDs
- **Min Size: 2**: Minimum replicas for I/O operations
- **Failure Domain: host**: Replicas spread across different nodes
- **Device Class: ssd**: Use only SSD devices for performance

### Resource Planning

Ceph daemon resource requirements:
- **MON**: 500m-2 CPU, 1-2Gi memory each (3 total)
- **MGR**: 500m-1 CPU, 512Mi-1Gi memory each (2 total)
- **OSD**: 1-2 CPU, 2-4Gi memory each (per device)
- **Total (3 OSDs)**: ~7-12 CPU, ~10-20Gi memory

### Storage Performance

Block storage characteristics:
- **Speed**: NVMe SSD performance (~3-5GB/s per OSD)
- **Latency**: Low latency for databases (~1-5ms)
- **Replication**: 3x overhead (3GB stored = 1GB usable)
- **IOPS**: High IOPS for transactional workloads

### Toolbox Usage

Ceph toolbox provides CLI access:
```bash
# Access toolbox
kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- bash

# Common commands
ceph status       # Cluster health
ceph osd status   # OSD status
ceph df           # Cluster capacity
ceph pg stat      # Placement group stats
rbd ls            # List RBD images
```

### Volume Expansion

StorageClass configured for volume expansion:
- `allowVolumeExpansion: true`
- Users can increase PVC size without downtime
- Filesystem automatically resized

### Backup and DR

For backup and disaster recovery documentation, see:
- `kubernetes/infrastructure/storage/rook-ceph/BACKUP_DISASTER_RECOVERY.md` (to be created)

---

## Change Log

| Date       | Version | Description                          | Author  |
|------------|---------|--------------------------------------|---------|
| 2025-10-26 | 3.0     | **v3.0 Refinement**: Updated header, story, scope, AC, dependencies, tasks, DoD for manifests-first approach. Separated manifest creation from deployment (moved to Story 45). Tasks simplified to T1-T7 focusing on local validation only. Added comprehensive Ceph cluster health checking and storage provisioning testing in runtime validation section. Added design notes for Ceph architecture, replication, and resource planning. | Platform Engineering |
| 2025-10-21 | 1.0     | Initial draft | Platform Engineering |
