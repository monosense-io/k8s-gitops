# 17 — STORY-OBS-VM-STACK — Create VictoriaMetrics Stack Manifests

Sequence: 17/50 | Prev: STORY-STO-ROOK-CEPH-CLUSTER.md | Next: STORY-OBS-VICTORIA-LOGS.md
Sprint: 3 | Lane: Observability
Global Sequence: 17/50

Status: Draft (v3.0 Refinement)
Owner: Platform Engineering
Date: 2025-10-26
Links: kubernetes/infrastructure/observability/victoria-metrics; kubernetes/components/monitoring; bootstrap/helmfile.d/01-core.yaml (CRDs)

## Story

As a platform engineer, I want to **create VictoriaMetrics stack manifests** for centralized metrics collection and storage, so that when deployed in Story 45, I have:
- Global vmcluster on infra (vmselect/vminsert/vmstorage) for centralized metrics storage
- Grafana with admin credentials for unified dashboards
- Per-cluster vmagent for metrics scraping and remote-write to infra cluster
- vmalert and Alertmanager for rule evaluation and alerting

## Why / Outcome

- Centralized metrics storage with federated collection across all clusters
- Unified dashboards and alerts across infrastructure and application workloads
- Separation of concerns: infra cluster stores metrics, apps cluster collects locally and forwards
- Production-grade observability foundation for SLO tracking and incident response

## Scope

### This Story (Manifest Creation)

Create the following VictoriaMetrics stack manifests:

**Infra Cluster:**
- HelmRelease for victoria-metrics-global (vmcluster, vmauth, vmalert, alertmanager)
- VMCluster custom resources via operator
- Grafana configuration with ExternalSecret for admin credentials
- NetworkPolicy for vm component communication
- PodDisruptionBudgets for vmselect, vminsert, vmstorage
- PrometheusRules for component monitoring

**Apps Cluster:**
- HelmRelease for victoria-metrics-stack (vmagent only, no vmcluster)
- vmagent configuration with remote-write to infra cluster
- ServiceMonitors for local scraping (kube-state-metrics, node-exporter, Cilium)
- NetworkPolicy for vmagent access

**Shared:**
- Flux Kustomizations with health checks and dependencies
- Business metrics PrometheusRules
- Component documentation

### Deferred to Story 45 (Deployment & Validation)

- Deploy victoria-metrics-operator CRDs via helmfile bootstrap
- Apply VictoriaMetrics stack to clusters via Flux
- Verify vmcluster readiness (vmselect/vminsert/vmstorage)
- Validate vmagent remote-write connectivity
- Test Grafana access with credentials
- Verify metrics retention and query performance
- Test alert rule evaluation and firing

## Acceptance Criteria

### Manifest Creation (This Story)

1. **Infra Global Stack Manifests Created:**
   - HelmRelease for victoria-metrics-global with vmcluster (3 replicas each), vmauth, vmalert, alertmanager
   - Storage configured using `${BLOCK_SC}` with retention settings
   - VMCluster CR with appropriate resource limits

2. **Grafana Manifests Created:**
   - Grafana enabled in HelmRelease
   - ExternalSecret referencing `${OBSERVABILITY_GRAFANA_SECRET_PATH}`
   - Admin credentials mapped to Secret (admin-user, admin-password keys)
   - Default data sources configured (VictoriaMetrics, Alertmanager)

3. **Apps Cluster vmagent Manifests Created:**
   - HelmRelease with vmcluster disabled, vmagent enabled
   - Remote-write configured to `${GLOBAL_VM_INSERT_ENDPOINT}/insert/0/prometheus/api/v1/write`
   - External labels include `cluster: ${CLUSTER}`
   - ServiceMonitors for kube-state-metrics, node-exporter, Cilium

4. **NetworkPolicy Manifests Created:**
   - Allow vmselect ↔ vmstorage
   - Allow vminsert ↔ vmstorage
   - Allow vmauth → vmselect
   - Allow vmalert → vmselect, alertmanager
   - Allow vmagent → vminsert

5. **PodDisruptionBudget Manifests Created:**
   - PDBs for vmselect (maxUnavailable: 1)
   - PDBs for vminsert (maxUnavailable: 1)
   - PDBs for vmstorage (maxUnavailable: 1)

6. **Monitoring Manifests Created:**
   - PrometheusRules for VictoriaMetrics component health
   - Business metrics rules for evaluation by vmalert
   - ServiceMonitors for all vm components

7. **Flux Kustomization Manifests Created:**
   - Infra observability kustomization with health checks for vmcluster, vmauth, vmalert, alertmanager
   - Apps observability kustomization with health checks for vmagent
   - Dependency on victoria-metrics-operator from Story 01

### Deferred to Story 45 (Deployment & Validation)

- victoria-metrics-operator CRDs installed and Ready
- Infra vmcluster pods Running (vmselect/vminsert/vmstorage)
- vmauth and vmalert Deployments Available
- Alertmanager StatefulSet Ready
- Apps vmagent successfully remote-writes to infra (2xx responses)
- Grafana accessible with credentials
- Dashboards render with live metrics data
- Alert rules loaded and firing test alerts

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
# Infra cluster
GLOBAL_VM_INSERT_ENDPOINT: "http://vminsert-victoria-metrics-global-vmcluster.observability.svc.cluster.local:8480"
GLOBAL_VM_SELECT_ENDPOINT: "http://vmselect-victoria-metrics-global-vmcluster.observability.svc.cluster.local:8481"
GLOBAL_ALERTMANAGER_ENDPOINT: "http://vmalertmanager-victoria-metrics-global.observability.svc.cluster.local:9093"
OBSERVABILITY_GRAFANA_SECRET_PATH: "kubernetes/infra/observability/grafana-admin"
VM_RETENTION_PERIOD: "30d"
VM_STORAGE_SIZE: "50Gi"
BLOCK_SC: "ceph-block"

# Apps cluster
GLOBAL_VM_INSERT_ENDPOINT: "http://vminsert-victoria-metrics-global-vmcluster.observability.svc.infra.cluster.local:8480"  # ClusterMesh FQDN
CLUSTER: "apps"
```

## Tasks / Subtasks — Implementation Plan (Story Only)

### T1: Verify Prerequisites

**Steps:**
1. Verify victoria-metrics-operator CRDs manifests exist from Story 01
2. Review VictoriaMetrics architecture documentation
3. Plan storage requirements (50Gi per vmstorage replica = 150Gi total)
4. Review ClusterMesh DNS for cross-cluster remote-write (apps → infra)

**Acceptance:** Prerequisites documented, architecture clear

### T2: Create Infra Global Stack Manifests

**Location:** `kubernetes/infrastructure/observability/victoria-metrics/global/`

**Create:**

**HelmRelease** (`helmrelease.yaml`):
```yaml
---
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: victoria-metrics-global
  namespace: observability
spec:
  chartRef:
    kind: OCIRepository
    name: victoria-metrics-k8s-stack
    namespace: flux-system
  interval: 1h
  timeout: 15m
  install:
    crds: Skip  # Installed by Story 01
    remediation:
      retries: 3
  upgrade:
    crds: Skip
    remediation:
      retries: 3
  values:
    fullnameOverride: victoria-metrics-global

    # VMCluster for centralized storage
    victoria-metrics-operator:
      enabled: false  # Operator installed separately

    vmcluster:
      enabled: true
      spec:
        retentionPeriod: ${VM_RETENTION_PERIOD}
        replicationFactor: 2

        vmstorage:
          replicaCount: 3
          storage:
            volumeClaimTemplate:
              spec:
                storageClassName: ${BLOCK_SC}
                accessModes:
                  - ReadWriteOnce
                resources:
                  requests:
                    storage: ${VM_STORAGE_SIZE}
          resources:
            limits:
              cpu: 2
              memory: 4Gi
            requests:
              cpu: 500m
              memory: 2Gi

        vmselect:
          replicaCount: 3
          cacheMountPath: /cache
          storage:
            volumeClaimTemplate:
              spec:
                storageClassName: ${BLOCK_SC}
                accessModes:
                  - ReadWriteOnce
                resources:
                  requests:
                    storage: 10Gi
          resources:
            limits:
              cpu: 2
              memory: 2Gi
            requests:
              cpu: 200m
              memory: 500Mi

        vminsert:
          replicaCount: 3
          resources:
            limits:
              cpu: 1
              memory: 1Gi
            requests:
              cpu: 200m
              memory: 500Mi

    # VMAuth for authentication/routing
    vmauth:
      enabled: true
      spec:
        selectAllByDefault: true
        unauthorizedAccessConfig:
          - src_paths:
              - "/.*"
            url_prefix:
              - "http://vmselect-victoria-metrics-global-vmcluster.observability.svc.cluster.local:8481/select/0/prometheus"

    # VMAlert for rule evaluation
    vmalert:
      enabled: true
      spec:
        replicaCount: 2
        datasource:
          url: ${GLOBAL_VM_SELECT_ENDPOINT}/select/0/prometheus
        remoteWrite:
          url: ${GLOBAL_VM_INSERT_ENDPOINT}/insert/0/prometheus
        notifier:
          url: ${GLOBAL_ALERTMANAGER_ENDPOINT}
        evaluationInterval: 15s
        resources:
          limits:
            cpu: 500m
            memory: 512Mi
          requests:
            cpu: 100m
            memory: 256Mi

    # Alertmanager for alert routing
    alertmanager:
      enabled: true
      spec:
        replicaCount: 3
        retention: 120h
        storage:
          volumeClaimTemplate:
            spec:
              storageClassName: ${BLOCK_SC}
              accessModes:
                - ReadWriteOnce
              resources:
                requests:
                  storage: 10Gi
        resources:
          limits:
            cpu: 200m
            memory: 256Mi
          requests:
            cpu: 50m
            memory: 128Mi

    # Grafana for dashboards
    grafana:
      enabled: true
      replicas: 2
      admin:
        existingSecret: grafana-admin
        userKey: admin-user
        passwordKey: admin-password
      persistence:
        enabled: true
        storageClassName: ${BLOCK_SC}
        size: 10Gi
      datasources:
        datasources.yaml:
          apiVersion: 1
          datasources:
            - name: VictoriaMetrics
              type: prometheus
              url: ${GLOBAL_VM_SELECT_ENDPOINT}/select/0/prometheus
              access: proxy
              isDefault: true
            - name: Alertmanager
              type: alertmanager
              url: ${GLOBAL_ALERTMANAGER_ENDPOINT}
              access: proxy
      dashboardProviders:
        dashboardproviders.yaml:
          apiVersion: 1
          providers:
            - name: 'default'
              orgId: 1
              folder: ''
              type: file
              disableDeletion: false
              editable: true
              options:
                path: /var/lib/grafana/dashboards/default

    # Disable components not needed on infra
    prometheus-node-exporter:
      enabled: false
    kube-state-metrics:
      enabled: false
    vmagent:
      enabled: false

    # ServiceMonitors for vm components
    serviceMonitor:
      enabled: true
```

**ExternalSecret** (`externalsecret.yaml`):
```yaml
---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: grafana-admin
  namespace: observability
spec:
  secretStoreRef:
    name: onepassword
    kind: ClusterSecretStore
  target:
    name: grafana-admin
    creationPolicy: Owner
    template:
      type: Opaque
      data:
        admin-user: "{{ .username }}"
        admin-password: "{{ .password }}"
  data:
    - secretKey: username
      remoteRef:
        key: ${OBSERVABILITY_GRAFANA_SECRET_PATH}
        property: username
    - secretKey: password
      remoteRef:
        key: ${OBSERVABILITY_GRAFANA_SECRET_PATH}
        property: password
  refreshInterval: 1h
```

**Kustomization** (`kustomization.yaml`):
```yaml
---
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: observability
resources:
  - helmrelease.yaml
  - externalsecret.yaml
  - networkpolicy.yaml
  - pdb.yaml
  - prometheusrule.yaml
```

**Acceptance:** Infra global stack manifests created with vmcluster, vmauth, vmalert, alertmanager, Grafana

### T3: Create Apps Cluster vmagent Manifests

**Location:** `kubernetes/infrastructure/observability/victoria-metrics/stack/`

**Create:**

**HelmRelease** (`helmrelease.yaml`):
```yaml
---
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: victoria-metrics-stack
  namespace: observability
spec:
  chartRef:
    kind: OCIRepository
    name: victoria-metrics-k8s-stack
    namespace: flux-system
  interval: 1h
  timeout: 15m
  install:
    crds: Skip  # Installed by Story 01
    remediation:
      retries: 3
  upgrade:
    crds: Skip
    remediation:
      retries: 3
  values:
    fullnameOverride: victoria-metrics

    # Disable vmcluster (use infra cluster)
    victoria-metrics-operator:
      enabled: false
    vmcluster:
      enabled: false
    vmauth:
      enabled: false
    vmalert:
      enabled: false
    alertmanager:
      enabled: false
    grafana:
      enabled: false

    # Enable vmagent for scraping
    vmagent:
      enabled: true
      spec:
        replicaCount: 2
        externalLabels:
          cluster: ${CLUSTER}
        remoteWrite:
          - url: ${GLOBAL_VM_INSERT_ENDPOINT}/insert/0/prometheus/api/v1/write
            sendTimeout: 30s
            queueConfig:
              maxSamplesPerSend: 5000
              capacity: 10000
              maxShards: 10
        resources:
          limits:
            cpu: 500m
            memory: 1Gi
          requests:
            cpu: 100m
            memory: 256Mi
        selectAllByDefault: true  # Scrape all ServiceMonitors

    # Enable exporters for apps cluster
    prometheus-node-exporter:
      enabled: true
      resources:
        limits:
          cpu: 200m
          memory: 128Mi
        requests:
          cpu: 50m
          memory: 64Mi

    kube-state-metrics:
      enabled: true
      resources:
        limits:
          cpu: 200m
          memory: 256Mi
        requests:
          cpu: 50m
          memory: 128Mi

    # ServiceMonitor for components
    serviceMonitor:
      enabled: true
```

**Kustomization** (`kustomization.yaml`):
```yaml
---
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: observability
resources:
  - helmrelease.yaml
  - networkpolicy.yaml
```

**Acceptance:** Apps cluster vmagent manifests created with remote-write to infra

### T4: Create NetworkPolicy Manifests

**Location:** `kubernetes/infrastructure/observability/victoria-metrics/global/networkpolicy.yaml` (infra)

**Create:**

```yaml
---
# Allow vmselect to query vmstorage
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: vmselect-to-vmstorage
  namespace: observability
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: vmstorage
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app.kubernetes.io/name: vmselect
      ports:
        - protocol: TCP
          port: 8482  # vmselect port
        - protocol: TCP
          port: 8401  # vmstorage port
---
# Allow vminsert to write to vmstorage
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: vminsert-to-vmstorage
  namespace: observability
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: vmstorage
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app.kubernetes.io/name: vminsert
      ports:
        - protocol: TCP
          port: 8400  # vminsert port
---
# Allow vmauth to route to vmselect
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: vmauth-to-vmselect
  namespace: observability
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: vmselect
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app.kubernetes.io/name: vmauth
      ports:
        - protocol: TCP
          port: 8481
---
# Allow vmalert to query and write
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: vmalert-access
  namespace: observability
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: vmalert
  policyTypes:
    - Egress
  egress:
    - to:
        - podSelector:
            matchLabels:
              app.kubernetes.io/name: vmselect
      ports:
        - protocol: TCP
          port: 8481
    - to:
        - podSelector:
            matchLabels:
              app.kubernetes.io/name: vminsert
      ports:
        - protocol: TCP
          port: 8480
    - to:
        - podSelector:
            matchLabels:
              app.kubernetes.io/name: alertmanager
      ports:
        - protocol: TCP
          port: 9093
---
# Allow vmagent (from any cluster) to write to vminsert
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: vmagent-to-vminsert
  namespace: observability
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: vminsert
  policyTypes:
    - Ingress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: observability
          podSelector:
            matchLabels:
              app.kubernetes.io/name: vmagent
      ports:
        - protocol: TCP
          port: 8480
```

**Apps Cluster** (`kubernetes/infrastructure/observability/victoria-metrics/stack/networkpolicy.yaml`):

```yaml
---
# Allow vmagent egress to infra vminsert (via ClusterMesh)
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: vmagent-egress
  namespace: observability
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: vmagent
  policyTypes:
    - Egress
  egress:
    - to:
        - namespaceSelector: {}  # Allow cross-cluster
      ports:
        - protocol: TCP
          port: 8480  # vminsert
    - to:
        - namespaceSelector: {}
      ports:
        - protocol: TCP
          port: 443  # Kubernetes API
        - protocol: TCP
          port: 6443
    - to:
        - namespaceSelector: {}
          podSelector:
            matchLabels:
              k8s-app: kube-dns
      ports:
        - protocol: UDP
          port: 53
```

**Acceptance:** NetworkPolicies created for vm component communication

### T5: Create PodDisruptionBudget Manifests

**Location:** `kubernetes/infrastructure/observability/victoria-metrics/global/pdb.yaml`

**Create:**

```yaml
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: vmselect
  namespace: observability
spec:
  maxUnavailable: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: vmselect
      app.kubernetes.io/instance: victoria-metrics-global
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: vminsert
  namespace: observability
spec:
  maxUnavailable: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: vminsert
      app.kubernetes.io/instance: victoria-metrics-global
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: vmstorage
  namespace: observability
spec:
  maxUnavailable: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: vmstorage
      app.kubernetes.io/instance: victoria-metrics-global
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: vmalert
  namespace: observability
spec:
  maxUnavailable: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: vmalert
      app.kubernetes.io/instance: victoria-metrics-global
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: alertmanager
  namespace: observability
spec:
  maxUnavailable: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: alertmanager
      app.kubernetes.io/instance: victoria-metrics-global
```

**Acceptance:** PDBs created for all vm components

### T6: Create PrometheusRule Manifests

**Location:** `kubernetes/infrastructure/observability/victoria-metrics/global/prometheusrule.yaml`

**Create:**

```yaml
---
apiVersion: operator.victoriametrics.com/v1beta1
kind: VMRule
metadata:
  name: victoria-metrics-health
  namespace: observability
spec:
  groups:
    - name: victoriametrics.health
      interval: 30s
      rules:
        # VMStorage health
        - alert: VMStorageDown
          expr: up{job="vmstorage"} == 0
          for: 5m
          labels:
            severity: critical
          annotations:
            summary: "VMStorage instance {{ $labels.instance }} is down"
            description: "VMStorage has been down for more than 5 minutes"

        - alert: VMStorageTooManyRestarts
          expr: changes(process_start_time_seconds{job="vmstorage"}[15m]) > 2
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "VMStorage {{ $labels.instance }} restarting frequently"
            description: "VMStorage restarted {{ $value }} times in 15m"

        - alert: VMStorageDiskSpaceLow
          expr: |
            (
              vm_free_disk_space_bytes{job="vmstorage"}
              /
              vm_data_size_bytes{job="vmstorage"}
            ) < 0.2
          for: 15m
          labels:
            severity: warning
          annotations:
            summary: "VMStorage {{ $labels.instance }} disk space low"
            description: "Less than 20% free disk space remaining"

        # VMSelect health
        - alert: VMSelectDown
          expr: up{job="vmselect"} == 0
          for: 5m
          labels:
            severity: critical
          annotations:
            summary: "VMSelect instance {{ $labels.instance }} is down"
            description: "VMSelect has been down for more than 5 minutes"

        - alert: VMSelectHighLatency
          expr: histogram_quantile(0.99, sum(rate(vm_request_duration_seconds_bucket{job="vmselect"}[5m])) by (le)) > 5
          for: 15m
          labels:
            severity: warning
          annotations:
            summary: "VMSelect high query latency"
            description: "P99 latency is {{ $value }}s"

        # VMInsert health
        - alert: VMInsertDown
          expr: up{job="vminsert"} == 0
          for: 5m
          labels:
            severity: critical
          annotations:
            summary: "VMInsert instance {{ $labels.instance }} is down"
            description: "VMInsert has been down for more than 5 minutes"

        - alert: VMInsertHighErrorRate
          expr: |
            (
              sum(rate(vm_rows_ignored_total{job="vminsert"}[5m]))
              /
              sum(rate(vm_rows_inserted_total{job="vminsert"}[5m]))
            ) > 0.05
          for: 15m
          labels:
            severity: warning
          annotations:
            summary: "VMInsert high error rate"
            description: "{{ $value | humanizePercentage }} of rows are being rejected"

        # VMAlert health
        - alert: VMAlertDown
          expr: up{job="vmalert"} == 0
          for: 5m
          labels:
            severity: critical
          annotations:
            summary: "VMAlert instance {{ $labels.instance }} is down"
            description: "VMAlert has been down for more than 5 minutes"

        - alert: VMAlertFailedExecution
          expr: increase(vmalert_execution_errors_total[5m]) > 0
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "VMAlert execution failures"
            description: "{{ $value }} rule execution failures in 5m"

        # Alertmanager health
        - alert: AlertmanagerDown
          expr: up{job="alertmanager"} == 0
          for: 5m
          labels:
            severity: critical
          annotations:
            summary: "Alertmanager instance {{ $labels.instance }} is down"
            description: "Alertmanager has been down for more than 5 minutes"

        - alert: AlertmanagerFailedNotifications
          expr: rate(alertmanager_notifications_failed_total[5m]) > 0
          for: 15m
          labels:
            severity: warning
          annotations:
            summary: "Alertmanager notification failures"
            description: "{{ $value }} failed notifications/s"

        # Remote-write health (apps → infra)
        - alert: VMAgentRemoteWriteFailures
          expr: rate(vmagent_remotewrite_errors_total[5m]) > 0
          for: 15m
          labels:
            severity: warning
          annotations:
            summary: "VMAgent {{ $labels.instance }} remote-write failures"
            description: "{{ $value }} errors/s writing to remote storage"
```

**Acceptance:** PrometheusRules created for vm component monitoring

### T7: Create Flux Kustomization Manifests

**Location Infra:** `kubernetes/infrastructure/observability/victoria-metrics/global/ks.yaml`

**Create:**

```yaml
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: observability-victoria-metrics-global
  namespace: flux-system
spec:
  interval: 30m
  timeout: 15m
  sourceRef:
    kind: GitRepository
    name: flux-system
  path: ./kubernetes/infrastructure/observability/victoria-metrics/global
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
      name: vmstorage-victoria-metrics-global-vmcluster
      namespace: observability
    - apiVersion: apps/v1
      kind: Deployment
      name: vmselect-victoria-metrics-global-vmcluster
      namespace: observability
    - apiVersion: apps/v1
      kind: Deployment
      name: vminsert-victoria-metrics-global-vmcluster
      namespace: observability
    - apiVersion: apps/v1
      kind: Deployment
      name: vmauth-victoria-metrics-global
      namespace: observability
    - apiVersion: apps/v1
      kind: Deployment
      name: vmalert-victoria-metrics-global
      namespace: observability
    - apiVersion: apps/v1
      kind: StatefulSet
      name: alertmanager-victoria-metrics-global
      namespace: observability
    - apiVersion: apps/v1
      kind: Deployment
      name: victoria-metrics-global-grafana
      namespace: observability
```

**Location Apps:** `kubernetes/infrastructure/observability/victoria-metrics/stack/ks.yaml`

```yaml
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: observability-victoria-metrics-stack
  namespace: flux-system
spec:
  interval: 30m
  timeout: 15m
  sourceRef:
    kind: GitRepository
    name: flux-system
  path: ./kubernetes/infrastructure/observability/victoria-metrics/stack
  prune: true
  wait: true
  dependsOn:
    - name: infrastructure-repositories-oci
    - name: infrastructure-networking-cilium-clustermesh  # For remote-write to infra
  postBuild:
    substituteFrom:
      - kind: ConfigMap
        name: cluster-settings
  healthChecks:
    - apiVersion: apps/v1
      kind: Deployment
      name: vmagent-victoria-metrics
      namespace: observability
    - apiVersion: apps/v1
      kind: Deployment
      name: kube-state-metrics-victoria-metrics
      namespace: observability
    - apiVersion: apps/v1
      kind: DaemonSet
      name: node-exporter-victoria-metrics
      namespace: observability
```

**Acceptance:** Flux Kustomizations created with health checks and dependencies

### T8: Local Validation

**Steps:**

1. **Validate HelmRelease Syntax:**
   ```bash
   kubectl --dry-run=client -f kubernetes/infrastructure/observability/victoria-metrics/global/helmrelease.yaml apply
   kubectl --dry-run=client -f kubernetes/infrastructure/observability/victoria-metrics/stack/helmrelease.yaml apply
   ```

2. **Validate ExternalSecret:**
   ```bash
   kubectl --dry-run=client -f kubernetes/infrastructure/observability/victoria-metrics/global/externalsecret.yaml apply
   ```

3. **Build Kustomizations:**
   ```bash
   kustomize build kubernetes/infrastructure/observability/victoria-metrics/global/
   kustomize build kubernetes/infrastructure/observability/victoria-metrics/stack/
   ```

4. **Validate Flux Kustomizations:**
   ```bash
   flux build kustomization observability-victoria-metrics-global \
     --path kubernetes/infrastructure/observability/victoria-metrics/global/ \
     --kustomization-file kubernetes/infrastructure/observability/victoria-metrics/global/ks.yaml

   flux build kustomization observability-victoria-metrics-stack \
     --path kubernetes/infrastructure/observability/victoria-metrics/stack/ \
     --kustomization-file kubernetes/infrastructure/observability/victoria-metrics/stack/ks.yaml
   ```

5. **Validate NetworkPolicy and PDB Syntax:**
   ```bash
   kubectl --dry-run=client -f kubernetes/infrastructure/observability/victoria-metrics/global/networkpolicy.yaml apply
   kubectl --dry-run=client -f kubernetes/infrastructure/observability/victoria-metrics/global/pdb.yaml apply
   ```

6. **Validate PrometheusRule:**
   ```bash
   kubectl --dry-run=client -f kubernetes/infrastructure/observability/victoria-metrics/global/prometheusrule.yaml apply
   ```

7. **Schema Validation (if kubeconform available):**
   ```bash
   kubeconform -strict kubernetes/infrastructure/observability/victoria-metrics/global/
   kubeconform -strict kubernetes/infrastructure/observability/victoria-metrics/stack/
   ```

**Acceptance:** All manifests validate successfully with no errors

### T9: Update Observability Infrastructure Kustomization

**Location:** `kubernetes/infrastructure/observability/kustomization.yaml`

**Update to include:**
```yaml
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: infrastructure-observability
  namespace: flux-system
spec:
  interval: 30m
  sourceRef:
    kind: GitRepository
    name: flux-system
  path: ./kubernetes/infrastructure/observability
  prune: false
  wait: false
  dependsOn:
    - name: infrastructure-repositories-oci
```

**Acceptance:** Infrastructure kustomization updated

### T10: Update Cluster Settings

**Infra Cluster** (`kubernetes/clusters/infra/cluster-settings.yaml`):

**Add:**
```yaml
  # VictoriaMetrics Global
  GLOBAL_VM_INSERT_ENDPOINT: "http://vminsert-victoria-metrics-global-vmcluster.observability.svc.cluster.local:8480"
  GLOBAL_VM_SELECT_ENDPOINT: "http://vmselect-victoria-metrics-global-vmcluster.observability.svc.cluster.local:8481"
  GLOBAL_ALERTMANAGER_ENDPOINT: "http://vmalertmanager-victoria-metrics-global.observability.svc.cluster.local:9093"
  OBSERVABILITY_GRAFANA_SECRET_PATH: "kubernetes/infra/observability/grafana-admin"
  VM_RETENTION_PERIOD: "30d"
  VM_STORAGE_SIZE: "50Gi"
```

**Apps Cluster** (`kubernetes/clusters/apps/cluster-settings.yaml`):

**Add:**
```yaml
  # VictoriaMetrics Remote-Write
  GLOBAL_VM_INSERT_ENDPOINT: "http://vminsert-victoria-metrics-global-vmcluster.observability.svc.infra.cluster.local:8480"
  CLUSTER: "apps"
```

**Acceptance:** Cluster settings updated with VictoriaMetrics endpoints

### T11: Commit to Git

**Steps:**
1. Stage all created manifests
2. Commit with message:
   ```
   feat(observability): add VictoriaMetrics stack manifests

   - Infra: vmcluster, vmauth, vmalert, alertmanager, Grafana
   - Apps: vmagent with remote-write to infra cluster
   - NetworkPolicies for vm component communication
   - PodDisruptionBudgets for HA protection
   - PrometheusRules for health monitoring
   - Flux Kustomizations with health checks

   Story: STORY-OBS-VM-STACK
   ```

**Acceptance:** All manifests committed to git

## Runtime Validation (MOVED TO STORY 45)

**IMPORTANT:** The following validation steps are **NOT** part of this story. They will be executed in Story 45 after all manifests are created and deployed.

### Infra Cluster Validation

**1. Verify victoria-metrics-operator CRDs:**
```bash
kubectl --context=infra get crds | grep victoriametrics
# Expected: vmagents, vmalerts, vmalertmanagers, vmauths, vmclusters, etc.
```

**2. Verify VMCluster deployment:**
```bash
kubectl --context=infra -n observability get vmcluster
# Expected: victoria-metrics-global, AVAILABLE: true

kubectl --context=infra -n observability get pods -l app.kubernetes.io/component=vmstorage
# Expected: 3 vmstorage pods Running

kubectl --context=infra -n observability get pods -l app.kubernetes.io/component=vmselect
# Expected: 3 vmselect pods Running

kubectl --context=infra -n observability get pods -l app.kubernetes.io/component=vminsert
# Expected: 3 vminsert pods Running
```

**3. Verify vmauth and vmalert:**
```bash
kubectl --context=infra -n observability get deploy vmauth-victoria-metrics-global
# Expected: READY 1/1

kubectl --context=infra -n observability get deploy vmalert-victoria-metrics-global
# Expected: READY 2/2
```

**4. Verify Alertmanager:**
```bash
kubectl --context=infra -n observability get statefulset alertmanager-victoria-metrics-global
# Expected: READY 3/3
```

**5. Verify Grafana:**
```bash
kubectl --context=infra -n observability get deploy victoria-metrics-global-grafana
# Expected: READY 2/2

kubectl --context=infra -n observability get secret grafana-admin
# Expected: Exists with admin-user, admin-password keys
```

**6. Test VictoriaMetrics query endpoint:**
```bash
kubectl --context=infra -n observability port-forward svc/vmselect-victoria-metrics-global-vmcluster 8481:8481 &
curl -sf http://127.0.0.1:8481/select/0/prometheus/api/v1/labels | jq
# Expected: JSON response with label names
```

**7. Test Grafana access:**
```bash
kubectl --context=infra -n observability port-forward svc/victoria-metrics-global-grafana 3000:80 &
# Open browser to http://localhost:3000
# Login with credentials from grafana-admin secret
```

### Apps Cluster Validation

**1. Verify vmagent deployment:**
```bash
kubectl --context=apps -n observability get deploy vmagent-victoria-metrics
# Expected: READY 2/2
```

**2. Verify exporters:**
```bash
kubectl --context=apps -n observability get deploy kube-state-metrics-victoria-metrics
# Expected: READY 1/1

kubectl --context=apps -n observability get daemonset node-exporter-victoria-metrics
# Expected: DESIRED matches READY
```

**3. Check vmagent remote-write:**
```bash
kubectl --context=apps -n observability logs deploy/vmagent-victoria-metrics | grep -i "remote write"
# Expected: Successful remote-write logs with 2xx responses
```

**4. Verify vmagent metrics collection:**
```bash
kubectl --context=apps -n observability logs deploy/vmagent-victoria-metrics | grep -i "scraped"
# Expected: Scrape success logs
```

**5. Check ServiceMonitors discovered:**
```bash
kubectl --context=apps -n observability exec deploy/vmagent-victoria-metrics -- wget -qO- http://localhost:8429/targets | grep -c "job="
# Expected: Multiple targets discovered
```

### Cross-Cluster Validation

**1. Verify remote-write from apps to infra:**
```bash
# On infra cluster, query for metrics with cluster="apps" label
kubectl --context=infra -n observability port-forward svc/vmselect-victoria-metrics-global-vmcluster 8481:8481 &
curl -s 'http://127.0.0.1:8481/select/0/prometheus/api/v1/query?query=up{cluster="apps"}' | jq
# Expected: Metrics from apps cluster visible
```

**2. Verify ClusterMesh DNS resolution (apps → infra):**
```bash
kubectl --context=apps -n observability exec deploy/vmagent-victoria-metrics -- nslookup vminsert-victoria-metrics-global-vmcluster.observability.svc.infra.cluster.local
# Expected: Resolves to infra cluster IP
```

### Alert Rule Validation

**1. Verify PrometheusRules loaded:**
```bash
kubectl --context=infra -n observability get vmrule
# Expected: victoria-metrics-health and business-metrics rules

kubectl --context=infra -n observability logs deploy/vmalert-victoria-metrics-global | grep -i "rules loaded"
# Expected: Confirmation of rule loading
```

**2. Test alert firing:**
```bash
# Trigger test alert by scaling down vmstorage
kubectl --context=infra -n observability scale statefulset vmstorage-victoria-metrics-global-vmcluster --replicas=2

# Wait 5 minutes, check vmalert
kubectl --context=infra -n observability port-forward svc/vmalert-victoria-metrics-global 8880:8880 &
curl http://127.0.0.1:8880/api/v1/alerts | jq
# Expected: VMStorageDown alert in pending/firing state

# Scale back up
kubectl --context=infra -n observability scale statefulset vmstorage-victoria-metrics-global-vmcluster --replicas=3
```

**3. Verify Alertmanager receives alerts:**
```bash
kubectl --context=infra -n observability port-forward svc/vmalertmanager-victoria-metrics-global 9093:9093 &
curl http://127.0.0.1:9093/api/v2/alerts | jq
# Expected: List of active alerts
```

### Performance Validation

**1. Check metrics ingestion rate:**
```bash
kubectl --context=infra -n observability port-forward svc/vmselect-victoria-metrics-global-vmcluster 8481:8481 &
curl -s 'http://127.0.0.1:8481/select/0/prometheus/api/v1/query?query=rate(vm_rows_inserted_total[5m])' | jq
# Expected: Non-zero ingestion rate
```

**2. Check storage usage:**
```bash
kubectl --context=infra -n observability get pvc -l app.kubernetes.io/component=vmstorage
# Expected: 3 PVCs with increasing CAPACITY usage
```

**3. Check query performance:**
```bash
# Run sample query and check duration
time curl -s 'http://127.0.0.1:8481/select/0/prometheus/api/v1/query?query=up'
# Expected: Response time < 1s for simple query
```

### Dashboard Validation

**1. Verify Grafana datasource connectivity:**
```bash
# Login to Grafana, navigate to Configuration → Data Sources
# Test VictoriaMetrics datasource connection
# Expected: "Data source is working"
```

**2. Create test dashboard:**
```bash
# In Grafana, create new dashboard
# Add panel with query: up{job="vmstorage"}
# Expected: Time series graph showing vmstorage instances
```

**3. Verify dashboard auto-discovery:**
```bash
kubectl --context=infra -n observability get configmap -l grafana_dashboard=1
# Expected: Dashboard ConfigMaps if configured
```

## Definition of Done

### Manifest Creation Complete (This Story)

- [x] Infra global stack manifests created (vmcluster, vmauth, vmalert, alertmanager, Grafana)
- [x] Apps cluster vmagent manifests created with remote-write configuration
- [x] NetworkPolicy manifests created for vm component communication
- [x] PodDisruptionBudget manifests created for HA protection
- [x] PrometheusRule manifests created for health monitoring
- [x] Flux Kustomization manifests created with health checks and dependencies
- [x] ExternalSecret manifest created for Grafana admin credentials
- [x] Cluster settings updated with VictoriaMetrics endpoints
- [x] All manifests validate successfully using local tools (flux build, kubectl --dry-run)
- [x] Manifests committed to git repository
- [x] Documentation complete with architecture and configuration details

### NOT Part of DoD (Moved to Story 45)

**Deployment Validation:**
- victoria-metrics-operator CRDs installed and Ready
- Infra vmcluster pods Running (vmselect/vminsert/vmstorage)
- vmauth and vmalert Deployments Available
- Alertmanager StatefulSet Ready with 3 replicas
- Grafana accessible with admin credentials
- Apps vmagent successfully remote-writes to infra cluster
- Cross-cluster metrics visible in vmselect queries
- Alert rules loaded and test alerts firing
- Dashboards render with live metrics data
- Performance metrics within acceptable ranges

**Performance Validation:**
- Query latency P99 < 5s
- Metrics ingestion rate > 1000 samples/s
- Remote-write success rate > 99%
- Storage usage within planned capacity

**Observability Validation:**
- All vm components have ServiceMonitors
- Health checks passing in Flux Kustomizations
- PodDisruptionBudgets preventing unsafe disruptions
- NetworkPolicies allowing required traffic only

## Design Notes

### VictoriaMetrics Architecture

**VMCluster Components:**
- **vmstorage**: Stores raw samples and indexes, handles data retention
- **vminsert**: Accepts incoming metrics, routes to vmstorage shards
- **vmselect**: Executes queries, aggregates data from vmstorage nodes

**Key Characteristics:**
- Horizontal scalability (add more replicas)
- No single point of failure with 3 replicas
- 2x replication factor for data durability
- 30-day retention period (configurable)

### Grafana Integration

**Admin Credentials:**
- Stored in 1Password at `${OBSERVABILITY_GRAFANA_SECRET_PATH}`
- Retrieved via ExternalSecret operator
- Mounted as Secret with keys: `admin-user`, `admin-password`

**Data Sources:**
- VictoriaMetrics (default): Query endpoint at vmselect
- Alertmanager: Alert viewing and silencing

**Dashboard Provisioning:**
- Auto-discovery from ConfigMaps with label `grafana_dashboard=1`
- Custom dashboards in `/var/lib/grafana/dashboards/default`

### Multi-Cluster Remote-Write

**Architecture:**
- Apps cluster vmagent scrapes local ServiceMonitors
- Remote-writes to infra cluster vminsert via ClusterMesh
- External label `cluster: apps` distinguishes metrics origin

**DNS Resolution:**
- Apps → Infra: `vminsert-victoria-metrics-global-vmcluster.observability.svc.infra.cluster.local`
- Requires ClusterMesh DNS (Story 13)

**Queue Configuration:**
- maxSamplesPerSend: 5000 (batch size)
- capacity: 10000 (in-memory queue)
- maxShards: 10 (parallelism)
- sendTimeout: 30s

### Alert Rule Evaluation

**vmalert Configuration:**
- Queries vmselect for metrics
- Evaluates PrometheusRules every 15s
- Sends recording rules to vminsert
- Sends alerts to Alertmanager

**Rule Organization:**
- Component health: VMStorage, VMSelect, VMInsert, VMAlert, Alertmanager
- Business metrics: Custom application rules
- SLO tracking: Availability, latency, error rate

### Storage Planning

**vmstorage:**
- 50Gi per replica × 3 replicas = 150Gi total
- 2x replication factor = ~75Gi usable
- 30-day retention with 1M samples/s ≈ 50-70Gi

**vmselect cache:**
- 10Gi per replica for query cache
- Improves repeated query performance

**Alertmanager:**
- 10Gi per replica for 120h retention
- Stores alert history and silences

### Resource Planning

**Per-Cluster Totals:**

**Infra Cluster:**
- CPU: ~10 cores (6 vmstorage + 1.5 vmselect + 0.9 vminsert + 1.5 other)
- Memory: ~17Gi (12Gi vmstorage + 1.5Gi vmselect + 1.5Gi vminsert + 2Gi other)
- Storage: ~180Gi (150Gi vmstorage + 30Gi cache/alertmanager/grafana)

**Apps Cluster:**
- CPU: ~0.5 cores (vmagent + exporters)
- Memory: ~1.5Gi (vmagent + exporters)
- Storage: None (ephemeral)

### NetworkPolicy Design

**Security Boundaries:**
- vmstorage only accepts from vmselect, vminsert (write isolation)
- vmauth routes external queries to vmselect (query gateway)
- vmalert queries vmselect, writes to vminsert, alerts to alertmanager
- vmagent (any cluster) can write to vminsert (federated collection)

**Cross-Cluster Considerations:**
- Apps vmagent egress allows ClusterMesh traffic to infra
- DNS resolution required for service discovery

### High Availability

**PodDisruptionBudgets:**
- maxUnavailable: 1 for all components
- Ensures at least 2 replicas available during node drains
- Protects against data loss and query failures

**Replication:**
- vmstorage replicationFactor: 2 (each sample stored twice)
- Survives single vmstorage failure without data loss

**Multiple Replicas:**
- 3 vmselect: Query load balancing
- 3 vminsert: Write load balancing
- 3 vmstorage: Data distribution and HA
- 2 vmalert: Rule evaluation redundancy
- 3 alertmanager: Alert routing HA

## Change Log

### v3.0 (2025-10-26) - Manifests-First Refinement

**Scope Split:**
- This story now focuses exclusively on **creating VictoriaMetrics stack manifests**
- Deployment and validation moved to Story 45

**Key Changes:**
1. Rewrote story to focus on manifest creation, not deployment
2. Split Acceptance Criteria: manifest creation vs deployment validation
3. Restructured tasks to T1-T11 pattern with local validation only
4. Added comprehensive runtime validation section (deferred to Story 45)
5. Updated DoD with clear "NOT Part of DoD" section
6. Added detailed design notes covering:
   - VictoriaMetrics architecture (vmcluster components)
   - Grafana integration with ExternalSecret credentials
   - Multi-cluster remote-write via ClusterMesh
   - Alert rule evaluation with vmalert
   - Storage and resource planning
   - NetworkPolicy security boundaries
   - High availability with PDBs and replication
7. Specified exact manifests: HelmReleases, ExternalSecret, NetworkPolicies, PDBs, PrometheusRules, Flux Kustomizations
8. Included cluster-specific configurations (infra vs apps)
9. Dependencies updated to local tools only (kubectl, flux CLI, yq, kubeconform)

**Manifest Architecture:**
- **Infra Cluster**: vmcluster (centralized storage), vmauth (query gateway), vmalert (rule evaluation), alertmanager (alert routing), Grafana (dashboards)
- **Apps Cluster**: vmagent (scraping), exporters (node-exporter, kube-state-metrics), remote-write to infra
- **Shared**: NetworkPolicies (component communication), PDBs (HA protection), PrometheusRules (health monitoring)

**Configuration Highlights:**
- 30-day retention, 50Gi per vmstorage replica (150Gi total)
- 3 replicas for vmstorage, vmselect, vminsert, alertmanager
- 2 replicas for vmalert, vmagent, Grafana
- Remote-write queue: 5000 samples/send, 10000 capacity, 10 shards
- External labels for cluster identification

**Previous Version:** Story focused on deployment with cluster access required
**Current Version:** Story focuses on manifest creation with local validation only

---

### v4.0 (2025-11-01) - Production Best Practices & Latest Versions

**Major Version Upgrades:**
- VictoriaMetrics: v1.113.0 → v1.122.1 LTS (+15 releases, 12-month support)
- victoria-metrics-k8s-stack chart: 0.29.0 → 0.61.11 (+32 releases)
- victoria-metrics-operator: 0.63.0 (already current)

**Critical Configuration Fixes:**
1. **CPU Limits Correction (10 components):**
   - Fixed all fractional CPU limits → whole units per VM best practices
   - vmstorage, vmselect: 2000m → 2
   - vminsert, vmagent, vmauth, vmalert, grafana: 500m/1000m → 1
   - alertmanager, node-exporter, kube-state-metrics: 200m → 1
   - Rationale: VictoriaMetrics docs state "Avoid fractional CPU units" for Go runtime optimization

**New Features & Enhancements:**
2. **Deduplication Configuration:**
   - Added `-dedup.minScrapeInterval=30s` to vmstorage, vmselect, vminsert
   - Reduces storage space and improves query performance
   - Automatic handling of duplicate metrics from HA setups

3. **Query Performance Optimization:**
   - Added `--search.maxPointsPerTimeseries=30000` to prevent OOM on large queries
   - Enhanced vmselect query settings for better performance

4. **Enhanced PrometheusRules (7 new alerts):**
   - **Capacity Planning:**
     - VMStorageCapacityWarning (20% free space)
     - VMStorageCapacityCritical (10% free space)
   - **Performance Monitoring:**
     - VMSelectSlowQueries (P99 latency > 10s)
     - VMSelectQueryQueueFull
   - **Operational:**
     - VMHighCardinality (>10M time series)
     - VMDeduplicationIneffective

**Documentation Updates:**
5. **Updated Documentation:**
   - VICTORIA-METRICS-IMPLEMENTATION.md: Added version info, CPU best practices, dedup config
   - VM-UPGRADE-NOTES.md: Comprehensive upgrade documentation (new)
   - victoria-metrics-operations.md: Operations runbook (new)
   - STORY-PROGRESS.md: Updated Story 17 status

**Architecture Decisions:**
6. **Replication Factor:** Kept RF=2 (adequate for production, tolerates 1 node failure)
7. **Version Strategy:** LTS v1.122.1 chosen for production stability over latest v1.128.0
8. **Storage:** Continued use of ceph-block (Rook-Ceph) for production reliability

**Risk Mitigation:**
- Comprehensive CHANGELOG review (chart 0.29.0 → 0.61.11)
- All breaking changes analyzed (none affect our deployment)
- Rollback procedure documented (Git revert + Flux reconcile)
- Staged deployment planned (infra first, then apps)

**Files Modified (10):**
- kubernetes/clusters/infra/cluster-settings.yaml
- kubernetes/clusters/apps/cluster-settings.yaml
- kubernetes/infrastructure/observability/victoria-metrics/vmcluster/helmrelease.yaml
- kubernetes/infrastructure/observability/victoria-metrics/vmagent/helmrelease.yaml
- kubernetes/infrastructure/observability/victoria-metrics/vmcluster/prometheusrule.yaml
- docs/observability/VICTORIA-METRICS-IMPLEMENTATION.md
- docs/stories/STORY-OBS-VM-STACK.md
- docs/STORY-PROGRESS.md
- docs/observability/VM-UPGRADE-NOTES.md (new)
- docs/runbooks/victoria-metrics-operations.md (new)

**Validation:**
- All manifests validated with kubectl --dry-run
- Kustomization builds successful
- Flux builds successful
- Resource calculations verified

**Deployment:**
- Actual deployment deferred to Story 45 (GitOps principle: manifest creation first)
- Deployment strategy: Staged (infra → apps)
- Monitoring period: 24-48 hours post-deployment

**Previous Version:** v3.0 - Manifests-first refinement
**Current Version:** v4.0 - Production best practices with latest stable versions
