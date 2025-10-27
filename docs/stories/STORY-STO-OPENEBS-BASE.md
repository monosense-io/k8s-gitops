# 14 — STORY-STO-OPENEBS-BASE — Create OpenEBS LocalPV Manifests

Sequence: 14/50 | Prev: STORY-NET-CLUSTERMESH-DNS.md | Next: STORY-STO-ROOK-CEPH-OPERATOR.md
Sprint: 3 | Lane: Storage
Global Sequence: 14/50

Status: Draft (v3.0 Refinement)
Owner: Platform Engineering
Date: 2025-10-26 (v3.0 Refinement)
Links: docs/architecture.md §10; kubernetes/infrastructure/storage/openebs/

---

## Story

As a platform engineer, I want to **create OpenEBS LocalPV manifests** for node-local storage provisioning, so that when deployed in Story 45, the infra cluster provides fast local storage classes for stateful components (logs, caches, CI runners) where node-local NVMe disks are appropriate.

This story creates the declarative OpenEBS manifests (HelmRelease, StorageClass, PrometheusRule). Actual deployment and dynamic provisioning validation happen in Story 45 (VALIDATE-NETWORKING).

## Why / Outcome

- Create OpenEBS LocalPV manifests for GitOps deployment
- Enable fast node-local storage with minimal overhead
- Support stateful workloads requiring local disk performance
- Provide simple storage lifecycle management
- Foundation for CI/CD runners and caching workloads

## Scope

**This Story (Manifest Creation):**
- Create OpenEBS manifests in `kubernetes/infrastructure/storage/openebs/`
- Create HelmRelease for OpenEBS LocalPV
- Create StorageClass for OpenEBS LocalPV provisioner
- Create PrometheusRule for observability
- Create Kustomization for OpenEBS resources
- Update cluster-settings with OpenEBS variables (if needed)
- Local validation (flux build, kubectl dry-run)

**Deferred to Story 45 (Deployment & Validation):**
- Deploying OpenEBS to infra cluster
- Verifying OpenEBS controller and DaemonSet running
- Testing dynamic PVC provisioning
- Validating storage performance
- Metrics scraping validation

---

## Acceptance Criteria

**Manifest Creation (This Story):**

1. **HelmRelease Manifest Created:**
   - `kubernetes/infrastructure/storage/openebs/app/helmrelease.yaml` exists
   - OpenEBS chart version configured
   - Namespace: `openebs-system`
   - LocalPV hostpath enabled
   - Base path configured via `${OPENEBS_BASEPATH}`

2. **StorageClass Manifest Created:**
   - `kubernetes/infrastructure/storage/openebs/storageclass.yaml` exists
   - StorageClass name: `${OPENEBS_STORAGE_CLASS}` (e.g., `openebs-hostpath`)
   - Provisioner: `openebs.io/local`
   - Volume binding mode: WaitForFirstConsumer
   - Base path configured

3. **PrometheusRule Manifest Created:**
   - `kubernetes/infrastructure/storage/openebs/prometheusrule.yaml` exists
   - Alert rules for OpenEBS provisioner failures
   - Alert rules for PVC binding issues

4. **Kustomization Created:**
   - `kubernetes/infrastructure/storage/openebs/ks.yaml` exists
   - References OpenEBS manifests
   - No dependencies (can deploy early)
   - `kubernetes/infrastructure/storage/openebs/app/kustomization.yaml` glue file exists

5. **Cluster Settings Alignment:**
   - Cluster-settings include OpenEBS variables:
     - Infra: `OPENEBS_BASEPATH: "/var/openebs/local"` (Talos-compatible path)
     - Infra: `OPENEBS_STORAGE_CLASS: "openebs-hostpath"`

6. **Local Validation Passes:**
   - `flux build kustomization cluster-infra-infrastructure --path ./kubernetes/infrastructure` succeeds
   - Output shows OpenEBS resources
   - `kubectl --dry-run=client` validates manifests

**Deferred to Story 45 (Deployment & Validation):**
- ❌ OpenEBS controller pod running
- ❌ OpenEBS node DaemonSet running on all nodes
- ❌ StorageClass available
- ❌ Dynamic PVC provisioning working
- ❌ PrometheusRule loaded
- ❌ Metrics scraped by VictoriaMetrics

---

## Dependencies

**Prerequisites (v3.0):**
- Story 44 (STORY-BOOT-CORE) complete (Flux operational)
- Talos Linux node configuration supports local storage paths
- Cluster-settings ConfigMaps with OpenEBS variables
- Tools: kubectl (for dry-run), flux CLI, yq

**NOT Required (v3.0):**
- ❌ Cluster access (validation is local-only)
- ❌ VictoriaMetrics deployed (deployment in Story 45)
- ❌ Running clusters (Story 45 handles deployment)

---

## Implementation Tasks

### T1: Verify Prerequisites (Local Validation Only)

- [ ] Verify Story 44 complete (Flux operational):
  ```bash
  ls -la bootstrap/helmfile.d/01-core.yaml.gotmpl
  grep -i "flux" bootstrap/helmfile.d/01-core.yaml.gotmpl
  ```

- [ ] Verify Talos supports local storage paths:
  ```bash
  # Note: /var/openebs/local is a Talos-compatible path
  # Talos mounts /var as persistent storage
  # This verification happens in Story 45 during deployment
  ```

---

### T2: Create OpenEBS Manifests

- [ ] Create directory structure:
  ```bash
  mkdir -p kubernetes/infrastructure/storage/openebs/app
  ```

- [ ] Create `helmrelease.yaml`:
  ```yaml
  ---
  apiVersion: v1
  kind: Namespace
  metadata:
    name: openebs-system
  ---
  apiVersion: source.toolkit.fluxcd.io/v1
  kind: HelmRepository
  metadata:
    name: openebs
    namespace: openebs-system
  spec:
    interval: 15m
    url: https://openebs.github.io/openebs
  ---
  apiVersion: helm.toolkit.fluxcd.io/v2
  kind: HelmRelease
  metadata:
    name: openebs
    namespace: openebs-system
  spec:
    interval: 1h
    chart:
      spec:
        chart: openebs
        version: 4.1.x
        sourceRef:
          kind: HelmRepository
          name: openebs
          namespace: openebs-system
    install:
      remediation:
        retries: 3
      createNamespace: false  # Namespace created above
    upgrade:
      remediation:
        retries: 3
        strategy: rollback
      cleanupOnFail: true
    rollback:
      recreate: true
      cleanupOnFail: true
    values:
      # Disable all engines except LocalPV hostpath
      engines:
        local:
          lvm:
            enabled: false
          zfs:
            enabled: false
        replicated:
          mayastor:
            enabled: false

      # Enable LocalPV hostpath
      localpv-provisioner:
        enabled: true
        hostpathClass:
          enabled: true
          name: ${OPENEBS_STORAGE_CLASS}
          basePath: ${OPENEBS_BASEPATH}
          isDefaultClass: false

      # Observability
      serviceMonitor:
        enabled: true

      # Helper pod for debugging
      helper:
        image: "busybox"
        imageTag: "latest"
  ```

- [ ] Create `storageclass.yaml`:
  ```yaml
  ---
  apiVersion: storage.k8s.io/v1
  kind: StorageClass
  metadata:
    name: ${OPENEBS_STORAGE_CLASS}
    annotations:
      storageclass.kubernetes.io/is-default-class: "false"
      cas.openebs.io/config: |
        - name: StorageType
          value: "hostpath"
        - name: BasePath
          value: ${OPENEBS_BASEPATH}
  provisioner: openebs.io/local
  volumeBindingMode: WaitForFirstConsumer
  reclaimPolicy: Delete
  ```

- [ ] Create `prometheusrule.yaml`:
  ```yaml
  ---
  apiVersion: monitoring.coreos.com/v1
  kind: PrometheusRule
  metadata:
    name: openebs
    namespace: openebs-system
  spec:
    groups:
      - name: openebs
        interval: 30s
        rules:
          - alert: OpenEBSProvisionerDown
            expr: up{job="openebs-localpv"} == 0
            for: 5m
            labels:
              severity: warning
            annotations:
              summary: "OpenEBS LocalPV provisioner is down"
              description: "OpenEBS LocalPV provisioner pod {{ $labels.pod }} is down"

          - alert: OpenEBSPVCBindingFailed
            expr: increase(openebs_volume_provision_total{status="failed"}[5m]) > 0
            for: 5m
            labels:
              severity: warning
            annotations:
              summary: "OpenEBS PVC binding failed"
              description: "OpenEBS failed to provision PVC in namespace {{ $labels.namespace }}"

          - alert: OpenEBSHighDiskUsage
            expr: |
              (openebs_actual_used / openebs_size_of_volume) > 0.85
            for: 10m
            labels:
              severity: warning
            annotations:
              summary: "OpenEBS volume high disk usage"
              description: "OpenEBS volume {{ $labels.persistentvolumeclaim }} in namespace {{ $labels.namespace }} is {{ $value | humanizePercentage }} full"
  ```

- [ ] Create `kustomization.yaml` (glue file):
  ```yaml
  ---
  apiVersion: kustomize.config.k8s.io/v1beta1
  kind: Kustomization
  resources:
    - helmrelease.yaml
    - storageclass.yaml
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
    name: openebs
    namespace: flux-system
  spec:
    interval: 10m
    retryInterval: 1m
    timeout: 5m
    sourceRef:
      kind: GitRepository
      name: flux-system
    path: ./kubernetes/infrastructure/storage/openebs/app
    prune: true
    wait: true
    postBuild:
      substitute: {}
      substituteFrom:
        - kind: ConfigMap
          name: cluster-settings
    targetNamespace: openebs-system
    healthChecks:
      - apiVersion: helm.toolkit.fluxcd.io/v2
        kind: HelmRelease
        name: openebs
        namespace: openebs-system
      - apiVersion: apps/v1
        kind: Deployment
        name: openebs-localpv-provisioner
        namespace: openebs-system
  ```

---

### T4: Local Validation (NO Cluster Access)

- [ ] Validate manifest syntax:
  ```bash
  kubectl --dry-run=client -f kubernetes/infrastructure/storage/openebs/app/
  ```

- [ ] Validate with kustomize:
  ```bash
  kustomize build kubernetes/infrastructure/storage/openebs/app
  ```

- [ ] Validate Flux build for infra cluster:
  ```bash
  flux build kustomization cluster-infra-infrastructure --path ./kubernetes/infrastructure | \
    yq 'select(.kind == "HelmRelease" and .metadata.name == "openebs")'

  # Verify base path substitution
  flux build kustomization cluster-infra-infrastructure --path ./kubernetes/infrastructure | \
    yq 'select(.kind == "StorageClass" and .metadata.name == "openebs-hostpath") | .metadata.annotations."cas.openebs.io/config"'
  # Expected: Contains BasePath: /var/openebs/local
  ```

---

### T5: Update Infrastructure Kustomization

- [ ] Create `kubernetes/infrastructure/storage/kustomization.yaml`:
  ```yaml
  ---
  apiVersion: kustomize.config.k8s.io/v1beta1
  kind: Kustomization
  resources:
    - openebs/ks.yaml
  ```

- [ ] Update `kubernetes/infrastructure/kustomization.yaml`:
  ```yaml
  resources:
    - networking/
    - security/
    - storage/  # ADD THIS LINE
  ```

---

### T6: Update Cluster Settings (If Needed)

- [ ] Verify infra cluster-settings have OpenEBS variables:
  ```yaml
  # kubernetes/clusters/infra/cluster-settings.yaml
  OPENEBS_BASEPATH: "/var/openebs/local"
  OPENEBS_STORAGE_CLASS: "openebs-hostpath"
  ```

- [ ] If variables missing, add them to cluster-settings ConfigMap

---

### T7: Commit Manifests to Git

- [ ] Commit and push:
  ```bash
  git add kubernetes/infrastructure/storage/openebs/
  git add kubernetes/infrastructure/storage/kustomization.yaml
  git add kubernetes/infrastructure/kustomization.yaml
  git commit -m "feat(storage): add OpenEBS LocalPV manifests

  - Create HelmRelease for OpenEBS 4.1.x
  - Enable LocalPV hostpath provisioner only
  - Create StorageClass with WaitForFirstConsumer binding
  - Configure Talos-compatible base path /var/openebs/local
  - Create PrometheusRule for provisioning failures and disk usage
  - Enable ServiceMonitor for metrics

  Part of Story 14 (v3.0 manifests-first approach)
  Deployment deferred to Story 45 (VALIDATE-NETWORKING)"
  git push origin main
  ```

---

### Runtime Validation (MOVED TO STORY 45)

The following validation happens in **Story 45 (VALIDATE-NETWORKING)** after cluster bootstrap:

```bash
# Deploy OpenEBS (Story 45 only)
flux reconcile kustomization openebs --with-source

# Verify namespace and HelmRelease
kubectl -n openebs-system get helmrelease openebs
kubectl -n openebs-system get helmrelease openebs -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}'
# Expected: True

# Verify controller deployment
kubectl -n openebs-system get deploy openebs-localpv-provisioner
kubectl -n openebs-system rollout status deploy/openebs-localpv-provisioner --timeout=5m

# Verify node DaemonSet (if any)
kubectl -n openebs-system get ds
kubectl -n openebs-system get pods -o wide
# Expected: Pods running on all nodes

# Verify StorageClass created
kubectl get sc openebs-hostpath
kubectl get sc openebs-hostpath -o yaml
# Expected: provisioner: openebs.io/local, volumeBindingMode: WaitForFirstConsumer

# Verify base path configuration
kubectl get sc openebs-hostpath -o jsonpath='{.metadata.annotations.cas\.openebs\.io/config}' | grep BasePath
# Expected: /var/openebs/local

# Test dynamic provisioning with sample PVC
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: openebs-test-pvc
  namespace: default
spec:
  storageClassName: openebs-hostpath
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
EOF

# Verify PVC is pending (WaitForFirstConsumer)
kubectl -n default get pvc openebs-test-pvc
# Expected: Status Pending (waiting for consumer pod)

# Create test pod to consume PVC
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: openebs-test-pod
  namespace: default
spec:
  containers:
    - name: test
      image: busybox:latest
      command: ["sh", "-c", "echo 'OpenEBS test' > /data/test.txt && sleep 3600"]
      volumeMounts:
        - name: data
          mountPath: /data
  volumes:
    - name: data
      persistentVolumeClaim:
        claimName: openebs-test-pvc
EOF

# Wait for pod to be running
kubectl -n default wait --for=condition=ready pod/openebs-test-pod --timeout=60s

# Verify PVC now bound
kubectl -n default get pvc openebs-test-pvc
# Expected: Status Bound

# Verify PV created
kubectl get pv
# Expected: PV bound to openebs-test-pvc

# Verify data persistence
kubectl -n default exec openebs-test-pod -- cat /data/test.txt
# Expected: "OpenEBS test"

# Verify hostpath on node
NODE=$(kubectl -n default get pod openebs-test-pod -o jsonpath='{.spec.nodeName}')
PV_NAME=$(kubectl -n default get pvc openebs-test-pvc -o jsonpath='{.spec.volumeName}')
echo "PVC provisioned on node: $NODE, PV: $PV_NAME"

# Check node filesystem (requires node access)
kubectl debug node/$NODE -it --image=busybox:latest -- ls -la /host/var/openebs/local/
# Expected: Directory for PV visible

# Verify metrics
kubectl -n openebs-system port-forward deploy/openebs-localpv-provisioner 8080:8080 &
sleep 2
curl -s http://localhost:8080/metrics | grep openebs_
# Expected metrics:
# - openebs_volume_provision_total
# - openebs_actual_used
# - openebs_size_of_volume

# Verify PrometheusRule
kubectl -n openebs-system get prometheusrule openebs
kubectl -n openebs-system get prometheusrule openebs -o yaml | grep -A 5 "alert:"
# Expected: Alert rules present

# Verify ServiceMonitor (if VictoriaMetrics deployed)
kubectl -n openebs-system get servicemonitor

# Test data persistence across pod deletion
kubectl -n default delete pod openebs-test-pod
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: openebs-test-pod-2
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
        claimName: openebs-test-pvc
EOF

kubectl -n default wait --for=condition=ready pod/openebs-test-pod-2 --timeout=60s
kubectl -n default logs openebs-test-pod-2
# Expected: "OpenEBS test" (data persisted)

# Test storage performance (optional)
kubectl -n default exec openebs-test-pod-2 -- sh -c "dd if=/dev/zero of=/data/testfile bs=1M count=100 conv=fdatasync"
# Expected: Write performance metrics (should be fast on NVMe)

# Cleanup test resources
kubectl -n default delete pod openebs-test-pod-2
kubectl -n default delete pvc openebs-test-pvc
kubectl get pv | grep openebs-test-pvc
# Expected: PV should be deleted (reclaimPolicy: Delete)

# Verify cleanup
kubectl get pv
# Expected: No PVs remaining for test

pkill -f "port-forward.*openebs"
```

---

## Definition of Done

**Manifest Creation Complete (This Story):**
- [ ] Directory created: `kubernetes/infrastructure/storage/openebs/app/`
- [ ] HelmRelease manifest created with:
  - [ ] OpenEBS 4.1.x
  - [ ] LocalPV hostpath enabled
  - [ ] Talos-compatible base path
  - [ ] ServiceMonitor enabled
- [ ] StorageClass manifest created with WaitForFirstConsumer binding
- [ ] PrometheusRule manifest created with alert rules
- [ ] Kustomization glue file created
- [ ] Flux Kustomization created with health checks
- [ ] Storage infrastructure kustomization created
- [ ] Infrastructure root kustomization updated to include storage
- [ ] Cluster-settings have OpenEBS variables
- [ ] Local validation passes:
  - [ ] `kubectl --dry-run=client` succeeds
  - [ ] `kustomize build` succeeds
  - [ ] `flux build` shows OpenEBS resources for infra cluster
  - [ ] Base path substitution verified
- [ ] Manifests committed to git
- [ ] Story 45 can proceed with deployment

**NOT Part of DoD (Moved to Story 45):**
- ❌ OpenEBS controller deployment running
- ❌ OpenEBS node DaemonSet running
- ❌ StorageClass available
- ❌ Dynamic PVC provisioning working
- ❌ Data persistence verified
- ❌ PrometheusRule loaded
- ❌ Metrics scraped by VictoriaMetrics
- ❌ Storage performance tested

---

## Design Notes

### OpenEBS LocalPV Architecture

OpenEBS LocalPV provides simple node-local storage:
- **No replication**: Data stored only on single node (node affinity)
- **Fast performance**: Direct local disk access (NVMe speed)
- **Simple lifecycle**: No complex storage backend
- **Use cases**: Logs, caches, CI/CD runners, temporary storage

### Talos Linux Compatibility

Talos filesystem considerations:
- **Persistent paths**: `/var` is mounted from persistent storage
- **Base path**: `/var/openebs/local` survives reboots
- **Immutable root**: Cannot use `/opt` or other standard paths
- **Node access**: Limited (no SSH), debugging via `kubectl debug node/`

### Storage Strategy

**OpenEBS LocalPV** (this story):
- Simple, fast, node-local storage
- No redundancy
- Ideal for ephemeral workloads

**Rook-Ceph** (Stories 15-16):
- Distributed, replicated storage
- High availability
- Ideal for databases, persistent app data

### Volume Binding Mode

**WaitForFirstConsumer**:
- PVC remains Pending until pod is scheduled
- Ensures PV is created on the same node as the pod
- Critical for node-local storage (prevents cross-node mounting)

---

## Change Log

| Date       | Version | Description                          | Author  |
|------------|---------|--------------------------------------|---------|
| 2025-10-26 | 3.0     | **v3.0 Refinement**: Updated header, story, scope, AC, dependencies, tasks, DoD for manifests-first approach. Separated manifest creation from deployment (moved to Story 45). Tasks simplified to T1-T7 focusing on local validation only. Added comprehensive dynamic provisioning and persistence testing in runtime validation section. Added design notes for OpenEBS architecture and Talos compatibility. | Platform Engineering |
| 2025-10-21 | 1.0     | Initial draft | Platform Engineering |
