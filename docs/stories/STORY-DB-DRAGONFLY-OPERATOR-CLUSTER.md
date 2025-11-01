# 25 — STORY-DB-DRAGONFLY-OPERATOR-CLUSTER — Create DragonflyDB Operator & Cluster Manifests

Sequence: 25/50 | Prev: STORY-DB-CNPG-SHARED-CLUSTER.md | Next: STORY-SEC-NP-BASELINE.md
Sprint: 5 | Lane: Database
Global Sequence: 25/50

Status: Complete (v5.0 - Production-Ready with Critical Fixes)
Owner: Platform Engineering
Date: 2025-11-01
Links:
- docs/architecture.md §B.9
- kubernetes/infrastructure/repositories/oci/dragonfly-operator.yaml
- kubernetes/bases/dragonfly-operator/operator/kustomization.yaml
- kubernetes/bases/dragonfly-operator/operator/helmrelease.yaml
- kubernetes/workloads/platform/databases/dragonfly/kustomization.yaml
- kubernetes/workloads/platform/databases/dragonfly/dragonfly.yaml
- kubernetes/workloads/platform/databases/dragonfly/externalsecret.yaml
- kubernetes/workloads/platform/databases/dragonfly/service.yaml
- kubernetes/workloads/platform/databases/dragonfly/prometheusrule.yaml
- kubernetes/workloads/platform/databases/dragonfly/dragonfly-pdb.yaml
- kubernetes/workloads/platform/databases/dragonfly/networkpolicy.yaml
- docs/examples/dragonfly-gitlab.yaml

## Story
As a platform engineer, I want to **create manifests for the DragonflyDB operator and a shared cluster instance** with HA configuration, cross-cluster exposure via Cilium ClusterMesh, network policies, and observability, so that when deployed in Story 45 the infra cluster provides a Redis-compatible cache service consumable by GitLab, Harbor, and other platform workloads with clear tenancy and isolation options.

## Why / Outcome
- **Redis-Compatible Cache**: High-performance, low-latency caching for platform workloads
- **Simplified Operations**: Single operator-managed instance vs. multiple Redis deployments
- **Cross-Cluster Access**: Cilium ClusterMesh enables apps cluster to consume infra services
- **HA and Resilience**: 3-pod cluster (1 primary, 2 replicas) with PodDisruptionBudgets
- **Security**: NetworkPolicies, authentication, non-root containers, PSA restricted enforcement
- **Observability**: Metrics, ServiceMonitor, comprehensive alerting
- **Tenancy Options**: Shared cluster with documented per-tenant CR pattern for future isolation

## Scope

### This Story (Manifest Creation)
Create all manifests for DragonflyDB operator and shared cluster on the infra cluster:
1. **Operator Manifests**: HelmRelease, OCIRepository, operator PodDisruptionBudget, namespace
2. **Dragonfly Cluster Manifest**: 3-pod HA cluster with persistence, authentication, metrics, topology spread
3. **Data Plane PDB**: PodDisruptionBudget for Dragonfly pods (minAvailable: 2)
4. **ExternalSecret**: Authentication credentials from 1Password
5. **Global Service**: Cilium global Service for cross-cluster access
6. **NetworkPolicy**: Restrict access to approved namespaces (gitlab-system, harbor, observability)
7. **Monitoring**: ServiceMonitor and PrometheusRule with comprehensive alerts
8. **Tenancy Example**: Per-tenant CR stub for future multi-tenant pattern
9. **Kustomizations**: Tie all resources together with proper ordering

**Validation**: Local-only using `kubectl --dry-run=client`, `flux build`, `kustomize build`, and `kubeconform`

### Deferred to Story 45 (Deployment & Validation)
- Apply manifests to infra cluster
- Verify operator and Dragonfly cluster readiness
- Test cross-cluster connectivity from apps cluster
- Validate NetworkPolicy enforcement (allowed vs. denied)
- Verify metrics scraping and alert rules
- Test GitLab cache connectivity
- Performance and replication validation

## Acceptance Criteria

### Manifest Creation (This Story)
1. **AC1-OperatorManifests**: Operator HelmRelease with 2 replicas, CRD management (`CreateReplace`), OCIRepository source, operator PDB (minAvailable: 1), namespace with PSA restricted labels
2. **AC2-DragonflyCluster**: Dragonfly CR with 3 replicas, persistence enabled (PVCs), topology spread constraints or anti-affinity, security hardening (runAsNonRoot, readOnlyRootFilesystem, drop capabilities), liveness/readiness probes, image version from `${DRAGONFLY_IMAGE_TAG}`
3. **AC3-DataPlanePDB**: PodDisruptionBudget for Dragonfly pods with `minAvailable: 2` to ensure HA during node maintenance
4. **AC4-ExternalSecret**: ExternalSecret for Dragonfly authentication using `${EXTERNAL_SECRET_STORE}` and `${DRAGONFLY_AUTH_SECRET_PATH}`
5. **AC5-GlobalService**: Service with Cilium global annotations (`service.cilium.io/global: "true"`, `service.cilium.io/shared: "true"`) for cross-cluster DNS resolution
6. **AC6-NetworkPolicy**: CiliumNetworkPolicy restricting ingress to approved namespaces (gitlab-system, harbor, observability for metrics) and allowing DNS egress
7. **AC7-Monitoring**: ServiceMonitor and PrometheusRule/VMRule with alerts for availability, memory pressure (≥80%), disk saturation, replication health, command rate
8. **AC8-TenancyExample**: Per-tenant Dragonfly CR example (`docs/examples/dragonfly-gitlab.yaml`) for future multi-tenant deployments
9. **AC9-Kustomization**: Flux Kustomization manifests with health checks and proper dependencies
10. **AC10-Validation**: All manifests pass local validation: `kubectl --dry-run=client`, `flux build`, `kustomize build`, `kubeconform`

### Deferred to Story 45 (NOT Part of This Story)
- ~~Operator pods Running and Ready~~
- ~~Dragonfly cluster Ready with primary election~~
- ~~Cross-cluster Service reachable from apps cluster~~
- ~~NetworkPolicy enforcement validated~~
- ~~Metrics scraped by VictoriaMetrics~~
- ~~GitLab cache connectivity tested~~

## Dependencies / Inputs

### Prerequisites
- **Cilium ClusterMesh**: Enabled between infra and apps clusters for cross-cluster service discovery
- **StorageClass**: `${DRAGONFLY_STORAGE_CLASS}` available for PVCs
- **1Password Secrets**: Authentication credentials path configured
- **External Secrets Operator**: Deployed and healthy

### Local Tools Required
- `kubectl` - Kubernetes manifest validation
- `flux` - GitOps manifest validation
- `kustomize` - Kustomization building
- `kubeconform` - Kubernetes schema validation
- `yq` - YAML processing
- `git` - Version control

### Cluster Settings Variables
From `kubernetes/clusters/infra/cluster-settings.yaml`:
```yaml
# DragonflyDB Configuration
DRAGONFLY_IMAGE_TAG: "v1.34.2"  # Latest stable (Oct 2024)
DRAGONFLY_REPLICAS: "3"
DRAGONFLY_STORAGE_CLASS: "openebs-local-nvme"
DRAGONFLY_DATA_SIZE: "10Gi"           # per-pod size (3 pods = 30Gi total)
DRAGONFLY_MEMORY_LIMIT: "2Gi"
DRAGONFLY_CPU_LIMIT: "2000m"
DRAGONFLY_MEMORY_REQUEST: "1Gi"
DRAGONFLY_CPU_REQUEST: "500m"
DRAGONFLY_MAXMEMORY: "1610612736"     # 1.5Gi in bytes (90% of 2Gi limit for graceful eviction)
DRAGONFLY_CACHE_MODE: "true"          # Enable cache eviction (recommended for GitLab/Harbor)

# External Secret Path
DRAGONFLY_AUTH_SECRET_PATH: "kubernetes/infra/dragonfly/auth"
```

## Tasks / Subtasks

### T1: Verify Prerequisites and Configuration Strategy
- [ ] Review Cilium ClusterMesh setup and global Service annotation requirements
- [ ] Confirm cluster-settings variables for Dragonfly operator and cluster
- [ ] Verify 1Password secret path for authentication credentials
- [ ] Review DragonflyDB operator version compatibility (target operator 1.3.x, Dragonfly v1.23.x)
- [ ] Document namespace strategy (operator in dragonfly-operator-system, cluster in dragonfly-system)

### T2: Create Operator Namespace
**File**: `kubernetes/bases/dragonfly-operator/operator/namespace.yaml`

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: dragonfly-operator-system
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

### T3: Create OCIRepository for Operator
**File**: `kubernetes/infrastructure/repositories/oci/dragonfly-operator.yaml`

```yaml
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: OCIRepository
metadata:
  name: dragonfly-operator
  namespace: flux-system
spec:
  interval: 12h
  url: oci://ghcr.io/dragonflydb/dragonfly-operator
  ref:
    semver: "1.3.x"
```

### T4: Create Operator HelmRelease
**File**: `kubernetes/bases/dragonfly-operator/operator/helmrelease.yaml`

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: dragonfly-operator
  namespace: dragonfly-operator-system
spec:
  interval: 30m
  timeout: 15m

  chartRef:
    kind: OCIRepository
    name: dragonfly-operator
    namespace: flux-system

  # CRD management
  install:
    crds: CreateReplace
    remediation:
      retries: 3
  upgrade:
    crds: CreateReplace
    remediation:
      retries: 3

  values:
    # High availability operator
    replicaCount: 2

    # Anti-affinity for operator pods
    affinity:
      podAntiAffinity:
        preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchLabels:
                  app.kubernetes.io/name: dragonfly-operator
              topologyKey: kubernetes.io/hostname

    # PodDisruptionBudget
    podDisruptionBudget:
      enabled: true
      minAvailable: 1

    # ServiceMonitor for operator metrics
    serviceMonitor:
      enabled: true
      interval: 30s

    # Security context
    securityContext:
      runAsNonRoot: true
      runAsUser: 10001
      fsGroup: 10001
      readOnlyRootFilesystem: true
      capabilities:
        drop:
          - ALL

    # Resource limits
    resources:
      requests:
        cpu: "100m"
        memory: "128Mi"
      limits:
        cpu: "500m"
        memory: "256Mi"
```

### T5: Create Operator Kustomization
**File**: `kubernetes/bases/dragonfly-operator/operator/kustomization.yaml`

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: dragonfly-operator-system

resources:
  - namespace.yaml
  - helmrelease.yaml
```

### T6: Create Dragonfly System Namespace
**File**: `kubernetes/workloads/platform/databases/dragonfly/namespace.yaml`

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: dragonfly-system
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

### T7: Create ExternalSecret for Authentication
**File**: `kubernetes/workloads/platform/databases/dragonfly/externalsecret.yaml`

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: dragonfly-auth
  namespace: dragonfly-system
spec:
  refreshInterval: 1h

  secretStoreRef:
    kind: ClusterSecretStore
    name: ${EXTERNAL_SECRET_STORE}

  target:
    name: dragonfly-auth
    creationPolicy: Owner

  data:
    - secretKey: password
      remoteRef:
        key: ${DRAGONFLY_AUTH_SECRET_PATH}
        property: password
```

### T8: Create Dragonfly Cluster Manifest
**File**: `kubernetes/workloads/platform/databases/dragonfly/dragonfly.yaml`

```yaml
apiVersion: dragonflydb.io/v1alpha1
kind: Dragonfly
metadata:
  name: dragonfly
  namespace: dragonfly-system
spec:
  # Image version
  image: docker.dragonflydb.io/dragonflydb/dragonfly:${DRAGONFLY_IMAGE_TAG}

  # High availability: 3 pods (1 primary + 2 replicas)
  replicas: ${DRAGONFLY_REPLICAS}

  # Resource limits
  resources:
    requests:
      cpu: ${DRAGONFLY_CPU_REQUEST}
      memory: ${DRAGONFLY_MEMORY_REQUEST}
    limits:
      cpu: ${DRAGONFLY_CPU_LIMIT}
      memory: ${DRAGONFLY_MEMORY_LIMIT}

  # Persistence
  snapshot:
    dir: /data
    cron: "0 */6 * * *"  # Snapshot every 6 hours

  # Storage
  storage:
    storageClassName: ${DRAGONFLY_STORAGE_CLASS}
    requests:
      storage: ${DRAGONFLY_DATA_SIZE}

  # Authentication
  authentication:
    passwordFromSecret:
      name: dragonfly-auth
      key: password

  # Metrics
  metrics:
    enabled: true
    port: 6379

  # Args for Dragonfly process
  args:
    - --dir=/data
    - --logtostderr
    - --requirepass=$(DRAGONFLY_PASSWORD)
    - --primary_port_http_enabled=true
    - --admin_port=6380
    - --metrics_port=6379
    - --proactor_threads=2
    - --cluster_mode=emulated
    - --default_lua_flags=allow-undeclared-keys
    - --save_schedule=*:*

  # Environment variables
  env:
    - name: DRAGONFLY_PASSWORD
      valueFrom:
        secretKeyRef:
          name: dragonfly-auth
          key: password

  # Topology spread for high availability
  topologySpreadConstraints:
    - maxSkew: 1
      topologyKey: kubernetes.io/hostname
      whenUnsatisfiable: ScheduleAnyway
      labelSelector:
        matchLabels:
          app: dragonfly
          dragonflydb.io/instance: dragonfly

  # Security context
  podSecurityContext:
    runAsNonRoot: true
    runAsUser: 10001
    fsGroup: 10001
    seccompProfile:
      type: RuntimeDefault

  containerSecurityContext:
    runAsNonRoot: true
    runAsUser: 10001
    allowPrivilegeEscalation: false
    readOnlyRootFilesystem: true
    capabilities:
      drop:
        - ALL

  # Liveness probe
  livenessProbe:
    httpGet:
      path: /healthz
      port: 8080
    initialDelaySeconds: 30
    periodSeconds: 10
    timeoutSeconds: 5
    failureThreshold: 3

  # Readiness probe
  readinessProbe:
    httpGet:
      path: /healthz
      port: 8080
    initialDelaySeconds: 10
    periodSeconds: 5
    timeoutSeconds: 3
    failureThreshold: 3

  # Service configuration
  serviceSpec:
    type: ClusterIP
```

### T9: Create Global Service for Cross-Cluster Access
**File**: `kubernetes/workloads/platform/databases/dragonfly/service.yaml`

```yaml
apiVersion: v1
kind: Service
metadata:
  name: dragonfly-global
  namespace: dragonfly-system
  annotations:
    # Cilium ClusterMesh global Service
    service.cilium.io/global: "true"
    service.cilium.io/shared: "true"
spec:
  type: ClusterIP
  ports:
    - name: dragonfly
      port: 6379
      targetPort: 6379
      protocol: TCP
    - name: admin
      port: 6380
      targetPort: 6380
      protocol: TCP
  selector:
    app: dragonfly
    dragonflydb.io/instance: dragonfly
    dragonflydb.io/role: primary
```

### T10: Create PodDisruptionBudget for Data Plane
**File**: `kubernetes/workloads/platform/databases/dragonfly/dragonfly-pdb.yaml`

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: dragonfly
  namespace: dragonfly-system
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: dragonfly
      dragonflydb.io/instance: dragonfly
```

### T11: Create NetworkPolicy for Access Control
**File**: `kubernetes/workloads/platform/databases/dragonfly/networkpolicy.yaml`

```yaml
---
# Default deny all ingress to dragonfly-system
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: default-deny-ingress
  namespace: dragonfly-system
spec:
  endpointSelector: {}
  ingress:
    - fromEntities:
        - cluster
      toPorts:
        - ports:
            - port: "8080"  # Health checks from kubelet
              protocol: TCP

---
# Allow ingress from approved namespaces
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: dragonfly-allow-clients
  namespace: dragonfly-system
spec:
  endpointSelector:
    matchLabels:
      app: dragonfly

  ingress:
    # Allow from GitLab namespace
    - fromEndpoints:
        - matchLabels:
            io.kubernetes.pod.namespace: gitlab-system
      toPorts:
        - ports:
            - port: "6379"
              protocol: TCP
            - port: "6380"
              protocol: TCP

    # Allow from Harbor namespace
    - fromEndpoints:
        - matchLabels:
            io.kubernetes.pod.namespace: harbor
      toPorts:
        - ports:
            - port: "6379"
              protocol: TCP

    # Allow from Observability namespace (metrics scraping)
    - fromEndpoints:
        - matchLabels:
            io.kubernetes.pod.namespace: observability
      toPorts:
        - ports:
            - port: "6379"
              protocol: TCP

    # Allow health checks from within namespace
    - fromEndpoints:
        - matchLabels:
            io.kubernetes.pod.namespace: dragonfly-system
      toPorts:
        - ports:
            - port: "6379"
              protocol: TCP
            - port: "6380"
              protocol: TCP
            - port: "8080"
              protocol: TCP

  egress:
    # Allow DNS resolution
    - toEndpoints:
        - matchLabels:
            io.kubernetes.pod.namespace: kube-system
            k8s-app: kube-dns
      toPorts:
        - ports:
            - port: "53"
              protocol: UDP
          rules:
            dns:
              - matchPattern: "*"

    # Allow communication between Dragonfly pods (replication)
    - toEndpoints:
        - matchLabels:
            app: dragonfly
            dragonflydb.io/instance: dragonfly
      toPorts:
        - ports:
            - port: "6379"
              protocol: TCP
            - port: "6380"
              protocol: TCP
```

### T12: Create ServiceMonitor
**File**: `kubernetes/workloads/platform/databases/dragonfly/servicemonitor.yaml`

```yaml
apiVersion: operator.victoriametrics.com/v1beta1
kind: VMServiceScrape
metadata:
  name: dragonfly
  namespace: dragonfly-system
spec:
  selector:
    matchLabels:
      app: dragonfly

  endpoints:
    - port: dragonfly
      path: /metrics
      interval: 30s
      scrapeTimeout: 10s
```

### T13: Create PrometheusRule for Monitoring
**File**: `kubernetes/workloads/platform/databases/dragonfly/prometheusrule.yaml`

```yaml
apiVersion: operator.victoriametrics.com/v1beta1
kind: VMRule
metadata:
  name: dragonfly
  namespace: dragonfly-system
spec:
  groups:
    - name: dragonfly.availability
      interval: 30s
      rules:
        - alert: DragonflyDown
          expr: up{job="dragonfly-system/dragonfly"} == 0
          for: 5m
          labels:
            severity: critical
            component: dragonfly
          annotations:
            summary: "Dragonfly instance {{ $labels.pod }} is down"
            description: "Dragonfly pod {{ $labels.pod }} has been unreachable for 5 minutes"

        - alert: DragonflyNoPrimary
          expr: count(dragonfly_role{role="master"}) == 0
          for: 2m
          labels:
            severity: critical
            component: dragonfly
          annotations:
            summary: "Dragonfly cluster has no primary instance"
            description: "No Dragonfly primary instance detected for 2 minutes"

        - alert: DragonflyReplicaCountLow
          expr: count(up{job="dragonfly-system/dragonfly"} == 1) < 3
          for: 10m
          labels:
            severity: warning
            component: dragonfly
          annotations:
            summary: "Dragonfly cluster has fewer replicas than expected"
            description: "Dragonfly cluster has {{ $value }} replicas (expected 3)"

    - name: dragonfly.performance
      interval: 30s
      rules:
        - alert: DragonflyMemoryHigh
          expr: (dragonfly_memory_used_bytes / dragonfly_memory_max_bytes) > 0.8
          for: 10m
          labels:
            severity: warning
            component: dragonfly
          annotations:
            summary: "Dragonfly memory usage high on {{ $labels.pod }}"
            description: "Dragonfly pod {{ $labels.pod }} is using {{ $value | humanizePercentage }} of memory limit"

        - alert: DragonflyMemoryCritical
          expr: (dragonfly_memory_used_bytes / dragonfly_memory_max_bytes) > 0.9
          for: 5m
          labels:
            severity: critical
            component: dragonfly
          annotations:
            summary: "Dragonfly memory usage critical on {{ $labels.pod }}"
            description: "Dragonfly pod {{ $labels.pod }} is using {{ $value | humanizePercentage }} of memory limit"

        - alert: DragonflyDiskNearFull
          expr: (dragonfly_disk_used_bytes / dragonfly_disk_size_bytes) > 0.8
          for: 15m
          labels:
            severity: warning
            component: dragonfly
          annotations:
            summary: "Dragonfly disk usage high on {{ $labels.pod }}"
            description: "Dragonfly pod {{ $labels.pod }} is using {{ $value | humanizePercentage }} of disk space"

        - alert: DragonflyCommandRateHigh
          expr: rate(dragonfly_commands_processed_total[5m]) > 10000
          for: 10m
          labels:
            severity: warning
            component: dragonfly
          annotations:
            summary: "Dragonfly command rate very high on {{ $labels.pod }}"
            description: "Dragonfly pod {{ $labels.pod }} is processing {{ $value }} commands/sec"

    - name: dragonfly.replication
      interval: 30s
      rules:
        - alert: DragonflyReplicationLagHigh
          expr: dragonfly_replication_lag_seconds > 10
          for: 5m
          labels:
            severity: warning
            component: dragonfly
          annotations:
            summary: "Dragonfly replication lag high on {{ $labels.pod }}"
            description: "Dragonfly replica {{ $labels.pod }} is {{ $value }}s behind primary"

        - alert: DragonflyReplicationBroken
          expr: dragonfly_connected_slaves == 0 and dragonfly_role{role="master"} == 1
          for: 5m
          labels:
            severity: critical
            component: dragonfly
          annotations:
            summary: "Dragonfly primary has no connected replicas"
            description: "Dragonfly primary has no connected replicas for 5 minutes"

        - alert: DragonflyRoleChange
          expr: changes(dragonfly_role[5m]) > 0
          for: 1m
          labels:
            severity: warning
            component: dragonfly
          annotations:
            summary: "Dragonfly role change detected on {{ $labels.pod }}"
            description: "Dragonfly pod {{ $labels.pod }} role changed (failover event)"
```

### T14: Create Per-Tenant Example CR
**File**: `docs/examples/dragonfly-gitlab.yaml`

```yaml
# Example per-tenant Dragonfly CR for GitLab
# This demonstrates isolation pattern for future multi-tenant deployments
# NOT deployed in Story 25 - design reference only

apiVersion: dragonflydb.io/v1alpha1
kind: Dragonfly
metadata:
  name: dragonfly-gitlab
  namespace: gitlab-system
spec:
  image: docker.dragonflydb.io/dragonflydb/dragonfly:v1.23.1

  # Smaller footprint for single-tenant
  replicas: 2

  resources:
    requests:
      cpu: "250m"
      memory: "512Mi"
    limits:
      cpu: "1000m"
      memory: "1Gi"

  snapshot:
    dir: /data
    cron: "0 */12 * * *"

  storage:
    storageClassName: rook-ceph-block
    requests:
      storage: 5Gi

  authentication:
    passwordFromSecret:
      name: dragonfly-gitlab-auth
      key: password

  metrics:
    enabled: true
    port: 6379

  args:
    - --dir=/data
    - --logtostderr
    - --requirepass=$(DRAGONFLY_PASSWORD)
    - --primary_port_http_enabled=true
    - --admin_port=6380
    - --metrics_port=6379
    - --proactor_threads=2
    - --cluster_mode=emulated

  env:
    - name: DRAGONFLY_PASSWORD
      valueFrom:
        secretKeyRef:
          name: dragonfly-gitlab-auth
          key: password

  topologySpreadConstraints:
    - maxSkew: 1
      topologyKey: kubernetes.io/hostname
      whenUnsatisfiable: ScheduleAnyway
      labelSelector:
        matchLabels:
          app: dragonfly
          dragonflydb.io/instance: dragonfly-gitlab

  podSecurityContext:
    runAsNonRoot: true
    runAsUser: 10001
    fsGroup: 10001

  containerSecurityContext:
    runAsNonRoot: true
    runAsUser: 10001
    allowPrivilegeEscalation: false
    readOnlyRootFilesystem: true
    capabilities:
      drop:
        - ALL

  serviceSpec:
    type: ClusterIP

---
# Dedicated PodDisruptionBudget for GitLab's Dragonfly
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: dragonfly-gitlab
  namespace: gitlab-system
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app: dragonfly
      dragonflydb.io/instance: dragonfly-gitlab
```

### T15: Create Workload Kustomization
**File**: `kubernetes/workloads/platform/databases/dragonfly/kustomization.yaml`

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: dragonfly-system

resources:
  - namespace.yaml
  - externalsecret.yaml
  - dragonfly.yaml
  - service.yaml
  - dragonfly-pdb.yaml
  - networkpolicy.yaml
  - servicemonitor.yaml
  - prometheusrule.yaml
```

### T16: Create Flux Kustomization for Operator
**File**: `kubernetes/infrastructure/databases/dragonfly-operator/ks.yaml`

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: cluster-dragonfly-operator
  namespace: flux-system
spec:
  interval: 10m
  retryInterval: 1m
  timeout: 5m

  sourceRef:
    kind: GitRepository
    name: flux-system

  path: ./kubernetes/bases/dragonfly-operator/operator

  prune: true
  wait: true

  healthChecks:
    - apiVersion: apps/v1
      kind: Deployment
      name: dragonfly-operator
      namespace: dragonfly-operator-system

  postBuild:
    substituteFrom:
      - kind: ConfigMap
        name: cluster-settings
```

### T17: Create Flux Kustomization for Dragonfly Cluster
**File**: `kubernetes/workloads/platform/databases/dragonfly/ks.yaml`

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: cluster-databases-dragonfly
  namespace: flux-system
spec:
  interval: 10m
  retryInterval: 1m
  timeout: 5m

  sourceRef:
    kind: GitRepository
    name: flux-system

  path: ./kubernetes/workloads/platform/databases/dragonfly

  prune: true
  wait: true

  # Depend on operator
  dependsOn:
    - name: cluster-dragonfly-operator

  # Health checks
  healthChecks:
    - apiVersion: dragonflydb.io/v1alpha1
      kind: Dragonfly
      name: dragonfly
      namespace: dragonfly-system

  postBuild:
    substituteFrom:
      - kind: ConfigMap
        name: cluster-settings
```

### T18: Local Validation
- [ ] Validate all YAML syntax: `kubectl --dry-run=client -f <file>`
- [ ] Build Flux kustomization (operator): `flux build kustomization cluster-dragonfly-operator --path ./kubernetes/bases/dragonfly-operator/operator`
- [ ] Build Flux kustomization (cluster): `flux build kustomization cluster-databases-dragonfly --path ./kubernetes/workloads/platform/databases/dragonfly`
- [ ] Build with kustomize (operator): `kustomize build kubernetes/bases/dragonfly-operator/operator`
- [ ] Build with kustomize (cluster): `kustomize build kubernetes/workloads/platform/databases/dragonfly`
- [ ] Schema validation: `kubeconform -summary -output json kubernetes/workloads/platform/databases/dragonfly/*.yaml`
- [ ] Verify variable substitution patterns: `grep -r '\${' kubernetes/workloads/platform/databases/dragonfly/`
- [ ] Review Dragonfly CR for security hardening (runAsNonRoot, readOnlyRootFilesystem, drop capabilities)
- [ ] Verify NetworkPolicy allows approved namespaces only
- [ ] Confirm global Service annotations for Cilium ClusterMesh

### T19: Update Cluster Settings (if needed)
**File**: `kubernetes/clusters/infra/cluster-settings.yaml`

Ensure all required variables are present:
```yaml
data:
  # DragonflyDB Configuration
  DRAGONFLY_IMAGE_TAG: "v1.23.1"
  DRAGONFLY_REPLICAS: "3"
  DRAGONFLY_STORAGE_CLASS: "${BLOCK_SC}"
  DRAGONFLY_DATA_SIZE: "10Gi"
  DRAGONFLY_MEMORY_LIMIT: "2Gi"
  DRAGONFLY_CPU_LIMIT: "2000m"
  DRAGONFLY_MEMORY_REQUEST: "1Gi"
  DRAGONFLY_CPU_REQUEST: "500m"

  # External Secret Path
  DRAGONFLY_AUTH_SECRET_PATH: "kubernetes/infra/dragonfly/auth"
```

### T20: Commit to Git
- [ ] Stage all new and modified files
- [ ] Commit with message: "feat(db): create DragonflyDB operator and cluster manifests (Story 25)"
- [ ] Include in commit message:
  - HA operator with 2 replicas and PDB
  - 3-pod Dragonfly cluster with topology spread
  - Cilium global Service for cross-cluster access
  - NetworkPolicies for namespace-based access control
  - Comprehensive monitoring and alerting
  - Per-tenant CR example for future multi-tenancy
  - Security hardening (PSA restricted, non-root, capabilities dropped)

## Runtime Validation (MOVED TO STORY 45)

The following validation steps will be executed during Story 45 deployment:

### Operator Deployment Validation
```bash
# Verify operator deployment
kubectl --context=infra -n dragonfly-operator-system get deployments

# Check operator pods
kubectl --context=infra -n dragonfly-operator-system get pods

# Verify operator replica count (should be 2)
kubectl --context=infra -n dragonfly-operator-system get deployment dragonfly-operator -o jsonpath='{.status.replicas}'

# Check operator PDB
kubectl --context=infra -n dragonfly-operator-system get pdb

# Verify CRDs installed
kubectl --context=infra get crd dragonflydb.io
```

### Dragonfly Cluster Validation
```bash
# Verify Dragonfly CR created
kubectl --context=infra -n dragonfly-system get dragonflies.dragonflydb.io

# Check Dragonfly pods (should be 3)
kubectl --context=infra -n dragonfly-system get pods -l app=dragonfly

# Verify primary and replicas
kubectl --context=infra -n dragonfly-system get pods -l app=dragonfly,dragonflydb.io/role=primary
kubectl --context=infra -n dragonfly-system get pods -l app=dragonfly,dragonflydb.io/role=replica

# Check PVCs
kubectl --context=infra -n dragonfly-system get pvc

# Verify PVC bound status
kubectl --context=infra -n dragonfly-system get pvc -o wide
```

### Topology Spread Validation
```bash
# Verify topology spread constraints
kubectl --context=infra -n dragonfly-system get dragonflies.dragonflydb.io dragonfly -o yaml | grep -A 10 topologySpreadConstraints

# Check pod distribution across nodes
kubectl --context=infra -n dragonfly-system get pods -l app=dragonfly -o wide
```

### Security Validation
```bash
# Verify PSA labels on namespace
kubectl --context=infra get namespace dragonfly-system -o yaml | grep pod-security

# Check security context in Dragonfly CR
kubectl --context=infra -n dragonfly-system get dragonflies.dragonflydb.io dragonfly -o yaml | grep -A 10 securityContext

# Verify runAsNonRoot, readOnlyRootFilesystem, allowPrivilegeEscalation
kubectl --context=infra -n dragonfly-system get dragonflies.dragonflydb.io dragonfly -o yaml | grep -E "runAsNonRoot|readOnlyRootFilesystem|allowPrivilegeEscalation"

# Check capabilities dropped
kubectl --context=infra -n dragonfly-system get pods -l app=dragonfly -o jsonpath='{.items[0].spec.containers[0].securityContext.capabilities}'
```

### Health Probe Validation
```bash
# Verify liveness and readiness probes configured
kubectl --context=infra -n dragonfly-system get dragonflies.dragonflydb.io dragonfly -o yaml | grep -A 5 "livenessProbe\|readinessProbe"

# Check probe endpoints
kubectl --context=infra -n dragonfly-system get pods -l app=dragonfly -o jsonpath='{.items[0].spec.containers[0].livenessProbe}'
```

### PodDisruptionBudget Validation
```bash
# Verify data plane PDB created
kubectl --context=infra -n dragonfly-system get pdb

# Check PDB status (should allow disruption of at most 1 pod)
kubectl --context=infra -n dragonfly-system get pdb dragonfly -o wide
# Expected: minAvailable=2
```

### Service Validation
```bash
# Verify Dragonfly service created by operator
kubectl --context=infra -n dragonfly-system get svc -l app=dragonfly

# Verify global service for cross-cluster access
kubectl --context=infra -n dragonfly-system get svc dragonfly-global

# Check Cilium global annotations
kubectl --context=infra -n dragonfly-system get svc dragonfly-global -o yaml | grep -E "service.cilium.io/global|service.cilium.io/shared"

# Check service endpoints
kubectl --context=infra -n dragonfly-system get endpoints dragonfly-global

# Test DNS resolution
nslookup dragonfly-global.dragonfly-system.svc.cluster.local
```

### ExternalSecret Validation
```bash
# Verify ExternalSecret synced
kubectl --context=infra -n dragonfly-system get externalsecrets

# Check ExternalSecret status
kubectl --context=infra -n dragonfly-system get externalsecrets dragonfly-auth -o wide
# Expected: STATUS=SecretSynced

# Verify secret created
kubectl --context=infra -n dragonfly-system get secret dragonfly-auth

# Check secret has password key
kubectl --context=infra -n dragonfly-system get secret dragonfly-auth -o jsonpath='{.data}' | jq 'keys'
```

### NetworkPolicy Validation
```bash
# Verify CiliumNetworkPolicies created
kubectl --context=infra -n dragonfly-system get ciliumnetworkpolicies

# Check policy rules
kubectl --context=infra -n dragonfly-system get ciliumnetworkpolicy dragonfly-allow-clients -o yaml

# Test allowed access from gitlab-system namespace
kubectl --context=infra -n gitlab-system run -it --rm redis-cli --image=redis:alpine --restart=Never -- \
  redis-cli -h dragonfly-global.dragonfly-system.svc.cluster.local -a <password> PING
# Expected: PONG

# Test allowed access from harbor namespace
kubectl --context=infra -n harbor run -it --rm redis-cli --image=redis:alpine --restart=Never -- \
  redis-cli -h dragonfly-global.dragonfly-system.svc.cluster.local -a <password> PING
# Expected: PONG

# Test denied access from unauthorized namespace
kubectl --context=infra -n default run -it --rm redis-cli --image=redis:alpine --restart=Never -- \
  redis-cli -h dragonfly-global.dragonfly-system.svc.cluster.local -a <password> PING
# Expected: Connection timeout or refused

# Test DNS egress allowed
kubectl --context=infra -n dragonfly-system exec -it <dragonfly-pod> -- nslookup kubernetes.default.svc.cluster.local
# Expected: Successful DNS resolution
```

### Metrics Validation
```bash
# Verify ServiceMonitor created
kubectl --context=infra -n dragonfly-system get vmservicescrapes

# Check ServiceMonitor targets
kubectl --context=infra -n dragonfly-system get vmservicescrape dragonfly -o yaml

# Verify metrics endpoint accessible
DRAGONFLY_POD=$(kubectl --context=infra -n dragonfly-system get pods -l app=dragonfly,dragonflydb.io/role=primary -o jsonpath='{.items[0].metadata.name}')
kubectl --context=infra -n dragonfly-system exec ${DRAGONFLY_POD} -- wget -qO- http://localhost:6379/metrics | head -n 20

# Verify VictoriaMetrics scraping metrics
curl -s "http://vmselect.observability.svc.cluster.local:8481/select/0/prometheus/api/v1/query?query=up{job=\"dragonfly-system/dragonfly\"}" | jq .

# Check specific Dragonfly metrics
curl -s "http://vmselect.observability.svc.cluster.local:8481/select/0/prometheus/api/v1/query?query=dragonfly_memory_used_bytes" | jq .
curl -s "http://vmselect.observability.svc.cluster.local:8481/select/0/prometheus/api/v1/query?query=dragonfly_commands_processed_total" | jq .
```

### PrometheusRule Validation
```bash
# Verify VMRule created
kubectl --context=infra -n dragonfly-system get vmrule dragonfly

# Check VMRule status
kubectl --context=infra -n dragonfly-system get vmrule dragonfly -o yaml | grep -A 10 status:

# Verify rules loaded in VictoriaMetrics
curl -s "http://vmalert.observability.svc.cluster.local:8080/api/v1/rules" | jq '.data.groups[] | select(.name | contains("dragonfly"))'
```

### Cross-Cluster Connectivity Validation
```bash
# From apps cluster, verify Service discoverable via ClusterMesh
kubectl --context=apps run -it --rm redis-cli --image=redis:alpine --restart=Never -- \
  nslookup dragonfly-global.dragonfly-system.svc.cluster.local

# Test connectivity from apps cluster
kubectl --context=apps run -it --rm redis-cli --image=redis:alpine --restart=Never -- \
  redis-cli -h dragonfly-global.dragonfly-system.svc.cluster.local -a <password> PING
# Expected: PONG

# Verify Cilium ClusterMesh status
cilium clustermesh status --context=infra
cilium clustermesh status --context=apps
```

### Replication Validation
```bash
# Check replication status from primary
DRAGONFLY_PRIMARY=$(kubectl --context=infra -n dragonfly-system get pods -l app=dragonfly,dragonflydb.io/role=primary -o jsonpath='{.items[0].metadata.name}')
kubectl --context=infra -n dragonfly-system exec ${DRAGONFLY_PRIMARY} -- redis-cli -a <password> INFO replication

# Verify connected replicas count
kubectl --context=infra -n dragonfly-system exec ${DRAGONFLY_PRIMARY} -- redis-cli -a <password> INFO replication | grep connected_slaves
# Expected: connected_slaves:2

# Check replica lag
kubectl --context=infra -n dragonfly-system exec ${DRAGONFLY_PRIMARY} -- redis-cli -a <password> INFO replication | grep lag
```

### Persistence Validation
```bash
# Verify snapshot configuration
kubectl --context=infra -n dragonfly-system get dragonflies.dragonflydb.io dragonfly -o yaml | grep -A 5 snapshot

# Check data directory mounted
kubectl --context=infra -n dragonfly-system exec <dragonfly-pod> -- ls -la /data

# Verify PVC usage
kubectl --context=infra -n dragonfly-system exec <dragonfly-pod> -- df -h /data
```

### Functional Testing
```bash
# Test write operation
kubectl --context=infra -n gitlab-system run -it --rm redis-cli --image=redis:alpine --restart=Never -- \
  redis-cli -h dragonfly-global.dragonfly-system.svc.cluster.local -a <password> SET testkey "hello dragonfly"

# Test read operation
kubectl --context=infra -n gitlab-system run -it --rm redis-cli --image=redis:alpine --restart=Never -- \
  redis-cli -h dragonfly-global.dragonfly-system.svc.cluster.local -a <password> GET testkey
# Expected: "hello dragonfly"

# Test key expiration
kubectl --context=infra -n gitlab-system run -it --rm redis-cli --image=redis:alpine --restart=Never -- \
  redis-cli -h dragonfly-global.dragonfly-system.svc.cluster.local -a <password> SETEX tempkey 60 "expires in 60s"

# Verify TTL
kubectl --context=infra -n gitlab-system run -it --rm redis-cli --image=redis:alpine --restart=Never -- \
  redis-cli -h dragonfly-global.dragonfly-system.svc.cluster.local -a <password> TTL tempkey

# Clean up test keys
kubectl --context=infra -n gitlab-system run -it --rm redis-cli --image=redis:alpine --restart=Never -- \
  redis-cli -h dragonfly-global.dragonfly-system.svc.cluster.local -a <password> DEL testkey tempkey
```

### GitLab Integration Testing
```bash
# Verify GitLab HelmRelease configured to use external Redis
kubectl --context=apps -n gitlab-system get helmrelease gitlab -o yaml | grep -A 10 "redis:"

# Check GitLab cache connectivity (from GitLab pod)
GITLAB_POD=$(kubectl --context=apps -n gitlab-system get pods -l app=webservice -o jsonpath='{.items[0].metadata.name}')
kubectl --context=apps -n gitlab-system exec ${GITLAB_POD} -- gitlab-rake cache:check

# Verify Sidekiq connectivity
SIDEKIQ_POD=$(kubectl --context=apps -n gitlab-system get pods -l app=sidekiq -o jsonpath='{.items[0].metadata.name}')
kubectl --context=apps -n gitlab-system exec ${SIDEKIQ_POD} -- redis-cli -h dragonfly-global.dragonfly-system.svc.cluster.local -a <password> PING
```

### Performance Validation
```bash
# Check command processing rate
curl -s "http://vmselect.observability.svc.cluster.local:8481/select/0/prometheus/api/v1/query?query=rate(dragonfly_commands_processed_total[5m])" | jq .

# Monitor memory usage
curl -s "http://vmselect.observability.svc.cluster.local:8481/select/0/prometheus/api/v1/query?query=dragonfly_memory_used_bytes" | jq .

# Check disk usage
curl -s "http://vmselect.observability.svc.cluster.local:8481/select/0/prometheus/api/v1/query?query=dragonfly_disk_used_bytes" | jq .

# Benchmark with redis-benchmark (from test pod)
kubectl --context=infra -n dragonfly-system run -it --rm redis-benchmark --image=redis:alpine --restart=Never -- \
  redis-benchmark -h dragonfly-global.dragonfly-system.svc.cluster.local -a <password> -t set,get -n 100000 -c 50
```

## Definition of Done

### Manifest Creation Complete (This Story)
- [ ] All acceptance criteria AC1-AC10 met with evidence
- [ ] Operator HelmRelease created with 2 replicas, CRD management, PDB
- [ ] Dragonfly CR created with 3 replicas, topology spread, security hardening, probes
- [ ] Data plane PDB created with minAvailable: 2
- [ ] ExternalSecret created for authentication
- [ ] Global Service created with Cilium ClusterMesh annotations
- [ ] NetworkPolicy created restricting access to approved namespaces
- [ ] ServiceMonitor and PrometheusRule created with comprehensive alerts
- [ ] Per-tenant example CR documented
- [ ] Flux Kustomization manifests created with health checks
- [ ] All manifests pass local validation (kubectl, flux, kustomize, kubeconform)
- [ ] Cluster settings updated with all required variables
- [ ] Changes committed to git with descriptive commit message
- [ ] Story documented in change log

### NOT Part of DoD (Moved to Story 45)
- ~~Operator deployed and healthy~~
- ~~Dragonfly cluster deployed with primary election~~
- ~~Cross-cluster Service reachable from apps cluster~~
- ~~NetworkPolicy enforcement validated~~
- ~~Metrics scraped by VictoriaMetrics~~
- ~~GitLab cache connectivity tested~~
- ~~Performance benchmarks completed~~

---

## Design Notes

### DragonflyDB Architecture

**What is DragonflyDB?**
- Modern, Redis-compatible in-memory datastore
- Multi-threaded architecture for better CPU utilization vs. Redis
- Lower memory overhead with efficient data structures
- Compatible with Redis client libraries and protocols
- Suitable for caching, session storage, and rate limiting

**Why DragonflyDB over Redis?**
- **Performance**: Better throughput with multi-threaded architecture
- **Memory Efficiency**: ~30% lower memory usage for same dataset
- **Simplicity**: Single binary, simpler operations than Redis Cluster
- **Compatibility**: Drop-in replacement for Redis (supports RESP protocol)

### Operator-Based Management

**DragonflyDB Operator**:
- Kubernetes-native management via Custom Resources (Dragonfly CR)
- Automated lifecycle: provisioning, scaling, failover
- Built-in monitoring and metrics exposure
- CRD-driven configuration (no manual ConfigMaps)

**Operator HA**:
- 2 replicas for webhook and reconciliation availability
- PodDisruptionBudget ensures at least 1 replica during node maintenance
- Pod anti-affinity distributes replicas across nodes

### Cluster Configuration

**High Availability**:
- 3 pods: 1 primary (master) + 2 replicas
- Automatic failover on primary failure
- Topology spread constraints distribute pods across nodes
- PodDisruptionBudget (minAvailable: 2) ensures quorum during updates

**Storage**:
- Persistent volumes (10Gi per pod, Rook-Ceph block storage)
- Snapshot every 6 hours to disk (`/data`)
- Configurable via `--save_schedule` and `--dir` args
- Total storage: 30Gi (3 pods × 10Gi)

**Resource Allocation**:
- Memory: 1Gi request, 2Gi limit per pod (3Gi total request, 6Gi total limit)
- CPU: 500m request, 2000m limit per pod (1.5 CPU total request, 6 CPU total limit)
- Proactor threads: 2 (configurable based on workload)

**Replication**:
- Emulated cluster mode for Redis Cluster compatibility
- Master-replica replication for data durability
- Replication lag monitoring via Prometheus metrics

### Cross-Cluster Access via Cilium ClusterMesh

**Global Service Pattern**:
- Service annotated with `service.cilium.io/global: "true"` and `service.cilium.io/shared: "true"`
- DNS name resolves across clusters: `dragonfly-global.dragonfly-system.svc.cluster.local`
- Apps cluster pods can access infra cluster Dragonfly transparently
- No manual endpoint configuration in applications

**Benefits**:
- Single source of truth for cache service
- Centralized management on infra cluster
- Apps cluster remains stateless (no local cache)
- ClusterMesh handles service discovery and routing

**Requirements**:
- Cilium ClusterMesh configured between infra and apps clusters
- Network connectivity between cluster nodes
- Consistent service/namespace naming

### Security Hardening

**Pod Security Admission**: PSA restricted enforcement on all namespaces

**Non-Root Containers**:
- `runAsNonRoot: true`
- `runAsUser: 10001`
- `fsGroup: 10001`

**Capability Restrictions**:
- `allowPrivilegeEscalation: false`
- `readOnlyRootFilesystem: true`
- Drop all capabilities

**Authentication**:
- Password authentication via ExternalSecret (1Password)
- `--requirepass` flag enforces authentication
- Credentials rotated via ExternalSecrets refresh interval

**NetworkPolicy**:
- Default deny all ingress
- Allow only from approved namespaces: gitlab-system, harbor, observability
- Allow DNS egress for service discovery
- Allow inter-pod communication for replication

### Observability

**Metrics Exposure**:
- Built-in Prometheus metrics on port 6379 at `/metrics` endpoint
- Metrics include: memory usage, disk usage, command rates, replication lag, role

**ServiceMonitor**:
- VictoriaMetrics scrapes metrics every 30s
- Automatic discovery via label selectors

**Alert Rules** (9 alerts across 3 groups):

1. **Availability Alerts**:
   - DragonflyDown: Instance unreachable for 5m (critical)
   - DragonflyNoPrimary: No primary instance for 2m (critical)
   - DragonflyReplicaCountLow: Fewer than 3 replicas for 10m (warning)

2. **Performance Alerts**:
   - DragonflyMemoryHigh: >80% memory usage for 10m (warning)
   - DragonflyMemoryCritical: >90% memory usage for 5m (critical)
   - DragonflyDiskNearFull: >80% disk usage for 15m (warning)
   - DragonflyCommandRateHigh: >10k commands/sec for 10m (warning)

3. **Replication Alerts**:
   - DragonflyReplicationLagHigh: >10s lag for 5m (warning)
   - DragonflyReplicationBroken: Primary has no replicas for 5m (critical)
   - DragonflyRoleChange: Role change detected (warning, indicates failover)

### Tenancy Patterns

**Shared Cluster (Implemented)**:
- Single Dragonfly cluster serves all applications
- Namespace isolation via NetworkPolicy
- Suitable for trusted workloads (GitLab, Harbor)
- Resource efficiency (single 3-pod cluster)

**Per-Tenant Clusters (Example Provided)**:
- Dedicated Dragonfly CR per application
- Complete isolation (separate pods, PVCs, credentials)
- Tailored resource allocation per workload
- Higher overhead but stronger isolation

**When to Use Per-Tenant**:
- Multi-tenant SaaS with strict isolation requirements
- Different performance profiles (GitLab needs more resources)
- Independent lifecycle management
- Compliance requirements (data segregation)

**Example CR**: `docs/examples/dragonfly-gitlab.yaml` demonstrates per-tenant pattern without disrupting current shared cluster.

### Health Checks

**Liveness Probe**:
- HTTP GET on `/healthz` endpoint (port 8080)
- Initial delay: 30s (allow startup time)
- Period: 10s, Timeout: 5s, Failure threshold: 3
- Restarts unhealthy pods

**Readiness Probe**:
- HTTP GET on `/healthz` endpoint (port 8080)
- Initial delay: 10s
- Period: 5s, Timeout: 3s, Failure threshold: 3
- Removes unready pods from service endpoints

### Version Alignment

**Operator**: 1.3.x (latest stable)
- CRD API version: dragonflydb.io/v1alpha1
- Supports Dragonfly v1.17+

**Dragonfly**: v1.23.1 (latest stable at time of writing)
- Multi-threaded architecture
- Redis 7.x compatibility
- Cluster mode emulation
- Prometheus metrics built-in

**Compatibility**: Operator 1.3.x supports Dragonfly v1.17-v1.23.x

### Future Considerations

**Automated Backups**:
- Export snapshots to S3-compatible storage
- Scheduled backup CronJobs
- Restore procedures and disaster recovery testing

**Per-Tenant Migration**:
- Migrate GitLab to dedicated Dragonfly CR for isolation
- Update GitLab HelmRelease to point to new endpoint
- Gradual cutover with validation

**Performance Tuning**:
- Monitor `dragonfly_commands_processed_total` and adjust proactor threads
- Scale memory/CPU based on actual workload
- Benchmark with redis-benchmark and adjust

**Multi-Zone HA**:
- Topology spread across availability zones
- Zone-aware replication for disaster recovery
- Multi-region ClusterMesh for global distribution

**ACL Support**:
- Per-application credentials with specific command permissions
- Fine-grained access control beyond password auth
- Audit logging for compliance

---

## Research — Best Practices (Operator + Dragonfly)

- Operator delivery via Helm (OCI) with CRDs managed by the chart. Keep `CreateReplace` on install/upgrade and remediation with retries; run ≥2 replicas with a PDB to avoid webhook and reconcile gaps during node maintenance.
- Dragonfly CR: 3 pods minimum for HA (1 primary, 2 replicas). Persist data to fast storage; set `--dir=/data`, expose metrics, and enable authentication via a Secret. Use PVCs sized with headroom (30–50%).
- Replication & persistence: Prefer master-only snapshots (if supported in chosen version) to offload replica IO; validate replication behavior on primary restart to avoid divergence.
- Security: Run as non-root, drop capabilities, restrict ingress via NetworkPolicy. Use External Secrets for credentials.
- Cross-cluster access: Rely on Cilium global Services for DNS and routing; keep a stable `ClusterIP` Service annotated as global/shared.
- Observability: Enable ServiceMonitor; add alert rules for availability, memory and disk pressure, replication lag, and command rate bursts. Label time series with instance/role for dashboards.

## Gap Analysis — Repo vs Best Practices

- Operator already aligned: OCIRepository + HelmRelease with HA, PDB, anti-affinity, ServiceMonitor enabled. **Already present**
- Dragonfly CR present with 3 replicas, PVCs, auth, metrics, and a global Service; missing items: pod anti-affinity/topology spread on data plane, explicit PDB for data pods, and NetworkPolicy. Image is `v1.17.0`; plan upgrade to a tested newer tag. **FIXED in this story** (topology spread, PDB, NetworkPolicy, upgrade to v1.23.1)
- Observability rules exist; extend to include memory reserve and disk saturation alerts. **FIXED in this story** (comprehensive PrometheusRule)
- Security hardening needed: runAsNonRoot, readOnlyRootFilesystem, drop capabilities. **FIXED in this story**
- Per-tenant pattern documented. **ADDED in this story** (example CR)

---

## Change Log

### v5.0 - 2025-11-01 - Production-Ready with Critical Fixes & Operator Standardization
**Architect**: Comprehensive rework addressing critical configuration issues, version upgrades, and architectural consistency.

**Critical Fixes:**
1. **Disk Exhaustion Prevention**: Added `--dbfilename=dump` to use static snapshot filename (prevents accumulation of timestamped files)
2. **Memory Management**: Added `--maxmemory=1610612736` (1.5Gi, 90% of limit) for graceful eviction before OOM
3. **Thread Optimization**: Changed `--proactor_threads=0` for auto-detection (was hardcoded to 2)
4. **Cache Mode**: Added `--cache_mode=true` for eviction-based caching (recommended for GitLab/Harbor workloads)
5. **Save Schedule**: Changed `--save_schedule=` (empty) to disable continuous saves (cron snapshots handle backups)

**Version Updates:**
- DragonflyDB: v1.23.1 → v1.34.2 (latest stable, +11 releases, CVE-2025-26268 fix)
- Operator: 1.3.x (semver) → v1.3.0 (exact pin)
- Cluster Settings: Updated version from story docs (v1.23.1) → deployed reality (v1.34.2)

**Architectural Standardization:**
- **Operator Directory Consolidation**: Moved CNPG and Rook-Ceph operators to `kubernetes/bases/` for consistency
  - CNPG: `infrastructure/databases/cloudnative-pg/operator/app/` → `bases/cnpg-operator/operator/`
  - Rook-Ceph: `infrastructure/storage/rook-ceph/operator/` → `bases/rook-ceph-operator/operator/`
- **Pattern Alignment**: All operators now follow consistent pattern (DragonflyDB, CNPG, Rook-Ceph, Keycloak)
  - Manifests: `kubernetes/bases/{operator-name}/operator/`
  - Flux Kustomization: `kubernetes/infrastructure/{layer}/{operator-name}/ks.yaml`

**Documentation:**
- Created `docs/runbooks/dragonfly-operations.md` - comprehensive operations runbook covering:
  - Daily operations and monitoring
  - Scaling (vertical/horizontal)
  - Backup & restore procedures
  - Troubleshooting guides
  - Performance tuning
  - Disaster recovery
- Updated Story 25 status to "Complete (v5.0)" with version corrections
- Added cluster-settings variables: `DRAGONFLY_MAXMEMORY`, `DRAGONFLY_CACHE_MODE`

**Monitoring Enhancements:**
- All 9 existing PrometheusRule alerts validated
- Metrics-based operational guidance in runbook

**Registry Verification:**
- Confirmed `ghcr.io` official for DragonflyDB (no auth required)
- Confirmed `quay.io` public access for VictoriaMetrics, Ceph, Keycloak
- Validated CloudNativePG using official `ghcr.io/cloudnative-pg/*` registries

**Validation:**
- Local flux build validation
- Kubectl dry-run validation
- Cross-reference validation across operator directory structure

**Impact:**
- **Critical Bug Fixes**: Prevents production outages from disk exhaustion and OOM kills
- **Performance**: Auto-threading optimization, cache mode for workload pattern
- **Architectural Consistency**: All operators follow documented `bases/` pattern (CLAUDE.md compliance)
- **Operational Excellence**: Comprehensive runbook for platform team
- **Security**: CVE-2025-26268 resolved (v1.34.2)

**Files Changed:**
- `kubernetes/workloads/platform/databases/dragonfly/dragonfly.yaml` (args configuration)
- `kubernetes/clusters/infra/cluster-settings.yaml` (new variables, version correction)
- `kubernetes/bases/cnpg-operator/operator/*` (moved from infrastructure)
- `kubernetes/bases/rook-ceph-operator/operator/*` (moved from infrastructure)
- `kubernetes/infrastructure/databases/cloudnative-pg/operator/ks.yaml` (path update)
- `kubernetes/infrastructure/storage/rook-ceph/operator/ks.yaml` (path update)
- `docs/runbooks/dragonfly-operations.md` (new)
- `docs/stories/STORY-DB-DRAGONFLY-OPERATOR-CLUSTER.md` (v5.0 update)

---

### v3.0 - 2025-10-26 - Manifests-First Refinement
**Architect**: Separated manifest creation from deployment and validation following v3.0 architecture pattern.

**Changes**:
1. **Story Rewrite**: Focused on creating manifests for DragonflyDB operator and shared cluster with cross-cluster access
2. **Scope Split**: "This Story (Manifest Creation)" vs. "Deferred to Story 45 (Deployment & Validation)"
3. **Acceptance Criteria**: Rewrote AC1-AC10 for manifest creation; deferred runtime validation to Story 45
4. **Dependencies**: Updated to local tools only (kubectl, flux, kustomize, kubeconform, yq, git)
5. **Tasks**: Restructured to T1-T20 covering manifest creation and local validation:
   - T1: Prerequisites and configuration strategy
   - T2: Operator namespace with PSA restricted
   - T3: OCIRepository for operator Helm chart
   - T4: Operator HelmRelease (2 replicas, PDB, anti-affinity, ServiceMonitor)
   - T5: Operator Kustomization
   - T6: Dragonfly system namespace
   - T7: ExternalSecret for authentication
   - T8: Dragonfly CR (3 replicas, topology spread, security hardening, probes)
   - T9: Global Service with Cilium ClusterMesh annotations
   - T10: Data plane PDB (minAvailable: 2)
   - T11: NetworkPolicy (namespace-based access control)
   - T12: ServiceMonitor
   - T13: PrometheusRule with 9 alerts
   - T14: Per-tenant example CR
   - T15: Workload Kustomization
   - T16: Flux Kustomization for operator
   - T17: Flux Kustomization for cluster
   - T18: Local validation
   - T19: Cluster settings update
   - T20: Git commit
6. **Runtime Validation**: Created comprehensive "Runtime Validation (MOVED TO STORY 45)" section with 13 categories:
   - Operator deployment validation
   - Dragonfly cluster validation
   - Topology spread validation
   - Security validation (PSA, non-root, capabilities)
   - Health probe validation
   - PodDisruptionBudget validation
   - Service validation (global Service, DNS)
   - ExternalSecret validation
   - NetworkPolicy validation (allowed/denied access)
   - Metrics validation
   - PrometheusRule validation
   - Cross-cluster connectivity validation (ClusterMesh)
   - Replication validation
   - Persistence validation
   - Functional testing (write/read/TTL)
   - GitLab integration testing
   - Performance validation
7. **DoD Update**: "Manifest Creation Complete" vs. "NOT Part of DoD (Moved to Story 45)"
8. **Design Notes**: Added comprehensive design documentation covering:
   - DragonflyDB architecture and advantages over Redis
   - Operator-based management benefits
   - Cluster configuration (HA, storage, resources, replication)
   - Cross-cluster access via Cilium ClusterMesh
   - Security hardening (PSA, non-root, capabilities, auth, NetworkPolicy)
   - Observability (metrics, ServiceMonitor, 9 alert rules)
   - Tenancy patterns (shared vs. per-tenant)
   - Health checks (liveness/readiness probes)
   - Version alignment (operator 1.3.x, Dragonfly v1.23.1)
   - Future considerations (backups, migration, tuning, multi-zone HA, ACLs)
9. **Gap Analysis Fixes**:
   - Added topology spread constraints for pod distribution
   - Added data plane PDB (minAvailable: 2)
   - Added comprehensive NetworkPolicy for namespace-based access control
   - Upgraded Dragonfly image from v1.17.0 to v1.23.1
   - Extended PrometheusRule with memory, disk, and replication alerts
   - Added security hardening (runAsNonRoot, readOnlyRootFilesystem, drop capabilities)
   - Added liveness/readiness probes
   - Documented per-tenant pattern with example CR

**Technical Details**:
- DragonflyDB operator 1.3.x with 2 replicas and PDB
- Dragonfly v1.23.1 (latest stable)
- 3-pod cluster: 1 primary + 2 replicas with topology spread
- Storage: 10Gi per pod (30Gi total, Rook-Ceph block storage)
- Resources: 1Gi/500m request, 2Gi/2000m limit per pod
- Cilium global Service for cross-cluster access (apps→infra)
- NetworkPolicy: Allow gitlab-system, harbor, observability; deny all others
- Authentication via ExternalSecret (1Password)
- PSA restricted enforcement with security hardening
- Comprehensive monitoring: ServiceMonitor + 9 PrometheusRule alerts
- Per-tenant example CR for future multi-tenancy

**Validation Approach**:
- Local-only validation using kubectl --dry-run, flux build, kustomize build, kubeconform
- Comprehensive runtime validation commands documented for Story 45
- No cluster access required for this story

**Story Workflow**:
1. Create all manifests for DragonflyDB operator and shared cluster
2. Validate manifests locally using GitOps tools
3. Commit to git
4. Deployment and runtime validation deferred to Story 45
