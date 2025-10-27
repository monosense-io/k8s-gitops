# 18 — STORY-OBS-VICTORIA-LOGS — Create VictoriaLogs Manifests

Sequence: 18/50 | Prev: STORY-OBS-VM-STACK.md | Next: STORY-OBS-FLUENT-BIT.md
Sprint: 3 | Lane: Observability
Global Sequence: 18/50

Status: Draft (v3.0 Refinement)
Owner: Platform Engineering
Date: 2025-10-26
Links: kubernetes/infrastructure/observability/victoria-logs; kubernetes/components/networkpolicy/monitoring

## Story

As a platform engineer, I want to **create VictoriaLogs manifests** for centralized log storage, so that when deployed in Story 45, I have:
- VictoriaLogs cluster on infra (vmselect/vminsert/vmstorage) for durable log storage
- vmauth for authenticated log ingestion and querying
- Integration with Grafana for log visualization
- ServiceMonitors for log component health

## Why / Outcome

- Durable, scalable log storage integrated with VictoriaMetrics and Grafana
- Centralized log aggregation across all clusters
- Long-term log retention for compliance and troubleshooting
- Unified observability platform (metrics + logs)

## Scope

### This Story (Manifest Creation)

Create the following VictoriaLogs manifests:

**Infra Cluster:**
- HelmRelease for victoria-logs with vmselect, vminsert, vmstorage components
- vmauth configuration for log ingestion and querying
- Storage configuration with retention and volume sizing
- NetworkPolicy for component communication and Fluent Bit ingestion
- PodDisruptionBudgets for HA protection
- ServiceMonitors for component health
- Flux Kustomization with health checks

**Configuration:**
- Multi-tenancy support via `X-Scope-OrgID` header
- Retention period configuration
- Storage class and volume sizing
- Resource limits and requests

### Deferred to Story 45 (Deployment & Validation)

- Deploy VictoriaLogs to infra cluster via Flux
- Verify pod readiness (vmselect/vminsert/vmstorage)
- Test log ingestion via HTTP POST
- Validate log retention and storage
- Configure Grafana Loki datasource pointing to VictoriaLogs
- Verify log queries from Grafana

## Acceptance Criteria

### Manifest Creation (This Story)

1. **VictoriaLogs HelmRelease Created:**
   - vmselect (3 replicas) for query execution
   - vminsert (3 replicas) for log ingestion
   - vmstorage (3 replicas) for log storage
   - Retention period set to `${OBSERVABILITY_LOGS_RETENTION}`
   - Storage class set to `${BLOCK_SC}` with volume sizing

2. **vmauth Configuration Created:**
   - Write endpoint: `/insert` → vminsert service
   - Read endpoint: `/select` → vmselect service
   - Multi-tenancy enabled via headers
   - Internal Service only (no public ingress)

3. **Storage Configuration Created:**
   - vmstorage PVCs with `${OBSERVABILITY_LOGS_STORAGE_SIZE}` per replica
   - Volume binding mode: Immediate
   - Reclaim policy: Delete

4. **NetworkPolicy Manifests Created:**
   - Allow Fluent Bit → vminsert (log ingestion)
   - Allow vmselect ↔ vmstorage (query execution)
   - Allow vminsert → vmstorage (log write)
   - Allow Grafana → vmauth (log queries)

5. **PodDisruptionBudget Manifests Created:**
   - PDBs for vmselect (maxUnavailable: 1)
   - PDBs for vminsert (maxUnavailable: 1)
   - PDBs for vmstorage (maxUnavailable: 1)

6. **ServiceMonitor Manifests Created:**
   - Scrape endpoints for vmselect, vminsert, vmstorage
   - Metrics exposed for VictoriaMetrics collection

7. **Flux Kustomization Created:**
   - Health checks for vmselect, vminsert, vmstorage deployments/statefulsets
   - Dependency on storage (Rook-Ceph)
   - Variable substitution from cluster-settings

### Deferred to Story 45 (Deployment & Validation)

- VictoriaLogs pods Running with correct replica counts
- vmauth Service accessible internally
- Log ingestion endpoint accepting HTTP POST
- Logs queryable via vmselect
- Grafana Loki datasource configured and working
- ServiceMonitors scraping metrics successfully
- Storage volumes created and bound

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
# VictoriaLogs Configuration
OBSERVABILITY_LOGS_RETENTION: "14d"
OBSERVABILITY_LOGS_STORAGE_SIZE: "100Gi"
OBSERVABILITY_LOG_ENDPOINT_HOST: "vmauth-victoria-logs.observability.svc.cluster.local"
OBSERVABILITY_LOG_ENDPOINT_PORT: "8427"
OBSERVABILITY_LOG_ENDPOINT_PATH: "/insert/jsonline"
OBSERVABILITY_LOG_TENANT: "default"
BLOCK_SC: "ceph-block"
```

## Tasks / Subtasks — Implementation Plan (Story Only)

### T1: Verify Prerequisites

**Steps:**
1. Review VictoriaLogs architecture and components
2. Plan storage requirements (100Gi per vmstorage replica = 300Gi total)
3. Review integration with Fluent Bit (Story 19)
4. Review Grafana Loki datasource compatibility

**Acceptance:** Prerequisites documented, architecture clear

### T2: Create VictoriaLogs HelmRelease Manifest

**Location:** `kubernetes/infrastructure/observability/victoria-logs/`

**Create HelmRelease** (`helmrelease.yaml`):
```yaml
---
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: victoria-logs
  namespace: observability
spec:
  chartRef:
    kind: OCIRepository
    name: victoria-logs-single
    namespace: flux-system
  interval: 1h
  timeout: 15m
  install:
    remediation:
      retries: 3
  upgrade:
    remediation:
      retries: 3
  values:
    fullnameOverride: victoria-logs

    # VictoriaLogs single-node deployment
    # (Clustered mode requires enterprise; use single with replicas)
    server:
      enabled: true
      replicaCount: 3

      # Data retention
      retentionPeriod: ${OBSERVABILITY_LOGS_RETENTION}

      # Storage configuration
      persistentVolume:
        enabled: true
        storageClass: ${BLOCK_SC}
        accessModes:
          - ReadWriteOnce
        size: ${OBSERVABILITY_LOGS_STORAGE_SIZE}

      # Resource limits
      resources:
        limits:
          cpu: 2
          memory: 4Gi
        requests:
          cpu: 500m
          memory: 2Gi

      # Service configuration
      service:
        type: ClusterIP
        port: 9428
        annotations:
          prometheus.io/scrape: "true"
          prometheus.io/port: "9428"

      # Extra arguments for multi-tenancy
      extraArgs:
        - -loggerFormat=json
        - -loggerLevel=INFO
        - -retentionPeriod=${OBSERVABILITY_LOGS_RETENTION}
        - -storageDataPath=/storage
        - -httpListenAddr=:9428

      # Security context
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 1000
        readOnlyRootFilesystem: true

      # Health checks
      livenessProbe:
        httpGet:
          path: /health
          port: 9428
        initialDelaySeconds: 30
        periodSeconds: 10
        timeoutSeconds: 5

      readinessProbe:
        httpGet:
          path: /health
          port: 9428
        initialDelaySeconds: 10
        periodSeconds: 5
        timeoutSeconds: 3

    # ServiceMonitor for metrics
    serviceMonitor:
      enabled: true
      namespace: observability
      interval: 30s
      scrapeTimeout: 10s

    # VMAuth for authentication and routing
    vmauth:
      enabled: true
      replicaCount: 2

      # Authentication config
      config:
        users:
          - username: ""
            url_prefix:
              - http://victoria-logs-server:9428
            unauthorized_user: true

      resources:
        limits:
          cpu: 500m
          memory: 512Mi
        requests:
          cpu: 100m
          memory: 256Mi

      service:
        type: ClusterIP
        port: 8427
```

**Note:** VictoriaLogs single-node mode is used. For true distributed mode (vmselect/vminsert/vmstorage), enterprise license is required. Adjust manifest if using enterprise:

**Alternative Enterprise Manifest** (if available):
```yaml
---
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: victoria-logs
  namespace: observability
spec:
  chartRef:
    kind: OCIRepository
    name: victoria-logs-cluster
    namespace: flux-system
  interval: 1h
  timeout: 15m
  values:
    fullnameOverride: victoria-logs

    # Distributed VictoriaLogs (enterprise)
    vmselect:
      enabled: true
      replicaCount: 3
      resources:
        limits:
          cpu: 1
          memory: 2Gi
        requests:
          cpu: 200m
          memory: 512Mi

    vminsert:
      enabled: true
      replicaCount: 3
      resources:
        limits:
          cpu: 1
          memory: 1Gi
        requests:
          cpu: 200m
          memory: 512Mi

    vmstorage:
      enabled: true
      replicaCount: 3
      retentionPeriod: ${OBSERVABILITY_LOGS_RETENTION}
      persistentVolume:
        enabled: true
        storageClass: ${BLOCK_SC}
        size: ${OBSERVABILITY_LOGS_STORAGE_SIZE}
      resources:
        limits:
          cpu: 2
          memory: 4Gi
        requests:
          cpu: 500m
          memory: 2Gi

    vmauth:
      enabled: true
      replicaCount: 2
```

**Acceptance:** VictoriaLogs HelmRelease created with storage and retention configuration

### T3: Create NetworkPolicy Manifests

**Location:** `kubernetes/infrastructure/observability/victoria-logs/networkpolicy.yaml`

**Create:**

```yaml
---
# Allow Fluent Bit to send logs to vmauth/vminsert
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: victoria-logs-ingress-fluentbit
  namespace: observability
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: victoria-logs
  policyTypes:
    - Ingress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: observability
          podSelector:
            matchLabels:
              app.kubernetes.io/name: fluent-bit
      ports:
        - protocol: TCP
          port: 9428  # VictoriaLogs HTTP
        - protocol: TCP
          port: 8427  # vmauth
---
# Allow vmauth to route to victoria-logs server
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: vmauth-to-victoria-logs
  namespace: observability
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: victoria-logs
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app.kubernetes.io/name: vmauth
              app.kubernetes.io/component: victoria-logs
      ports:
        - protocol: TCP
          port: 9428
---
# Allow Grafana to query logs via vmauth
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: grafana-to-victoria-logs
  namespace: observability
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: vmauth
      app.kubernetes.io/component: victoria-logs
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app.kubernetes.io/name: grafana
      ports:
        - protocol: TCP
          port: 8427
---
# Allow vmagent to scrape metrics from victoria-logs
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: vmagent-to-victoria-logs-metrics
  namespace: observability
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: victoria-logs
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app.kubernetes.io/name: vmagent
      ports:
        - protocol: TCP
          port: 9428
```

**Acceptance:** NetworkPolicies created for log ingestion and querying

### T4: Create PodDisruptionBudget Manifests

**Location:** `kubernetes/infrastructure/observability/victoria-logs/pdb.yaml`

**Create:**

```yaml
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: victoria-logs-server
  namespace: observability
spec:
  maxUnavailable: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: victoria-logs
      app.kubernetes.io/component: server
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: victoria-logs-vmauth
  namespace: observability
spec:
  maxUnavailable: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: vmauth
      app.kubernetes.io/component: victoria-logs
```

**If using enterprise clustered mode, add:**

```yaml
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: victoria-logs-vmselect
  namespace: observability
spec:
  maxUnavailable: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: vmselect
      app.kubernetes.io/instance: victoria-logs
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: victoria-logs-vminsert
  namespace: observability
spec:
  maxUnavailable: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: vminsert
      app.kubernetes.io/instance: victoria-logs
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: victoria-logs-vmstorage
  namespace: observability
spec:
  maxUnavailable: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: vmstorage
      app.kubernetes.io/instance: victoria-logs
```

**Acceptance:** PDBs created for VictoriaLogs components

### T5: Create ServiceMonitor Manifests

**Location:** `kubernetes/infrastructure/observability/victoria-logs/servicemonitor.yaml`

**Create:**

```yaml
---
apiVersion: operator.victoriametrics.com/v1beta1
kind: VMServiceScrape
metadata:
  name: victoria-logs
  namespace: observability
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: victoria-logs
  endpoints:
    - port: http
      interval: 30s
      scrapeTimeout: 10s
      path: /metrics
```

**Acceptance:** ServiceMonitor created for VictoriaLogs metrics

### T6: Create Kustomization Manifest

**Location:** `kubernetes/infrastructure/observability/victoria-logs/kustomization.yaml`

**Create:**

```yaml
---
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: observability
resources:
  - helmrelease.yaml
  - networkpolicy.yaml
  - pdb.yaml
  - servicemonitor.yaml
```

**Acceptance:** Kustomization manifest created

### T7: Create Flux Kustomization Manifest

**Location:** `kubernetes/infrastructure/observability/victoria-logs/ks.yaml`

**Create:**

```yaml
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: observability-victoria-logs
  namespace: flux-system
spec:
  interval: 30m
  timeout: 15m
  sourceRef:
    kind: GitRepository
    name: flux-system
  path: ./kubernetes/infrastructure/observability/victoria-logs
  prune: true
  wait: true
  dependsOn:
    - name: infrastructure-repositories-oci
    - name: infrastructure-storage-rook-ceph-cluster
  postBuild:
    substituteFrom:
      - kind: ConfigMap
        name: cluster-settings
  healthChecks:
    - apiVersion: apps/v1
      kind: StatefulSet
      name: victoria-logs-server
      namespace: observability
    - apiVersion: apps/v1
      kind: Deployment
      name: vmauth-victoria-logs
      namespace: observability
```

**If using enterprise clustered mode:**

```yaml
  healthChecks:
    - apiVersion: apps/v1
      kind: StatefulSet
      name: vmstorage-victoria-logs
      namespace: observability
    - apiVersion: apps/v1
      kind: Deployment
      name: vmselect-victoria-logs
      namespace: observability
    - apiVersion: apps/v1
      kind: Deployment
      name: vminsert-victoria-logs
      namespace: observability
    - apiVersion: apps/v1
      kind: Deployment
      name: vmauth-victoria-logs
      namespace: observability
```

**Acceptance:** Flux Kustomization created with health checks

### T8: Local Validation

**Steps:**

1. **Validate HelmRelease Syntax:**
   ```bash
   kubectl --dry-run=client -f kubernetes/infrastructure/observability/victoria-logs/helmrelease.yaml apply
   ```

2. **Build Kustomization:**
   ```bash
   kustomize build kubernetes/infrastructure/observability/victoria-logs/
   ```

3. **Validate Flux Kustomization:**
   ```bash
   flux build kustomization observability-victoria-logs \
     --path kubernetes/infrastructure/observability/victoria-logs/ \
     --kustomization-file kubernetes/infrastructure/observability/victoria-logs/ks.yaml
   ```

4. **Validate NetworkPolicy Syntax:**
   ```bash
   kubectl --dry-run=client -f kubernetes/infrastructure/observability/victoria-logs/networkpolicy.yaml apply
   ```

5. **Validate PDB Syntax:**
   ```bash
   kubectl --dry-run=client -f kubernetes/infrastructure/observability/victoria-logs/pdb.yaml apply
   ```

6. **Validate ServiceMonitor:**
   ```bash
   kubectl --dry-run=client -f kubernetes/infrastructure/observability/victoria-logs/servicemonitor.yaml apply
   ```

7. **Schema Validation (if kubeconform available):**
   ```bash
   kubeconform -strict kubernetes/infrastructure/observability/victoria-logs/
   ```

**Acceptance:** All manifests validate successfully with no errors

### T9: Update Observability Infrastructure Kustomization

**Location:** Update `kubernetes/infrastructure/observability/kustomization.yaml` if needed to include victoria-logs subdirectory

**Acceptance:** Infrastructure kustomization references victoria-logs

### T10: Update Cluster Settings

**Infra Cluster** (`kubernetes/clusters/infra/cluster-settings.yaml`):

**Add:**
```yaml
  # VictoriaLogs Configuration
  OBSERVABILITY_LOGS_RETENTION: "14d"
  OBSERVABILITY_LOGS_STORAGE_SIZE: "100Gi"
  OBSERVABILITY_LOG_ENDPOINT_HOST: "vmauth-victoria-logs.observability.svc.cluster.local"
  OBSERVABILITY_LOG_ENDPOINT_PORT: "8427"
  OBSERVABILITY_LOG_ENDPOINT_PATH: "/insert/jsonline"
  OBSERVABILITY_LOG_TENANT: "default"
```

**Acceptance:** Cluster settings updated with VictoriaLogs configuration

### T11: Commit to Git

**Steps:**
1. Stage all created manifests
2. Commit with message:
   ```
   feat(observability): add VictoriaLogs manifests

   - VictoriaLogs server with 14-day retention
   - vmauth for log ingestion and querying
   - NetworkPolicies for Fluent Bit ingestion and Grafana queries
   - PodDisruptionBudgets for HA protection
   - ServiceMonitors for health metrics
   - Flux Kustomization with health checks

   Story: STORY-OBS-VICTORIA-LOGS
   ```

**Acceptance:** All manifests committed to git

## Runtime Validation (MOVED TO STORY 45)

**IMPORTANT:** The following validation steps are **NOT** part of this story. They will be executed in Story 45 after all manifests are created and deployed.

### Deployment Validation

**1. Verify VictoriaLogs pods:**
```bash
kubectl --context=infra -n observability get statefulset victoria-logs-server
# Expected: READY 3/3

kubectl --context=infra -n observability get pods -l app.kubernetes.io/name=victoria-logs
# Expected: 3 pods Running
```

**2. Verify vmauth:**
```bash
kubectl --context=infra -n observability get deploy vmauth-victoria-logs
# Expected: READY 2/2
```

**3. Check storage volumes:**
```bash
kubectl --context=infra -n observability get pvc -l app.kubernetes.io/name=victoria-logs
# Expected: 3 PVCs Bound (100Gi each)
```

### Ingestion Validation

**1. Test log ingestion endpoint:**
```bash
kubectl --context=infra -n observability port-forward svc/vmauth-victoria-logs 8427:8427 &

# Send test log
curl -X POST http://127.0.0.1:8427/insert/jsonline \
  -H "Content-Type: application/json" \
  -H "X-Scope-OrgID: default" \
  -d '{"_msg":"Test log message","level":"info","app":"test"}'

# Expected: 200 OK response
```

**2. Verify log ingestion via direct server:**
```bash
kubectl --context=infra -n observability port-forward svc/victoria-logs-server 9428:9428 &

curl -X POST http://127.0.0.1:9428/insert/jsonline \
  -H "Content-Type: application/json" \
  -d '{"_msg":"Direct test log","level":"debug","source":"manual"}'
```

### Query Validation

**1. Query logs via vmauth:**
```bash
# Query recent logs
curl -s "http://127.0.0.1:8427/select/logsql/query" \
  -H "X-Scope-OrgID: default" \
  -d "query=*" \
  -d "limit=10" | jq

# Expected: JSON response with log entries
```

**2. Query specific logs:**
```bash
curl -s "http://127.0.0.1:8427/select/logsql/query" \
  -H "X-Scope-OrgID: default" \
  -d "query=level:info" \
  -d "limit=5" | jq

# Expected: Filtered log entries
```

**3. Test time-range queries:**
```bash
curl -s "http://127.0.0.1:8427/select/logsql/query" \
  -H "X-Scope-OrgID: default" \
  -d "query=*" \
  -d "start=$(date -u -d '1 hour ago' +%s)000000000" \
  -d "end=$(date -u +%s)000000000" | jq
```

### Health Check Validation

**1. Check VictoriaLogs health:**
```bash
kubectl --context=infra -n observability port-forward svc/victoria-logs-server 9428:9428 &
curl -sf http://127.0.0.1:9428/health
# Expected: "OK"
```

**2. Check vmauth health:**
```bash
kubectl --context=infra -n observability port-forward svc/vmauth-victoria-logs 8427:8427 &
curl -sf http://127.0.0.1:8427/health
# Expected: "OK" or 200 status
```

### Metrics Validation

**1. Verify ServiceMonitor scraping:**
```bash
kubectl --context=infra -n observability get vmservicescrape victoria-logs
# Expected: ServiceScrape exists

# Check metrics endpoint
curl -s http://127.0.0.1:9428/metrics | grep victoria_logs
# Expected: VictoriaLogs metrics
```

**2. Query VictoriaLogs metrics in VictoriaMetrics:**
```bash
# Port-forward to vmselect from Story 17
kubectl --context=infra -n observability port-forward svc/vmselect-victoria-metrics-global-vmcluster 8481:8481 &

curl -s 'http://127.0.0.1:8481/select/0/prometheus/api/v1/query?query=up{job="victoria-logs"}' | jq
# Expected: up=1 for victoria-logs instances
```

### Grafana Integration Validation

**1. Configure Loki datasource in Grafana:**

Navigate to Grafana → Configuration → Data Sources → Add data source → Loki

**Configuration:**
- Name: VictoriaLogs
- URL: `http://vmauth-victoria-logs.observability.svc.cluster.local:8427`
- Custom HTTP Headers:
  - Header: `X-Scope-OrgID`
  - Value: `default`

**2. Test Loki datasource:**
```bash
# In Grafana, run LogQL query:
{job="fluent-bit"}

# Expected: Log entries displayed
```

**3. Create test dashboard:**
- Add Logs panel
- Select VictoriaLogs datasource
- Query: `{level="error"}`
- Expected: Error logs displayed

### Storage and Retention Validation

**1. Check storage usage:**
```bash
kubectl --context=infra -n observability exec -it victoria-logs-server-0 -- df -h /storage
# Expected: Storage mounted and available
```

**2. Verify retention period:**
```bash
kubectl --context=infra -n observability logs victoria-logs-server-0 | grep retention
# Expected: Log showing 14d retention period
```

**3. Test retention enforcement:**
```bash
# Insert old log (15 days ago)
OLD_TIMESTAMP=$(date -u -d '15 days ago' +%s)000000000

curl -X POST http://127.0.0.1:9428/insert/jsonline \
  -H "Content-Type: application/json" \
  -d "{\"_msg\":\"Old log\",\"_time\":\"$OLD_TIMESTAMP\"}"

# Query for old log after retention period passes
# Expected: Log should be deleted after 14 days
```

### Multi-Tenancy Validation

**1. Test different tenants:**
```bash
# Insert log for tenant "app1"
curl -X POST http://127.0.0.1:8427/insert/jsonline \
  -H "Content-Type: application/json" \
  -H "X-Scope-OrgID: app1" \
  -d '{"_msg":"App1 log","app":"app1"}'

# Insert log for tenant "app2"
curl -X POST http://127.0.0.1:8427/insert/jsonline \
  -H "Content-Type: application/json" \
  -H "X-Scope-OrgID: app2" \
  -d '{"_msg":"App2 log","app":"app2"}'

# Query app1 tenant
curl -s "http://127.0.0.1:8427/select/logsql/query" \
  -H "X-Scope-OrgID: app1" \
  -d "query=*" | jq

# Expected: Only app1 logs visible
```

### Performance Validation

**1. Test bulk ingestion:**
```bash
# Generate 1000 log entries
for i in {1..1000}; do
  echo "{\"_msg\":\"Bulk test log $i\",\"index\":$i}"
done > /tmp/bulk_logs.json

# Send bulk logs
curl -X POST http://127.0.0.1:9428/insert/jsonline \
  -H "Content-Type: application/json" \
  --data-binary @/tmp/bulk_logs.json

# Expected: All logs ingested successfully
```

**2. Query performance:**
```bash
time curl -s "http://127.0.0.1:8427/select/logsql/query" \
  -H "X-Scope-OrgID: default" \
  -d "query=*" \
  -d "limit=1000" | jq > /dev/null

# Expected: Query completes in < 2s
```

### NetworkPolicy Validation

**1. Verify Fluent Bit can send logs:**
```bash
# From Story 19, after Fluent Bit is deployed
kubectl --context=infra -n observability logs -l app.kubernetes.io/name=fluent-bit | grep -i "victoria-logs"
# Expected: Successful log forwarding
```

**2. Verify Grafana can query:**
```bash
# Test from Grafana pod
kubectl --context=infra -n observability exec -it deploy/victoria-metrics-global-grafana -- \
  curl -s http://vmauth-victoria-logs.observability.svc.cluster.local:8427/health

# Expected: "OK"
```

## Definition of Done

### Manifest Creation Complete (This Story)

- [x] VictoriaLogs HelmRelease created with server/vmauth configuration
- [x] Storage configured with 14-day retention and 100Gi per replica
- [x] NetworkPolicy manifests created for log ingestion and querying
- [x] PodDisruptionBudget manifests created for HA protection
- [x] ServiceMonitor manifests created for metrics collection
- [x] Flux Kustomization created with health checks and dependencies
- [x] Cluster settings updated with VictoriaLogs endpoints
- [x] All manifests validate successfully using local tools (flux build, kubectl --dry-run)
- [x] Manifests committed to git repository
- [x] Documentation complete with integration and query examples

### NOT Part of DoD (Moved to Story 45)

**Deployment Validation:**
- VictoriaLogs pods Running (3 replicas)
- vmauth Deployment Available (2 replicas)
- Storage PVCs Bound (300Gi total)
- Health endpoints responding with OK

**Ingestion Validation:**
- Log ingestion endpoint accepting HTTP POST
- Multi-tenancy working via X-Scope-OrgID header
- Bulk log ingestion successful

**Query Validation:**
- Logs queryable via vmauth
- Time-range queries working
- LogQL-compatible queries successful
- Grafana Loki datasource configured and working

**Performance Validation:**
- Bulk ingestion rate > 10k logs/s
- Query latency < 2s for 1000 results
- Storage usage tracking correctly

**Integration Validation:**
- ServiceMonitors scraping metrics
- VictoriaMetrics collecting VictoriaLogs metrics
- Grafana dashboards displaying logs
- NetworkPolicies allowing required traffic only

## Design Notes

### VictoriaLogs Architecture

**Single-Node Mode (Community):**
- Single VictoriaLogs server pod (can be scaled horizontally)
- Built-in HTTP API for ingestion and querying
- Simpler deployment, suitable for most use cases
- Horizontal scaling via multiple replicas (eventual consistency)

**Clustered Mode (Enterprise):**
- vmselect: Query execution engine
- vminsert: Log ingestion endpoint
- vmstorage: Distributed log storage
- Requires VictoriaMetrics enterprise license

**This Story Uses:** Single-node mode with 3 replicas for HA

### Log Ingestion

**Supported Formats:**
- JSON Lines (recommended): `{"_msg":"log message","field":"value"}`
- Logfmt: `level=info msg="log message"`
- Plain text: Single line per log

**HTTP Endpoints:**
- `/insert/jsonline` - JSON Lines format
- `/insert/logfmt` - Logfmt format
- `/insert` - Auto-detect format

**Special Fields:**
- `_msg`: Log message (required)
- `_time`: Timestamp (optional, defaults to ingestion time)
- `_stream`: Stream identifier (optional)

### Multi-Tenancy

**Tenant Isolation:**
- Tenants separated via `X-Scope-OrgID` HTTP header
- Each tenant has isolated log storage
- Queries only return logs for specified tenant

**Tenant Configuration:**
- No pre-configuration required
- Tenants created automatically on first log ingestion
- Default tenant: `default`

### Log Querying

**Query Formats:**
- LogQL (Loki-compatible): `{app="myapp",level="error"}`
- VictoriaLogs query language: More powerful filtering

**Query Endpoints:**
- `/select/logsql/query` - LogQL queries
- `/select/logsql/field_names` - List available fields
- `/select/logsql/field_values` - List field values

**Time Range:**
- `start`: Start timestamp (nanoseconds)
- `end`: End timestamp (nanoseconds)
- Defaults to last 5 minutes if not specified

### Storage and Retention

**Storage Configuration:**
- Each replica stores full copy of logs (no sharding in single-node mode)
- 100Gi per replica = 300Gi total for 3 replicas
- 14-day retention = ~20GB of logs per day (assuming 1MB/s ingestion rate)

**Retention Enforcement:**
- Automatic deletion of logs older than retention period
- Runs periodically (every hour)
- Based on `_time` field in logs

### Grafana Integration

**Loki Datasource Compatibility:**
- VictoriaLogs supports Loki's HTTP API
- Use Loki datasource type in Grafana
- Set custom header `X-Scope-OrgID` for tenant selection

**Dashboard Examples:**
- Logs panel with LogQL queries
- Log volume graph
- Log rate metrics
- Error rate tracking

### Resource Planning

**Per-Replica Resources:**
- CPU: 500m request, 2 limit
- Memory: 2Gi request, 4Gi limit
- Storage: 100Gi

**Total Infra Cluster:**
- 3 VictoriaLogs replicas: 1.5-6 CPU cores, 6-12Gi memory, 300Gi storage
- 2 vmauth replicas: 0.2-1 CPU cores, 0.5-1Gi memory

**Ingestion Capacity:**
- Single-node mode: ~10-50k logs/s per replica (depends on log size)
- 3 replicas: ~30-150k logs/s total

### Security Considerations

**NetworkPolicies:**
- Fluent Bit can send logs (port 8427 via vmauth)
- Grafana can query logs (port 8427 via vmauth)
- vmagent can scrape metrics (port 9428)
- No external ingress by default

**Authentication:**
- vmauth provides basic routing (no auth in this config)
- Can add auth headers for production
- Multi-tenancy via X-Scope-OrgID header

**Data Isolation:**
- Logs isolated by tenant
- No cross-tenant queries possible
- PVCs encrypted at rest (if storage class supports)

### High Availability

**Replication:**
- 3 VictoriaLogs replicas (each stores full copy)
- No automatic log replication between replicas
- Clients should round-robin or load-balance across replicas

**PodDisruptionBudgets:**
- maxUnavailable: 1 for all components
- Ensures at least 2 replicas available during updates

**Recovery:**
- If replica fails, logs stored on PVC persist
- Replica restarts and continues serving from PVC
- No data loss as long as PVC survives

## Change Log

### v3.0 (2025-10-26) - Manifests-First Refinement

**Scope Split:**
- This story now focuses exclusively on **creating VictoriaLogs manifests**
- Deployment and validation moved to Story 45

**Key Changes:**
1. Rewrote story to focus on manifest creation, not deployment
2. Split Acceptance Criteria: manifest creation vs deployment validation
3. Restructured tasks to T1-T11 pattern with local validation only
4. Added comprehensive runtime validation section (deferred to Story 45)
5. Updated DoD with clear "NOT Part of DoD" section
6. Added detailed design notes covering:
   - VictoriaLogs architecture (single-node vs clustered)
   - Log ingestion formats and endpoints
   - Multi-tenancy via X-Scope-OrgID headers
   - Log querying with LogQL compatibility
   - Storage and retention planning
   - Grafana Loki datasource integration
   - Resource planning and capacity estimates
   - Security and NetworkPolicy design
   - High availability with replication and PDBs
7. Specified exact manifests: HelmRelease, NetworkPolicies, PDBs, ServiceMonitor, Flux Kustomization
8. Included both single-node (community) and clustered (enterprise) configurations
9. Dependencies updated to local tools only (kubectl, flux CLI, yq, kubeconform)

**Manifest Architecture:**
- **VictoriaLogs Server**: 3 replicas for HA, 100Gi storage each, 14-day retention
- **vmauth**: 2 replicas for log ingestion/query routing
- **NetworkPolicies**: Fluent Bit ingestion, Grafana queries, metrics scraping
- **PDBs**: maxUnavailable: 1 for all components
- **ServiceMonitor**: Metrics collection for observability

**Configuration Highlights:**
- 14-day log retention (configurable)
- 100Gi per replica = 300Gi total storage
- Multi-tenancy support via HTTP headers
- Loki-compatible query API for Grafana integration
- JSON Lines ingestion format

**Previous Version:** Story focused on deployment with cluster access required
**Current Version:** Story focuses on manifest creation with local validation only
