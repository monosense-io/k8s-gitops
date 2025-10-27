# 15 — STORY-STO-ROOK-CEPH-OPERATOR — Create Rook-Ceph Operator Manifests

Sequence: 15/50 | Prev: STORY-STO-OPENEBS-BASE.md | Next: STORY-STO-ROOK-CEPH-CLUSTER.md
Sprint: 3 | Lane: Storage
Global Sequence: 15/50

Status: Draft (v3.0 Refinement)
Owner: Platform Engineering
Date: 2025-10-26 (v3.0 Refinement)
Links: docs/architecture.md §10; kubernetes/infrastructure/storage/rook-ceph/operator/

---

## Story

As a platform engineer, I want to **create Rook-Ceph operator manifests** for managing Ceph storage clusters, so that when deployed in Story 45, the infra cluster can provide durable distributed storage (block, object, filesystem) for platform services with high availability and data redundancy.

This story creates the declarative Rook-Ceph operator manifests (HelmRelease, PrometheusRule). Actual deployment and operator validation happen in Story 45 (VALIDATE-NETWORKING). The Ceph cluster itself is created in Story 16.

## Why / Outcome

- Create Rook-Ceph operator manifests for GitOps deployment
- Enable lifecycle management of Ceph storage clusters
- Support resilient block storage (RBD) for databases and stateful apps
- Support object storage (RGW) for backups and artifacts
- Foundation for distributed storage with replication and self-healing

## Scope

**This Story (Manifest Creation):**
- Create Rook-Ceph operator manifests in `kubernetes/infrastructure/storage/rook-ceph/operator/`
- Create HelmRelease for Rook-Ceph operator
- Create PrometheusRule for operator observability
- Create Kustomization for operator resources
- Local validation (flux build, kubectl dry-run)

**Deferred to Story 45 (Deployment & Validation):**
- Deploying Rook-Ceph operator to infra cluster
- Verifying operator deployment running
- Testing operator CRD registration
- Validating operator logs and health
- Metrics scraping validation

**Deferred to Story 16 (Ceph Cluster Creation):**
- Creating CephCluster resource
- Configuring OSDs, MONs, MGRs
- Creating storage classes and pools
- Testing actual storage provisioning

---

## Acceptance Criteria

**Manifest Creation (This Story):**

1. **HelmRelease Manifest Created:**
   - `kubernetes/infrastructure/storage/rook-ceph/operator/helmrelease.yaml` exists
   - Rook-Ceph chart version configured
   - Namespace: `rook-ceph`
   - ServiceMonitor enabled for metrics
   - Resource limits configured

2. **PrometheusRule Manifest Created:**
   - `kubernetes/infrastructure/storage/rook-ceph/operator/prometheusrule.yaml` exists
   - Alert rules for operator failures
   - Alert rules for CRD reconciliation issues

3. **Kustomization Created:**
   - `kubernetes/infrastructure/storage/rook-ceph/operator/ks.yaml` exists
   - References operator manifests
   - No dependencies (can deploy after OpenEBS)
   - `kubernetes/infrastructure/storage/rook-ceph/operator/kustomization.yaml` glue file exists

4. **Local Validation Passes:**
   - `flux build kustomization cluster-infra-infrastructure --path ./kubernetes/infrastructure` succeeds
   - Output shows Rook-Ceph operator resources
   - `kubectl --dry-run=client` validates manifests

**Deferred to Story 45 (Deployment & Validation):**
- ❌ Rook-Ceph operator deployment running
- ❌ Operator CRDs registered
- ❌ Operator logs healthy
- ❌ PrometheusRule loaded
- ❌ Metrics scraped by VictoriaMetrics

**Deferred to Story 16 (Ceph Cluster):**
- ❌ CephCluster resource created
- ❌ Ceph MONs/MGRs/OSDs running
- ❌ Storage classes available
- ❌ PVC provisioning working

---

## Dependencies

**Prerequisites (v3.0):**
- Story 44 (STORY-BOOT-CORE) complete (Flux operational)
- Story 43 (STORY-BOOT-CRDS) complete (if Rook CRDs in bootstrap)
- Cluster-settings ConfigMaps
- Tools: kubectl (for dry-run), flux CLI, yq

**NOT Required (v3.0):**
- ❌ Cluster access (validation is local-only)
- ❌ Node storage devices configured (Story 16)
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

- [ ] Verify Story 43 complete (if Rook CRDs in bootstrap):
  ```bash
  ls -la bootstrap/helmfile.d/00-crds.yaml.gotmpl
  grep -i "rook" bootstrap/helmfile.d/00-crds.yaml.gotmpl || echo "CRDs installed by operator"
  ```

---

### T2: Create Rook-Ceph Operator Manifests

- [ ] Create directory structure:
  ```bash
  mkdir -p kubernetes/infrastructure/storage/rook-ceph/operator
  ```

- [ ] Create `helmrelease.yaml`:
  ```yaml
  ---
  apiVersion: v1
  kind: Namespace
  metadata:
    name: rook-ceph
  ---
  apiVersion: source.toolkit.fluxcd.io/v1
  kind: HelmRepository
  metadata:
    name: rook-ceph
    namespace: rook-ceph
  spec:
    interval: 15m
    url: https://charts.rook.io/release
  ---
  apiVersion: helm.toolkit.fluxcd.io/v2
  kind: HelmRelease
  metadata:
    name: rook-ceph-operator
    namespace: rook-ceph
  spec:
    interval: 1h
    chart:
      spec:
        chart: rook-ceph
        version: v1.15.x
        sourceRef:
          kind: HelmRepository
          name: rook-ceph
          namespace: rook-ceph
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
      # Operator configuration
      crds:
        enabled: true  # Install CRDs via Helm

      # Resource limits
      resources:
        limits:
          cpu: 500m
          memory: 512Mi
        requests:
          cpu: 100m
          memory: 128Mi

      # Observability
      monitoring:
        enabled: true

      # CSI driver configuration
      csi:
        enableCSIHostNetwork: true
        provisionerReplicas: 2

        # CSI resource limits
        csiRBDProvisionerResource: |
          - name: csi-provisioner
            resource:
              requests:
                memory: 128Mi
                cpu: 100m
              limits:
                memory: 256Mi
                cpu: 200m
          - name: csi-resizer
            resource:
              requests:
                memory: 128Mi
                cpu: 100m
              limits:
                memory: 256Mi
                cpu: 200m
          - name: csi-snapshotter
            resource:
              requests:
                memory: 128Mi
                cpu: 100m
              limits:
                memory: 256Mi
                cpu: 200m

      # Node affinity for operator (optional - run on all nodes)
      nodeSelector: {}

      tolerations: []

      # Log level
      logLevel: INFO

      # Discover devices automatically
      enableDiscoveryDaemon: true
      discoveryDaemonResources:
        limits:
          cpu: 200m
          memory: 128Mi
        requests:
          cpu: 50m
          memory: 64Mi
  ```

- [ ] Create `prometheusrule.yaml`:
  ```yaml
  ---
  apiVersion: monitoring.coreos.com/v1
  kind: PrometheusRule
  metadata:
    name: rook-ceph-operator
    namespace: rook-ceph
  spec:
    groups:
      - name: rook-ceph-operator
        interval: 30s
        rules:
          - alert: RookCephOperatorDown
            expr: up{job="rook-ceph-operator"} == 0
            for: 5m
            labels:
              severity: critical
            annotations:
              summary: "Rook-Ceph operator is down"
              description: "Rook-Ceph operator pod {{ $labels.pod }} is down"

          - alert: RookCephOperatorReconcileErrors
            expr: increase(rook_ceph_operator_reconcile_errors_total[5m]) > 0
            for: 10m
            labels:
              severity: warning
            annotations:
              summary: "Rook-Ceph operator reconcile errors"
              description: "Rook-Ceph operator is experiencing reconcile errors for {{ $labels.resource }}"

          - alert: RookCephCRDMissing
            expr: absent(apiserver_requested_deprecated_apis{resource="cephclusters.ceph.rook.io"})
            for: 5m
            labels:
              severity: critical
            annotations:
              summary: "Rook-Ceph CRDs not registered"
              description: "Rook-Ceph CRDs are not registered in the API server"

          - alert: RookCephDiscoveryDaemonDown
            expr: up{job="rook-ceph-discovery"} == 0
            for: 10m
            labels:
              severity: warning
            annotations:
              summary: "Rook-Ceph discovery daemon is down"
              description: "Rook-Ceph discovery daemon pod {{ $labels.pod }} is down"
  ```

- [ ] Create `kustomization.yaml` (glue file):
  ```yaml
  ---
  apiVersion: kustomize.config.k8s.io/v1beta1
  kind: Kustomization
  resources:
    - helmrelease.yaml
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
    name: rook-ceph-operator
    namespace: flux-system
  spec:
    interval: 10m
    retryInterval: 1m
    timeout: 5m
    sourceRef:
      kind: GitRepository
      name: flux-system
    path: ./kubernetes/infrastructure/storage/rook-ceph/operator
    prune: true
    wait: true
    targetNamespace: rook-ceph
    healthChecks:
      - apiVersion: helm.toolkit.fluxcd.io/v2
        kind: HelmRelease
        name: rook-ceph-operator
        namespace: rook-ceph
      - apiVersion: apps/v1
        kind: Deployment
        name: rook-ceph-operator
        namespace: rook-ceph
  ```

---

### T4: Local Validation (NO Cluster Access)

- [ ] Validate manifest syntax:
  ```bash
  kubectl --dry-run=client -f kubernetes/infrastructure/storage/rook-ceph/operator/
  ```

- [ ] Validate with kustomize:
  ```bash
  kustomize build kubernetes/infrastructure/storage/rook-ceph/operator
  ```

- [ ] Validate Flux build for infra cluster:
  ```bash
  flux build kustomization cluster-infra-infrastructure --path ./kubernetes/infrastructure | \
    yq 'select(.kind == "HelmRelease" and .metadata.name == "rook-ceph-operator")'

  # Verify CRD installation enabled
  flux build kustomization cluster-infra-infrastructure --path ./kubernetes/infrastructure | \
    yq 'select(.kind == "HelmRelease" and .metadata.name == "rook-ceph-operator") | .spec.values.crds.enabled'
  # Expected: true
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
    - rook-ceph/operator/ks.yaml  # ADD THIS LINE
  ```

---

### T6: Commit Manifests to Git

- [ ] Commit and push:
  ```bash
  git add kubernetes/infrastructure/storage/rook-ceph/operator/
  git commit -m "feat(storage): add Rook-Ceph operator manifests

  - Create HelmRelease for Rook-Ceph operator v1.15.x
  - Enable CRD installation via Helm
  - Configure CSI driver with 2 provisioner replicas
  - Enable device discovery daemon
  - Create PrometheusRule for operator health monitoring
  - Set resource limits for operator and CSI components

  Part of Story 15 (v3.0 manifests-first approach)
  Deployment deferred to Story 45 (VALIDATE-NETWORKING)
  Ceph cluster creation deferred to Story 16"
  git push origin main
  ```

---

### Runtime Validation (MOVED TO STORY 45)

The following validation happens in **Story 45 (VALIDATE-NETWORKING)** after cluster bootstrap:

```bash
# Deploy Rook-Ceph operator (Story 45 only)
flux reconcile kustomization rook-ceph-operator --with-source

# Verify namespace and HelmRelease
kubectl -n rook-ceph get helmrelease rook-ceph-operator
kubectl -n rook-ceph get helmrelease rook-ceph-operator -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}'
# Expected: True

# Verify operator deployment
kubectl -n rook-ceph get deploy rook-ceph-operator
kubectl -n rook-ceph rollout status deploy/rook-ceph-operator --timeout=5m

# Verify operator pods running
kubectl -n rook-ceph get pods -l app=rook-ceph-operator
kubectl -n rook-ceph get pods -l app=rook-ceph-operator -o wide
# Expected: 1 pod in Running state

# Verify operator logs healthy
kubectl -n rook-ceph logs -l app=rook-ceph-operator --tail=50
# Expected: No errors, operator started successfully

# Verify CRDs registered
kubectl get crd | grep ceph.rook.io
# Expected CRDs:
# - cephblockpools.ceph.rook.io
# - cephclusters.ceph.rook.io
# - cephfilesystems.ceph.rook.io
# - cephnfses.ceph.rook.io
# - cephobjectstores.ceph.rook.io
# - cephobjectstoreusers.ceph.rook.io
# - cephobjectzones.ceph.rook.io
# - cephobjectzongroups.ceph.rook.io
# - cephrbdmirrors.ceph.rook.io

# Verify specific CRD
kubectl get crd cephclusters.ceph.rook.io -o yaml | grep "version:"
# Expected: v1

# Verify discovery daemon running
kubectl -n rook-ceph get ds rook-discover
kubectl -n rook-ceph get pods -l app=rook-discover -o wide
# Expected: One pod per node in Running state

# Verify discovery daemon logs
kubectl -n rook-ceph logs -l app=rook-discover --tail=20
# Expected: Device discovery logs, no errors

# Check discovered devices on nodes
kubectl -n rook-ceph logs -l app=rook-discover | grep "discovered device"
# Expected: List of available devices on each node

# Verify CSI driver pods
kubectl -n rook-ceph get pods -l app=csi-rbdplugin
kubectl -n rook-ceph get pods -l app=csi-rbdplugin-provisioner
# Expected: CSI pods running

# Verify CSI provisioner replicas
kubectl -n rook-ceph get deploy csi-rbdplugin-provisioner
# Expected: 2/2 replicas ready

# Verify operator metrics endpoint
kubectl -n rook-ceph port-forward deploy/rook-ceph-operator 8080:8080 &
sleep 2
curl -s http://localhost:8080/metrics | grep rook_ceph_operator
# Expected metrics:
# - rook_ceph_operator_reconcile_errors_total
# - rook_ceph_operator_reconcile_duration_seconds

# Verify PrometheusRule
kubectl -n rook-ceph get prometheusrule rook-ceph-operator
kubectl -n rook-ceph get prometheusrule rook-ceph-operator -o yaml | grep -A 5 "alert:"
# Expected: Alert rules present

# Verify operator ServiceMonitor (if created)
kubectl -n rook-ceph get servicemonitor

# Check operator version
kubectl -n rook-ceph get deploy rook-ceph-operator -o jsonpath='{.spec.template.spec.containers[0].image}'
# Expected: rook/ceph:v1.15.x

# Verify operator ready to create CephCluster
kubectl -n rook-ceph describe deploy rook-ceph-operator | grep -A 10 "Conditions"
# Expected: Available: True

# Check operator resource usage
kubectl -n rook-ceph top pod -l app=rook-ceph-operator
# Expected: Within resource limits (CPU < 500m, Memory < 512Mi)

# Verify operator can watch all namespaces (if configured)
kubectl -n rook-ceph logs -l app=rook-ceph-operator | grep "watching namespace"
# Expected: Watching appropriate namespaces

# Test operator reconciliation (create dummy CephCluster to validate CRD)
# NOTE: This is just to test CRD registration, not actual cluster creation
kubectl apply -f - <<EOF
apiVersion: ceph.rook.io/v1
kind: CephCluster
metadata:
  name: test-validation
  namespace: rook-ceph
spec:
  dataDirHostPath: /var/lib/rook
  mon:
    count: 1
  mgr:
    count: 1
  storage:
    useAllNodes: false
    useAllDevices: false
EOF

# Verify operator recognizes the resource
kubectl -n rook-ceph get cephcluster test-validation
# Expected: Resource created (will not reconcile without actual devices)

# Check operator logs for reconciliation attempt
kubectl -n rook-ceph logs -l app=rook-ceph-operator --tail=20 | grep test-validation
# Expected: Operator attempting to reconcile (may show warnings about devices)

# Cleanup test resource
kubectl -n rook-ceph delete cephcluster test-validation

pkill -f "port-forward.*rook-ceph-operator"
```

---

## Definition of Done

**Manifest Creation Complete (This Story):**
- [ ] Directory created: `kubernetes/infrastructure/storage/rook-ceph/operator/`
- [ ] HelmRelease manifest created with:
  - [ ] Rook-Ceph operator v1.15.x
  - [ ] CRD installation enabled
  - [ ] CSI driver configured
  - [ ] Device discovery enabled
  - [ ] Resource limits set
- [ ] PrometheusRule manifest created with operator health alerts
- [ ] Kustomization glue file created
- [ ] Flux Kustomization created with health checks
- [ ] Storage infrastructure kustomization updated to include Rook-Ceph operator
- [ ] Local validation passes:
  - [ ] `kubectl --dry-run=client` succeeds
  - [ ] `kustomize build` succeeds
  - [ ] `flux build` shows Rook-Ceph operator resources
  - [ ] CRD installation config verified
- [ ] Manifests committed to git
- [ ] Story 45 can proceed with deployment
- [ ] Story 16 can proceed with Ceph cluster creation

**NOT Part of DoD (Moved to Story 45):**
- ❌ Rook-Ceph operator deployment running
- ❌ Operator CRDs registered
- ❌ Operator logs healthy
- ❌ Discovery daemon running
- ❌ CSI driver pods running
- ❌ PrometheusRule loaded
- ❌ Metrics scraped by VictoriaMetrics

**NOT Part of DoD (Moved to Story 16):**
- ❌ CephCluster resource created
- ❌ Ceph MONs/MGRs/OSDs running
- ❌ Storage classes available
- ❌ PVC provisioning working

---

## Design Notes

### Rook-Ceph Architecture

Rook-Ceph provides Kubernetes-native distributed storage:
- **Operator**: Manages Ceph cluster lifecycle (this story)
- **Ceph Cluster**: MON, MGR, OSD daemons (Story 16)
- **CSI Driver**: Provides dynamic PVC provisioning
- **Storage Types**: Block (RBD), Object (RGW), Filesystem (CephFS)

### Operator Responsibilities

The Rook-Ceph operator:
- **CRD Management**: Installs and manages Ceph-related CRDs
- **Cluster Orchestration**: Creates and maintains Ceph daemons
- **Device Discovery**: Finds available storage devices on nodes
- **Health Monitoring**: Watches Ceph health and triggers recovery
- **CSI Integration**: Manages CSI driver for PVC provisioning

### CSI Driver Configuration

CSI driver components:
- **Provisioner**: Creates/deletes PVs (2 replicas for HA)
- **Resizer**: Handles PVC expansion
- **Snapshotter**: Manages volume snapshots
- **Node Plugin**: DaemonSet on all nodes for mounting

### Device Discovery

Discovery daemon:
- **Purpose**: Scans nodes for available block devices
- **Deployment**: DaemonSet on all nodes
- **Output**: ConfigMap with device inventory per node
- **Usage**: Used by CephCluster to allocate OSDs (Story 16)

### Resource Planning

Operator resource usage:
- **Operator Pod**: ~100m CPU, ~128Mi memory (light)
- **Discovery Daemon**: ~50m CPU, ~64Mi memory per node (light)
- **CSI Provisioner**: ~200m CPU, ~256Mi memory (moderate)
- **Total per node**: ~250m CPU, ~320Mi memory

### Separation of Concerns

**Story 15 (this story):**
- Install Rook-Ceph operator
- Register CRDs
- Deploy CSI driver and discovery daemon
- NO actual Ceph cluster

**Story 16 (next):**
- Create CephCluster resource
- Deploy MON, MGR, OSD daemons
- Create block pools and storage classes
- Test actual storage provisioning

---

## Change Log

| Date       | Version | Description                          | Author  |
|------------|---------|--------------------------------------|---------|
| 2025-10-26 | 3.0     | **v3.0 Refinement**: Updated header, story, scope, AC, dependencies, tasks, DoD for manifests-first approach. Separated manifest creation from deployment (moved to Story 45). Separated operator deployment from Ceph cluster creation (moved to Story 16). Tasks simplified to T1-T6 focusing on local validation only. Added comprehensive operator validation and CRD testing in runtime validation section. Added design notes for Rook-Ceph architecture and operator responsibilities. | Platform Engineering |
| 2025-10-21 | 1.0     | Initial draft | Platform Engineering |
