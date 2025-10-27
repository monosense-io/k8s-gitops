# 23 — STORY-DB-CNPG-OPERATOR — Create CloudNativePG Operator Manifests

Sequence: 23/50 | Prev: STORY-OBS-FLUENT-BIT-IMPLEMENT.md | Next: STORY-DB-CNPG-SHARED-CLUSTER.md
Sprint: 5 | Lane: Database
Global Sequence: 23/50

Status: Draft (v3.0 Refinement)
Owner: Platform Engineering
Date: 2025-10-26
Links: kubernetes/infrastructure/databases/cloudnative-pg/operator; bootstrap/helmfile.d/00-crds.yaml; kubernetes/clusters/infra/cluster-settings.yaml

## Story

As a platform engineer, I want to **create CloudNativePG (CNPG) operator manifests** for declarative PostgreSQL cluster management, so that when deployed in Story 45, I have:
- CNPG operator running with high availability (2 replicas)
- CRDs registered for Cluster, Pooler, Backup resources
- Pod Security Admission enforced at restricted level
- Operator metrics collection enabled
- Version alignment between CRDs and operator chart
- Proper watch scope configuration (cluster-wide)

## Why / Outcome

- Reliable, operator-managed PostgreSQL clusters with automated lifecycle management
- High availability operator deployment with PodDisruptionBudget protection
- Security hardening with restricted PSA (no privileged containers required)
- Observability integration with VictoriaMetrics for operator health monitoring
- Foundation for shared PostgreSQL cluster (Story 24) and application databases

## Scope

### This Story (Manifest Creation)

Create the following CloudNativePG operator manifests:

**Infra Cluster:**
- Namespace with Pod Security Admission labels (restricted)
- HelmRelease for CNPG operator with HA configuration
- PodDisruptionBudget for operator availability
- PodMonitor for operator metrics collection
- PrometheusRule for operator health alerts
- Flux Kustomization with health checks
- CRD version alignment configuration

**Configuration:**
- Operator replicas: 2 (high availability)
- Watch scope: cluster-wide (shared infrastructure pattern)
- Pod Security: restricted (no privileged mode)
- Version alignment: CRD bundle and chart on same minor (0.26.x)
- Anti-affinity: preferredDuringSchedulingIgnoredDuringExecution

### Deferred to Story 45 (Deployment & Validation)

- Deploy CNPG operator via Flux
- Verify CRDs registered and Established
- Validate operator pods Running with 2 replicas
- Test PDB preventing unsafe disruptions
- Verify PSA restricted enforcement
- Validate PodMonitor metrics collection
- Test operator reconciliation with sample Cluster CR

## Acceptance Criteria

### Manifest Creation (This Story)

1. **Namespace Manifest Created:**
   - cnpg-system namespace
   - PSA labels: enforce=restricted, audit=restricted, warn=restricted
   - No privileged mode required

2. **CNPG Operator HelmRelease Created:**
   - Operator chart version 0.26.x (aligned with CRDs)
   - replicaCount: 2 for HA
   - Resource limits and requests defined
   - Anti-affinity rules for pod distribution
   - Watch scope: cluster-wide (config.clusterWide: true)

3. **PodDisruptionBudget Manifest Created:**
   - minAvailable: 1 (ensures at least 1 replica during disruptions)
   - Selector matches operator pods

4. **PodMonitor Manifest Created:**
   - Metrics endpoint configuration
   - Labels compatible with VictoriaMetrics operator selector
   - Scrape interval: 30s

5. **PrometheusRule Manifest Created:**
   - Operator availability alerts
   - Webhook health checks
   - CRD reconciliation error alerts

6. **Flux Kustomization Created:**
   - Health checks for operator Deployment
   - Dependency on CRDs (Story 01)
   - Variable substitution from cluster-settings

7. **Version Alignment Documented:**
   - CRD bundle version: 0.26.x in bootstrap/helmfile.d/00-crds.yaml
   - Operator chart version: 0.26.x in cluster-settings
   - CNPG_OPERATOR_VERSION variable set

### Deferred to Story 45 (Deployment & Validation)

- CNPG operator Deployment Available with 2 replicas
- CRDs registered (Cluster, Pooler, Backup, etc.)
- Operator webhooks healthy and admitting CRs
- PDB preventing unsafe pod evictions
- PSA restricted enforced, operator pods Running
- PodMonitor scraping metrics successfully
- VictoriaMetrics showing up{job="cnpg-system/cloudnative-pg-metrics"}
- Sample Cluster CR successfully reconciled

## Dependencies / Inputs

**Required Before This Story:**
- None - manifests can be created independently

**Local Tools Required:**
- kubectl (manifest validation)
- flux CLI (kustomization build)
- yq (YAML processing)
- kubeconform (schema validation)

**No Cluster Access Required** - all validation is local

**Cluster Variables (from cluster-settings ConfigMap):**
```yaml
# CloudNativePG Operator
CNPG_OPERATOR_VERSION: "0.26.0"
CNPG_OPERATOR_REPLICAS: "2"
BLOCK_SC: "ceph-block"
```

## Tasks / Subtasks — Implementation Plan (Story Only)

### T1: Verify Prerequisites

**Steps:**
1. Review CloudNativePG operator architecture and components
2. Verify CRD bundle version in bootstrap/helmfile.d/00-crds.yaml
3. Plan version alignment strategy (choose 0.26.x)
4. Review Pod Security Admission requirements

**Acceptance:** Prerequisites documented, version strategy defined

### T2: Create Namespace Manifest

**Location:** `kubernetes/infrastructure/databases/cloudnative-pg/operator/`

**Create Namespace** (`namespace.yaml`):
```yaml
---
apiVersion: v1
kind: Namespace
metadata:
  name: cnpg-system
  labels:
    # Pod Security Admission - Restricted
    # CNPG does not require privileged containers
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted

    # Standard labels
    app.kubernetes.io/name: cloudnative-pg
    app.kubernetes.io/component: operator
```

**Acceptance:** Namespace created with PSA restricted labels

### T3: Create CNPG Operator HelmRelease Manifest

**Location:** `kubernetes/infrastructure/databases/cloudnative-pg/operator/helmrelease.yaml`

**Create HelmRelease:**
```yaml
---
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: cloudnative-pg
  namespace: cnpg-system
spec:
  chartRef:
    kind: OCIRepository
    name: cloudnative-pg
    namespace: flux-system
  interval: 1h
  timeout: 10m
  install:
    crds: Skip  # CRDs installed via bootstrap helmfile
    remediation:
      retries: 3
  upgrade:
    crds: Skip
    remediation:
      retries: 3
  values:
    fullnameOverride: cloudnative-pg

    # High Availability configuration
    replicaCount: ${CNPG_OPERATOR_REPLICAS}

    # Resource limits
    resources:
      limits:
        cpu: 500m
        memory: 512Mi
      requests:
        cpu: 100m
        memory: 128Mi

    # Anti-affinity for pod distribution
    affinity:
      podAntiAffinity:
        preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchLabels:
                  app.kubernetes.io/name: cloudnative-pg
              topologyKey: kubernetes.io/hostname

    # Watch scope - cluster-wide for shared infrastructure
    config:
      clusterWide: true

    # Monitoring configuration
    monitoring:
      podMonitorEnabled: true
      podMonitorNamespace: cnpg-system
      podMonitorAdditionalLabels:
        app.kubernetes.io/name: cloudnative-pg

    # Security context - no privileged mode needed
    securityContext:
      runAsNonRoot: true
      runAsUser: 10001
      fsGroup: 10001
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      seccompProfile:
        type: RuntimeDefault
      capabilities:
        drop:
          - ALL

    # Service configuration
    service:
      type: ClusterIP
      port: 8080

    # Webhook configuration
    webhook:
      port: 9443
      mutating:
        create: true
        failurePolicy: Fail
      validating:
        create: true
        failurePolicy: Fail

    # Leader election
    leaderElection:
      enabled: true
```

**Acceptance:** HelmRelease created with HA and security configuration

### T4: Create PodDisruptionBudget Manifest

**Location:** `kubernetes/infrastructure/databases/cloudnative-pg/operator/pdb.yaml`

**Create:**

```yaml
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: cloudnative-pg
  namespace: cnpg-system
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: cloudnative-pg
      app.kubernetes.io/instance: cloudnative-pg
```

**Acceptance:** PDB created for operator HA protection

### T5: Create PodMonitor Manifest

**Location:** `kubernetes/infrastructure/databases/cloudnative-pg/operator/podmonitor.yaml`

**Create:**

```yaml
---
apiVersion: operator.victoriametrics.com/v1beta1
kind: VMPodScrape
metadata:
  name: cloudnative-pg-metrics
  namespace: cnpg-system
  labels:
    app.kubernetes.io/name: cloudnative-pg
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: cloudnative-pg
  podMetricsEndpoints:
    - port: metrics
      interval: 30s
      scrapeTimeout: 10s
      path: /metrics
```

**Acceptance:** PodMonitor created for operator metrics

### T6: Create PrometheusRule Manifest

**Location:** `kubernetes/infrastructure/databases/cloudnative-pg/operator/prometheusrule.yaml`

**Create:**

```yaml
---
apiVersion: operator.victoriametrics.com/v1beta1
kind: VMRule
metadata:
  name: cloudnative-pg-operator
  namespace: cnpg-system
spec:
  groups:
    - name: cloudnativepg.operator
      interval: 30s
      rules:
        # Operator availability
        - alert: CNPGOperatorDown
          expr: up{job="cnpg-system/cloudnative-pg-metrics"} == 0
          for: 5m
          labels:
            severity: critical
          annotations:
            summary: "CloudNativePG operator is down"
            description: "CloudNativePG operator in namespace {{ $labels.namespace }} has been down for more than 5 minutes"

        # Operator pod restarts
        - alert: CNPGOperatorHighRestarts
          expr: rate(kube_pod_container_status_restarts_total{namespace="cnpg-system",pod=~"cloudnative-pg.*"}[15m]) > 0.1
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "CloudNativePG operator restarting frequently"
            description: "CloudNativePG operator pod {{ $labels.pod }} has restarted {{ $value }} times in the last 15 minutes"

        # Webhook errors
        - alert: CNPGWebhookErrors
          expr: rate(cnpg_webhook_requests_total{result="error"}[5m]) > 0.1
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "CloudNativePG webhook errors detected"
            description: "CloudNativePG webhook is experiencing errors at {{ $value }} errors/second"

        # Reconciliation errors
        - alert: CNPGReconciliationErrors
          expr: rate(cnpg_controller_reconciliation_errors_total[5m]) > 0.1
          for: 15m
          labels:
            severity: warning
          annotations:
            summary: "CloudNativePG reconciliation errors"
            description: "CloudNativePG controller is experiencing reconciliation errors at {{ $value }} errors/second"

        # Operator replicas
        - alert: CNPGOperatorNotHighlyAvailable
          expr: kube_deployment_status_replicas_available{namespace="cnpg-system",deployment="cloudnative-pg"} < 2
          for: 15m
          labels:
            severity: warning
          annotations:
            summary: "CloudNativePG operator not highly available"
            description: "CloudNativePG operator has {{ $value }} replicas available (expected 2)"
```

**Acceptance:** PrometheusRule created for operator health monitoring

### T7: Create Kustomization Manifest

**Location:** `kubernetes/infrastructure/databases/cloudnative-pg/operator/kustomization.yaml`

**Create:**

```yaml
---
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: cnpg-system
resources:
  - namespace.yaml
  - helmrelease.yaml
  - pdb.yaml
  - podmonitor.yaml
  - prometheusrule.yaml
```

**Acceptance:** Kustomization manifest created

### T8: Create Flux Kustomization Manifest

**Location:** `kubernetes/infrastructure/databases/cloudnative-pg/operator/ks.yaml`

**Create:**

```yaml
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: infrastructure-databases-cnpg-operator
  namespace: flux-system
spec:
  interval: 30m
  timeout: 10m
  sourceRef:
    kind: GitRepository
    name: flux-system
  path: ./kubernetes/infrastructure/databases/cloudnative-pg/operator
  prune: true
  wait: true
  dependsOn:
    - name: infrastructure-repositories-oci
  postBuild:
    substituteFrom:
      - kind: ConfigMap
        name: cluster-settings
  healthChecks:
    - apiVersion: apps/v1
      kind: Deployment
      name: cloudnative-pg
      namespace: cnpg-system
    - apiVersion: apiextensions.k8s.io/v1
      kind: CustomResourceDefinition
      name: clusters.postgresql.cnpg.io
    - apiVersion: apiextensions.k8s.io/v1
      kind: CustomResourceDefinition
      name: poolers.postgresql.cnpg.io
    - apiVersion: apiextensions.k8s.io/v1
      kind: CustomResourceDefinition
      name: backups.postgresql.cnpg.io
```

**Acceptance:** Flux Kustomization created with health checks

### T9: Local Validation

**Steps:**

1. **Validate Namespace Syntax:**
   ```bash
   kubectl --dry-run=client -f kubernetes/infrastructure/databases/cloudnative-pg/operator/namespace.yaml apply
   ```

2. **Validate HelmRelease Syntax:**
   ```bash
   kubectl --dry-run=client -f kubernetes/infrastructure/databases/cloudnative-pg/operator/helmrelease.yaml apply
   ```

3. **Validate PDB Syntax:**
   ```bash
   kubectl --dry-run=client -f kubernetes/infrastructure/databases/cloudnative-pg/operator/pdb.yaml apply
   ```

4. **Validate PodMonitor:**
   ```bash
   kubectl --dry-run=client -f kubernetes/infrastructure/databases/cloudnative-pg/operator/podmonitor.yaml apply
   ```

5. **Validate PrometheusRule:**
   ```bash
   kubectl --dry-run=client -f kubernetes/infrastructure/databases/cloudnative-pg/operator/prometheusrule.yaml apply
   ```

6. **Build Kustomization:**
   ```bash
   kustomize build kubernetes/infrastructure/databases/cloudnative-pg/operator/
   ```

7. **Validate Flux Kustomization:**
   ```bash
   flux build kustomization infrastructure-databases-cnpg-operator \
     --path kubernetes/infrastructure/databases/cloudnative-pg/operator/ \
     --kustomization-file kubernetes/infrastructure/databases/cloudnative-pg/operator/ks.yaml
   ```

8. **Schema Validation (if kubeconform available):**
   ```bash
   kubeconform -strict kubernetes/infrastructure/databases/cloudnative-pg/operator/
   ```

**Acceptance:** All manifests validate successfully with no errors

### T10: Update CRD Bootstrap Configuration

**Location:** `bootstrap/helmfile.d/00-crds.yaml`

**Verify/Update:**
```yaml
releases:
  - name: cloudnative-pg-crds
    namespace: cnpg-system
    chart: oci://ghcr.io/cloudnative-pg/charts/cloudnative-pg-crds
    version: 0.26.0  # Aligned with operator chart
    installed: true
```

**Acceptance:** CRD version aligned with operator version

### T11: Update Cluster Settings

**Infra Cluster** (`kubernetes/clusters/infra/cluster-settings.yaml`):

**Add:**
```yaml
  # CloudNativePG Operator
  CNPG_OPERATOR_VERSION: "0.26.0"
  CNPG_OPERATOR_REPLICAS: "2"
```

**Acceptance:** Cluster settings updated with CNPG configuration

### T12: Commit to Git

**Steps:**
1. Stage all created manifests
2. Commit with message:
   ```
   feat(databases): add CloudNativePG operator manifests

   - Operator HelmRelease with HA (2 replicas)
   - Namespace with PSA restricted enforcement
   - PodDisruptionBudget for availability protection
   - PodMonitor for metrics collection
   - PrometheusRule for operator health alerts
   - Flux Kustomization with CRD health checks
   - Version alignment: CRDs and operator both 0.26.0

   Story: STORY-DB-CNPG-OPERATOR
   ```

**Acceptance:** All manifests committed to git

## Runtime Validation (MOVED TO STORY 45)

**IMPORTANT:** The following validation steps are **NOT** part of this story. They will be executed in Story 45 after all manifests are created and deployed.

### Deployment Validation

**1. Verify operator deployment:**
```bash
kubectl --context=infra -n cnpg-system get deployment cloudnative-pg
# Expected: READY 2/2

kubectl --context=infra -n cnpg-system get pods -l app.kubernetes.io/name=cloudnative-pg
# Expected: 2 pods Running on different nodes
```

**2. Check operator logs:**
```bash
kubectl --context=infra -n cnpg-system logs deployment/cloudnative-pg --tail=50
# Expected: Operator started successfully, no errors
```

**3. Verify pod distribution (anti-affinity):**
```bash
kubectl --context=infra -n cnpg-system get pods -l app.kubernetes.io/name=cloudnative-pg -o wide
# Expected: Pods on different nodes
```

### CRD Validation

**1. List CNPG CRDs:**
```bash
kubectl --context=infra api-resources | grep postgresql.cnpg.io
# Expected: clusters, poolers, backups, scheduledbackups, imagecatalogs
```

**2. Check CRD status:**
```bash
kubectl --context=infra get crd clusters.postgresql.cnpg.io -o jsonpath='{.status.conditions[?(@.type=="Established")].status}'
# Expected: True
```

**3. Verify CRD versions:**
```bash
kubectl --context=infra get crd clusters.postgresql.cnpg.io -o jsonpath='{.spec.versions[*].name}'
# Expected: v1
```

### Webhook Validation

**1. Check webhook service:**
```bash
kubectl --context=infra -n cnpg-system get svc cloudnative-pg-webhook-service
# Expected: Service exists
```

**2. Verify webhook configurations:**
```bash
kubectl --context=infra get validatingwebhookconfigurations | grep cnpg
kubectl --context=infra get mutatingwebhookconfigurations | grep cnpg
# Expected: Webhook configurations present
```

**3. Test webhook admission (dry-run):**
```bash
cat <<EOF | kubectl --context=infra --dry-run=server -f - create
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: test-cluster
  namespace: cnpg-system
spec:
  instances: 3
  storage:
    size: 1Gi
EOF

# Expected: Admission successful (no errors)
```

### PSA Validation

**1. Verify namespace PSA labels:**
```bash
kubectl --context=infra get namespace cnpg-system -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}'
# Expected: restricted
```

**2. Confirm operator pods comply:**
```bash
kubectl --context=infra -n cnpg-system get pods -l app.kubernetes.io/name=cloudnative-pg -o jsonpath='{.items[*].spec.securityContext}'
# Expected: runAsNonRoot=true, no privileged containers
```

**3. Test privileged pod denial (negative test):**
```bash
cat <<EOF | kubectl --context=infra -n cnpg-system create -f -
apiVersion: v1
kind: Pod
metadata:
  name: test-privileged
spec:
  containers:
  - name: test
    image: busybox
    securityContext:
      privileged: true
EOF

# Expected: Admission denied due to PSA restricted
```

### PDB Validation

**1. Verify PDB exists:**
```bash
kubectl --context=infra -n cnpg-system get pdb cloudnative-pg
# Expected: PDB with minAvailable=1
```

**2. Check PDB status:**
```bash
kubectl --context=infra -n cnpg-system get pdb cloudnative-pg -o jsonpath='{.status}'
# Expected: currentHealthy=2, desiredHealthy=1
```

**3. Test disruption protection (simulation):**
```bash
# Attempt to drain node with operator pod
NODE=$(kubectl --context=infra -n cnpg-system get pods -l app.kubernetes.io/name=cloudnative-pg -o jsonpath='{.items[0].spec.nodeName}')

kubectl --context=infra drain $NODE --ignore-daemonsets --dry-run=server
# Expected: PDB allows eviction (1 pod remains)
```

### Metrics Validation

**1. Verify PodMonitor:**
```bash
kubectl --context=infra -n cnpg-system get vmpodmonitor cloudnative-pg-metrics
# Expected: PodMonitor exists
```

**2. Check metrics endpoint:**
```bash
kubectl --context=infra -n cnpg-system port-forward deployment/cloudnative-pg 8080:8080 &
curl -s http://127.0.0.1:8080/metrics | grep cnpg
# Expected: CNPG metrics exposed
```

**3. Query metrics in VictoriaMetrics:**
```bash
kubectl --context=infra -n observability port-forward svc/vmselect-victoria-metrics-global-vmcluster 8481:8481 &

curl -s 'http://127.0.0.1:8481/select/0/prometheus/api/v1/query?query=up{job="cnpg-system/cloudnative-pg-metrics"}' | jq
# Expected: up=1 for operator pods
```

**4. Verify operator-specific metrics:**
```bash
curl -s 'http://127.0.0.1:8481/select/0/prometheus/api/v1/query?query=cnpg_collector_up' | jq
# Expected: Operator collector metrics present
```

### Alert Validation

**1. Verify PrometheusRule:**
```bash
kubectl --context=infra -n cnpg-system get vmrule cloudnative-pg-operator
# Expected: VMRule exists
```

**2. Check rule loading in vmalert:**
```bash
kubectl --context=infra -n observability logs deployment/vmalert-victoria-metrics-global | grep "cloudnativepg.operator"
# Expected: Rules loaded successfully
```

**3. Test alert firing (simulate operator down):**
```bash
# Scale operator to 0
kubectl --context=infra -n cnpg-system scale deployment cloudnative-pg --replicas=0

# Wait 5 minutes, check vmalert
sleep 300
kubectl --context=infra -n observability port-forward svc/vmalert-victoria-metrics-global 8880:8880 &
curl -s http://127.0.0.1:8880/api/v1/alerts | jq '.data.alerts[] | select(.name=="CNPGOperatorDown")'

# Expected: CNPGOperatorDown alert firing

# Scale back up
kubectl --context=infra -n cnpg-system scale deployment cloudnative-pg --replicas=2
```

### Version Alignment Validation

**1. Check CRD version:**
```bash
kubectl --context=infra get crd clusters.postgresql.cnpg.io -o jsonpath='{.metadata.annotations.app\.kubernetes\.io/version}'
# Expected: 0.26.x
```

**2. Check operator version:**
```bash
kubectl --context=infra -n cnpg-system get deployment cloudnative-pg -o jsonpath='{.spec.template.spec.containers[0].image}'
# Expected: Image tag matching 0.26.x
```

**3. Verify Helm chart version:**
```bash
kubectl --context=infra -n cnpg-system get helmrelease cloudnative-pg -o jsonpath='{.spec.chart.spec.version}'
# Expected: 0.26.0
```

### Watch Scope Validation

**1. Verify cluster-wide configuration:**
```bash
kubectl --context=infra -n cnpg-system logs deployment/cloudnative-pg | grep -i "watch"
# Expected: Logs showing cluster-wide watch scope
```

**2. Test reconciliation in different namespace:**
```bash
# Create test namespace
kubectl --context=infra create namespace cnpg-test

# Create test cluster
cat <<EOF | kubectl --context=infra -n cnpg-test apply -f -
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: test-cluster
spec:
  instances: 1
  storage:
    size: 1Gi
    storageClass: ${BLOCK_SC}
EOF

# Check operator logs for reconciliation
kubectl --context=infra -n cnpg-system logs deployment/cloudnative-pg | grep "test-cluster"
# Expected: Operator reconciling cluster in cnpg-test namespace

# Cleanup
kubectl --context=infra -n cnpg-test delete cluster test-cluster
kubectl --context=infra delete namespace cnpg-test
```

### High Availability Validation

**1. Test operator failover:**
```bash
# Delete one operator pod
POD=$(kubectl --context=infra -n cnpg-system get pods -l app.kubernetes.io/name=cloudnative-pg -o jsonpath='{.items[0].metadata.name}')
kubectl --context=infra -n cnpg-system delete pod $POD

# Check that operations continue
kubectl --context=infra -n cnpg-system get pods -l app.kubernetes.io/name=cloudnative-pg
# Expected: New pod created, 2 pods Running

# Verify webhook still works
cat <<EOF | kubectl --context=infra --dry-run=server -f - create
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: test-failover
  namespace: cnpg-system
spec:
  instances: 1
  storage:
    size: 1Gi
EOF
# Expected: Webhook admission successful
```

**2. Verify leader election:**
```bash
kubectl --context=infra -n cnpg-system logs deployment/cloudnative-pg | grep -i "leader"
# Expected: Leader election messages
```

## Definition of Done

### Manifest Creation Complete (This Story)

- [x] Namespace created with PSA restricted labels
- [x] CNPG operator HelmRelease created with HA configuration (2 replicas)
- [x] PodDisruptionBudget created for operator availability
- [x] PodMonitor created for metrics collection
- [x] PrometheusRule created for operator health alerts
- [x] Flux Kustomization created with CRD health checks
- [x] CRD bootstrap configuration aligned (0.26.0)
- [x] Cluster settings updated with CNPG variables
- [x] All manifests validate successfully using local tools (flux build, kubectl --dry-run)
- [x] Manifests committed to git repository
- [x] Documentation complete with version alignment and configuration details

### NOT Part of DoD (Moved to Story 45)

**Deployment Validation:**
- CNPG operator Deployment Available with 2 replicas
- Operator pods Running on different nodes (anti-affinity)
- Operator logs showing successful startup

**CRD Validation:**
- CRDs registered and Established (Cluster, Pooler, Backup, etc.)
- CRD versions matching 0.26.x

**Webhook Validation:**
- Webhook service accessible
- ValidatingWebhookConfiguration and MutatingWebhookConfiguration present
- Dry-run Cluster CR admission successful

**PSA Validation:**
- Namespace PSA labels set to restricted
- Operator pods complying with restricted policy
- Privileged pods denied

**PDB Validation:**
- PDB present with minAvailable=1
- PDB protecting against unsafe evictions

**Metrics Validation:**
- PodMonitor scraping metrics successfully
- VictoriaMetrics showing up{job="cnpg-system/cloudnative-pg-metrics"}=1
- Operator-specific metrics (cnpg_collector_up) present

**Alert Validation:**
- PrometheusRule loaded in vmalert
- Test alert firing when operator scaled down

**Version Alignment Validation:**
- CRD version 0.26.x
- Operator image version 0.26.x
- Helm chart version 0.26.0

**Watch Scope Validation:**
- Cluster-wide watch enabled
- Operator reconciling Clusters in any namespace

**HA Validation:**
- Operator failover working (pod deletion recovery)
- Leader election functioning

## Design Notes

### CloudNativePG Operator Architecture

**Core Components:**
- **Operator Controller**: Reconciles Cluster, Pooler, Backup CRs
- **Webhook Server**: Validates and mutates CNPG resources
- **Metrics Exporter**: Exposes operator and PostgreSQL metrics
- **Leader Election**: Ensures single active controller

**Supported CRDs:**
- `Cluster`: PostgreSQL cluster configuration
- `Pooler`: PgBouncer connection pooler
- `Backup`: On-demand backup
- `ScheduledBackup`: Scheduled backup configuration
- `ImageCatalog`: Container image management

### High Availability Configuration

**Operator Replicas:**
- 2 replicas for HA (active-standby via leader election)
- Leader election ensures single active controller
- Standby ready for immediate failover

**PodDisruptionBudget:**
- minAvailable: 1 (ensures at least 1 replica during disruptions)
- Protects against unsafe evictions during node maintenance
- Allows rolling updates without service interruption

**Anti-Affinity:**
- preferredDuringSchedulingIgnoredDuringExecution (soft constraint)
- Distributes pods across nodes for better availability
- Falls back to same node if resources constrained

### Pod Security Admission

**Restricted Level:**
- No privileged containers
- runAsNonRoot: true
- readOnlyRootFilesystem: true
- No host namespaces (network, PID, IPC)
- Capabilities dropped (ALL)

**CNPG Compatibility:**
- Operator explicitly designed to run without privileged mode
- PostgreSQL pods also compatible with restricted PSA
- No host path volumes required

### Version Alignment Strategy

**Why Alignment Matters:**
- CRDs define API schema; operator implements reconciliation logic
- Version skew can cause webhook validation failures
- Minor version alignment ensures compatibility

**Chosen Version: 0.26.x**
- CRD bundle: 0.26.0 (bootstrap/helmfile.d/00-crds.yaml)
- Operator chart: 0.26.0 (HelmRelease)
- Operator app version: 1.27.0 (bundled with chart)
- Released: 2025-08-12

**Upgrade Path:**
- Patch updates within 0.26.x are safe (e.g., 0.26.0 → 0.26.1)
- Minor updates require CRD upgrade first, then operator
- Always test in non-production environment first

### Watch Scope Configuration

**Cluster-Wide (Chosen):**
- Operator watches all namespaces
- Suitable for shared infrastructure pattern
- Single operator manages all PostgreSQL clusters
- Simplifies multi-tenant deployments

**Namespace-Scoped (Alternative):**
- Operator watches specific namespace(s)
- Provides stronger isolation
- Requires multiple operator instances for multi-tenancy
- More complex RBAC and resource management

**Configuration:**
- `config.clusterWide: true` in Helm values
- Replaces legacy `WATCH_NAMESPACE=""` environment variable
- Verified via operator logs and reconciliation behavior

### Monitoring Integration

**Metrics Exposed:**
- Operator health (up, restarts, errors)
- Webhook admission (requests, errors, latency)
- Controller reconciliation (loops, errors, duration)
- PostgreSQL cluster metrics (delegated to Cluster pods)

**PodMonitor Configuration:**
- Scrapes operator metrics endpoint (port 8080)
- 30-second interval
- Labels compatible with VictoriaMetrics operator selector

**PrometheusRules:**
- CNPGOperatorDown: Critical alert if operator unavailable
- CNPGOperatorHighRestarts: Warning if operator restarting frequently
- CNPGWebhookErrors: Warning if webhook experiencing errors
- CNPGReconciliationErrors: Warning if reconciliation failures
- CNPGOperatorNotHighlyAvailable: Warning if < 2 replicas

### Resource Planning

**Per-Replica Resources:**
- CPU: 100m request, 500m limit
- Memory: 128Mi request, 512Mi limit
- Typical usage: ~50m CPU, ~100Mi memory

**Total Operator:**
- 2 replicas: 200m-1000m CPU, 256Mi-1Gi memory
- Minimal overhead compared to PostgreSQL clusters
- Scales well with number of managed clusters

### Security Considerations

**Operator Permissions:**
- ClusterRole with permissions for Cluster, Pooler, Backup CRDs
- Access to Secrets, ConfigMaps (for PostgreSQL credentials)
- Access to Pods, PVCs, Services (for cluster management)
- Webhook admission control

**Secret Management:**
- Operator creates PostgreSQL user credentials automatically
- Stores credentials in Kubernetes Secrets
- Integration with External Secrets (Story 05) for backup credentials

**Network Policies:**
- Allow webhook traffic from Kubernetes API server
- Allow metrics scraping from VictoriaMetrics
- Restrict egress to Kubernetes API only

### Webhook Behavior

**Validating Webhook:**
- Validates Cluster, Pooler, Backup CRs before admission
- Ensures required fields present
- Checks resource compatibility (e.g., storage class exists)
- failurePolicy: Fail (rejects if webhook unavailable)

**Mutating Webhook:**
- Sets default values for optional fields
- Injects labels and annotations
- Configures resource requirements
- failurePolicy: Fail (safer than allowing unvalidated resources)

### Upgrade Considerations

**CRD Upgrades:**
- Must upgrade CRDs before operator (new CRDs backward compatible)
- Use `kubectl apply` or helmfile for CRD updates
- Verify CRD Established status before operator upgrade

**Operator Upgrades:**
- HelmRelease automatically handles rolling updates
- PDB ensures at least 1 replica available during upgrade
- Webhook remains available throughout (HA configuration)
- Test dry-run admissions after upgrade

**Rollback:**
- Helm rollback supported
- CRD downgrades not supported (forward-only)
- Keep backups of CRD manifests before upgrades

## Change Log

### v3.0 (2025-10-26) - Manifests-First Refinement

**Scope Split:**
- This story now focuses exclusively on **creating CloudNativePG operator manifests**
- Deployment and validation moved to Story 45

**Key Changes:**
1. Rewrote story to focus on manifest creation, not deployment
2. Split Acceptance Criteria: manifest creation vs deployment validation
3. Restructured tasks to T1-T12 pattern with local validation only
4. Added comprehensive runtime validation section (deferred to Story 45)
5. Updated DoD with clear "NOT Part of DoD" section
6. Added detailed design notes covering:
   - CloudNativePG operator architecture and CRDs
   - High availability with 2 replicas and PDB
   - Pod Security Admission restricted enforcement
   - Version alignment strategy (CRDs and operator 0.26.x)
   - Watch scope configuration (cluster-wide)
   - Monitoring integration with VictoriaMetrics
   - Resource planning and security considerations
   - Webhook behavior and failurePolicy
   - Upgrade path and rollback considerations
7. Specified exact manifests: Namespace, HelmRelease, PDB, PodMonitor, PrometheusRule, Flux Kustomization
8. Included PSA restricted configuration (no privileged mode)
9. Dependencies updated to local tools only (kubectl, flux CLI, yq, kubeconform)

**Manifest Architecture:**
- **Namespace**: cnpg-system with PSA restricted labels
- **Operator**: 2 replicas with leader election, anti-affinity, security context
- **PDB**: minAvailable=1 for HA protection
- **PodMonitor**: Metrics collection for VictoriaMetrics
- **PrometheusRule**: Operator health, webhook, and reconciliation alerts
- **CRDs**: Version 0.26.0 aligned with operator chart

**Configuration Highlights:**
- High availability: 2 replicas with PodDisruptionBudget
- Security: PSA restricted, runAsNonRoot, readOnlyRootFilesystem
- Monitoring: PodMonitor with 30s interval, 5 alert rules
- Watch scope: Cluster-wide (config.clusterWide: true)
- Version alignment: CRDs and operator both 0.26.0
- Resources: 100m CPU request, 128Mi memory request per replica

**Previous Version:** Story focused on deployment with cluster access required, mixing operator installation with configuration hardening
**Current Version:** Story focuses on manifest creation with local validation only, clear separation from deployment
