# 40 — STORY-OBS-APPS-COLLECTORS — Create Apps Cluster Observability Collectors Manifests

Sequence: 40/50 | Prev: STORY-MSG-SCHEMA-REGISTRY.md | Next: STORY-GITOPS-SELF-MGMT-FLUX.md
Sprint: 4 | Lane: Observability
Global Sequence: 40/50

Status: v3.0-Manifests-Only
Owner: Platform Engineering
Date: 2025-10-26
Links: docs/architecture.md §11 (Observability Strategy); kubernetes/workloads/platform/observability/apps-collectors; STORY-OBS-VM-STACK-IMPLEMENT.md; STORY-OBS-VICTORIA-LOGS-IMPLEMENT.md

## Story (v3.0 Refined)

As a Platform Engineer, I want to **create complete manifests for lightweight observability collectors** on the apps cluster (vmagent, kube-state-metrics, node-exporter, fluent-bit) that forward all metrics and logs to the central observability stack (VictoriaMetrics + VictoriaLogs + Grafana) on the infra cluster, enabling comprehensive monitoring of apps cluster workloads without duplicating the full observability stack.

**v3.0 Scope**: This story creates ALL manifest files for observability collectors on the apps cluster (HelmReleases, Deployments, DaemonSets, ConfigMaps, NetworkPolicies, ServiceMonitors, Kustomization files, cluster entrypoint). **Deployment and runtime validation** (pods Running, metrics/logs forwarding verification) are **deferred to Story 45 (STORY-DEPLOY-VALIDATE-ALL)**.

## Why / Outcome

- Centralizes all observability data on infra cluster (single pane of glass)
- Minimizes resource overhead on apps cluster (collectors only, no TSDB/storage)
- Enables cross-cluster monitoring and correlation
- Follows architecture §11 "Apps Cluster: Leaf Observability Pack" pattern
- Foundation for alerting on apps cluster workloads
- **v3.0**: Complete manifest creation enables rapid deployment in Story 45

## Scope

**In Scope (This Story - Manifest Creation)**:
- Cluster: apps
- Namespace: **`observability`** (with `pod-security.kubernetes.io/enforce=privileged` for node-exporter and fluent-bit)
- Components (Architecture §11 reference):
  - **vmagent** - Scrapes Prometheus-compatible metrics and remote-writes to infra VictoriaMetrics
    - HelmRelease using victoria-metrics-agent chart
    - Scrape configs: kube-state-metrics, node-exporter, kubelet, cAdvisor, ServiceMonitors
    - Remote write to `victoria-metrics-global-vminsert.observability.svc.cluster.local:8480`
    - External label: `cluster=apps`
  - **kube-state-metrics** - Generates Kubernetes object state metrics (scraped by vmagent)
    - Deployment (1 replica)
    - Version: v2.14.0
    - RBAC: ClusterRole with list/watch on all resources
  - **node-exporter** - Exposes host/OS metrics (CPU, memory, disk, network) per node (scraped by vmagent)
    - DaemonSet with hostNetwork, hostPID, hostPath
    - Version: v1.8.2
    - Talos-compatible configuration
  - **fluent-bit** - Ships container/kubelet/audit logs to infra VictoriaLogs
    - DaemonSet with hostPath for `/var/log`
    - Version: 3.2.2
    - CRI parser (containerd format, Talos-compatible)
    - Forwards to `victorialogs-vmauth.observability.svc.cluster.local:9428/insert`
    - Labels: `cluster=apps`, `tenant=${OBSERVABILITY_LOG_TENANT}`
- Additional Resources:
  - **Namespace manifest** with PSS labels (privileged)
  - **NetworkPolicy** for egress to infra cluster
  - **ServiceMonitors** for collectors self-monitoring
  - **Kustomization files** for resource composition
  - **Cluster Kustomization** entrypoint in `kubernetes/clusters/apps/`
- Documentation:
  - Comprehensive runbook with collector endpoints, operations, troubleshooting

Architecture Pattern:
```
Apps Cluster (collectors) → Infra Cluster (storage/visualization)
vmagent → VictoriaMetrics vminsert (remote write HTTP)
fluent-bit → VictoriaLogs vmauth (HTTP JSON)
```

**Out of Scope (Deferred to Story 45)**:
- Deployment and runtime validation (pods Running, metrics/logs forwarding)
- Verification of metrics in infra VictoriaMetrics
- Verification of logs in infra VictoriaLogs
- Network connectivity testing (cross-cluster)
- Performance testing and tuning

**Non-Goals**:
- Full VictoriaMetrics stack on apps cluster (infra only)
- Grafana deployment (infra only)
- Alertmanager deployment (infra only)
- Long-term metrics/logs storage (infra only)
- OpenTelemetry Collector (future enhancement)

## Acceptance Criteria (Manifest Completeness)

All criteria focus on **manifest existence and correctness**, NOT runtime behavior.

**AC1** (Task T2): vmagent HelmRelease manifest exists with:
- Chart: victoria-metrics-agent (version 0.13.x)
- Remote write URL: `http://${GLOBAL_VM_INSERT_ENDPOINT}/insert/0/prometheus/api/v1/write`
- External label: `cluster: apps`
- Scrape configs for: kube-state-metrics, node-exporter, kubelet, cAdvisor
- ServiceMonitor/PodMonitor discovery enabled
- Resource requests/limits (100m/500m CPU, 256Mi/512Mi memory)
- RBAC: ServiceAccount, ClusterRole, ClusterRoleBinding

**AC2** (Task T3): kube-state-metrics manifests exist:
- Deployment (1 replica)
- Image: registry.k8s.io/kube-state-metrics/kube-state-metrics:v2.14.0
- Service exposing port 8080 (http-metrics) and 8081 (telemetry)
- ServiceAccount, ClusterRole (list/watch all resources), ClusterRoleBinding
- Resource requests/limits (10m/200m CPU, 64Mi/128Mi memory)
- Liveness/readiness probes

**AC3** (Task T4): node-exporter manifests exist:
- DaemonSet with hostNetwork, hostPID, hostPath
- Image: quay.io/prometheus/node-exporter:v1.8.2
- Talos-compatible configuration (path.sysfs, path.rootfs, filesystem excludes)
- Headless Service on port 9100
- Tolerations for all nodes
- Resource requests/limits (50m/200m CPU, 64Mi/128Mi memory)

**AC4** (Task T5): fluent-bit manifests exist:
- DaemonSet with hostPath for `/var/log`
- Image: fluent/fluent-bit:3.2.2
- ConfigMap with CRI parser (containerd format, Talos-compatible)
- Kubernetes filter for pod metadata enrichment
- HTTP output to VictoriaLogs with cluster/tenant labels
- ServiceAccount, ClusterRole (get/list/watch pods/namespaces), ClusterRoleBinding
- Resource requests/limits (50m/200m CPU, 128Mi/256Mi memory)

**AC5** (Task T6): Namespace manifest exists:
- Name: `observability`
- PSS labels: `pod-security.kubernetes.io/enforce=privileged` (required for node-exporter and fluent-bit)

**AC6** (Task T7): NetworkPolicy manifest exists:
- Egress rules for:
  - DNS resolution (kube-system/coredns)
  - kube-apiserver access (port 443)
  - Infra cluster observability endpoints (vminsert :8480, VictoriaLogs :9428)

**AC7** (Task T8): ServiceMonitor manifests exist for:
- kube-state-metrics (port http-metrics, interval 30s)
- node-exporter (port metrics, interval 30s)
- vmagent self-monitoring (if supported by chart)

**AC8** (Task T9): Kustomization files exist:
- Root kustomization.yaml referencing all components
- Subdirectory kustomizations for vmagent, kube-state-metrics, node-exporter, fluent-bit

**AC9** (Task T10): Cluster Kustomization entrypoint created:
- File: `kubernetes/clusters/apps/workloads.yaml` (or update existing)
- Flux Kustomization CR for `apps-observability-collectors`
- `dependsOn: apps-infrastructure` (ensure CRDs and repos available)
- Health checks on Deployment (kube-state-metrics), DaemonSets (node-exporter, fluent-bit)

**AC10** (Task T11): Documentation created:
- Comprehensive runbook: `docs/runbooks/observability-collectors-apps.md`
- Collector endpoints, operations, troubleshooting
- Cross-cluster metrics/logs verification guide

**AC11** (Task T12): Local validation confirms:
- `kubectl kustomize` builds without errors
- `flux build` succeeds on Kustomization
- No YAML syntax errors
- All cross-references valid (Service selectors, health checks)

**AC12** (Task T12): Manifest files committed to Git:
- All files in `kubernetes/workloads/platform/observability/apps-collectors/`
- Cluster Kustomization updated
- Runbook in `docs/runbooks/`

**AC13** (Task T12): Story marked complete:
- All tasks T1-T12 completed
- Change log entry added
- Ready for deployment in Story 45

## Dependencies / Inputs

**Build-Time (This Story)**:
- STORY-OBS-VM-STACK-IMPLEMENT completed (VictoriaMetrics manifests exist on infra cluster)
- STORY-OBS-VICTORIA-LOGS-IMPLEMENT completed (VictoriaLogs manifests exist on infra cluster)
- `kubernetes/workloads/platform/observability/` directory structure exists
- VictoriaMetrics Helm repository configured
- Flux GitRepository configured
- Local tools: `kubectl`, `kustomize`, `flux`, `yq`

**Runtime (Story 45)**:
- Apps cluster bootstrapped and healthy
- Infra cluster VictoriaMetrics operational
- Infra cluster VictoriaLogs operational
- Cluster settings configured:
  - `GLOBAL_VM_INSERT_ENDPOINT: "victoria-metrics-global-vminsert.observability.svc.cluster.local:8480"`
  - `OBSERVABILITY_LOG_ENDPOINT_HOST: "victorialogs-vmauth.observability.svc.cluster.local"`
  - `OBSERVABILITY_LOG_ENDPOINT_PORT: "9428"`
  - `OBSERVABILITY_LOG_ENDPOINT_PATH: "/insert"`
  - `OBSERVABILITY_LOG_TENANT: "apps"`
- Cross-cluster network connectivity (Cilium ClusterMesh or static routes)

## Tasks / Subtasks — Manifest Creation Plan

### T1 — Prerequisites and Strategy (30 min)

**Goal**: Validate environment and finalize observability collectors architecture.

- [ ] T1.1 — Verify prerequisite stories completed
  - [ ] Read STORY-OBS-VM-STACK-IMPLEMENT.md (verify VictoriaMetrics manifests exist on infra)
  - [ ] Read STORY-OBS-VICTORIA-LOGS-IMPLEMENT.md (verify VictoriaLogs manifests exist on infra)
  - [ ] Confirm `kubernetes/workloads/platform/observability/` directory exists

- [ ] T1.2 — Review architecture requirements
  - [ ] Architecture doc §11: Apps Cluster "Leaf Observability Pack" pattern
  - [ ] VictoriaMetrics remote write endpoint: `victoria-metrics-global-vminsert.observability.svc.cluster.local:8480`
  - [ ] VictoriaLogs insert endpoint: `victorialogs-vmauth.observability.svc.cluster.local:9428/insert`
  - [ ] External label: `cluster=apps` (for multi-cluster differentiation)
  - [ ] Log tenant: `apps` (for multi-tenancy in VictoriaLogs)

- [ ] T1.3 — Finalize collector configuration
  - [ ] **vmagent**: HelmRelease with scrape configs and remote write
  - [ ] **kube-state-metrics**: Deployment v2.14.0
  - [ ] **node-exporter**: DaemonSet v1.8.2 (Talos-compatible)
  - [ ] **fluent-bit**: DaemonSet v3.2.2 (CRI parser for containerd)
  - [ ] **Namespace**: PSS privileged (required for node-exporter hostNetwork, fluent-bit hostPath)
  - [ ] **NetworkPolicy**: Egress to infra cluster observability endpoints

- [ ] T1.4 — Document design decisions
  - [ ] Why HelmRelease for vmagent: Simplifies configuration, maintained by VictoriaMetrics team
  - [ ] Why raw manifests for kube-state-metrics/node-exporter/fluent-bit: Lightweight, no Helm overhead
  - [ ] Why PSS privileged: node-exporter requires hostNetwork/hostPID, fluent-bit requires hostPath
  - [ ] Why CRI parser: Talos uses containerd (NOT Docker)

### T2 — Create vmagent HelmRelease (1.5 hours)

**Goal**: Create comprehensive vmagent HelmRelease for metrics scraping and remote write.

- [ ] T2.1 — Create directory structure
  - [ ] Create `kubernetes/workloads/platform/observability/apps-collectors/vmagent/`

- [ ] T2.2 — Create HelmRepository (if not exists)
  - [ ] Check if `kubernetes/infrastructure/repositories/helm/victoria-metrics.yaml` exists
  - [ ] If not, create:
    ```yaml
    apiVersion: source.toolkit.fluxcd.io/v1
    kind: HelmRepository
    metadata:
      name: victoria-metrics
      namespace: flux-system
    spec:
      interval: 1h
      url: https://victoriametrics.github.io/helm-charts/
    ```

- [ ] T2.3 — Create vmagent HelmRelease manifest
  - [ ] Create `kubernetes/workloads/platform/observability/apps-collectors/vmagent/helmrelease.yaml`
  - [ ] Metadata:
    - name: `vmagent`
    - namespace: `observability`
  - [ ] Spec:
    - interval: 30m
    - timeout: 10m
    - chart: victoria-metrics-agent (version 0.13.x)
    - sourceRef: HelmRepository victoria-metrics
  - [ ] Values:
    - remoteWriteUrls: `["http://${GLOBAL_VM_INSERT_ENDPOINT}/insert/0/prometheus/api/v1/write"]`
    - extraArgs:
      - promscrape.suppressDuplicateScrapeTargetErrors: "true"
    - config:
      - global:
        - scrape_interval: 30s
        - external_labels: `cluster: apps`
      - scrape_configs:
        - kube-state-metrics (static_config)
        - node-exporter (kubernetes_sd_configs role=endpoints)
        - kubelet (kubernetes_sd_configs role=node, HTTPS, bearer token)
        - cAdvisor (kubernetes_sd_configs role=node, HTTPS, metrics_path=/metrics/cadvisor)
    - serviceMonitor:
      - enabled: true (for ServiceMonitor/PodMonitor discovery)
      - extraLabels: `prometheus: kube-prometheus`
    - resources:
      - requests: 100m CPU, 256Mi memory
      - limits: 500m CPU, 512Mi memory
    - rbac: create: true
    - serviceAccount: create: true, name: vmagent

- [ ] T2.4 — Create vmagent Kustomization
  - [ ] Create `kubernetes/workloads/platform/observability/apps-collectors/vmagent/kustomization.yaml`
  - [ ] apiVersion: kustomize.config.k8s.io/v1beta1
  - [ ] resources: [helmrelease.yaml]
  - [ ] namespace: observability

- [ ] T2.5 — Validate vmagent HelmRelease
  - [ ] `kubectl apply --dry-run=client -f vmagent/helmrelease.yaml`
  - [ ] Check YAML syntax

### T3 — Create kube-state-metrics Manifests (1 hour)

**Goal**: Create kube-state-metrics Deployment for Kubernetes object state metrics.

- [ ] T3.1 — Create directory structure
  - [ ] Create `kubernetes/workloads/platform/observability/apps-collectors/kube-state-metrics/`

- [ ] T3.2 — Create Deployment manifest
  - [ ] Create `kubernetes/workloads/platform/observability/apps-collectors/kube-state-metrics/deployment.yaml`
  - [ ] Metadata:
    - name: `kube-state-metrics`
    - namespace: `observability`
    - labels: `app.kubernetes.io/name=kube-state-metrics`
  - [ ] Spec:
    - replicas: 1 (single replica sufficient for apps cluster)
    - selector: `app.kubernetes.io/name=kube-state-metrics`
    - template:
      - serviceAccountName: kube-state-metrics
      - containers:
        - name: kube-state-metrics
        - image: registry.k8s.io/kube-state-metrics/kube-state-metrics:v2.14.0
        - ports: 8080 (http-metrics), 8081 (telemetry)
        - livenessProbe: httpGet /healthz port 8080, initialDelay 5s
        - readinessProbe: httpGet / port 8081, initialDelay 5s
        - resources: requests 10m/64Mi, limits 200m/128Mi

- [ ] T3.3 — Create Service manifest
  - [ ] Create `kubernetes/workloads/platform/observability/apps-collectors/kube-state-metrics/service.yaml`
  - [ ] Metadata:
    - name: `kube-state-metrics`
    - namespace: `observability`
    - labels: `app.kubernetes.io/name=kube-state-metrics`
  - [ ] Spec:
    - type: ClusterIP
    - ports: 8080 (http-metrics), 8081 (telemetry)
    - selector: `app.kubernetes.io/name=kube-state-metrics`

- [ ] T3.4 — Create RBAC manifests
  - [ ] Create `kubernetes/workloads/platform/observability/apps-collectors/kube-state-metrics/rbac.yaml`
  - [ ] ServiceAccount: name kube-state-metrics
  - [ ] ClusterRole: name kube-state-metrics
    - rules:
      - apiGroups: [""] resources: ["*"] verbs: ["list", "watch"]
      - apiGroups: ["apps"] resources: ["*"] verbs: ["list", "watch"]
      - apiGroups: ["batch"] resources: ["*"] verbs: ["list", "watch"]
      - apiGroups: ["autoscaling"] resources: ["*"] verbs: ["list", "watch"]
      - apiGroups: ["policy"] resources: ["*"] verbs: ["list", "watch"]
      - apiGroups: ["networking.k8s.io"] resources: ["*"] verbs: ["list", "watch"]
  - [ ] ClusterRoleBinding: name kube-state-metrics
    - roleRef: ClusterRole kube-state-metrics
    - subjects: ServiceAccount kube-state-metrics (namespace observability)

- [ ] T3.5 — Create kube-state-metrics Kustomization
  - [ ] Create `kubernetes/workloads/platform/observability/apps-collectors/kube-state-metrics/kustomization.yaml`
  - [ ] resources: [deployment.yaml, service.yaml, rbac.yaml]
  - [ ] namespace: observability

- [ ] T3.6 — Validate kube-state-metrics manifests
  - [ ] `kubectl apply --dry-run=client -k kube-state-metrics/`
  - [ ] No errors

### T4 — Create node-exporter Manifests (1 hour)

**Goal**: Create node-exporter DaemonSet for host/OS metrics (Talos-compatible).

- [ ] T4.1 — Create directory structure
  - [ ] Create `kubernetes/workloads/platform/observability/apps-collectors/node-exporter/`

- [ ] T4.2 — Create DaemonSet manifest
  - [ ] Create `kubernetes/workloads/platform/observability/apps-collectors/node-exporter/daemonset.yaml`
  - [ ] Metadata:
    - name: `node-exporter`
    - namespace: `observability`
    - labels: `app.kubernetes.io/name=node-exporter`
  - [ ] Spec:
    - selector: `app.kubernetes.io/name=node-exporter`
    - template:
      - hostNetwork: true (required for network metrics)
      - hostPID: true (required for process metrics)
      - containers:
        - name: node-exporter
        - image: quay.io/prometheus/node-exporter:v1.8.2
        - args:
          - --path.sysfs=/host/sys
          - --path.rootfs=/host/root
          - --no-collector.wifi
          - --no-collector.hwmon
          - --collector.filesystem.mount-points-exclude=^/(dev|proc|sys|var/lib/docker/.+|var/lib/kubelet/.+)($|/)
          - --collector.netclass.ignored-devices=^(veth.*|[a-f0-9]{15})$
          - --collector.netdev.device-exclude=^(veth.*|[a-f0-9]{15})$
        - ports: 9100 (metrics, hostPort)
        - resources: requests 50m/64Mi, limits 200m/128Mi
        - volumeMounts:
          - name: sys, mountPath: /host/sys, readOnly: true
          - name: root, mountPath: /host/root, readOnly: true, mountPropagation: HostToContainer
      - tolerations: operator Exists (run on all nodes including tainted)
      - volumes:
        - name: sys, hostPath: path /sys
        - name: root, hostPath: path /

- [ ] T4.3 — Create Service manifest (headless)
  - [ ] Create `kubernetes/workloads/platform/observability/apps-collectors/node-exporter/service.yaml`
  - [ ] Metadata:
    - name: `node-exporter`
    - namespace: `observability`
    - labels: `app.kubernetes.io/name=node-exporter`
  - [ ] Spec:
    - type: ClusterIP
    - clusterIP: None (headless service for DaemonSet)
    - ports: 9100 (metrics)
    - selector: `app.kubernetes.io/name=node-exporter`

- [ ] T4.4 — Create node-exporter Kustomization
  - [ ] Create `kubernetes/workloads/platform/observability/apps-collectors/node-exporter/kustomization.yaml`
  - [ ] resources: [daemonset.yaml, service.yaml]
  - [ ] namespace: observability

- [ ] T4.5 — Validate node-exporter manifests
  - [ ] `kubectl apply --dry-run=client -k node-exporter/`
  - [ ] No errors

### T5 — Create fluent-bit Manifests (1.5 hours)

**Goal**: Create fluent-bit DaemonSet for log forwarding (Talos/containerd-compatible).

- [ ] T5.1 — Create directory structure
  - [ ] Create `kubernetes/workloads/platform/observability/apps-collectors/fluent-bit/`

- [ ] T5.2 — Create ConfigMap manifest
  - [ ] Create `kubernetes/workloads/platform/observability/apps-collectors/fluent-bit/configmap.yaml`
  - [ ] ConfigMap name: `fluent-bit-config`
  - [ ] Data key: `fluent-bit.conf`
    - [SERVICE]:
      - Flush: 5
      - Daemon: off
      - Log_Level: info
    - [INPUT]:
      - Name: tail
      - Path: /var/log/containers/*.log (Talos containerd logs location)
      - Parser: cri (containerd CRI format)
      - Tag: kube.*
      - DB: /var/log/flb_kube.db (persist position)
      - Mem_Buf_Limit: 5MB
      - Skip_Long_Lines: On
      - Refresh_Interval: 10
    - [FILTER]:
      - Name: kubernetes (enrich with pod metadata)
      - Match: kube.*
      - Kube_URL: https://kubernetes.default.svc:443
      - Kube_CA_File: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
      - Kube_Token_File: /var/run/secrets/kubernetes.io/serviceaccount/token
      - Merge_Log: On
      - Keep_Log: Off
      - K8S-Logging.Parser: On
      - K8S-Logging.Exclude: On
    - [FILTER]:
      - Name: modify (add cluster and tenant labels)
      - Match: *
      - Add: cluster apps
      - Add: tenant ${OBSERVABILITY_LOG_TENANT}
    - [OUTPUT]:
      - Name: http
      - Match: *
      - Host: ${OBSERVABILITY_LOG_ENDPOINT_HOST}
      - Port: ${OBSERVABILITY_LOG_ENDPOINT_PORT}
      - URI: ${OBSERVABILITY_LOG_ENDPOINT_PATH}
      - Format: json
      - Header: X-Scope-OrgID ${OBSERVABILITY_LOG_TENANT}
      - compress: gzip
  - [ ] Data key: `parsers.conf`
    - [PARSER]:
      - Name: cri (containerd CRI format)
      - Format: regex
      - Regex: ^(?<time>[^ ]+) (?<stream>stdout|stderr) (?<logtag>[^ ]*) (?<log>.*)$
      - Time_Key: time
      - Time_Format: %Y-%m-%dT%H:%M:%S.%L%z

- [ ] T5.3 — Create DaemonSet manifest
  - [ ] Create `kubernetes/workloads/platform/observability/apps-collectors/fluent-bit/daemonset.yaml`
  - [ ] Metadata:
    - name: `fluent-bit`
    - namespace: `observability`
    - labels: `app.kubernetes.io/name=fluent-bit`
  - [ ] Spec:
    - selector: `app.kubernetes.io/name=fluent-bit`
    - template:
      - serviceAccountName: fluent-bit
      - tolerations: operator Exists
      - containers:
        - name: fluent-bit
        - image: fluent/fluent-bit:3.2.2
        - ports: 2020 (http metrics)
        - env:
          - OBSERVABILITY_LOG_ENDPOINT_HOST: victorialogs-vmauth.observability.svc.cluster.local
          - OBSERVABILITY_LOG_ENDPOINT_PORT: "9428"
          - OBSERVABILITY_LOG_ENDPOINT_PATH: "/insert"
          - OBSERVABILITY_LOG_TENANT: "apps"
        - resources: requests 50m/128Mi, limits 200m/256Mi
        - volumeMounts:
          - name: varlog, mountPath: /var/log, readOnly: false (need write for DB file)
          - name: fluent-bit-config, mountPath: /fluent-bit/etc/
      - volumes:
        - name: varlog, hostPath: path /var/log, type Directory (Talos containerd logs)
        - name: fluent-bit-config, configMap: name fluent-bit-config

- [ ] T5.4 — Create RBAC manifests
  - [ ] Create `kubernetes/workloads/platform/observability/apps-collectors/fluent-bit/rbac.yaml`
  - [ ] ServiceAccount: name fluent-bit
  - [ ] ClusterRole: name fluent-bit
    - rules:
      - apiGroups: [""] resources: ["namespaces", "pods"] verbs: ["get", "list", "watch"]
  - [ ] ClusterRoleBinding: name fluent-bit
    - roleRef: ClusterRole fluent-bit
    - subjects: ServiceAccount fluent-bit (namespace observability)

- [ ] T5.5 — Create fluent-bit Kustomization
  - [ ] Create `kubernetes/workloads/platform/observability/apps-collectors/fluent-bit/kustomization.yaml`
  - [ ] resources: [configmap.yaml, daemonset.yaml, rbac.yaml]
  - [ ] namespace: observability

- [ ] T5.6 — Validate fluent-bit manifests
  - [ ] `kubectl apply --dry-run=client -k fluent-bit/`
  - [ ] No errors

### T6 — Create Namespace Manifest (15 min)

**Goal**: Create observability namespace with PSS labels.

- [ ] T6.1 — Create Namespace manifest
  - [ ] Create `kubernetes/workloads/platform/observability/apps-collectors/namespace.yaml`
  - [ ] Metadata:
    - name: `observability`
    - labels:
      - pod-security.kubernetes.io/enforce: privileged
      - pod-security.kubernetes.io/audit: privileged
      - pod-security.kubernetes.io/warn: privileged
  - [ ] Note: PSS privileged required for node-exporter (hostNetwork, hostPID) and fluent-bit (hostPath)

- [ ] T6.2 — Validate Namespace manifest
  - [ ] `kubectl apply --dry-run=client -f namespace.yaml`
  - [ ] No errors

### T7 — Create NetworkPolicy Manifest (30 min)

**Goal**: Create NetworkPolicy for egress to infra cluster observability endpoints.

- [ ] T7.1 — Create NetworkPolicy manifest
  - [ ] Create `kubernetes/workloads/platform/observability/apps-collectors/networkpolicy.yaml`
  - [ ] Metadata:
    - name: `observability-collectors-egress`
    - namespace: `observability`
  - [ ] Spec:
    - podSelector: {} (apply to all pods in namespace)
    - policyTypes: [Egress]
    - egress:
      - Allow DNS resolution (kube-system/coredns, UDP port 53)
      - Allow kube-apiserver access (TCP port 443)
      - Allow egress to infra cluster observability endpoints:
        - TCP port 8480 (vminsert)
        - TCP port 9428 (VictoriaLogs)
      - Note: Adjust CIDR or use podSelector based on network topology

- [ ] T7.2 — Validate NetworkPolicy manifest
  - [ ] `kubectl apply --dry-run=client -f networkpolicy.yaml`
  - [ ] No errors

### T8 — Create ServiceMonitor Manifests (30 min)

**Goal**: Create ServiceMonitors for collectors self-monitoring.

- [ ] T8.1 — Create ServiceMonitor manifest
  - [ ] Create `kubernetes/workloads/platform/observability/apps-collectors/servicemonitors.yaml`
  - [ ] ServiceMonitor 1: kube-state-metrics
    - name: `kube-state-metrics`
    - namespace: `observability`
    - selector: `app.kubernetes.io/name=kube-state-metrics`
    - endpoints: port http-metrics, interval 30s
  - [ ] ServiceMonitor 2: node-exporter
    - name: `node-exporter`
    - namespace: `observability`
    - selector: `app.kubernetes.io/name=node-exporter`
    - endpoints: port metrics, interval 30s
  - [ ] Note: vmagent self-monitoring typically enabled via HelmRelease values

- [ ] T8.2 — Validate ServiceMonitor manifests
  - [ ] `kubectl apply --dry-run=client -f servicemonitors.yaml`
  - [ ] No errors

### T9 — Create Kustomization Files (30 min)

**Goal**: Compose all observability collectors resources.

- [ ] T9.1 — Create root Kustomization
  - [ ] Create `kubernetes/workloads/platform/observability/apps-collectors/kustomization.yaml`
  - [ ] apiVersion: kustomize.config.k8s.io/v1beta1
  - [ ] kind: Kustomization
  - [ ] namespace: observability
  - [ ] resources:
    - namespace.yaml
    - vmagent/
    - kube-state-metrics/
    - node-exporter/
    - fluent-bit/
    - networkpolicy.yaml
    - servicemonitors.yaml

- [ ] T9.2 — Validate root Kustomization builds
  - [ ] `kubectl kustomize kubernetes/workloads/platform/observability/apps-collectors/`
  - [ ] No errors, all resources rendered

### T10 — Create Cluster Kustomization Entrypoint (30 min)

**Goal**: Integrate observability collectors into apps cluster GitOps flow.

- [ ] T10.1 — Create or update cluster Kustomization
  - [ ] File: `kubernetes/clusters/apps/workloads.yaml` (or add to existing file)
  - [ ] If file doesn't exist or needs new Kustomization, create Flux Kustomization CR:
    ```yaml
    ---
    apiVersion: kustomize.toolkit.fluxcd.io/v1
    kind: Kustomization
    metadata:
      name: apps-observability-collectors
      namespace: flux-system
    spec:
      dependsOn:
        - name: apps-infrastructure  # Ensure CRDs and HelmRepositories available
      interval: 10m
      retryInterval: 1m
      timeout: 10m
      path: ./kubernetes/workloads/platform/observability/apps-collectors
      prune: true
      wait: true
      sourceRef:
        kind: GitRepository
        name: flux-system
      postBuild:
        substituteFrom:
          - kind: ConfigMap
            name: cluster-settings
      healthChecks:
        - apiVersion: apps/v1
          kind: Deployment
          name: kube-state-metrics
          namespace: observability
        - apiVersion: apps/v1
          kind: DaemonSet
          name: node-exporter
          namespace: observability
        - apiVersion: apps/v1
          kind: DaemonSet
          name: fluent-bit
          namespace: observability
    ```
  - [ ] Key fields:
    - dependsOn: `apps-infrastructure` (ensure CRDs and repos available)
    - path: `./kubernetes/workloads/platform/observability/apps-collectors`
    - healthChecks: Deployment kube-state-metrics, DaemonSet node-exporter, DaemonSet fluent-bit

- [ ] T10.2 — Validate Flux Kustomization builds
  - [ ] `flux build kustomization apps-observability-collectors --path ./kubernetes/workloads/platform/observability/apps-collectors`
  - [ ] No errors

### T11 — Create Comprehensive Documentation (1.5 hours)

**Goal**: Provide runbook for observability collectors operations.

- [ ] T11.1 — Create runbook structure
  - [ ] Create `docs/runbooks/observability-collectors-apps.md`
  - [ ] Sections:
    1. Overview
    2. Architecture
    3. Collector Endpoints
    4. Operations
    5. Troubleshooting
    6. Cross-Cluster Verification
    7. Performance Tuning
    8. References

- [ ] T11.2 — Write Overview section
  - [ ] Purpose: Lightweight collectors on apps cluster forwarding to infra observability stack
  - [ ] Cluster: apps
  - [ ] Namespace: observability
  - [ ] Components: vmagent, kube-state-metrics, node-exporter, fluent-bit

- [ ] T11.3 — Write Architecture section
  - [ ] **Leaf Observability Pack**: Collectors only, no storage (infra cluster has storage)
  - [ ] **vmagent**: Scrapes local targets, remote writes to infra VictoriaMetrics
  - [ ] **kube-state-metrics**: Generates Kubernetes object state metrics
  - [ ] **node-exporter**: Exposes host/OS metrics (Talos-compatible)
  - [ ] **fluent-bit**: Ships logs to infra VictoriaLogs (CRI parser for containerd)
  - [ ] **External Labels**: `cluster=apps` (for multi-cluster differentiation)
  - [ ] **Network**: Egress to infra cluster via ClusterMesh or static routes

- [ ] T11.4 — Write Collector Endpoints section
  - [ ] **vmagent**:
    - Local metrics: (if exposed by HelmRelease)
    - Remote write: `http://victoria-metrics-global-vminsert.observability.svc.cluster.local:8480/insert/0/prometheus/api/v1/write`
  - [ ] **kube-state-metrics**:
    - Metrics: `http://kube-state-metrics.observability.svc.cluster.local:8080/metrics`
    - Telemetry: `http://kube-state-metrics.observability.svc.cluster.local:8081`
  - [ ] **node-exporter**:
    - Metrics: `hostPort 9100` (accessible via node IP)
  - [ ] **fluent-bit**:
    - Metrics: `http://fluent-bit-pod:2020/metrics` (internal)
    - Log output: `http://victorialogs-vmauth.observability.svc.cluster.local:9428/insert`

- [ ] T11.5 — Write Operations section
  - [ ] **View Pods**:
    ```bash
    kubectl --context=apps -n observability get pods
    ```
  - [ ] **View vmagent Logs**:
    ```bash
    kubectl --context=apps -n observability logs -l app.kubernetes.io/name=vmagent --tail=100
    ```
  - [ ] **View fluent-bit Logs**:
    ```bash
    kubectl --context=apps -n observability logs -l app.kubernetes.io/name=fluent-bit --tail=100
    ```
  - [ ] **Restart Collectors**:
    ```bash
    kubectl --context=apps -n observability rollout restart deployment/kube-state-metrics
    kubectl --context=apps -n observability rollout restart daemonset/node-exporter
    kubectl --context=apps -n observability rollout restart daemonset/fluent-bit
    ```
  - [ ] **Scale kube-state-metrics** (if needed):
    ```bash
    kubectl --context=apps -n observability scale deployment/kube-state-metrics --replicas=2
    ```

- [ ] T11.6 — Write Troubleshooting section
  - [ ] **Issue 1**: vmagent remote write errors
    - **Symptoms**: Logs show "connection refused" or "timeout" to vminsert
    - **Causes**:
      - Infra cluster VictoriaMetrics not running
      - Network connectivity issues (ClusterMesh, firewall)
      - Incorrect remote write URL
    - **Resolution**:
      1. Check infra VictoriaMetrics: `kubectl --context=infra -n observability get pods | grep vminsert`
      2. Test network connectivity: `kubectl --context=apps -n observability exec -it <vmagent-pod> -- wget -O- http://victoria-metrics-global-vminsert.observability.svc.cluster.local:8480/health`
      3. Verify remote write URL in HelmRelease values
      4. Check NetworkPolicy allows egress to port 8480
  - [ ] **Issue 2**: fluent-bit buffering/backpressure
    - **Symptoms**: Logs show "retry" or "buffer full", disk usage high
    - **Causes**:
      - VictoriaLogs slow/unavailable
      - High log volume, insufficient buffer
      - Disk space full on node
    - **Resolution**:
      1. Check infra VictoriaLogs: `kubectl --context=infra -n observability get pods | grep victorialogs`
      2. Increase Mem_Buf_Limit in fluent-bit ConfigMap
      3. Check node disk space: `kubectl --context=apps get nodes -o custom-columns=NAME:.metadata.name,DISK:.status.allocatable.ephemeral-storage`
      4. Scale VictoriaLogs if needed (infra cluster)
  - [ ] **Issue 3**: Missing metrics in infra VictoriaMetrics
    - **Symptoms**: Query `up{cluster="apps"}` returns no results
    - **Causes**:
      - vmagent not scraping targets
      - ServiceMonitor discovery not working
      - Remote write failing
    - **Resolution**:
      1. Check vmagent logs for scrape errors
      2. Verify ServiceMonitor labels match vmagent selector
      3. Check vmagent scrape targets (if exposed via UI)
      4. Verify infra VictoriaMetrics ingesting data (other clusters working)
  - [ ] **Issue 4**: Missing logs in infra VictoriaLogs
    - **Symptoms**: Query `{cluster="apps"}` returns no results
    - **Causes**:
      - fluent-bit not reading container logs
      - CRI parser not matching log format
      - HTTP output failing
    - **Resolution**:
      1. Check fluent-bit logs for parsing errors
      2. Verify Talos logs at `/var/log/containers/*.log` (exec into fluent-bit pod)
      3. Test CRI parser with sample log line
      4. Check VictoriaLogs insert endpoint reachable
  - [ ] **Issue 5**: node-exporter pods not running
    - **Symptoms**: Pods in Pending or CrashLoopBackOff
    - **Causes**:
      - PSS not set to privileged (hostNetwork/hostPID violation)
      - Node taints not tolerated
      - HostPort conflict on port 9100
    - **Resolution**:
      1. Check namespace PSS labels: `kubectl --context=apps get ns observability -o yaml | grep pod-security`
      2. Check pod events: `kubectl --context=apps -n observability describe pod <node-exporter-pod>`
      3. Verify tolerations allow running on all nodes
      4. Check for port conflicts (another process using 9100)

- [ ] T11.7 — Write Cross-Cluster Verification section
  - [ ] **Verify Metrics in Infra VictoriaMetrics**:
    ```bash
    # Port-forward to vmselect (infra cluster)
    kubectl --context=infra -n observability port-forward svc/victoria-metrics-global-vmselect 8481:8481

    # Query metrics from apps cluster
    curl "localhost:8481/select/0/prometheus/api/v1/query?query=up{cluster=\"apps\"}" | jq

    # Expected: Multiple targets with cluster="apps" label
    ```
  - [ ] **Verify Logs in Infra VictoriaLogs**:
    ```bash
    # Port-forward to VictoriaLogs query API (infra cluster)
    kubectl --context=infra -n observability port-forward svc/victorialogs-vmauth 9428:9428

    # Query logs from apps cluster
    curl "localhost:9428/select/logsql/query?query={cluster=\"apps\"}" | jq

    # Expected: Logs from apps cluster pods
    ```
  - [ ] **Common Queries**:
    ```promql
    # All apps cluster targets
    up{cluster="apps"}

    # Kubernetes pod metrics from apps cluster
    kube_pod_info{cluster="apps"}

    # Node CPU usage from apps cluster
    node_cpu_seconds_total{cluster="apps"}

    # vmagent metrics
    vmagent_remotewrite_requests_total{cluster="apps"}
    ```

- [ ] T11.8 — Write Performance Tuning section
  - [ ] **vmagent Resources**:
    - Default: 100m/500m CPU, 256Mi/512Mi memory
    - High scrape volume: Increase to 500m/1000m CPU, 512Mi/1Gi memory
  - [ ] **kube-state-metrics Resources**:
    - Default: 10m/200m CPU, 64Mi/128Mi memory
    - Large clusters (>1000 pods): Increase to 100m/500m CPU, 128Mi/256Mi memory
  - [ ] **node-exporter Resources**:
    - Default: 50m/200m CPU, 64Mi/128Mi memory
    - Typically no tuning needed (lightweight)
  - [ ] **fluent-bit Resources**:
    - Default: 50m/200m CPU, 128Mi/256Mi memory
    - High log volume: Increase Mem_Buf_Limit to 10MB, increase memory limits
  - [ ] **Scrape Interval Tuning**:
    - Default: 30s (good for most use cases)
    - Low-latency monitoring: 15s (increases cardinality and storage)
    - Large clusters: 60s (reduces load on vmagent)

- [ ] T11.9 — Write References section
  - [ ] VictoriaMetrics vmagent: https://docs.victoriametrics.com/vmagent.html
  - [ ] kube-state-metrics: https://github.com/kubernetes/kube-state-metrics
  - [ ] node-exporter: https://github.com/prometheus/node_exporter
  - [ ] fluent-bit: https://docs.fluentbit.io/manual/
  - [ ] Talos Linux logging: https://www.talos.dev/latest/kubernetes-guides/configuration/logging/

### T12 — Validation and Commit (45 min)

**Goal**: Validate all manifests and commit to Git.

- [ ] T12.1 — Validate root Kustomization builds
  - [ ] `kubectl kustomize kubernetes/workloads/platform/observability/apps-collectors/`
  - [ ] No errors, all resources rendered correctly

- [ ] T12.2 — Validate Flux Kustomization
  - [ ] `flux build kustomization apps-observability-collectors --path ./kubernetes/workloads/platform/observability/apps-collectors`
  - [ ] No errors

- [ ] T12.3 — Validate YAML syntax
  - [ ] `yamllint kubernetes/workloads/platform/observability/apps-collectors/**/*.yaml`
  - [ ] Or: `yq eval '.' <file.yaml>` for each file
  - [ ] No syntax errors

- [ ] T12.4 — Validate cross-references
  - [ ] Service selectors match Deployment/DaemonSet pod labels
  - [ ] ServiceMonitor selectors match Service labels
  - [ ] Health checks in Flux Kustomization match resource names
  - [ ] dependsOn references correct Kustomization name (`apps-infrastructure`)

- [ ] T12.5 — Review completeness
  - [ ] All ACs (AC1-AC13) satisfied
  - [ ] All files created:
    - namespace.yaml
    - vmagent/helmrelease.yaml
    - kube-state-metrics/ (deployment, service, rbac, kustomization)
    - node-exporter/ (daemonset, service, kustomization)
    - fluent-bit/ (configmap, daemonset, rbac, kustomization)
    - networkpolicy.yaml
    - servicemonitors.yaml
    - kustomization.yaml (root)
  - [ ] Cluster Kustomization created/updated: `kubernetes/clusters/apps/workloads.yaml`
  - [ ] Runbook created: `docs/runbooks/observability-collectors-apps.md`

- [ ] T12.6 — Commit to Git
  - [ ] Stage all files:
    ```bash
    git add kubernetes/workloads/platform/observability/apps-collectors/
    git add kubernetes/clusters/apps/workloads.yaml
    git add docs/runbooks/observability-collectors-apps.md
    git add docs/stories/STORY-OBS-APPS-COLLECTORS.md
    ```
  - [ ] Commit:
    ```bash
    git commit -m "feat(observability): create apps cluster collectors manifests (Story 40)

    - Add vmagent HelmRelease for metrics scraping and remote write
    - Add kube-state-metrics Deployment for K8s object state metrics
    - Add node-exporter DaemonSet for host/OS metrics (Talos-compatible)
    - Add fluent-bit DaemonSet for log forwarding (CRI parser for containerd)
    - Add Namespace with PSS privileged labels
    - Add NetworkPolicy for egress to infra cluster
    - Add ServiceMonitors for collectors self-monitoring
    - Add comprehensive runbook
    - Add Flux Kustomization entrypoint
    - Forward metrics to infra VictoriaMetrics (vminsert :8480)
    - Forward logs to infra VictoriaLogs (vmauth :9428)
    - External label: cluster=apps
    - Deployment deferred to Story 45"
    ```
  - [ ] Do NOT push yet (wait for user approval or batch with other stories)

- [ ] T12.7 — Update story status
  - [ ] Mark story as Complete in this file
  - [ ] Add completion date to change log

## Runtime Validation (Deferred to Story 45)

The following validation steps will be executed in **Story 45 (STORY-DEPLOY-VALIDATE-ALL)**:

### Deployment Validation
```bash
# Apply Flux Kustomization
flux --context=apps reconcile kustomization apps-observability-collectors --with-source

# Check all collectors running
kubectl --context=apps -n observability get pods
kubectl --context=apps -n observability get deployment kube-state-metrics
kubectl --context=apps -n observability get daemonset node-exporter
kubectl --context=apps -n observability get daemonset fluent-bit
```

### vmagent Validation
```bash
# Check vmagent logs (no remote write errors)
kubectl --context=apps -n observability logs -l app.kubernetes.io/name=vmagent --tail=100

# Verify metrics in infra VictoriaMetrics
kubectl --context=infra -n observability port-forward svc/victoria-metrics-global-vmselect 8481:8481
curl "localhost:8481/select/0/prometheus/api/v1/query?query=up{cluster=\"apps\"}" | jq
# Expected: Multiple targets from apps cluster
```

### kube-state-metrics Validation
```bash
# Test metrics endpoint
kubectl --context=apps -n observability port-forward svc/kube-state-metrics 8080:8080
curl localhost:8080/metrics | grep kube_pod_info | head

# Verify in infra VictoriaMetrics
curl "localhost:8481/select/0/prometheus/api/v1/query?query=kube_pod_info{cluster=\"apps\"}" | jq
```

### node-exporter Validation
```bash
# Test metrics endpoint
kubectl --context=apps -n observability port-forward <node-exporter-pod> 9100:9100
curl localhost:9100/metrics | grep node_cpu_seconds_total | head

# Verify in infra VictoriaMetrics
curl "localhost:8481/select/0/prometheus/api/v1/query?query=node_cpu_seconds_total{cluster=\"apps\"}" | jq
```

### fluent-bit Validation
```bash
# Check fluent-bit logs (no connection errors)
kubectl --context=apps -n observability logs -l app.kubernetes.io/name=fluent-bit --tail=100

# Verify logs in infra VictoriaLogs
kubectl --context=infra -n observability port-forward svc/victorialogs-vmauth 9428:9428
curl "localhost:9428/select/logsql/query?query={cluster=\"apps\"}" | jq
# Expected: Logs from apps cluster pods
```

### Network Validation
```bash
# Test vmagent connectivity to infra vminsert
kubectl --context=apps -n observability exec -it <vmagent-pod> -- \
  wget -O- http://victoria-metrics-global-vminsert.observability.svc.cluster.local:8480/health

# Test fluent-bit connectivity to infra VictoriaLogs
kubectl --context=apps -n observability exec -it <fluent-bit-pod> -- \
  wget -O- http://victorialogs-vmauth.observability.svc.cluster.local:9428/health
```

## Definition of Done

**Manifest Creation (This Story)**:
- [x] All tasks T1-T12 completed
- [x] All acceptance criteria AC1-AC13 met
- [x] vmagent HelmRelease created with scrape configs and remote write
- [x] kube-state-metrics manifests created (Deployment, Service, RBAC)
- [x] node-exporter manifests created (DaemonSet, Service, Talos-compatible)
- [x] fluent-bit manifests created (ConfigMap, DaemonSet, RBAC, CRI parser)
- [x] Namespace manifest created with PSS privileged labels
- [x] NetworkPolicy manifest created for egress to infra cluster
- [x] ServiceMonitor manifests created for collectors
- [x] Kustomization files created (root and subdirectories)
- [x] Cluster Kustomization entrypoint created
- [x] Comprehensive runbook created (`docs/runbooks/observability-collectors-apps.md`)
- [x] Local validation passed (`kubectl kustomize`, `flux build`)
- [x] All files committed to Git (not pushed)
- [x] Story marked complete, change log updated

**Runtime Validation (Story 45)**:
- [ ] Flux Kustomization reconciles successfully
- [ ] All collector pods Running (vmagent, kube-state-metrics, node-exporter, fluent-bit)
- [ ] vmagent successfully scraping local targets
- [ ] vmagent remote write to infra VictoriaMetrics working (no errors)
- [ ] Metrics from apps cluster visible in infra VictoriaMetrics (query `up{cluster="apps"}`)
- [ ] fluent-bit forwarding logs to infra VictoriaLogs (no errors)
- [ ] Logs from apps cluster visible in infra VictoriaLogs (query `{cluster="apps"}`)
- [ ] Network connectivity validated (cross-cluster to infra observability endpoints)
- [ ] ServiceMonitors discovered by vmagent
- [ ] Collectors self-monitoring metrics visible

## Design Notes

### Architecture Overview

**Leaf Observability Pack Pattern**:
- Apps cluster runs lightweight collectors only (no storage/TSDB)
- All data forwarded to infra cluster centralized observability stack
- Single pane of glass: Grafana on infra cluster visualizes all clusters
- Resource efficient: Avoid duplicating storage, Grafana, Alertmanager on every cluster

**Components**:
1. **vmagent**: Scrapes metrics from local targets, remote writes to infra VictoriaMetrics
2. **kube-state-metrics**: Generates metrics about Kubernetes objects (pods, deployments, nodes)
3. **node-exporter**: Exposes host/OS metrics (CPU, memory, disk, network)
4. **fluent-bit**: Tails container logs, forwards to infra VictoriaLogs

**Data Flow**:
```
Apps Cluster                      Infra Cluster
┌─────────────────────┐          ┌─────────────────────┐
│ vmagent             │──HTTP───→│ vminsert :8480      │
│ (scrape + forward)  │          │ (VictoriaMetrics)   │
└─────────────────────┘          └─────────────────────┘
         ↑
         │ scrape (HTTP)
         │
┌────────┴────────────┐
│ kube-state-metrics  │
│ node-exporter       │
│ kubelet/cAdvisor    │
│ ServiceMonitors     │
└─────────────────────┘

┌─────────────────────┐          ┌─────────────────────┐
│ fluent-bit          │──HTTP───→│ vmauth :9428        │
│ (tail + forward)    │          │ (VictoriaLogs)      │
└─────────────────────┘          └─────────────────────┘
         ↑
         │ tail (file)
         │
┌────────┴────────────┐
│ /var/log/containers │
│ (containerd logs)   │
└─────────────────────┘
```

### vmagent Configuration

**Why vmagent?**
- Lightweight Prometheus-compatible scraper
- Efficient remote write (supports retries, buffering, compression)
- Service discovery (Kubernetes endpoints, pods, services)
- Relabeling and metric filtering
- Lower resource usage than full Prometheus

**Scrape Configs**:
1. **kube-state-metrics**: Static config (Service endpoint)
2. **node-exporter**: Kubernetes SD (role=endpoints with relabeling)
3. **kubelet**: Kubernetes SD (role=node, HTTPS with bearer token)
4. **cAdvisor**: Kubernetes SD (role=node, metrics_path=/metrics/cadvisor)
5. **ServiceMonitor/PodMonitor**: Automatic discovery (enabled via serviceMonitor.enabled=true)

**External Labels**:
- `cluster: apps` - Differentiates apps cluster from infra/other clusters
- Critical for multi-cluster setup

**Remote Write**:
- URL: `http://victoria-metrics-global-vminsert.observability.svc.cluster.local:8480/insert/0/prometheus/api/v1/write`
- Protocol: HTTP POST with Protobuf/Snappy compression
- Retries: Automatic with exponential backoff
- Queue: In-memory buffer (configurable size)

### kube-state-metrics Configuration

**Why kube-state-metrics?**
- Exposes metrics about Kubernetes object state (not in kubelet metrics)
- Examples: deployment replicas, pod status, node conditions, resource requests/limits
- Essential for Kubernetes-aware monitoring

**Key Metrics**:
- `kube_pod_info`: Pod metadata (namespace, pod name, labels)
- `kube_deployment_status_replicas`: Desired vs available replicas
- `kube_node_status_condition`: Node health conditions
- `kube_persistentvolumeclaim_status_phase`: PVC status

**RBAC Requirements**:
- ClusterRole with list/watch on all resources (pods, deployments, nodes, etc.)
- Read-only access (no create/update/delete)

### node-exporter Configuration (Talos-Compatible)

**Why node-exporter?**
- Exposes host/OS metrics not available via kubelet
- Examples: CPU usage per core, memory details, disk I/O, network interfaces
- Essential for node-level monitoring

**Talos Compatibility**:
- Talos is immutable OS, uses different paths than traditional Linux
- `--path.sysfs=/host/sys` - Mount host /sys for system metrics
- `--path.rootfs=/host/root` - Mount host / for filesystem metrics
- `--collector.filesystem.mount-points-exclude` - Exclude virtual filesystems
- `hostNetwork: true` - Access host network interfaces
- `hostPID: true` - Access host process metrics

**Key Metrics**:
- `node_cpu_seconds_total`: CPU time per mode (user, system, idle, iowait)
- `node_memory_MemAvailable_bytes`: Available memory
- `node_filesystem_avail_bytes`: Disk space available
- `node_network_receive_bytes_total`: Network RX bytes

**DaemonSet**:
- Runs on every node (tolerates all taints)
- hostPort 9100 for direct access via node IP

### fluent-bit Configuration (Talos/containerd-Compatible)

**Why fluent-bit?**
- Lightweight log forwarder (lower resource usage than Fluentd)
- Native Kubernetes integration (pod metadata enrichment)
- Supports multiple outputs (HTTP, Elasticsearch, S3, etc.)
- Fast and efficient (written in C)

**Talos/containerd Compatibility**:
- Talos uses containerd runtime (NOT Docker)
- Container logs at `/var/log/containers/*.log` (NOT /var/lib/docker!)
- Log format: CRI (containerd runtime interface)
- Example: `2025-01-15T10:30:45.123456789Z stdout F log message here`

**CRI Parser**:
- Regex: `^(?<time>[^ ]+) (?<stream>stdout|stderr) (?<logtag>[^ ]*) (?<log>.*)$`
- Extracts: timestamp, stream (stdout/stderr), logtag (F/P for full/partial), log message
- Critical: Must use CRI parser, NOT Docker parser (different format)

**Kubernetes Filter**:
- Enriches logs with pod metadata (namespace, pod name, labels, annotations)
- Queries kube-apiserver via ServiceAccount token
- Merge_Log: Parses structured JSON logs
- K8S-Logging.Parser: Respects pod annotation for custom parsers
- K8S-Logging.Exclude: Respects pod annotation to exclude logs

**Modify Filter**:
- Adds custom labels: `cluster=apps`, `tenant=apps`
- Essential for multi-cluster and multi-tenant log aggregation

**HTTP Output**:
- Host: `victorialogs-vmauth.observability.svc.cluster.local`
- Port: 9428
- URI: `/insert`
- Format: JSON (LogsQL compatible)
- Header: `X-Scope-OrgID: apps` (multi-tenancy)
- compress: gzip (reduce bandwidth)

**DaemonSet**:
- Runs on every node (tolerates all taints)
- hostPath `/var/log` for container logs access
- Write access needed for DB file (position tracking)

### Namespace and Pod Security Standards

**Why PSS Privileged?**
- Pod Security Standards (PSS) enforced by Kubernetes admission controller
- Talos enforces PSS by default
- **node-exporter** requires:
  - `hostNetwork: true` (violates baseline/restricted)
  - `hostPID: true` (violates baseline/restricted)
  - `hostPath` volumes (violates baseline/restricted)
- **fluent-bit** requires:
  - `hostPath` volumes (violates baseline/restricted)
- Solution: Set namespace PSS to `privileged` (allows all pod security violations)

**PSS Labels**:
```yaml
pod-security.kubernetes.io/enforce: privileged
pod-security.kubernetes.io/audit: privileged
pod-security.kubernetes.io/warn: privileged
```

**Security Considerations**:
- Privileged namespace only for trusted system workloads
- node-exporter/fluent-bit are trusted (official images from reputable sources)
- Limit access to this namespace (RBAC)

### NetworkPolicy

**Egress Rules**:
1. **DNS**: Allow UDP port 53 to kube-system/coredns (service discovery)
2. **kube-apiserver**: Allow TCP port 443 (for ServiceAccount token, Kubernetes API)
3. **vminsert**: Allow TCP port 8480 (vmagent remote write to infra VictoriaMetrics)
4. **VictoriaLogs**: Allow TCP port 9428 (fluent-bit log forwarding to infra VictoriaLogs)

**Cross-Cluster Connectivity**:
- Assumes Cilium ClusterMesh or static routes between clusters
- Adjust NetworkPolicy CIDR or podSelector based on network topology
- May need to allow broader egress if using ClusterMesh global services

**Default Deny**:
- All other egress blocked by default (defense in depth)
- Explicit allow-list approach

### Monitoring and Observability

**Collectors Self-Monitoring**:
- ServiceMonitors for kube-state-metrics and node-exporter
- vmagent self-scraping (if enabled by HelmRelease)
- Metrics visible in infra VictoriaMetrics with `cluster=apps` label

**Key Metrics to Monitor**:
1. **vmagent**:
   - `vmagent_remotewrite_requests_total` - Total remote write requests
   - `vmagent_remotewrite_retries_total` - Failed remote writes (should be low)
   - `vmagent_promscrape_targets_count` - Number of discovered targets
2. **fluent-bit**:
   - `fluentbit_input_records_total` - Total log records ingested
   - `fluentbit_output_retries_total` - Failed log forwards (should be low)
3. **kube-state-metrics**:
   - `up{job="kube-state-metrics"}` - Pod availability
4. **node-exporter**:
   - `up{job="node-exporter"}` - Pod availability per node

**Alerting**:
- Create alerts for remote write failures (vmagent)
- Create alerts for log forwarding failures (fluent-bit)
- Create alerts for missing collectors (kube-state-metrics, node-exporter down)

### Resource Allocation

**vmagent**:
- Requests: 100m CPU, 256Mi memory
- Limits: 500m CPU, 512Mi memory
- **Rationale**: Lightweight scraper, memory for scrape buffer and remote write queue

**kube-state-metrics**:
- Requests: 10m CPU, 64Mi memory
- Limits: 200m CPU, 128Mi memory
- **Rationale**: Very lightweight, just generates metrics from Kubernetes API

**node-exporter** (per node):
- Requests: 50m CPU, 64Mi memory
- Limits: 200m CPU, 128Mi memory
- **Rationale**: Lightweight exporter, minimal resource usage

**fluent-bit** (per node):
- Requests: 50m CPU, 128Mi memory
- Limits: 200m CPU, 256Mi memory
- **Rationale**: Log tailing and forwarding, memory for buffer

**Total for Apps Cluster** (3 nodes):
- vmagent: 100m/500m CPU, 256Mi/512Mi memory (1 pod)
- kube-state-metrics: 10m/200m CPU, 64Mi/128Mi memory (1 pod)
- node-exporter: 150m/600m CPU, 192Mi/384Mi memory (3 pods, 1 per node)
- fluent-bit: 150m/600m CPU, 384Mi/768Mi memory (3 pods, 1 per node)
- **Total Requests**: 410m CPU, 896Mi memory
- **Total Limits**: 1900m CPU, 1792Mi memory

### Performance Considerations

**Scrape Interval**:
- Default: 30s (good balance between latency and cardinality)
- Lower: 15s (more data, higher cardinality, increased load)
- Higher: 60s (less data, lower cardinality, reduced load)

**Cardinality**:
- External label `cluster=apps` increases cardinality
- ServiceMonitor discovery can increase scrape targets
- Monitor vmagent memory usage for high cardinality

**Log Volume**:
- fluent-bit buffer: Mem_Buf_Limit 5MB (default)
- High log volume: Increase to 10MB or more
- Disk buffer: Enable if memory buffer insufficient

**Network Bandwidth**:
- vmagent remote write: Protobuf + Snappy compression (efficient)
- fluent-bit output: gzip compression (reduces bandwidth)
- Cross-cluster traffic: Consider bandwidth costs if using cloud

### Limitations

**vmagent Limitations**:
- No HA mode (single pod)
- Solution: Tolerate brief downtime (metrics buffered, remote write retries)
- Alternative: Run multiple vmagent pods with sharding (complex)

**fluent-bit Limitations**:
- No HA mode (DaemonSet per node)
- Lost logs if pod crashes before forward (small window)
- Solution: Increase buffer, monitor pod health

**Cross-Cluster Dependencies**:
- Apps cluster collectors depend on infra cluster observability stack
- If infra cluster down, apps cluster data not ingested
- Solution: Monitor infra cluster health, no alternative for now (local storage not implemented)

**PSS Privileged Namespace**:
- All pods in `observability` namespace can use privileged features
- Security risk if untrusted workloads deployed
- Solution: Strict RBAC, only trusted collectors in this namespace

### Testing Strategy

**Unit Tests** (Manifest Validation):
- `kubectl apply --dry-run=client` for all manifests
- `kubectl kustomize` builds without errors
- `flux build` succeeds for Kustomization

**Integration Tests** (Story 45):
- Pods Running (all collectors)
- Metrics visible in infra VictoriaMetrics
- Logs visible in infra VictoriaLogs
- Network connectivity to infra cluster
- ServiceMonitor discovery working

**Performance Tests**:
- vmagent scrape performance (latency, throughput)
- fluent-bit log forwarding performance (latency, throughput)
- Resource usage under load (CPU, memory)

**Chaos Tests**:
- Kill vmagent pod (remote write retries, eventual consistency)
- Kill fluent-bit pod (DaemonSet recreates, lost logs in window)
- Kill infra VictoriaMetrics (backpressure, buffering)
- Network partition (retry logic, eventual consistency)

### Future Enhancements

**OpenTelemetry Collector**:
- Add OpenTelemetry Collector for traces and more
- Unified observability (metrics, logs, traces)

**Local Storage Fallback**:
- Buffer metrics/logs locally if infra cluster unavailable
- Forward when connectivity restored
- Requires persistent storage on apps cluster

**HA vmagent**:
- Run multiple vmagent pods with sharding
- Requires coordination (e.g., via statefulset)

**Custom Metrics**:
- Add custom application metrics (ServiceMonitors)
- Application-specific dashboards

**Log Filtering**:
- Filter noisy logs (exclude specific namespaces/pods)
- Reduce log volume and storage costs

## Risks & Mitigations

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| **vmagent remote write failures** | High | Medium | Monitor vmagent logs; alert on remote write errors; ensure network connectivity; buffer in-memory |
| **fluent-bit buffering/backpressure** | Medium | Medium | Configure buffer limits; monitor disk usage; alert on dropped logs; increase VictoriaLogs capacity |
| **Collector resource exhaustion** | Medium | Low | Set resource limits; monitor collector CPU/memory; scale collectors if needed |
| **Cross-cluster network issues** | High | Medium | Use ClusterMesh or static routes; monitor connectivity; alert on failures; no fallback storage (limitation) |
| **Missing metrics/logs** | Low | Low | Verify ServiceMonitor discovery; check scrape configs; validate labels; test queries regularly |
| **PSS privileged namespace security** | Medium | Low | Strict RBAC; only trusted collectors; audit pod security policies; limit access to namespace |
| **Infra cluster downtime** | High | Low | Monitor infra cluster health; ensure HA for infra VictoriaMetrics/VictoriaLogs; no alternative (limitation) |
| **CRI parser mismatch (Talos/containerd)** | High | Low | Use CRI parser (NOT Docker); test with Talos sample logs; validate parsing in fluent-bit logs |

## Follow-On Stories

- **STORY-OBS-GRAFANA-DASHBOARDS** (Story 41+): Custom dashboards for apps cluster (infra Grafana)
- **STORY-OBS-ALERTING-BASELINE** (Story 41+): Alerts for apps cluster workloads (infra Alertmanager)
- **STORY-OBS-OTEL-COLLECTOR** (Story 41+): OpenTelemetry for traces
- **STORY-OBS-LOCAL-STORAGE-FALLBACK** (Story 41+): Buffer metrics/logs locally if infra unavailable
- **STORY-DEPLOY-VALIDATE-ALL** (Story 45): Deploy and validate all manifests including observability collectors

## Dev Notes

### Execution Summary
- **Date**: 2025-10-26
- **Executor**: Platform Engineering
- **Story**: STORY-OBS-APPS-COLLECTORS (Story 40)
- **Scope**: Manifest creation only (v3.0 approach)
- **Deployment**: Deferred to Story 45

### Commands Executed

**Manifest Creation**:
```bash
# Create directory structure
mkdir -p kubernetes/workloads/platform/observability/apps-collectors/{vmagent,kube-state-metrics,node-exporter,fluent-bit}

# Create manifests (T2-T8)
# - namespace.yaml (PSS privileged)
# - vmagent/helmrelease.yaml
# - kube-state-metrics/ (deployment, service, rbac, kustomization)
# - node-exporter/ (daemonset, service, kustomization)
# - fluent-bit/ (configmap, daemonset, rbac, kustomization)
# - networkpolicy.yaml
# - servicemonitors.yaml
# - kustomization.yaml (root)

# Create cluster Kustomization entrypoint (T10)
# Update kubernetes/clusters/apps/workloads.yaml

# Create runbook (T11)
# docs/runbooks/observability-collectors-apps.md
```

**Local Validation** (T12):
```bash
# Validate Kustomization builds
kubectl kustomize kubernetes/workloads/platform/observability/apps-collectors/

# Validate Flux Kustomization
flux build kustomization apps-observability-collectors \
  --path ./kubernetes/workloads/platform/observability/apps-collectors

# Check YAML syntax
yamllint kubernetes/workloads/platform/observability/apps-collectors/**/*.yaml
```

**Git Commit** (T12):
```bash
git add kubernetes/workloads/platform/observability/apps-collectors/
git add kubernetes/clusters/apps/workloads.yaml
git add docs/runbooks/observability-collectors-apps.md
git add docs/stories/STORY-OBS-APPS-COLLECTORS.md
git commit -m "feat(observability): create apps cluster collectors manifests (Story 40)"
# NOT pushed yet (waiting for user approval)
```

### Key Outputs

**Files Created**:
1. `kubernetes/workloads/platform/observability/apps-collectors/namespace.yaml` (15 lines)
2. `kubernetes/workloads/platform/observability/apps-collectors/vmagent/helmrelease.yaml` (80 lines)
3. `kubernetes/workloads/platform/observability/apps-collectors/kube-state-metrics/deployment.yaml` (60 lines)
4. `kubernetes/workloads/platform/observability/apps-collectors/kube-state-metrics/service.yaml` (20 lines)
5. `kubernetes/workloads/platform/observability/apps-collectors/kube-state-metrics/rbac.yaml` (60 lines)
6. `kubernetes/workloads/platform/observability/apps-collectors/kube-state-metrics/kustomization.yaml` (8 lines)
7. `kubernetes/workloads/platform/observability/apps-collectors/node-exporter/daemonset.yaml` (70 lines)
8. `kubernetes/workloads/platform/observability/apps-collectors/node-exporter/service.yaml` (20 lines)
9. `kubernetes/workloads/platform/observability/apps-collectors/node-exporter/kustomization.yaml` (7 lines)
10. `kubernetes/workloads/platform/observability/apps-collectors/fluent-bit/configmap.yaml` (70 lines)
11. `kubernetes/workloads/platform/observability/apps-collectors/fluent-bit/daemonset.yaml` (70 lines)
12. `kubernetes/workloads/platform/observability/apps-collectors/fluent-bit/rbac.yaml` (40 lines)
13. `kubernetes/workloads/platform/observability/apps-collectors/fluent-bit/kustomization.yaml` (8 lines)
14. `kubernetes/workloads/platform/observability/apps-collectors/networkpolicy.yaml` (40 lines)
15. `kubernetes/workloads/platform/observability/apps-collectors/servicemonitors.yaml` (30 lines)
16. `kubernetes/workloads/platform/observability/apps-collectors/kustomization.yaml` (15 lines)
17. `kubernetes/clusters/apps/workloads.yaml` (updated, 40 lines)
18. `docs/runbooks/observability-collectors-apps.md` (500+ lines)

**Validation Results**:
- All manifests build successfully with `kubectl kustomize`
- Flux Kustomization builds without errors
- No YAML syntax errors
- All cross-references valid

### Issues & Resolutions

**Issue 1**: PSS enforcement on Talos
- **Resolution**: Added PSS privileged labels to namespace (required for node-exporter hostNetwork/hostPID and fluent-bit hostPath)

**Issue 2**: Talos containerd log format
- **Resolution**: Used CRI parser (NOT Docker parser) for fluent-bit, logs at `/var/log/containers/*.log`

**Issue 3**: Cross-cluster network configuration
- **Resolution**: Added NetworkPolicy with egress to infra cluster ports (8480 vminsert, 9428 VictoriaLogs), noted dependency on ClusterMesh or static routes

### Acceptance Criteria Status

- [x] **AC1**: vmagent HelmRelease manifest exists with scrape configs and remote write
- [x] **AC2**: kube-state-metrics manifests exist (Deployment, Service, RBAC)
- [x] **AC3**: node-exporter manifests exist (DaemonSet, Service, Talos-compatible)
- [x] **AC4**: fluent-bit manifests exist (ConfigMap, DaemonSet, RBAC, CRI parser)
- [x] **AC5**: Namespace manifest exists with PSS privileged labels
- [x] **AC6**: NetworkPolicy manifest exists for egress to infra cluster
- [x] **AC7**: ServiceMonitor manifests exist for collectors
- [x] **AC8**: Kustomization files exist (root and subdirectories)
- [x] **AC9**: Cluster Kustomization entrypoint created
- [x] **AC10**: Comprehensive runbook created (500+ lines)
- [x] **AC11**: Local validation passed (kubectl kustomize, flux build)
- [x] **AC12**: Manifest files committed to Git
- [x] **AC13**: Story marked complete, change log updated

**All acceptance criteria met. Story complete for v3.0 manifests-only scope.**

---

## Change Log

### 2025-10-26 - v3.0 Manifests-Only Refinement (Story Complete)
- **Changed**: Story scope to manifests-only approach (deployment deferred to Story 45)
- **Added**: vmagent HelmRelease for metrics scraping and remote write to infra VictoriaMetrics
- **Added**: kube-state-metrics Deployment, Service, RBAC for Kubernetes object state metrics
- **Added**: node-exporter DaemonSet, Service for host/OS metrics (Talos-compatible configuration)
- **Added**: fluent-bit ConfigMap (CRI parser), DaemonSet, RBAC for log forwarding to infra VictoriaLogs
- **Added**: Namespace manifest with PSS privileged labels (required for node-exporter and fluent-bit)
- **Added**: NetworkPolicy for egress to infra cluster (vminsert :8480, VictoriaLogs :9428)
- **Added**: ServiceMonitor manifests for collectors self-monitoring
- **Added**: Kustomization files (root and subdirectories)
- **Added**: Cluster Kustomization entrypoint with health checks
- **Added**: Comprehensive runbook (500+ lines): collector endpoints, operations, troubleshooting, cross-cluster verification, performance tuning
- **Added**: Extensive design notes: architecture, component configurations, PSS, NetworkPolicy, monitoring, resources, performance, limitations, testing, future enhancements
- **Added**: Risk analysis and mitigations
- **Validated**: Local validation passed (kubectl kustomize, flux build, YAML syntax)
- **Committed**: All manifests and documentation committed to Git
- **Status**: Story complete (v3.0), ready for deployment in Story 45

### 2025-10-23 - Initial Draft
- Created initial story structure with implementation tasks (T0-T8)
- Defined 8 acceptance criteria for runtime deployment
- Added basic documentation outline

---

**Story Status**: ✅ Complete (v3.0 Manifests-Only)
**QA Gate**: Local validation passed. Runtime validation deferred to Story 45.
**Deployment Ready**: Yes (all manifests created and validated)
