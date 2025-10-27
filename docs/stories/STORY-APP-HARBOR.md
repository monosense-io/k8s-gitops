# 34 — STORY-APP-HARBOR — Create Harbor Manifests (infra)

**Status:** v3.0 (Manifests-first) | **Date:** 2025-10-26
**Sequence:** 34/50 | **Prev:** STORY-CICD-GITLAB-APPS.md | **Next:** STORY-TENANCY-BASELINE.md
**Sprint:** 7 | **Lane:** Applications | **Global Sequence:** 34/50

**Owner:** Platform Engineering
**Links:** docs/architecture.md §19; kubernetes/workloads/platform/registry/harbor; kubernetes/infrastructure/networking/cilium/gateway

---

## 📖 Story

As a **Platform Engineer**, I need to **create Kubernetes manifests** for Harbor container registry with external state (PostgreSQL via CNPG pooler, Redis via Dragonfly, S3-compatible object storage backed by MinIO), Gateway API HTTPS exposure, and Trivy vulnerability scanning on the **infra cluster**, so that I have a complete, version-controlled configuration for the platform container registry, ready for deployment and validation in Story 45.

## 🎯 Scope

### This Story (34): Manifest Creation (Local Only)
- Create all Kubernetes manifests for Harbor container registry
- Define HelmRelease for Harbor (external DB/Redis/S3)
- Configure External Secrets for database, Redis, S3, admin credentials
- Set up Gateway API HTTPRoute for HTTPS exposure
- Configure MinIO S3 backend for registry blobs and Helm charts
- Define NetworkPolicies for security isolation
- Document architecture, external dependencies, and operational patterns
- **NO cluster deployment** (all work happens locally in git repository)

### Story 45: Deployment and Validation
- Bootstrap infrastructure on both clusters using helmfile
- Deploy all manifests via Flux reconciliation
- Validate Harbor HTTPS endpoint
- Test database/Redis/MinIO connectivity
- Test image push/pull operations
- Validate Trivy scanning
- Validate monitoring and metrics

---

## ✅ Acceptance Criteria

### Manifest Completeness (AC1-AC12)

**AC1**: Harbor namespace manifest exists:
- `kubernetes/workloads/platform/registry/harbor/namespace.yaml` (namespace: `harbor`)

**AC2**: External Secrets configured for all dependencies:
- `kubernetes/workloads/platform/registry/harbor/externalsecrets.yaml`:
  - Database secret: `harbor-db-credentials` (host, port, dbname, username, password, sslmode) from `${HARBOR_DB_SECRET_PATH}`
  - Redis secret: `harbor-redis-credentials` (addr, password) from `${HARBOR_REDIS_SECRET_PATH}`
  - S3 secret: `harbor-s3-credentials` (regionendpoint, bucket, accesskey, secretkey) from `${HARBOR_S3_SECRET_PATH}`
  - Admin secret: `harbor-admin` (password) from `${HARBOR_ADMIN_SECRET_PATH}`

**AC3**: Harbor HelmRelease configured with external state:
- `kubernetes/workloads/platform/registry/harbor/helmrelease.yaml`:
  - Chart: `harbor/harbor` (version 1.14+)
  - `externalURL: https://${HARBOR_HOST}`
  - `expose.type: clusterIP` (use Gateway API for ingress)
  - External PostgreSQL: `database.type: external` with CNPG pooler connection
  - External Redis: `redis.type: external` with Dragonfly connection
  - External S3: `persistence.imageChartStorage.type: s3` with MinIO backend
  - MinIO-specific settings: `disableredirect: true`, `registry.relativeurls: true`
  - ChartMuseum disabled: `chartmuseum.enabled: false` (use OCI artifacts)
  - Trivy enabled: `trivy.enabled: true` (vulnerability scanning)
  - Resource requests/limits for production sizing

**AC4**: MinIO S3 configuration for object storage:
- `persistence.imageChartStorage.type: s3`
- `s3.regionendpoint: http://10.25.11.3:9000` (MinIO endpoint)
- `s3.bucket: harbor`
- `s3.accesskey` and `s3.secretkey` via HelmRelease `valuesFrom` (no plaintext)
- `persistence.imageChartStorage.disableredirect: true` (MinIO compatibility)
- `registry.relativeurls: true` (Gateway-fronted)

**AC5**: Gateway API HTTPRoute for HTTPS exposure:
- `kubernetes/infrastructure/networking/cilium/gateway/harbor-httproute.yaml`:
  - HTTPRoute for `${HARBOR_HOST}` (Harbor UI and registry API)
  - TLS termination with cert-manager issuer
  - Attach to existing Gateway in `cilium-gateway` namespace
  - BackendRef to Harbor Service (port 80)

**AC6**: NetworkPolicies for security isolation:
- `kubernetes/workloads/platform/registry/harbor/networkpolicy.yaml`:
  - Allow egress: CNPG pooler, Dragonfly, MinIO, Trivy update endpoints, DNS
  - Allow ingress: From Gateway for HTTPRoute traffic
  - Default deny: All other traffic

**AC7**: Monitoring and alerting configured:
- `kubernetes/workloads/platform/registry/harbor/monitoring/prometheusrule.yaml` (or `vmrule.yaml`):
  - 6+ alerts: Harbor core unavailable, registry unavailable, database connectivity, Redis connectivity, storage errors, Trivy scan failures
- ServiceMonitor enabled in HelmRelease for Harbor core and registry

**AC8**: Flux Kustomization with correct dependencies:
- `kubernetes/workloads/platform/registry/harbor/ks.yaml`:
  - Depends on: CNPG shared cluster, Dragonfly, External Secrets, cert-manager, Gateway
  - Health check: Harbor core Deployment
  - Wait: true, timeout: 10m

**AC9**: Cluster settings updated with Harbor variables:
- `HARBOR_HOST` (e.g., `harbor.infra.example.com`)
- `HARBOR_DB_SECRET_PATH`, `HARBOR_REDIS_SECRET_PATH`, `HARBOR_S3_SECRET_PATH`, `HARBOR_ADMIN_SECRET_PATH`
- MinIO endpoint: `MINIO_ENDPOINT` (e.g., `http://10.25.11.3:9000`)
- MinIO bucket: `HARBOR_S3_BUCKET` (default: `harbor`)

**AC10**: Comprehensive README created:
- `kubernetes/workloads/platform/registry/harbor/README.md`:
  - Architecture overview (external DB/Redis/S3, Gateway API)
  - External dependencies and prerequisites
  - MinIO S3 configuration details
  - Image push/pull usage guide
  - Trivy vulnerability scanning
  - Troubleshooting guide (database connectivity, Redis, MinIO, image operations)
  - Rollback procedure (chart version revert)

**AC11**: Rollback guide documented:
- Procedure for reverting Harbor chart version
- Testing steps for rollback validation
- Evidence requirements

**AC12**: HelmRepository already exists:
- `kubernetes/infrastructure/repositories/helm/harbor.yaml` (chart source)

---

## 📋 Dependencies / Inputs

### Local Tools Required
- Text editor (VS Code, vim, etc.)
- `yq` for YAML validation
- `kustomize` for manifest validation (`kustomize build`)
- `flux` CLI for Kustomization validation (`flux build kustomization`)
- Git for version control

### Upstream Stories (Deployment Prerequisites - Story 45)
- **STORY-DB-CNPG-INFRA** — CNPG shared cluster with `harbor-pooler` (rw)
- **STORY-DB-DRAGONFLY** — Dragonfly (Redis-compatible) deployed
- **STORY-SEC-EXTERNAL-SECRETS-BASE** — External Secrets Operator configured
- **STORY-SEC-CERT-MANAGER** — cert-manager with issuers for TLS
- **STORY-NET-CILIUM-GATEWAY** — Gateway API enabled with Cilium
- **STORY-OBS-VM-STACK** — VictoriaMetrics for ServiceMonitor

### External Prerequisites (Story 45)
- MinIO deployed with bucket `harbor` created
- MinIO accessible at `http://10.25.11.3:9000` (internal endpoint, no TLS)
- 1Password secrets at specified paths (database, Redis, S3, admin)
- DNS record: `${HARBOR_HOST}` pointing to cluster ingress

---

## 🛠️ Tasks / Subtasks

### T1: Prerequisites and Strategy

- [ ] **T1.1**: Review Harbor architecture with external state
  - Study [Harbor Helm chart docs](https://github.com/goharbor/harbor-helm)
  - Understand external PostgreSQL/Redis/S3 configuration
  - Review MinIO compatibility requirements (`disableredirect`, `relativeurls`)
  - Understand Trivy vulnerability scanning

- [ ] **T1.2**: Define directory structure
  ```
  kubernetes/workloads/platform/registry/harbor/
  ├── namespace.yaml
  ├── externalsecrets.yaml
  ├── helmrelease.yaml
  ├── networkpolicy.yaml
  ├── kustomization.yaml
  ├── ks.yaml
  ├── README.md
  └── monitoring/
      ├── prometheusrule.yaml
      └── kustomization.yaml

  kubernetes/infrastructure/networking/cilium/gateway/
  └── harbor-httproute.yaml
  ```

### T2: Namespace Manifest

- [ ] **T2.1**: Create `namespace.yaml`
  ```yaml
  apiVersion: v1
  kind: Namespace
  metadata:
    name: harbor
    labels:
      app.kubernetes.io/managed-by: flux
      toolkit.fluxcd.io/tenant: platform-registry
  ```

### T3: External Secrets

- [ ] **T3.1**: Create `externalsecrets.yaml`
  ```yaml
  apiVersion: external-secrets.io/v1beta1
  kind: ExternalSecret
  metadata:
    name: harbor-db-credentials
    namespace: harbor
  spec:
    refreshInterval: 1h
    secretStoreRef:
      kind: ClusterSecretStore
      name: onepassword
    target:
      name: harbor-db-credentials
      creationPolicy: Owner
      template:
        type: Opaque
        data:
          host: "{{ .host }}"
          port: "{{ .port }}"
          database: "{{ .database }}"
          username: "{{ .username }}"
          password: "{{ .password }}"
          sslmode: "{{ .sslmode | default \"disable\" }}"
    dataFrom:
      - extract:
          key: ${HARBOR_DB_SECRET_PATH}
  ---
  apiVersion: external-secrets.io/v1beta1
  kind: ExternalSecret
  metadata:
    name: harbor-redis-credentials
    namespace: harbor
  spec:
    refreshInterval: 1h
    secretStoreRef:
      kind: ClusterSecretStore
      name: onepassword
    target:
      name: harbor-redis-credentials
      creationPolicy: Owner
      template:
        type: Opaque
        data:
          addr: "{{ .addr }}"
          password: "{{ .password | default \"\" }}"
    dataFrom:
      - extract:
          key: ${HARBOR_REDIS_SECRET_PATH}
  ---
  apiVersion: external-secrets.io/v1beta1
  kind: ExternalSecret
  metadata:
    name: harbor-s3-credentials
    namespace: harbor
  spec:
    refreshInterval: 1h
    secretStoreRef:
      kind: ClusterSecretStore
      name: onepassword
    target:
      name: harbor-s3-credentials
      creationPolicy: Owner
      template:
        type: Opaque
        data:
          regionendpoint: "{{ .regionendpoint }}"
          bucket: "{{ .bucket }}"
          accesskey: "{{ .accesskey }}"
          secretkey: "{{ .secretkey }}"
    dataFrom:
      - extract:
          key: ${HARBOR_S3_SECRET_PATH}
  ---
  apiVersion: external-secrets.io/v1beta1
  kind: ExternalSecret
  metadata:
    name: harbor-admin
    namespace: harbor
  spec:
    refreshInterval: 1h
    secretStoreRef:
      kind: ClusterSecretStore
      name: onepassword
    target:
      name: harbor-admin
      creationPolicy: Owner
      template:
        type: Opaque
        data:
          password: "{{ .password }}"
    dataFrom:
      - extract:
          key: ${HARBOR_ADMIN_SECRET_PATH}
  ```

### T4: Harbor HelmRelease

- [ ] **T4.1**: Create `helmrelease.yaml` (External State Configuration)
  ```yaml
  apiVersion: helm.toolkit.fluxcd.io/v2
  kind: HelmRelease
  metadata:
    name: harbor
    namespace: harbor
  spec:
    interval: 1h
    chart:
      spec:
        chart: harbor
        version: ">=1.14.0 <2.0.0"  # Latest stable
        sourceRef:
          kind: HelmRepository
          name: harbor
          namespace: flux-system
        interval: 12h
    maxHistory: 3
    install:
      createNamespace: false
      remediation:
        retries: 3
      timeout: 10m
    upgrade:
      cleanupOnFail: true
      remediation:
        retries: 3
        strategy: rollback
      timeout: 10m
    valuesFrom:
      # Inject S3 credentials from External Secret
      - kind: Secret
        name: harbor-s3-credentials
        valuesKey: accesskey
        targetPath: persistence.imageChartStorage.s3.accesskey
      - kind: Secret
        name: harbor-s3-credentials
        valuesKey: secretkey
        targetPath: persistence.imageChartStorage.s3.secretkey
      - kind: Secret
        name: harbor-s3-credentials
        valuesKey: regionendpoint
        targetPath: persistence.imageChartStorage.s3.regionendpoint
      - kind: Secret
        name: harbor-s3-credentials
        valuesKey: bucket
        targetPath: persistence.imageChartStorage.s3.bucket
    values:
      # External URL (HTTPS via Gateway)
      externalURL: https://${HARBOR_HOST}

      # Expose configuration (use ClusterIP, Gateway handles ingress)
      expose:
        type: clusterIP
        tls:
          enabled: false  # TLS terminated at Gateway

      # External PostgreSQL (CNPG pooler)
      database:
        type: external
        external:
          host: harbor-pooler-rw.cnpg-system.svc.cluster.local
          port: 5432
          username: harbor_app
          password:
            secret: harbor-db-credentials
            key: password
          coreDatabase: registry
          sslmode: disable  # Internal cluster traffic

      # External Redis (Dragonfly)
      redis:
        type: external
        external:
          addr: dragonfly.dragonfly-system.svc.cluster.local:6379
          password:
            secret: harbor-redis-credentials
            key: password

      # External S3 object storage (MinIO)
      persistence:
        persistentVolumeClaim:
          registry:
            # Disable PVC for registry (use S3)
            existingClaim: ""
            storageClass: ""
            size: 0
          chartmuseum:
            # ChartMuseum disabled (use OCI)
            existingClaim: ""
          jobservice:
            # JobService scan data cache (small PVC)
            storageClass: ${BLOCK_SC}
            size: 10Gi
          database:
            # Database disabled (external)
            existingClaim: ""
          redis:
            # Redis disabled (external)
            existingClaim: ""
          trivy:
            # Trivy vulnerability DB cache
            storageClass: ${BLOCK_SC}
            size: 5Gi

        imageChartStorage:
          # Use S3 for registry blobs and charts
          type: s3
          disableredirect: true  # Required for MinIO
          s3:
            # Credentials injected via valuesFrom (see above)
            # regionendpoint, bucket, accesskey, secretkey
            secure: false  # MinIO is HTTP (internal)
            v4auth: true
            region: us-east-1

      # Registry configuration
      registry:
        relativeurls: true  # Gateway-fronted
        replicas: 2
        resources:
          requests:
            cpu: 100m
            memory: 256Mi
          limits:
            cpu: 500m
            memory: 512Mi

      # Harbor Core
      core:
        replicas: 2
        secret: ${HARBOR_SECRET_KEY}  # From cluster-settings
        xsrfKey: ${HARBOR_XSRF_KEY}   # From cluster-settings
        resources:
          requests:
            cpu: 100m
            memory: 256Mi
          limits:
            cpu: 500m
            memory: 512Mi

      # Portal (UI)
      portal:
        replicas: 2
        resources:
          requests:
            cpu: 50m
            memory: 128Mi
          limits:
            cpu: 200m
            memory: 256Mi

      # JobService
      jobservice:
        replicas: 1
        resources:
          requests:
            cpu: 100m
            memory: 256Mi
          limits:
            cpu: 500m
            memory: 512Mi

      # ChartMuseum (disabled, use OCI)
      chartmuseum:
        enabled: false

      # Trivy vulnerability scanner
      trivy:
        enabled: true
        replicas: 1
        resources:
          requests:
            cpu: 200m
            memory: 512Mi
          limits:
            cpu: 1000m
            memory: 1Gi

      # Notary (image signing, optional)
      notary:
        enabled: false

      # Metrics
      metrics:
        enabled: true
        serviceMonitor:
          enabled: true

      # Admin credentials
      harborAdminPassword:
        secret: harbor-admin
        key: password
  ```

### T5: Gateway API HTTPRoute

- [ ] **T5.1**: Create `infrastructure/networking/cilium/gateway/harbor-httproute.yaml`
  ```yaml
  apiVersion: gateway.networking.k8s.io/v1
  kind: HTTPRoute
  metadata:
    name: harbor
    namespace: harbor
  spec:
    parentRefs:
      - name: cilium-gateway
        namespace: cilium-gateway
    hostnames:
      - ${HARBOR_HOST}
    rules:
      - matches:
          - path:
              type: PathPrefix
              value: /
        backendRefs:
          - name: harbor
            port: 80
  ```

- [ ] **T5.2**: Update `infrastructure/networking/cilium/gateway/kustomization.yaml`
  ```yaml
  # Add harbor-httproute.yaml to resources
  ```

### T6: NetworkPolicy

- [ ] **T6.1**: Create `networkpolicy.yaml`
  ```yaml
  apiVersion: networking.k8s.io/v1
  kind: NetworkPolicy
  metadata:
    name: harbor-egress
    namespace: harbor
  spec:
    podSelector:
      matchLabels:
        app: harbor
    policyTypes:
      - Egress
    egress:
      # Allow DNS
      - to:
          - namespaceSelector:
              matchLabels:
                kubernetes.io/metadata.name: kube-system
        ports:
          - protocol: UDP
            port: 53

      # Allow CNPG pooler (PostgreSQL)
      - to:
          - namespaceSelector:
              matchLabels:
                kubernetes.io/metadata.name: cnpg-system
        ports:
          - protocol: TCP
            port: 5432

      # Allow Dragonfly (Redis)
      - to:
          - namespaceSelector:
              matchLabels:
                kubernetes.io/metadata.name: dragonfly-system
        ports:
          - protocol: TCP
            port: 6379

      # Allow MinIO (S3)
      - to:
          - podSelector: {}
        ports:
          - protocol: TCP
            port: 9000

      # Allow Trivy DB updates (GitHub/Aqua)
      - to:
          - namespaceSelector: {}
        ports:
          - protocol: TCP
            port: 443
  ```

### T7: Monitoring and Alerting

- [ ] **T7.1**: Create `monitoring/prometheusrule.yaml`
  ```yaml
  apiVersion: monitoring.coreos.com/v1
  kind: PrometheusRule
  metadata:
    name: harbor
    namespace: harbor
    labels:
      prometheus: vmagent
  spec:
    groups:
      - name: harbor
        interval: 30s
        rules:
          # Harbor core unavailable
          - alert: HarborCoreUnavailable
            expr: |
              kube_deployment_status_replicas_available{namespace="harbor",deployment="harbor-core"} < 1
            for: 5m
            labels:
              severity: critical
              component: harbor-core
            annotations:
              summary: "Harbor core is unavailable"
              description: "Harbor core has no available replicas for {{ $value }} minutes."

          # Harbor registry unavailable
          - alert: HarborRegistryUnavailable
            expr: |
              kube_deployment_status_replicas_available{namespace="harbor",deployment="harbor-registry"} < 1
            for: 5m
            labels:
              severity: critical
              component: harbor-registry
            annotations:
              summary: "Harbor registry is unavailable"
              description: "Harbor registry has no available replicas for {{ $value }} minutes."

          # Database connectivity
          - alert: HarborDatabaseConnectivityIssue
            expr: |
              increase(harbor_core_database_connection_errors_total[5m]) > 10
            for: 5m
            labels:
              severity: critical
              component: harbor-db
            annotations:
              summary: "Harbor database connectivity issues"
              description: "{{ $value }} database connection errors in the last 5 minutes."

          # Redis connectivity
          - alert: HarborRedisConnectivityIssue
            expr: |
              increase(harbor_core_redis_connection_errors_total[5m]) > 10
            for: 5m
            labels:
              severity: critical
              component: harbor-redis
            annotations:
              summary: "Harbor Redis connectivity issues"
              description: "{{ $value }} Redis connection errors in the last 5 minutes."

          # Storage errors
          - alert: HarborStorageErrors
            expr: |
              increase(harbor_registry_storage_errors_total[10m]) > 50
            for: 10m
            labels:
              severity: warning
              component: harbor-storage
            annotations:
              summary: "Harbor storage errors"
              description: "{{ $value }} storage errors in the last 10 minutes."

          # Trivy scan failures
          - alert: HarborTrivyScanFailures
            expr: |
              increase(harbor_trivy_scan_errors_total[15m]) > 20
            for: 15m
            labels:
              severity: warning
              component: harbor-trivy
            annotations:
              summary: "Harbor Trivy scan failures"
              description: "{{ $value }} Trivy scan failures in the last 15 minutes."
  ```

- [ ] **T7.2**: Create `monitoring/kustomization.yaml`
  ```yaml
  apiVersion: kustomize.config.k8s.io/v1beta1
  kind: Kustomization
  namespace: harbor
  resources:
    - prometheusrule.yaml
  ```

### T8: Flux Kustomization

- [ ] **T8.1**: Create `ks.yaml`
  ```yaml
  apiVersion: kustomize.toolkit.fluxcd.io/v1
  kind: Kustomization
  metadata:
    name: harbor
    namespace: flux-system
  spec:
    interval: 10m
    path: ./kubernetes/workloads/platform/registry/harbor
    prune: true
    wait: true
    timeout: 10m
    sourceRef:
      kind: GitRepository
      name: flux-system
    dependsOn:
      - name: cluster-infra-infrastructure
      - name: external-secrets
      - name: cert-manager
      - name: cilium-gateway
    healthChecks:
      - apiVersion: apps/v1
        kind: Deployment
        name: harbor-core
        namespace: harbor
    postBuild:
      substituteFrom:
        - kind: ConfigMap
          name: cluster-settings
  ```

### T9: Kustomization

- [ ] **T9.1**: Create `kustomization.yaml`
  ```yaml
  apiVersion: kustomize.config.k8s.io/v1beta1
  kind: Kustomization
  namespace: harbor
  resources:
    - namespace.yaml
    - externalsecrets.yaml
    - helmrelease.yaml
    - networkpolicy.yaml
    - monitoring
  ```

### T10: Comprehensive README

- [ ] **T10.1**: Create `README.md`
  ```markdown
  # Harbor Container Registry

  ## Overview

  Self-managed Harbor container registry with external dependencies on the **infra cluster**:

  - **Database**: PostgreSQL via CNPG pooler (`harbor-pooler-rw.cnpg-system`)
  - **Cache**: Redis-compatible Dragonfly (`dragonfly.dragonfly-system`)
  - **Object Storage**: MinIO S3-compatible (`http://10.25.11.3:9000`)
  - **Ingress**: Gateway API with Cilium (HTTPS via cert-manager)
  - **Security**: Trivy vulnerability scanning

  ## Architecture

  ```
  ┌─────────────────────────────────────────────────────────────┐
  │                     Infra Cluster                            │
  │                                                               │
  │  ┌──────────────┐     ┌──────────────┐     ┌──────────────┐ │
  │  │   Gateway    │────▶│    Harbor    │────▶│  CNPG Pooler │ │
  │  │   (Cilium)   │     │   (harbor)   │     │  (Postgres)  │ │
  │  │              │     │              │     │              │ │
  │  └──────────────┘     └──────────────┘     └──────────────┘ │
  │                              │                                │
  │                              │                                │
  │                       ┌──────▼────────┐                       │
  │                       │   Dragonfly   │                       │
  │                       │    (Redis)    │                       │
  │                       └───────────────┘                       │
  │                                                               │
  │                       ┌──────────────┐                        │
  │                       │    MinIO     │                        │
  │                       │  (S3 API)    │                        │
  │                       └──────────────┘                        │
  └─────────────────────────────────────────────────────────────┘
  ```

  ## Components

  ```
  harbor/
  ├── namespace.yaml              # harbor namespace
  ├── externalsecrets.yaml        # DB, Redis, S3, admin secrets
  ├── helmrelease.yaml            # Harbor chart with external state
  ├── networkpolicy.yaml          # Egress to DB/Redis/MinIO
  └── monitoring/                 # PrometheusRule (6 alerts)
  ```

  ## External Dependencies

  ### 1. PostgreSQL (CNPG Pooler)

  **Service**: `harbor-pooler-rw.cnpg-system.svc.cluster.local:5432`
  **Database**: `registry`
  **User**: `harbor_app`

  **Secret Path**: `${HARBOR_DB_SECRET_PATH}` (1Password)
  **Secret Keys**: `host`, `port`, `database`, `username`, `password`, `sslmode`

  **Testing**:
  ```bash
  kubectl -n harbor exec -ti deploy/harbor-core -- psql 'host=harbor-pooler-rw.cnpg-system.svc.cluster.local dbname=registry user=harbor_app sslmode=disable' -c 'select 1'
  ```

  ### 2. Redis (Dragonfly)

  **Service**: `dragonfly.dragonfly-system.svc.cluster.local:6379`

  **Secret Path**: `${HARBOR_REDIS_SECRET_PATH}` (1Password)
  **Secret Keys**: `addr`, `password`

  **Testing**:
  ```bash
  kubectl -n harbor exec -ti deploy/harbor-core -- redis-cli -h dragonfly.dragonfly-system.svc.cluster.local -p 6379 ping
  ```

  ### 3. MinIO (S3 Object Storage)

  **Endpoint**: `http://10.25.11.3:9000` (internal, no TLS)
  **Bucket**: `harbor`

  **Secret Path**: `${HARBOR_S3_SECRET_PATH}` (1Password)
  **Secret Keys**: `regionendpoint`, `bucket`, `accesskey`, `secretkey`

  **MinIO-Specific Configuration**:
  - `disableredirect: true` (MinIO doesn't support S3 redirects)
  - `registry.relativeurls: true` (Gateway-fronted Harbor)
  - `secure: false` (internal HTTP endpoint)

  **Testing**:
  ```bash
  aws --endpoint-url http://10.25.11.3:9000 s3 ls s3://harbor
  ```

  ## Image Push/Pull

  ### Login

  ```bash
  docker login ${HARBOR_HOST}
  # Username: admin
  # Password: <from harbor-admin secret>
  ```

  ### Create Project

  1. Navigate to `https://${HARBOR_HOST}`
  2. Login as admin
  3. Projects → New Project
  4. Name: `test`, Public: Yes

  ### Push Image

  ```bash
  # Tag image
  docker tag myapp:latest ${HARBOR_HOST}/test/myapp:latest

  # Push
  docker push ${HARBOR_HOST}/test/myapp:latest
  ```

  ### Pull Image

  ```bash
  docker pull ${HARBOR_HOST}/test/myapp:latest
  ```

  ## Trivy Vulnerability Scanning

  ### Automatic Scanning

  Harbor automatically scans images on push when Trivy is enabled.

  **View Scan Results**:
  1. Navigate to project → Repositories
  2. Click on image tag
  3. View "Vulnerabilities" tab

  ### Manual Scan

  ```bash
  # Trigger scan via API
  curl -X POST "https://${HARBOR_HOST}/api/v2.0/projects/test/repositories/myapp/artifacts/latest/scan" \
    -H "Authorization: Basic $(echo -n 'admin:<password>' | base64)"

  # Check scan status
  curl "https://${HARBOR_HOST}/api/v2.0/projects/test/repositories/myapp/artifacts/latest" \
    -H "Authorization: Basic $(echo -n 'admin:<password>' | base64)" | jq .scan_overview
  ```

  ## Troubleshooting

  ### Check Harbor Status

  ```bash
  # Check all pods
  kubectl -n harbor get pods

  # Check core
  kubectl -n harbor logs -l component=core

  # Check registry
  kubectl -n harbor logs -l component=registry

  # Check jobservice
  kubectl -n harbor logs -l component=jobservice
  ```

  ### Database Connectivity

  ```bash
  # From core pod
  kubectl -n harbor exec -ti deploy/harbor-core -- psql 'host=harbor-pooler-rw.cnpg-system.svc.cluster.local dbname=registry user=harbor_app sslmode=disable' -c 'select 1'
  ```

  ### Redis Connectivity

  ```bash
  # From core pod
  kubectl -n harbor exec -ti deploy/harbor-core -- redis-cli -h dragonfly.dragonfly-system.svc.cluster.local -p 6379 ping
  ```

  ### MinIO Connectivity

  ```bash
  # List bucket contents
  aws --endpoint-url http://10.25.11.3:9000 s3 ls s3://harbor

  # Check bucket policy
  aws --endpoint-url http://10.25.11.3:9000 s3api get-bucket-policy --bucket harbor
  ```

  ### HTTPS Endpoint

  ```bash
  # Test Harbor web
  curl -Ik https://${HARBOR_HOST}

  # Test registry API
  curl -Ik https://${HARBOR_HOST}/v2/

  # Check certificate
  echo | openssl s_client -connect ${HARBOR_HOST}:443 -servername ${HARBOR_HOST} 2>/dev/null | openssl x509 -noout -text
  ```

  ### Image Push/Pull Failures

  **Error: "denied: requested access to the resource is denied"**
  - Check project permissions
  - Verify user has push/pull role

  **Error: "Get https://${HARBOR_HOST}/v2/: x509: certificate signed by unknown authority"**
  - Add Harbor CA to Docker trusted CAs
  - Or use `--insecure-registry` (not recommended for production)

  **Error: "blob upload unknown: blob upload unknown to registry"**
  - Check MinIO connectivity from Harbor
  - Verify S3 credentials in `harbor-s3-credentials`

  ## Rollback Procedure

  ### Rollback Chart Version

  1. **Identify Current Version**:
     ```bash
     flux get helmrelease harbor -n harbor
     ```

  2. **Edit HelmRelease**:
     ```bash
     # Change chart version constraint
     # From: version: ">=1.14.0 <2.0.0"
     # To:   version: "1.13.x"  # Previous stable
     ```

  3. **Commit and Push**:
     ```bash
     git add kubernetes/workloads/platform/registry/harbor/helmrelease.yaml
     git commit -m "rollback: revert Harbor to chart version 1.13.x"
     git push
     ```

  4. **Monitor Rollback**:
     ```bash
     flux reconcile helmrelease harbor -n harbor --with-source
     kubectl -n harbor get pods -w
     ```

  5. **Validate**:
     ```bash
     # Test login
     docker login ${HARBOR_HOST}

     # Test push
     docker push ${HARBOR_HOST}/test/probe:rollback

     # Test pull
     docker pull ${HARBOR_HOST}/test/probe:rollback
     ```

  6. **Evidence**:
     - Record chart version before and after
     - Capture pod status
     - Screenshot successful image push/pull

  ## Monitoring

  ### Metrics

  ```bash
  # Check ServiceMonitors
  kubectl -n harbor get servicemonitor

  # Query VictoriaMetrics
  # up{job~"harbor.*"}
  ```

  ### Alerts

  6 PrometheusRule alerts configured:
  - Harbor core unavailable (critical)
  - Harbor registry unavailable (critical)
  - Database connectivity issues (critical)
  - Redis connectivity issues (critical)
  - Storage errors (warning)
  - Trivy scan failures (warning)

  ## References

  - [Harbor Helm Chart](https://github.com/goharbor/harbor-helm)
  - [Harbor Documentation](https://goharbor.io/docs/)
  - [MinIO S3 Compatibility](https://min.io/docs/minio/linux/integrations/aws-cli-with-minio.html)
  - [Trivy Vulnerability Scanner](https://aquasecurity.github.io/trivy/)
  ```

### T11: Cluster Settings Update

- [ ] **T11.1**: Update `kubernetes/clusters/infra/cluster-settings.yaml`
  ```yaml
  # Harbor configuration
  HARBOR_HOST: "harbor.infra.example.com"

  # Secret paths (1Password)
  HARBOR_DB_SECRET_PATH: "kubernetes/infra/harbor/database"
  HARBOR_REDIS_SECRET_PATH: "kubernetes/infra/harbor/redis"
  HARBOR_S3_SECRET_PATH: "kubernetes/infra/harbor/s3"
  HARBOR_ADMIN_SECRET_PATH: "kubernetes/infra/harbor/admin"

  # Harbor secrets (generate with pwgen or similar)
  HARBOR_SECRET_KEY: "<generate-random-32-char-string>"
  HARBOR_XSRF_KEY: "<generate-random-32-char-string>"

  # MinIO configuration
  MINIO_ENDPOINT: "http://10.25.11.3:9000"
  HARBOR_S3_BUCKET: "harbor"
  ```

### T12: Validation and Git Commit

- [ ] **T12.1**: Validate all manifests with kustomize
  ```bash
  # Validate Harbor kustomization
  kustomize build kubernetes/workloads/platform/registry/harbor

  # Validate Gateway HTTPRoute
  kustomize build kubernetes/infrastructure/networking/cilium/gateway
  ```

- [ ] **T12.2**: Validate Flux Kustomization
  ```bash
  # Validate Harbor Flux Kustomization
  flux build kustomization harbor \
    --path ./kubernetes/workloads/platform/registry/harbor \
    --kustomization-file ./kubernetes/workloads/platform/registry/harbor/ks.yaml
  ```

- [ ] **T12.3**: Commit manifests to git
  ```bash
  git add kubernetes/workloads/platform/registry/harbor/
  git add kubernetes/infrastructure/networking/cilium/gateway/harbor-httproute.yaml
  git commit -m "feat(harbor): add Harbor manifests with external state and MinIO S3 backend

  - Create Harbor HelmRelease with external PostgreSQL/Redis/MinIO
  - Configure MinIO S3 backend for registry blobs and charts
  - Set up Gateway API HTTPRoute for HTTPS
  - Add External Secrets for all dependencies
  - Create NetworkPolicy for security isolation
  - Add PrometheusRule with 6 alerts
  - Document architecture, MinIO config, and rollback procedure

  External dependencies:
  - PostgreSQL: CNPG pooler (harbor-pooler-rw.cnpg-system)
  - Redis: Dragonfly (dragonfly.dragonfly-system)
  - S3: MinIO (http://10.25.11.3:9000, bucket: harbor)

  MinIO-specific configuration:
  - disableredirect: true (MinIO compatibility)
  - registry.relativeurls: true (Gateway-fronted)
  - secure: false (internal HTTP endpoint)

  Features:
  - Trivy vulnerability scanning enabled
  - ChartMuseum disabled (use OCI artifacts)
  - ServiceMonitor for metrics

  Story: STORY-APP-HARBOR (34/50)
  Related: STORY-DB-CNPG-INFRA, STORY-DB-DRAGONFLY, STORY-NET-CILIUM-GATEWAY"
  ```

---

## 🧪 Runtime Validation (Deferred to Story 45)

**IMPORTANT**: The following validation steps are **NOT performed in this story**. They are documented here for reference and will be executed in Story 45 after deployment.

### Deployment Validation (Story 45)

```bash
# 1. Bootstrap infrastructure
task bootstrap:infra

# 2. Verify Flux reconciliation
flux --context=infra get kustomizations -A
flux --context=infra get helmreleases -n harbor

# 3. Check Harbor pods
kubectl --context=infra -n harbor get pods

# 4. Test HTTPS endpoint
curl -Ik https://${HARBOR_HOST}
curl -Ik https://${HARBOR_HOST}/v2/

# 5. Test database connectivity
kubectl --context=infra -n harbor exec -ti deploy/harbor-core -- psql 'host=harbor-pooler-rw.cnpg-system.svc.cluster.local dbname=registry user=harbor_app sslmode=disable' -c 'select 1'

# 6. Test Redis connectivity
kubectl --context=infra -n harbor exec -ti deploy/harbor-core -- redis-cli -h dragonfly.dragonfly-system.svc.cluster.local -p 6379 ping

# 7. Test MinIO connectivity
aws --endpoint-url http://10.25.11.3:9000 s3 ls s3://harbor

# 8. Test image push
docker login ${HARBOR_HOST}
docker tag busybox:latest ${HARBOR_HOST}/test/busybox:latest
docker push ${HARBOR_HOST}/test/busybox:latest

# 9. Test image pull
docker pull ${HARBOR_HOST}/test/busybox:latest

# 10. Verify Trivy scan
# Check Harbor UI → Projects → test → Repositories → busybox → Vulnerabilities

# 11. Check metrics
kubectl --context=infra -n harbor port-forward svc/harbor 8080:80
curl http://localhost:8080/metrics
```

---

## ✅ Definition of Done

### Manifest Creation (This Story)
- [ ] All manifests created per AC1-AC12
- [ ] Kustomize validation passes (`kustomize build`)
- [ ] Flux validation passes (`flux build kustomization`)
- [ ] README.md comprehensive and accurate
- [ ] Rollback procedure documented
- [ ] Git commit pushed to repository
- [ ] No deployment or cluster access performed

### Deployment and Validation (Story 45)
- [ ] Harbor HTTPS endpoint accessible
- [ ] Database connectivity verified (CNPG pooler)
- [ ] Redis connectivity verified (Dragonfly)
- [ ] MinIO S3 connectivity verified
- [ ] Image push/pull successful
- [ ] Trivy vulnerability scanning functional
- [ ] Metrics scraped by VictoriaMetrics
- [ ] All 6 alerts active
- [ ] Rollback procedure validated

---

## 📐 Design Notes

### External State Architecture

**Why External PostgreSQL/Redis/MinIO?**

Harbor Helm chart includes PostgreSQL and Redis by default, but production deployments should use external services:

**Benefits**:
- **Separation of concerns**: Stateful services managed separately
- **Reliability**: CNPG provides HA PostgreSQL with automated failover
- **Performance**: Dedicated resources for database/cache/storage
- **Scalability**: Independent scaling of Harbor components vs storage
- **Backup/DR**: Centralized backup strategy for all databases

**Trade-offs**:
- More complex configuration (connection strings, secrets)
- Additional dependencies (CNPG, Dragonfly, MinIO must be running first)
- Cross-namespace communication (requires NetworkPolicies)

### MinIO S3 Backend

**Why MinIO instead of PVC?**

Harbor can store registry blobs on PVC or S3-compatible object storage:

**Advantages of MinIO**:
- **Scalability**: Independent scaling of storage capacity
- **Durability**: Erasure coding for data redundancy
- **Cost**: Cheaper than block storage for large blobs
- **Flexibility**: Easy migration to cloud S3 (AWS, GCS, Azure)

**MinIO-Specific Configuration**:

1. **`disableredirect: true`**: MinIO doesn't support S3 redirect responses (HTTP 307). Harbor must directly download blobs instead of redirecting clients.

2. **`registry.relativeurls: true`**: When Harbor is behind a reverse proxy/Gateway, registry must use relative URLs to avoid HTTPS→HTTP downgrade issues.

3. **`secure: false`**: MinIO endpoint is HTTP (internal cluster traffic). For external MinIO, set `secure: true`.

4. **`v4auth: true`**: Use AWS Signature Version 4 for authentication (MinIO default).

### ChartMuseum vs OCI Artifacts

**Why Disable ChartMuseum?**

Harbor originally used ChartMuseum for Helm chart storage, but OCI artifacts are now the standard:

**Advantages of OCI**:
- **Unified storage**: Charts and images use same registry backend
- **Better security**: Same RBAC, scanning, signing as images
- **Standardized**: Helm 3+ native OCI support
- **Simplified**: One less component to maintain

**Configuration**:
- `chartmuseum.enabled: false`
- Helm charts stored as OCI artifacts in registry

### Trivy Vulnerability Scanning

**Why Trivy?**

Harbor supports multiple vulnerability scanners (Clair, Trivy, Anchore). Trivy is preferred:

**Advantages**:
- **Fast**: Scans complete in seconds
- **Comprehensive**: OS packages + language dependencies (npm, Maven, Go, etc.)
- **Up-to-date**: Daily vulnerability database updates
- **Easy**: No separate database required

**Configuration**:
- `trivy.enabled: true`
- Trivy DB stored on PVC (5Gi)
- Internet egress required for DB updates

### Gateway API vs Ingress

**Why Gateway API?**

Harbor Helm chart supports multiple expose types (LoadBalancer, NodePort, Ingress, ClusterIP):

**Advantages of Gateway API + ClusterIP**:
- **Native Cilium integration**: Better performance and observability
- **Standardized**: Kubernetes-native API (GA in v1.29)
- **TLS termination**: Integrated with cert-manager
- **Centralized routing**: All HTTPRoutes in one location

**Configuration**:
- `expose.type: clusterIP`
- Create HTTPRoute manually (in `cilium/gateway/`)
- Attach to existing Gateway (`cilium-gateway`)

### Resource Sizing Guidance

**Harbor Components**:

| Component | Replicas | CPU Request | Memory Request | CPU Limit | Memory Limit |
|-----------|----------|-------------|----------------|-----------|--------------|
| Core | 2 | 100m | 256Mi | 500m | 512Mi |
| Portal | 2 | 50m | 128Mi | 200m | 256Mi |
| Registry | 2 | 100m | 256Mi | 500m | 512Mi |
| JobService | 1 | 100m | 256Mi | 500m | 512Mi |
| Trivy | 1 | 200m | 512Mi | 1000m | 1Gi |

**Total**: ~650m CPU / ~1.5Gi memory (minimum)

**Storage**:
- JobService PVC: 10Gi (scan data cache)
- Trivy PVC: 5Gi (vulnerability DB)
- MinIO bucket: Unlimited (object storage)

### Monitoring Strategy

**6 PrometheusRule Alerts**:

1. **HarborCoreUnavailable** (critical): No core replicas available
2. **HarborRegistryUnavailable** (critical): No registry replicas available
3. **HarborDatabaseConnectivityIssue** (critical): DB connection errors
4. **HarborRedisConnectivityIssue** (critical): Redis connection errors
5. **HarborStorageErrors** (warning): S3 operation errors
6. **HarborTrivyScanFailures** (warning): Trivy scan failures

**Metrics Sources**:
- Harbor exposes Prometheus metrics at `/metrics`
- ServiceMonitor auto-discovered by VictoriaMetrics

### Rollback Strategy

**Chart Version Rollback**:

Harbor Helm chart follows semantic versioning. Rollback procedure:

1. **Identify target version**: Previous stable release
2. **Update HelmRelease**: Change `spec.chart.spec.version`
3. **Commit and push**: GitOps workflow
4. **Monitor reconciliation**: `flux get helmrelease harbor`
5. **Validate**: Test image push/pull
6. **Evidence**: Record version, pod status, test results

**Database Schema Rollback**:

⚠️ **WARNING**: Chart version rollback may fail if database schema migrations are not backward-compatible. Always:
- Test rollback in staging first
- Review release notes for breaking changes
- Have database backup before upgrade

---

## 📝 Change Log

### v3.0 - 2025-10-26
- Refined to manifests-first architecture pattern
- Separated manifest creation (Story 34) from deployment (Story 45)
- Configured external PostgreSQL (CNPG pooler), Redis (Dragonfly), MinIO S3 object storage
- Added MinIO-specific configuration (disableredirect, relativeurls)
- Created Gateway API HTTPRoute for HTTPS exposure
- Disabled ChartMuseum (use OCI artifacts)
- Enabled Trivy vulnerability scanning
- Created 6 PrometheusRule alerts for comprehensive monitoring
- Documented architecture, MinIO configuration, and rollback procedure
- Added comprehensive README with troubleshooting and usage guide

### v2.0 - 2025-10-22
- Original implementation-focused story with deployment tasks

---

**Story Owner:** Platform Engineering
**Last Updated:** 2025-10-26
**Status:** v3.0 (Manifests-first)
