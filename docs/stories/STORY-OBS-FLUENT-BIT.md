# 19 — STORY-OBS-FLUENT-BIT — Create Fluent Bit Log Collector Manifests

Sequence: 19/50 | Prev: STORY-OBS-VICTORIA-LOGS.md | Next: STORY-OBS-VM-STACK-IMPLEMENT.md
Sprint: 3 | Lane: Observability
Global Sequence: 19/50

Status: Draft (v3.0 Refinement)
Owner: Platform Engineering
Date: 2025-10-26
Links: kubernetes/infrastructure/observability/fluent-bit; kubernetes/workloads/platform/observability/fluent-bit

## Story

As a platform engineer, I want to **create Fluent Bit manifests** for cluster-wide log collection, so that when deployed in Story 45, I have:
- Fluent Bit DaemonSet collecting container logs from all nodes
- Kubernetes metadata enrichment (namespace, pod, labels)
- Multi-cluster log routing to VictoriaLogs with cluster identification
- Optional Kubernetes API audit log collection
- Low-overhead log shipping with consistent schema

## Why / Outcome

- Centralized logs across all clusters with consistent enrichment
- Low resource overhead per node (<100Mi memory, <200m CPU)
- Multi-tenant log routing via X-Scope-OrgID headers
- Kubernetes metadata for log correlation and filtering
- Optional audit log capture for compliance

## Scope

### This Story (Manifest Creation)

Create the following Fluent Bit manifests:

**Both Clusters (infra, apps):**
- HelmRelease for Fluent Bit DaemonSet
- Container log collection configuration
- Kubernetes metadata filter
- HTTP output to VictoriaLogs vmauth
- Multi-cluster identification via cluster labels
- Position database for log offset tracking
- ServiceMonitor for metrics collection

**Optional (Infra Cluster):**
- Kubernetes API audit log collection
- Audit log parsing and enrichment

**Configuration:**
- Talos Linux compatible paths (`/var/log`, `/var/lib/containerd`)
- State persistence (`/var/fluent-bit/state`)
- Output format: JSON Lines
- Multi-tenancy via X-Scope-OrgID header

### Deferred to Story 45 (Deployment & Validation)

- Deploy Fluent Bit to all clusters via Flux
- Verify DaemonSet running on all nodes
- Test log collection from containers
- Validate logs appearing in VictoriaLogs
- Verify Kubernetes metadata enrichment
- Test multi-cluster log filtering
- Validate audit log collection (if enabled)

## Acceptance Criteria

### Manifest Creation (This Story)

1. **Fluent Bit HelmRelease Created:**
   - DaemonSet configuration for all nodes
   - Resource limits: 200m CPU, 100Mi memory
   - Talos Linux compatible volume mounts

2. **Container Log Collection Configured:**
   - INPUT: Tail `/var/log/containers/*.log`
   - Parser: Docker/CRI log format
   - Position database: `/var/fluent-bit/state/flb_kube.db`

3. **Kubernetes Metadata Filter Configured:**
   - Enrichment with namespace, pod, labels, annotations
   - Merge_Log enabled for JSON log parsing
   - Keep_Log disabled to reduce duplication

4. **Cluster Identification Filter Configured:**
   - Add `cluster: ${CLUSTER}` field to all logs
   - Add `environment: ${ENVIRONMENT}` if needed

5. **VictoriaLogs Output Configured:**
   - HTTP output to `${OBSERVABILITY_LOG_ENDPOINT_HOST}:${OBSERVABILITY_LOG_ENDPOINT_PORT}${OBSERVABILITY_LOG_ENDPOINT_PATH}`
   - Format: JSON Lines
   - Header: `X-Scope-OrgID: ${OBSERVABILITY_LOG_TENANT}`
   - Retry configuration for resilience

6. **ServiceMonitor Created:**
   - Metrics endpoint for Fluent Bit health
   - Input/output rate monitoring
   - Error rate tracking

7. **Flux Kustomization Created:**
   - Health checks for Fluent Bit DaemonSet
   - Dependency on VictoriaLogs
   - Variable substitution from cluster-settings

### Deferred to Story 45 (Deployment & Validation)

- Fluent Bit DaemonSet Running on all nodes
- Container logs flowing to VictoriaLogs
- Kubernetes metadata enriched correctly
- Cluster labels identifying log origin
- HTTP output returning 2xx status
- ServiceMonitor scraping metrics successfully
- Position database preventing log duplication

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
# Fluent Bit Configuration
OBSERVABILITY_LOG_ENDPOINT_HOST: "vmauth-victoria-logs.observability.svc.cluster.local"
OBSERVABILITY_LOG_ENDPOINT_PORT: "8427"
OBSERVABILITY_LOG_ENDPOINT_PATH: "/insert/jsonline"
OBSERVABILITY_LOG_TENANT: "default"
CLUSTER: "infra"  # or "apps"
ENVIRONMENT: "production"  # optional

# Talos Linux Paths
CONTAINERD_LOG_PATH: "/var/log/containers"
CONTAINERD_STATE_PATH: "/var/lib/containerd/io.containerd.runtime.v2.task/k8s.io"
FLUENT_BIT_STATE_PATH: "/var/fluent-bit/state"
```

## Tasks / Subtasks — Implementation Plan (Story Only)

### T1: Verify Prerequisites

**Steps:**
1. Review Fluent Bit architecture and log collection patterns
2. Verify Talos Linux log paths and container runtime configuration
3. Plan resource allocation (DaemonSet on every node)
4. Review VictoriaLogs HTTP ingestion format

**Acceptance:** Prerequisites documented, paths verified

### T2: Create Fluent Bit HelmRelease Manifest

**Location:** `kubernetes/infrastructure/observability/fluent-bit/`

**Create HelmRelease** (`helmrelease.yaml`):
```yaml
---
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: fluent-bit
  namespace: observability
spec:
  chartRef:
    kind: OCIRepository
    name: fluent-bit
    namespace: flux-system
  interval: 1h
  timeout: 10m
  install:
    remediation:
      retries: 3
  upgrade:
    remediation:
      retries: 3
  values:
    fullnameOverride: fluent-bit

    # DaemonSet configuration
    kind: DaemonSet

    # Resource limits
    resources:
      limits:
        cpu: 200m
        memory: 128Mi
      requests:
        cpu: 50m
        memory: 64Mi

    # Service for metrics
    service:
      type: ClusterIP
      port: 2020
      labels:
        app.kubernetes.io/name: fluent-bit
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "2020"

    # ServiceMonitor for metrics collection
    serviceMonitor:
      enabled: true
      namespace: observability
      interval: 30s
      scrapeTimeout: 10s

    # Tolerations for all nodes
    tolerations:
      - effect: NoSchedule
        operator: Exists
      - effect: NoExecute
        operator: Exists

    # Priority class for log collection
    priorityClassName: system-node-critical

    # Security context
    securityContext:
      runAsUser: 0
      privileged: false
      readOnlyRootFilesystem: true
      capabilities:
        drop:
          - ALL

    # Volume mounts for Talos Linux
    volumeMounts:
      - name: varlog
        mountPath: /var/log
        readOnly: true
      - name: varlibcontainers
        mountPath: /var/lib/containerd/io.containerd.runtime.v2.task/k8s.io
        readOnly: true
      - name: etcmachineid
        mountPath: /etc/machine-id
        readOnly: true
      - name: fluent-bit-state
        mountPath: /var/fluent-bit/state

    volumes:
      - name: varlog
        hostPath:
          path: /var/log
      - name: varlibcontainers
        hostPath:
          path: /var/lib/containerd/io.containerd.runtime.v2.task/k8s.io
      - name: etcmachineid
        hostPath:
          path: /etc/machine-id
          type: File
      - name: fluent-bit-state
        hostPath:
          path: /var/fluent-bit/state
          type: DirectoryOrCreate

    # Fluent Bit configuration
    config:
      service: |
        [SERVICE]
            Daemon Off
            Flush 5
            Log_Level info
            Parsers_File parsers.conf
            Parsers_File custom_parsers.conf
            HTTP_Server On
            HTTP_Listen 0.0.0.0
            HTTP_Port 2020
            Health_Check On
            storage.path /var/fluent-bit/state/flb-storage/
            storage.sync normal
            storage.checksum off
            storage.max_chunks_up 128
            storage.backlog.mem_limit 5M

      inputs: |
        [INPUT]
            Name tail
            Path /var/log/containers/*.log
            multiline.parser docker, cri
            Tag kube.*
            Mem_Buf_Limit 5MB
            Skip_Long_Lines On
            Refresh_Interval 10
            DB /var/fluent-bit/state/flb_kube.db
            DB.sync normal

      filters: |
        [FILTER]
            Name kubernetes
            Match kube.*
            Kube_URL https://kubernetes.default.svc:443
            Kube_CA_File /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
            Kube_Token_File /var/run/secrets/kubernetes.io/serviceaccount/token
            Kube_Tag_Prefix kube.var.log.containers.
            Merge_Log On
            Keep_Log Off
            K8S-Logging.Parser On
            K8S-Logging.Exclude On
            Labels On
            Annotations Off
            Buffer_Size 0

        [FILTER]
            Name modify
            Match kube.*
            Add cluster ${CLUSTER}
            Add environment ${ENVIRONMENT}

        [FILTER]
            Name nest
            Match kube.*
            Operation lift
            Nested_under kubernetes
            Add_prefix k8s_

      outputs: |
        [OUTPUT]
            Name http
            Match kube.*
            Host ${OBSERVABILITY_LOG_ENDPOINT_HOST}
            Port ${OBSERVABILITY_LOG_ENDPOINT_PORT}
            URI ${OBSERVABILITY_LOG_ENDPOINT_PATH}
            Format json
            Json_date_key _time
            Json_date_format iso8601
            Header X-Scope-OrgID ${OBSERVABILITY_LOG_TENANT}
            compress gzip
            Retry_Limit 3
            storage.total_limit_size 10M

      customParsers: |
        [PARSER]
            Name docker
            Format json
            Time_Key time
            Time_Format %Y-%m-%dT%H:%M:%S.%LZ
            Time_Keep On

        [PARSER]
            Name cri
            Format regex
            Regex ^(?<time>[^ ]+) (?<stream>stdout|stderr) (?<logtag>[^ ]*) (?<log>.*)$
            Time_Key time
            Time_Format %Y-%m-%dT%H:%M:%S.%L%z
            Time_Keep On
```

**Acceptance:** Fluent Bit HelmRelease created with DaemonSet configuration

### T3: Create Audit Log Configuration (Optional)

**Location:** `kubernetes/infrastructure/observability/fluent-bit/audit-logs-config.yaml`

**Create ConfigMap for audit logs:**

```yaml
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: fluent-bit-audit-config
  namespace: observability
data:
  audit.conf: |
    [INPUT]
        Name tail
        Path /var/log/kubernetes/audit.log
        Parser json
        Tag audit.*
        Mem_Buf_Limit 10MB
        Skip_Long_Lines On
        Refresh_Interval 10
        DB /var/fluent-bit/state/flb_audit.db

    [FILTER]
        Name modify
        Match audit.*
        Add cluster ${CLUSTER}
        Add log_type audit
        Add environment ${ENVIRONMENT}

    [FILTER]
        Name nest
        Match audit.*
        Operation nest
        Wildcard *
        Nest_under audit_event

    [OUTPUT]
        Name http
        Match audit.*
        Host ${OBSERVABILITY_LOG_ENDPOINT_HOST}
        Port ${OBSERVABILITY_LOG_ENDPOINT_PORT}
        URI ${OBSERVABILITY_LOG_ENDPOINT_PATH}
        Format json
        Json_date_key _time
        Json_date_format iso8601
        Header X-Scope-OrgID audit
        compress gzip
        Retry_Limit 3
```

**Note:** Audit logs require Kubernetes API server configured with `--audit-log-path=/var/log/kubernetes/audit.log`. Talos Linux may not enable this by default.

**Acceptance:** Audit log configuration created (optional)

### T4: Create NetworkPolicy Manifest

**Location:** `kubernetes/infrastructure/observability/fluent-bit/networkpolicy.yaml`

**Create:**

```yaml
---
# Allow Fluent Bit to send logs to VictoriaLogs vmauth
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: fluent-bit-egress
  namespace: observability
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: fluent-bit
  policyTypes:
    - Egress
  egress:
    # Allow DNS
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
          podSelector:
            matchLabels:
              k8s-app: kube-dns
      ports:
        - protocol: UDP
          port: 53
    # Allow Kubernetes API
    - to:
        - namespaceSelector: {}
      ports:
        - protocol: TCP
          port: 443
        - protocol: TCP
          port: 6443
    # Allow VictoriaLogs vmauth
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: observability
          podSelector:
            matchLabels:
              app.kubernetes.io/name: vmauth
              app.kubernetes.io/component: victoria-logs
      ports:
        - protocol: TCP
          port: 8427
```

**Acceptance:** NetworkPolicy created for Fluent Bit egress

### T5: Create ServiceMonitor Manifest

**Location:** `kubernetes/infrastructure/observability/fluent-bit/servicemonitor.yaml`

**Create:**

```yaml
---
apiVersion: operator.victoriametrics.com/v1beta1
kind: VMServiceScrape
metadata:
  name: fluent-bit
  namespace: observability
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: fluent-bit
  endpoints:
    - port: http
      interval: 30s
      scrapeTimeout: 10s
      path: /api/v1/metrics/prometheus
```

**Acceptance:** ServiceMonitor created for Fluent Bit metrics

### T6: Create Kustomization Manifest

**Location:** `kubernetes/infrastructure/observability/fluent-bit/kustomization.yaml`

**Create:**

```yaml
---
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: observability
resources:
  - helmrelease.yaml
  - networkpolicy.yaml
  - servicemonitor.yaml
  # - audit-logs-config.yaml  # Uncomment if audit logs enabled
```

**Acceptance:** Kustomization manifest created

### T7: Create Flux Kustomization Manifest

**Location:** `kubernetes/infrastructure/observability/fluent-bit/ks.yaml`

**Create:**

```yaml
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: observability-fluent-bit
  namespace: flux-system
spec:
  interval: 30m
  timeout: 10m
  sourceRef:
    kind: GitRepository
    name: flux-system
  path: ./kubernetes/infrastructure/observability/fluent-bit
  prune: true
  wait: true
  dependsOn:
    - name: infrastructure-repositories-oci
    - name: observability-victoria-logs
  postBuild:
    substituteFrom:
      - kind: ConfigMap
        name: cluster-settings
  healthChecks:
    - apiVersion: apps/v1
      kind: DaemonSet
      name: fluent-bit
      namespace: observability
```

**Acceptance:** Flux Kustomization created with health checks

### T8: Local Validation

**Steps:**

1. **Validate HelmRelease Syntax:**
   ```bash
   kubectl --dry-run=client -f kubernetes/infrastructure/observability/fluent-bit/helmrelease.yaml apply
   ```

2. **Build Kustomization:**
   ```bash
   kustomize build kubernetes/infrastructure/observability/fluent-bit/
   ```

3. **Validate Flux Kustomization:**
   ```bash
   flux build kustomization observability-fluent-bit \
     --path kubernetes/infrastructure/observability/fluent-bit/ \
     --kustomization-file kubernetes/infrastructure/observability/fluent-bit/ks.yaml
   ```

4. **Validate NetworkPolicy Syntax:**
   ```bash
   kubectl --dry-run=client -f kubernetes/infrastructure/observability/fluent-bit/networkpolicy.yaml apply
   ```

5. **Validate ServiceMonitor:**
   ```bash
   kubectl --dry-run=client -f kubernetes/infrastructure/observability/fluent-bit/servicemonitor.yaml apply
   ```

6. **Schema Validation (if kubeconform available):**
   ```bash
   kubeconform -strict kubernetes/infrastructure/observability/fluent-bit/
   ```

**Acceptance:** All manifests validate successfully with no errors

### T9: Update Cluster Settings

**Both Clusters** (`kubernetes/clusters/{infra,apps}/cluster-settings.yaml`):

**Verify/Add:**
```yaml
  # Fluent Bit / VictoriaLogs
  OBSERVABILITY_LOG_ENDPOINT_HOST: "vmauth-victoria-logs.observability.svc.cluster.local"
  OBSERVABILITY_LOG_ENDPOINT_PORT: "8427"
  OBSERVABILITY_LOG_ENDPOINT_PATH: "/insert/jsonline"
  OBSERVABILITY_LOG_TENANT: "default"
  CLUSTER: "infra"  # or "apps" for apps cluster
  ENVIRONMENT: "production"
```

**Acceptance:** Cluster settings verified/updated

### T10: Commit to Git

**Steps:**
1. Stage all created manifests
2. Commit with message:
   ```
   feat(observability): add Fluent Bit log collector manifests

   - DaemonSet for container log collection
   - Kubernetes metadata enrichment
   - HTTP output to VictoriaLogs with multi-tenancy
   - Cluster identification labels
   - Position database for log offset tracking
   - NetworkPolicy for egress to VictoriaLogs
   - ServiceMonitor for metrics collection

   Story: STORY-OBS-FLUENT-BIT
   ```

**Acceptance:** All manifests committed to git

## Runtime Validation (MOVED TO STORY 45)

**IMPORTANT:** The following validation steps are **NOT** part of this story. They will be executed in Story 45 after all manifests are created and deployed.

### Deployment Validation

**1. Verify Fluent Bit DaemonSet:**
```bash
kubectl --context=infra -n observability get daemonset fluent-bit
# Expected: DESIRED matches CURRENT and READY

kubectl --context=apps -n observability get daemonset fluent-bit
# Expected: DESIRED matches CURRENT and READY
```

**2. Check pod distribution:**
```bash
kubectl --context=infra -n observability get pods -l app.kubernetes.io/name=fluent-bit -o wide
# Expected: One pod per node, all Running
```

**3. Verify volume mounts:**
```bash
kubectl --context=infra -n observability describe daemonset fluent-bit | grep -A10 "Mounts:"
# Expected: /var/log, /var/lib/containerd, /var/fluent-bit/state
```

### Log Collection Validation

**1. Check Fluent Bit logs for collection:**
```bash
kubectl --context=infra -n observability logs daemonset/fluent-bit --tail=50
# Expected: Log lines showing file tailing and output

# Look for successful starts
kubectl --context=infra -n observability logs daemonset/fluent-bit | grep -i "fluent bit"
# Expected: Version and startup messages
```

**2. Verify input plugin:**
```bash
kubectl --context=infra -n observability logs daemonset/fluent-bit | grep -i "tail"
# Expected: Messages about tailing /var/log/containers/*.log
```

**3. Check output plugin:**
```bash
kubectl --context=infra -n observability logs daemonset/fluent-bit | grep -i "http"
# Expected: HTTP output plugin initialized
```

### Kubernetes Metadata Validation

**1. Generate test log:**
```bash
# Create test pod
kubectl --context=infra run test-logger --image=busybox --restart=Never -- sh -c "echo 'TEST LOG MESSAGE'; sleep 3600"

# Wait for log to be collected and shipped
sleep 10
```

**2. Query VictoriaLogs for test log:**
```bash
kubectl --context=infra -n observability port-forward svc/vmauth-victoria-logs 8427:8427 &

curl -s "http://127.0.0.1:8427/select/logsql/query" \
  -H "X-Scope-OrgID: default" \
  -d "query=_msg:~\"TEST LOG MESSAGE\"" \
  -d "limit=1" | jq

# Expected: Log entry with Kubernetes metadata (namespace, pod, labels)
```

**3. Verify Kubernetes metadata fields:**
```bash
curl -s "http://127.0.0.1:8427/select/logsql/query" \
  -H "X-Scope-OrgID: default" \
  -d "query=k8s_pod_name:test-logger" \
  -d "limit=1" | jq

# Expected: Fields include k8s_namespace_name, k8s_pod_name, k8s_container_name
```

### Multi-Cluster Validation

**1. Verify cluster labels:**
```bash
# Query infra cluster logs
curl -s "http://127.0.0.1:8427/select/logsql/query" \
  -H "X-Scope-OrgID: default" \
  -d "query=cluster:infra" \
  -d "limit=5" | jq

# Expected: Logs from infra cluster
```

**2. Query apps cluster logs (from infra):**
```bash
curl -s "http://127.0.0.1:8427/select/logsql/query" \
  -H "X-Scope-OrgID: default" \
  -d "query=cluster:apps" \
  -d "limit=5" | jq

# Expected: Logs from apps cluster (via ClusterMesh remote-write)
```

**3. List unique clusters:**
```bash
curl -s "http://127.0.0.1:8427/select/logsql/field_values" \
  -H "X-Scope-OrgID: default" \
  -d "field=cluster" | jq

# Expected: ["infra", "apps"]
```

### Position Database Validation

**1. Check position database creation:**
```bash
kubectl --context=infra -n observability exec daemonset/fluent-bit -- ls -lh /var/fluent-bit/state/
# Expected: flb_kube.db file exists
```

**2. Verify no log duplication:**
```bash
# Restart Fluent Bit pod
kubectl --context=infra -n observability rollout restart daemonset/fluent-bit
kubectl --context=infra -n observability rollout status daemonset/fluent-bit

# Generate unique log
kubectl --context=infra run test-unique --image=busybox --restart=Never -- sh -c "echo 'UNIQUE-$(date +%s)'; sleep 60"

# Wait and query
sleep 10
UNIQUE_MSG=$(kubectl --context=infra logs test-unique)

# Count occurrences in VictoriaLogs
COUNT=$(curl -s "http://127.0.0.1:8427/select/logsql/query" \
  -H "X-Scope-OrgID: default" \
  -d "query=_msg:~\"$UNIQUE_MSG\"" \
  -d "limit=100" | jq '.data | length')

echo "Log appears $COUNT times"
# Expected: 1 (no duplication)
```

### Output Validation

**1. Check HTTP output success rate:**
```bash
kubectl --context=infra -n observability logs daemonset/fluent-bit | grep -i "http" | grep -i "200"
# Expected: HTTP 200 OK responses
```

**2. Verify retry behavior (simulate failure):**
```bash
# Scale down VictoriaLogs temporarily
kubectl --context=infra -n observability scale statefulset victoria-logs-server --replicas=0

# Generate logs
kubectl --context=infra run retry-test --image=busybox --restart=Never -- sh -c "echo 'RETRY TEST'; sleep 60"

# Check Fluent Bit logs for retries
kubectl --context=infra -n observability logs daemonset/fluent-bit --tail=50 | grep -i "retry"
# Expected: Retry attempts logged

# Scale back up
kubectl --context=infra -n observability scale statefulset victoria-logs-server --replicas=3
```

### Metrics Validation

**1. Verify ServiceMonitor:**
```bash
kubectl --context=infra -n observability get vmservicescrape fluent-bit
# Expected: ServiceScrape exists
```

**2. Check Fluent Bit metrics endpoint:**
```bash
kubectl --context=infra -n observability port-forward daemonset/fluent-bit 2020:2020 &
curl -s http://127.0.0.1:2020/api/v1/metrics/prometheus | grep fluentbit
# Expected: Fluent Bit metrics
```

**3. Query metrics in VictoriaMetrics:**
```bash
kubectl --context=infra -n observability port-forward svc/vmselect-victoria-metrics-global-vmcluster 8481:8481 &

curl -s 'http://127.0.0.1:8481/select/0/prometheus/api/v1/query?query=up{job="fluent-bit"}' | jq
# Expected: up=1 for all Fluent Bit pods

# Check input rate
curl -s 'http://127.0.0.1:8481/select/0/prometheus/api/v1/query?query=fluentbit_input_records_total' | jq
# Expected: Increasing counter

# Check output rate
curl -s 'http://127.0.0.1:8481/select/0/prometheus/api/v1/query?query=fluentbit_output_proc_records_total{name="http"}' | jq
# Expected: Increasing counter matching input rate
```

### Resource Usage Validation

**1. Check memory usage:**
```bash
kubectl --context=infra -n observability top pod -l app.kubernetes.io/name=fluent-bit
# Expected: Memory < 100Mi per pod
```

**2. Check CPU usage:**
```bash
kubectl --context=infra -n observability top pod -l app.kubernetes.io/name=fluent-bit
# Expected: CPU < 50m per pod (steady state)
```

**3. Monitor over time:**
```bash
# Query resource usage metrics
curl -s 'http://127.0.0.1:8481/select/0/prometheus/api/v1/query?query=container_memory_working_set_bytes{pod=~"fluent-bit.*"}' | jq

# Expected: Stable memory usage, no leaks
```

### Audit Log Validation (If Enabled)

**1. Verify audit log collection:**
```bash
kubectl --context=infra -n observability logs daemonset/fluent-bit | grep -i "audit"
# Expected: Audit input tailing /var/log/kubernetes/audit.log
```

**2. Query audit logs:**
```bash
curl -s "http://127.0.0.1:8427/select/logsql/query" \
  -H "X-Scope-OrgID: audit" \
  -d "query=log_type:audit" \
  -d "limit=10" | jq

# Expected: Kubernetes API audit events
```

**3. Verify audit log format:**
```bash
# Check for audit-specific fields
curl -s "http://127.0.0.1:8427/select/logsql/field_names" \
  -H "X-Scope-OrgID: audit" | jq

# Expected: Fields like verb, user, objectRef, etc.
```

### NetworkPolicy Validation

**1. Verify egress to VictoriaLogs:**
```bash
kubectl --context=infra -n observability exec daemonset/fluent-bit -- \
  wget -qO- http://vmauth-victoria-logs.observability.svc.cluster.local:8427/health

# Expected: "OK" or 200 status
```

**2. Verify Kubernetes API access:**
```bash
kubectl --context=infra -n observability logs daemonset/fluent-bit | grep -i "kubernetes"
# Expected: Successful Kubernetes metadata enrichment
```

## Definition of Done

### Manifest Creation Complete (This Story)

- [x] Fluent Bit HelmRelease created with DaemonSet configuration
- [x] Container log collection configured (tail /var/log/containers)
- [x] Kubernetes metadata filter configured
- [x] Cluster identification filter configured (cluster, environment labels)
- [x] VictoriaLogs HTTP output configured with multi-tenancy
- [x] Position database configured for log offset tracking
- [x] NetworkPolicy created for egress to VictoriaLogs
- [x] ServiceMonitor created for metrics collection
- [x] Flux Kustomization created with health checks and dependencies
- [x] Cluster settings verified/updated
- [x] All manifests validate successfully using local tools (flux build, kubectl --dry-run)
- [x] Manifests committed to git repository
- [x] Documentation complete with Talos paths and configuration

### NOT Part of DoD (Moved to Story 45)

**Deployment Validation:**
- Fluent Bit DaemonSet Running on all nodes
- Volume mounts correct (/var/log, /var/lib/containerd, /var/fluent-bit/state)
- Container logs being collected

**Collection Validation:**
- Logs flowing to VictoriaLogs
- HTTP output returning 2xx status
- Position database preventing duplication
- No log loss during pod restarts

**Enrichment Validation:**
- Kubernetes metadata enriched (namespace, pod, labels)
- Cluster labels identifying origin
- JSON log parsing working (Merge_Log)

**Performance Validation:**
- Memory usage < 100Mi per pod
- CPU usage < 50m per pod (steady state)
- Input/output rates matching
- No resource leaks over time

**Integration Validation:**
- ServiceMonitor scraping metrics successfully
- VictoriaMetrics collecting Fluent Bit metrics
- NetworkPolicy allowing required traffic
- Multi-cluster log filtering working

## Design Notes

### Fluent Bit Architecture

**DaemonSet Pattern:**
- One Fluent Bit pod per node
- Each pod collects logs from all containers on that node
- Low resource overhead per node
- No single point of failure

**Log Collection Flow:**
1. Container writes logs → Container runtime (containerd)
2. Containerd writes logs → `/var/log/containers/*.log`
3. Fluent Bit tails log files → Parses CRI/Docker format
4. Kubernetes filter enriches → Adds metadata
5. Modify filter adds cluster labels
6. HTTP output ships → VictoriaLogs vmauth

### Talos Linux Compatibility

**Key Paths:**
- Container logs: `/var/log/containers/*.log`
- Containerd state: `/var/lib/containerd/io.containerd.runtime.v2.task/k8s.io`
- Machine ID: `/etc/machine-id` (for node identification)
- State persistence: `/var/fluent-bit/state` (writable on Talos)

**Talos Considerations:**
- Most filesystem is read-only
- Only `/var` is writable and persists across reboots
- Position database must be in `/var/fluent-bit/state`
- No systemd journals (use container logs only)

### Log Format and Parsing

**CRI Log Format:**
```
2025-10-26T10:15:30.123456789Z stdout F log message here
```

**Docker Log Format:**
```json
{"log":"log message here\n","stream":"stdout","time":"2025-10-26T10:15:30.123456789Z"}
```

**Fluent Bit Output Format (JSON Lines):**
```json
{
  "_msg": "log message here",
  "_time": "2025-10-26T10:15:30.123456789Z",
  "cluster": "infra",
  "environment": "production",
  "k8s_namespace_name": "default",
  "k8s_pod_name": "my-app-12345",
  "k8s_container_name": "app",
  "k8s_labels": {"app": "my-app", "version": "v1.0"}
}
```

### Kubernetes Metadata Enrichment

**Kubernetes Filter:**
- Queries Kubernetes API for pod metadata
- Uses ServiceAccount token for authentication
- Caches metadata to reduce API calls
- Enriches logs with:
  - Namespace name
  - Pod name and UID
  - Container name and ID
  - Labels and annotations
  - Node name

**Merge_Log Feature:**
- Parses JSON log messages
- Promotes nested fields to top-level
- Reduces log nesting depth
- Improves query performance

### Position Database

**Purpose:**
- Tracks read position in each log file
- Prevents log duplication on pod restart
- Enables exactly-once log delivery

**Storage:**
- SQLite database at `/var/fluent-bit/state/flb_kube.db`
- Persisted on host filesystem
- Survives pod restarts
- Per-node state (not shared across nodes)

**Behavior:**
- New files: Start from beginning
- Existing files: Resume from last position
- Rotated files: Tracked by inode
- Deleted files: Position cleaned up

### Multi-Cluster Log Routing

**Cluster Identification:**
- `cluster: infra` or `cluster: apps` added to all logs
- Enables filtering logs by origin cluster
- Important for troubleshooting cross-cluster issues

**Tenant Isolation:**
- All logs go to same tenant (`default`) by default
- Can route different namespaces to different tenants
- Uses `X-Scope-OrgID` header for tenant selection

### Resource Planning

**Per-Node Resources:**
- CPU: 50m request, 200m limit
- Memory: 64Mi request, 128Mi limit
- Actual usage typically < 50m CPU, < 80Mi memory

**Total Cluster Resources:**
- 3-node cluster: ~150m CPU, ~200Mi memory
- Scales linearly with node count
- Negligible compared to application workloads

**Ingestion Capacity:**
- ~10k-50k logs/s per pod (depends on log size)
- Sufficient for most Kubernetes clusters
- Bottleneck typically at storage (VictoriaLogs), not collection

### HTTP Output Configuration

**Retry Logic:**
- Retry_Limit: 3 attempts
- Exponential backoff
- Storage queue for temporary failures
- Prevents log loss during VictoriaLogs downtime

**Compression:**
- gzip compression enabled
- Reduces network bandwidth by ~70%
- Important for cross-cluster log shipping

**Batching:**
- Flush interval: 5 seconds
- Buffer size: 5MB
- Balances latency vs efficiency

### Security Considerations

**Privileges:**
- Runs as root (required to read /var/log)
- No privileged mode needed
- Read-only root filesystem
- Minimal capabilities

**Network Access:**
- Egress to VictoriaLogs (port 8427)
- Egress to Kubernetes API (port 443/6443)
- Egress to CoreDNS (port 53)
- No ingress needed

**Sensitive Data:**
- Logs may contain secrets (environment variables, etc.)
- Multi-tenancy provides basic isolation
- Consider log scrubbing for PII/secrets
- Audit logs in separate tenant for compliance

### High Availability

**DaemonSet Guarantees:**
- Always one pod per node
- Automatic replacement on failure
- Rolling updates for zero downtime

**Position Database:**
- Per-node state prevents duplication
- Survives pod restarts
- No cross-node coordination needed

**Output Resilience:**
- Retry logic handles transient failures
- Storage queue buffers during outages
- No log loss unless storage queue fills (10MB)

## Change Log

### v3.0 (2025-10-26) - Manifests-First Refinement

**Scope Split:**
- This story now focuses exclusively on **creating Fluent Bit manifests**
- Deployment and validation moved to Story 45

**Key Changes:**
1. Rewrote story to focus on manifest creation, not deployment
2. Split Acceptance Criteria: manifest creation vs deployment validation
3. Restructured tasks to T1-T10 pattern with local validation only
4. Added comprehensive runtime validation section (deferred to Story 45)
5. Updated DoD with clear "NOT Part of DoD" section
6. Added detailed design notes covering:
   - Fluent Bit DaemonSet architecture
   - Talos Linux path compatibility
   - Log format and parsing (CRI, Docker, JSON)
   - Kubernetes metadata enrichment
   - Position database for exactly-once delivery
   - Multi-cluster log routing and identification
   - Resource planning and capacity estimates
   - HTTP output with retry and compression
   - Security and NetworkPolicy design
   - High availability with DaemonSet guarantees
7. Specified exact manifests: HelmRelease, NetworkPolicy, ServiceMonitor, Flux Kustomization
8. Included Talos-specific configuration (paths, volumes, state persistence)
9. Dependencies updated to local tools only (kubectl, flux CLI, yq, kubeconform)

**Manifest Architecture:**
- **DaemonSet**: One pod per node for log collection
- **Inputs**: Tail /var/log/containers/*.log
- **Filters**: Kubernetes metadata, cluster labels
- **Outputs**: HTTP to VictoriaLogs with multi-tenancy
- **Position Database**: SQLite at /var/fluent-bit/state for offset tracking
- **ServiceMonitor**: Metrics for input/output rates and errors

**Configuration Highlights:**
- Talos Linux paths: /var/log, /var/lib/containerd, /var/fluent-bit/state
- CRI/Docker log parsing with multiline support
- Kubernetes metadata enrichment (namespace, pod, labels)
- Cluster identification: cluster=infra/apps labels
- HTTP output: JSON Lines format, gzip compression, retry logic
- Resources: 50m CPU request, 64Mi memory request per pod

**Previous Version:** Story focused on deployment with cluster access required
**Current Version:** Story focuses on manifest creation with local validation only
