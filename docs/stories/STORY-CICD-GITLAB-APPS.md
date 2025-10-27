# 33 — STORY-CICD-GITLAB-APPS — Create GitLab Manifests (apps)

**Status:** v3.0 (Manifests-first) | **Date:** 2025-10-26
**Sequence:** 33/50 | **Prev:** STORY-CICD-GITHUB-ARC.md | **Next:** STORY-APP-HARBOR.md
**Sprint:** 7 | **Lane:** Applications | **Global Sequence:** 33/50

**Owner:** Platform Engineering
**Links:** docs/architecture.md §"GitLab Configuration"; kubernetes/workloads/tenants/gitlab; kubernetes/infrastructure/networking/cilium/gateway

---

## 📖 Story

As a **Platform Engineer**, I need to **create Kubernetes manifests** for GitLab with external state (PostgreSQL via CNPG pooler, Redis via Dragonfly, S3 object storage), Gateway API HTTPS exposure, Keycloak OIDC SSO, and GitLab Runner with privileged DIND support on the **apps cluster**, so that I have a complete, version-controlled configuration for self-managed GitLab with CI/CD capabilities, ready for deployment and validation in Story 45.

## 🎯 Scope

### This Story (33): Manifest Creation (Local Only)
- Create all Kubernetes manifests for GitLab and GitLab Runner
- Define HelmReleases for GitLab (external DB/Redis/S3) and Runner (Kubernetes executor)
- Configure External Secrets for database, Redis, S3, root credentials, OIDC client
- Set up Gateway API HTTPRoutes for HTTPS exposure (GitLab web + registry)
- Configure Keycloak OIDC integration for SSO (JIT provisioning, auto-linking)
- Define security isolation (privileged namespace for runner, PSA labels)
- Document architecture, external dependencies, and operational patterns
- **NO cluster deployment** (all work happens locally in git repository)

### Story 45: Deployment and Validation
- Bootstrap infrastructure on both clusters using helmfile
- Deploy all manifests via Flux reconciliation
- Validate GitLab web/registry HTTPS endpoints
- Test database/Redis/S3 connectivity
- Validate Keycloak SSO login flow
- Test GitLab Runner registration and DIND pipeline
- Validate monitoring and metrics

---

## ✅ Acceptance Criteria

### Manifest Completeness (AC1-AC14)

**AC1**: GitLab namespace manifests exist:
- `kubernetes/workloads/tenants/gitlab/namespace.yaml` (namespace: `gitlab-system`, no privileged workloads)

**AC2**: GitLab Runner namespace with privileged PSA labels:
- `kubernetes/workloads/tenants/gitlab-runner/namespace.yaml`:
  - `pod-security.kubernetes.io/enforce: privileged` (DIND requires privileged containers)
  - `pod-security.kubernetes.io/audit: privileged`
  - `pod-security.kubernetes.io/warn: privileged`

**AC3**: External Secrets configured for all dependencies:
- `kubernetes/workloads/tenants/gitlab/externalsecrets.yaml`:
  - Database secret: `gitlab-db-credentials` (host, port, dbname, user, password, sslmode) from `${GITLAB_DB_SECRET_PATH}`
  - Redis secret: `gitlab-redis-credentials` (host, port, password) from `${GITLAB_REDIS_SECRET_PATH}`
  - S3 secret: `gitlab-s3-credentials` (endpoint, region, access_key, secret_key, bucket) from `${GITLAB_S3_SECRET_PATH}`
  - Root admin secret: `gitlab-root` (password) from `${GITLAB_ROOT_SECRET_PATH}`
  - OIDC client secret: `gitlab-oidc-credentials` (client_id, client_secret) from `${GITLAB_OIDC_SECRET_PATH}`
- `kubernetes/workloads/tenants/gitlab-runner/externalsecrets.yaml`:
  - Runner registration secret: `gitlab-runner-registration` (token) from `${GITLAB_RUNNER_REG_TOKEN}`

**AC4**: GitLab HelmRelease configured with external state:
- `kubernetes/workloads/tenants/gitlab/helmrelease.yaml`:
  - Chart: `gitlab/gitlab` (version 8.0+)
  - Disable in-chart dependencies: `postgresql.install: false`, `redis.install: false`, `minio.enabled: false`
  - External PostgreSQL: `global.psql.*` pointing to CNPG pooler (`gitlab-pooler-rw.cnpg-system.svc.cluster.local`)
  - External Redis: `global.redis.*` pointing to Dragonfly service
  - External S3: `global.appConfig.object_store.*` using `gitlab-s3-credentials`
  - Ingress disabled: rely on Gateway API HTTPRoutes
  - Root password: from `gitlab-root` secret
  - Resource requests/limits for production sizing

**AC5**: Keycloak OIDC integration configured:
- `global.appConfig.omniauth.*` in GitLab HelmRelease:
  - `enabled: true`
  - `allowSingleSignOn: ['openid_connect']` (JIT provisioning)
  - `autoLinkUser: ['openid_connect']` (auto-link existing users)
  - `blockAutoCreatedUsers: false`
  - `syncProfileFromProvider: ['openid_connect']`
  - Provider: `openid_connect` with `issuer`, `client_id`, `client_secret`, `redirect_uri`

**AC6**: Gateway API HTTPRoutes for HTTPS exposure:
- `kubernetes/infrastructure/networking/cilium/gateway/gitlab-httproutes.yaml`:
  - HTTPRoute for `${GITLAB_HOST}` (GitLab web UI)
  - HTTPRoute for `${GITLAB_REGISTRY_HOST}` (GitLab container registry, optional)
  - TLS termination with cert-manager issuer
  - Attach to existing Gateway in `cilium-gateway` namespace

**AC7**: GitLab Runner HelmRelease with privileged DIND support:
- `kubernetes/workloads/tenants/gitlab-runner/helmrelease.yaml`:
  - Chart: `gitlab/gitlab-runner` (version 0.66+)
  - `gitlabUrl: https://${GITLAB_HOST}`
  - `runnerRegistrationToken` from `gitlab-runner-registration` secret
  - Kubernetes executor: `runners.executor: kubernetes`
  - Privileged mode: `runners.config.kubernetes.privileged: true` (DIND support)
  - Dedicated ServiceAccount with minimal RBAC
  - S3 cache configuration (optional, using `gitlab-s3-credentials`)

**AC8**: RBAC for GitLab Runner:
- `kubernetes/workloads/tenants/gitlab-runner/rbac.yaml`:
  - ServiceAccount: `gitlab-runner`
  - Role: Permissions for pods, secrets, configmaps in `gitlab-runner` namespace
  - RoleBinding: Bind ServiceAccount to Role

**AC9**: NetworkPolicies for security isolation:
- `kubernetes/workloads/tenants/gitlab/networkpolicy.yaml`:
  - Allow egress: CNPG pooler, Redis/Dragonfly, S3 endpoint, SMTP (optional), DNS
  - Allow ingress: From Gateway for HTTPRoute traffic
- `kubernetes/workloads/tenants/gitlab-runner/networkpolicy.yaml`:
  - Allow egress: GitLab API, registries (Harbor/GitLab), Docker registry mirror (Spegel), DNS
  - Deny all other traffic

**AC10**: Monitoring and alerting configured:
- `kubernetes/workloads/tenants/gitlab/monitoring/prometheusrule.yaml` (or `vmrule.yaml`):
  - 8+ alerts: GitLab web unavailable, Sidekiq queue backlog, database connectivity, Redis connectivity, S3 errors, certificate expiry, high error rate, low success rate
- ServiceMonitor enabled in HelmRelease for GitLab and Runner

**AC11**: Flux Kustomizations with correct dependencies:
- `kubernetes/workloads/tenants/gitlab/ks.yaml`:
  - Depends on: CNPG shared cluster, External Secrets, cert-manager, Gateway
  - Health check: GitLab webservice Deployment
  - Wait: true, timeout: 15m (GitLab takes time to initialize)
- `kubernetes/workloads/tenants/gitlab-runner/ks.yaml`:
  - Depends on: GitLab (runner needs GitLab API)
  - Health check: GitLab Runner Deployment
  - Wait: true, timeout: 5m

**AC12**: Cluster settings updated with GitLab variables:
- `GITLAB_HOST` (e.g., `gitlab.apps.example.com`)
- `GITLAB_REGISTRY_HOST` (e.g., `registry.gitlab.apps.example.com`)
- `GITLAB_DB_SECRET_PATH`, `GITLAB_REDIS_SECRET_PATH`, `GITLAB_S3_SECRET_PATH`, `GITLAB_ROOT_SECRET_PATH`, `GITLAB_OIDC_SECRET_PATH`, `GITLAB_RUNNER_REG_TOKEN`
- Keycloak OIDC: `KEYCLOAK_HOST`, `KEYCLOAK_REALM`, `GITLAB_OIDC_CLIENT_ID`

**AC13**: Comprehensive README created:
- `kubernetes/workloads/tenants/gitlab/README.md`:
  - Architecture overview (external DB/Redis/S3, Gateway API, OIDC SSO)
  - External dependencies and prerequisites
  - Keycloak OIDC setup instructions (client creation, redirect URIs)
  - GitLab Runner DIND usage guide
  - Troubleshooting guide (database connectivity, Redis, S3, OIDC, runner registration)
  - Example `.gitlab-ci.yml` for DIND pipeline

**AC14**: Example CI/CD pipeline for DIND:
- `kubernetes/workloads/tenants/gitlab/examples/dind-pipeline.yml`:
  - Sample `.gitlab-ci.yml` using `docker:27` + `docker:27-dind`
  - Build and push image to registry (Harbor or GitLab Registry)
  - Security best practices (no secrets in logs, use CI variables)

---

## 📋 Dependencies / Inputs

### Local Tools Required
- Text editor (VS Code, vim, etc.)
- `yq` for YAML validation
- `kustomize` for manifest validation (`kustomize build`)
- `flux` CLI for Kustomization validation (`flux build kustomization`)
- Git for version control

### Upstream Stories (Deployment Prerequisites - Story 45)
- **STORY-DB-CNPG-APPS** — CNPG shared cluster with `gitlab-pooler` (rw)
- **STORY-DB-DRAGONFLY** — Dragonfly (Redis-compatible) deployed
- **STORY-SEC-EXTERNAL-SECRETS-BASE** — External Secrets Operator configured
- **STORY-SEC-CERT-MANAGER** — cert-manager with issuers for TLS
- **STORY-NET-CILIUM-GATEWAY** — Gateway API enabled with Cilium
- **STORY-OBS-VM-STACK** — VictoriaMetrics for ServiceMonitor

### External Prerequisites (Story 45)
- S3-compatible object storage (MinIO, Rook RGW, AWS S3) with bucket created
- Keycloak realm configured with OIDC client for GitLab
- 1Password secrets at specified paths (database, Redis, S3, root, OIDC, runner token)
- DNS records: `${GITLAB_HOST}`, `${GITLAB_REGISTRY_HOST}` pointing to cluster ingress

---

## 🛠️ Tasks / Subtasks

### T1: Prerequisites and Strategy

- [ ] **T1.1**: Review GitLab architecture with external state
  - Study [GitLab Helm chart docs](https://docs.gitlab.com/charts/)
  - Understand external PostgreSQL/Redis/S3 configuration
  - Review Keycloak OIDC integration requirements
  - Understand privileged DIND security implications

- [ ] **T1.2**: Define directory structure
  ```
  kubernetes/workloads/tenants/
  ├── gitlab/
  │   ├── namespace.yaml
  │   ├── externalsecrets.yaml
  │   ├── helmrelease.yaml
  │   ├── networkpolicy.yaml
  │   ├── kustomization.yaml
  │   ├── ks.yaml
  │   ├── README.md
  │   ├── monitoring/
  │   │   ├── prometheusrule.yaml
  │   │   └── kustomization.yaml
  │   └── examples/
  │       └── dind-pipeline.yml
  └── gitlab-runner/
      ├── namespace.yaml
      ├── externalsecrets.yaml
      ├── helmrelease.yaml
      ├── rbac.yaml
      ├── networkpolicy.yaml
      ├── kustomization.yaml
      └── ks.yaml

  kubernetes/infrastructure/networking/cilium/gateway/
  └── gitlab-httproutes.yaml
  ```

### T2: Namespace Manifests

- [ ] **T2.1**: Create `gitlab/namespace.yaml`
  ```yaml
  apiVersion: v1
  kind: Namespace
  metadata:
    name: gitlab-system
    labels:
      app.kubernetes.io/managed-by: flux
      toolkit.fluxcd.io/tenant: gitlab
      # Default PSA: baseline (no privileged workloads in GitLab)
  ```

- [ ] **T2.2**: Create `gitlab-runner/namespace.yaml`
  ```yaml
  apiVersion: v1
  kind: Namespace
  metadata:
    name: gitlab-runner
    labels:
      pod-security.kubernetes.io/enforce: privileged
      pod-security.kubernetes.io/audit: privileged
      pod-security.kubernetes.io/warn: privileged
      app.kubernetes.io/managed-by: flux
      toolkit.fluxcd.io/tenant: gitlab-runner
  ```

### T3: External Secrets

- [ ] **T3.1**: Create `gitlab/externalsecrets.yaml`
  ```yaml
  apiVersion: external-secrets.io/v1beta1
  kind: ExternalSecret
  metadata:
    name: gitlab-db-credentials
    namespace: gitlab-system
  spec:
    refreshInterval: 1h
    secretStoreRef:
      kind: ClusterSecretStore
      name: onepassword
    target:
      name: gitlab-db-credentials
      creationPolicy: Owner
      template:
        type: Opaque
        data:
          host: "{{ .host }}"
          port: "{{ .port }}"
          database: "{{ .database }}"
          username: "{{ .username }}"
          password: "{{ .password }}"
          sslmode: "{{ .sslmode | default \"require\" }}"
    dataFrom:
      - extract:
          key: ${GITLAB_DB_SECRET_PATH}
  ---
  apiVersion: external-secrets.io/v1beta1
  kind: ExternalSecret
  metadata:
    name: gitlab-redis-credentials
    namespace: gitlab-system
  spec:
    refreshInterval: 1h
    secretStoreRef:
      kind: ClusterSecretStore
      name: onepassword
    target:
      name: gitlab-redis-credentials
      creationPolicy: Owner
      template:
        type: Opaque
        data:
          host: "{{ .host }}"
          port: "{{ .port }}"
          password: "{{ .password | default \"\" }}"
    dataFrom:
      - extract:
          key: ${GITLAB_REDIS_SECRET_PATH}
  ---
  apiVersion: external-secrets.io/v1beta1
  kind: ExternalSecret
  metadata:
    name: gitlab-s3-credentials
    namespace: gitlab-system
  spec:
    refreshInterval: 1h
    secretStoreRef:
      kind: ClusterSecretStore
      name: onepassword
    target:
      name: gitlab-s3-credentials
      creationPolicy: Owner
      template:
        type: Opaque
        data:
          endpoint: "{{ .endpoint }}"
          region: "{{ .region | default \"us-east-1\" }}"
          bucket: "{{ .bucket }}"
          access_key: "{{ .access_key }}"
          secret_key: "{{ .secret_key }}"
    dataFrom:
      - extract:
          key: ${GITLAB_S3_SECRET_PATH}
  ---
  apiVersion: external-secrets.io/v1beta1
  kind: ExternalSecret
  metadata:
    name: gitlab-root
    namespace: gitlab-system
  spec:
    refreshInterval: 1h
    secretStoreRef:
      kind: ClusterSecretStore
      name: onepassword
    target:
      name: gitlab-root
      creationPolicy: Owner
      template:
        type: Opaque
        data:
          password: "{{ .password }}"
    dataFrom:
      - extract:
          key: ${GITLAB_ROOT_SECRET_PATH}
  ---
  apiVersion: external-secrets.io/v1beta1
  kind: ExternalSecret
  metadata:
    name: gitlab-oidc-credentials
    namespace: gitlab-system
  spec:
    refreshInterval: 1h
    secretStoreRef:
      kind: ClusterSecretStore
      name: onepassword
    target:
      name: gitlab-oidc-credentials
      creationPolicy: Owner
      template:
        type: Opaque
        data:
          client_id: "{{ .client_id }}"
          client_secret: "{{ .client_secret }}"
    dataFrom:
      - extract:
          key: ${GITLAB_OIDC_SECRET_PATH}
  ```

- [ ] **T3.2**: Create `gitlab-runner/externalsecrets.yaml`
  ```yaml
  apiVersion: external-secrets.io/v1beta1
  kind: ExternalSecret
  metadata:
    name: gitlab-runner-registration
    namespace: gitlab-runner
  spec:
    refreshInterval: 1h
    secretStoreRef:
      kind: ClusterSecretStore
      name: onepassword
    target:
      name: gitlab-runner-registration
      creationPolicy: Owner
      template:
        type: Opaque
        data:
          runner-registration-token: "{{ .token }}"
    dataFrom:
      - extract:
          key: ${GITLAB_RUNNER_REG_TOKEN}
  ```

### T4: GitLab HelmRelease

- [ ] **T4.1**: Create `gitlab/helmrelease.yaml` (External State Configuration)
  ```yaml
  apiVersion: source.toolkit.fluxcd.io/v1
  kind: HelmRepository
  metadata:
    name: gitlab
    namespace: gitlab-system
  spec:
    interval: 12h
    url: https://charts.gitlab.io
  ---
  apiVersion: helm.toolkit.fluxcd.io/v2
  kind: HelmRelease
  metadata:
    name: gitlab
    namespace: gitlab-system
  spec:
    interval: 1h
    chart:
      spec:
        chart: gitlab
        version: ">=8.0.0 <9.0.0"  # Latest stable
        sourceRef:
          kind: HelmRepository
          name: gitlab
        interval: 12h
    maxHistory: 3
    install:
      createNamespace: false
      remediation:
        retries: 3
      timeout: 15m
    upgrade:
      cleanupOnFail: true
      remediation:
        retries: 3
        strategy: rollback
      timeout: 15m
    values:
      # Global configuration
      global:
        # Hosts and TLS
        hosts:
          domain: ${SECRET_DOMAIN}
          gitlab:
            name: ${GITLAB_HOST}
          registry:
            name: ${GITLAB_REGISTRY_HOST}

        # Ingress: Disable chart ingress, use Gateway API
        ingress:
          enabled: false

        # External PostgreSQL (CNPG pooler)
        psql:
          host: gitlab-pooler-rw.cnpg-system.svc.cluster.local
          port: 5432
          database: gitlab
          username: gitlab_app
          password:
            secret: gitlab-db-credentials
            key: password

        # External Redis (Dragonfly)
        redis:
          host: dragonfly.dragonfly-system.svc.cluster.local
          port: 6379
          password:
            secret: gitlab-redis-credentials
            key: password

        # External S3 object storage (disable in-chart MinIO)
        minio:
          enabled: false

        # Object storage configuration
        appConfig:
          # Artifacts storage
          artifacts:
            enabled: true
            bucket: ${GITLAB_S3_BUCKET_ARTIFACTS}
            connection:
              secret: gitlab-s3-credentials
              key: connection

          # LFS storage
          lfs:
            enabled: true
            bucket: ${GITLAB_S3_BUCKET_LFS}
            connection:
              secret: gitlab-s3-credentials
              key: connection

          # Uploads storage
          uploads:
            enabled: true
            bucket: ${GITLAB_S3_BUCKET_UPLOADS}
            connection:
              secret: gitlab-s3-credentials
              key: connection

          # Packages storage
          packages:
            enabled: true
            bucket: ${GITLAB_S3_BUCKET_PACKAGES}
            connection:
              secret: gitlab-s3-credentials
              key: connection

          # Container registry storage
          registry:
            bucket: ${GITLAB_S3_BUCKET_REGISTRY}
            connection:
              secret: gitlab-s3-credentials
              key: connection

          # OmniAuth (Keycloak OIDC)
          omniauth:
            enabled: true
            allowSingleSignOn: ['openid_connect']
            autoLinkUser: ['openid_connect']
            blockAutoCreatedUsers: false
            syncProfileFromProvider: ['openid_connect']
            syncProfileAttributes: ['name', 'email']
            providers:
              - name: openid_connect
                label: Keycloak
                args:
                  name: openid_connect
                  scope: ['openid', 'profile', 'email']
                  response_type: code
                  issuer: https://${KEYCLOAK_HOST}/realms/${KEYCLOAK_REALM}
                  discovery: true
                  uid_field: preferred_username
                  client_auth_method: query
                  send_scope_to_token_endpoint: false
                  pkce: true
                  client_options:
                    identifier:
                      secret: gitlab-oidc-credentials
                      key: client_id
                    secret:
                      secret: gitlab-oidc-credentials
                      key: client_secret
                    redirect_uri: https://${GITLAB_HOST}/users/auth/openid_connect/callback

        # Initial root password
        initialRootPassword:
          secret: gitlab-root
          key: password

      # Disable in-chart PostgreSQL
      postgresql:
        install: false

      # Disable in-chart Redis
      redis:
        install: false

      # GitLab components
      gitlab:
        # Webservice (Rails app)
        webservice:
          replicaCount: 2
          resources:
            requests:
              cpu: 500m
              memory: 2Gi
            limits:
              cpu: 2000m
              memory: 4Gi
          workhorse:
            resources:
              requests:
                cpu: 100m
                memory: 256Mi
              limits:
                cpu: 500m
                memory: 512Mi

        # Sidekiq (background jobs)
        sidekiq:
          replicaCount: 1
          resources:
            requests:
              cpu: 500m
              memory: 1Gi
            limits:
              cpu: 2000m
              memory: 2Gi

        # Gitaly (Git repository storage)
        gitaly:
          persistence:
            enabled: true
            storageClass: ${BLOCK_SC}
            size: 50Gi
          resources:
            requests:
              cpu: 500m
              memory: 1Gi
            limits:
              cpu: 2000m
              memory: 2Gi

        # GitLab Shell (Git SSH access)
        gitlab-shell:
          resources:
            requests:
              cpu: 100m
              memory: 128Mi
            limits:
              cpu: 500m
              memory: 256Mi

        # Toolbox (admin CLI)
        toolbox:
          resources:
            requests:
              cpu: 100m
              memory: 256Mi
            limits:
              cpu: 500m
              memory: 512Mi

      # Container Registry
      registry:
        enabled: true
        resources:
          requests:
            cpu: 100m
            memory: 256Mi
          limits:
            cpu: 500m
            memory: 512Mi

      # Monitoring
      prometheus:
        install: false  # Use VictoriaMetrics

      # Shared components
      shared-secrets:
        enabled: true

      # Certmanager
      certmanager:
        install: false  # Already deployed

      # Nginx Ingress Controller
      nginx-ingress:
        enabled: false  # Use Cilium Gateway API
  ```

### T5: GitLab Runner HelmRelease

- [ ] **T5.1**: Create `gitlab-runner/rbac.yaml`
  ```yaml
  apiVersion: v1
  kind: ServiceAccount
  metadata:
    name: gitlab-runner
    namespace: gitlab-runner
  ---
  apiVersion: rbac.authorization.k8s.io/v1
  kind: Role
  metadata:
    name: gitlab-runner
    namespace: gitlab-runner
  rules:
    # Pod management for Kubernetes executor
    - apiGroups: [""]
      resources: ["pods", "pods/exec", "pods/log", "pods/attach"]
      verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
    # ConfigMap management
    - apiGroups: [""]
      resources: ["configmaps"]
      verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
    # Secret management (for runner jobs)
    - apiGroups: [""]
      resources: ["secrets"]
      verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
    # Service management
    - apiGroups: [""]
      resources: ["services"]
      verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  ---
  apiVersion: rbac.authorization.k8s.io/v1
  kind: RoleBinding
  metadata:
    name: gitlab-runner
    namespace: gitlab-runner
  roleRef:
    apiGroup: rbac.authorization.k8s.io
    kind: Role
    name: gitlab-runner
  subjects:
    - kind: ServiceAccount
      name: gitlab-runner
      namespace: gitlab-runner
  ```

- [ ] **T5.2**: Create `gitlab-runner/helmrelease.yaml`
  ```yaml
  apiVersion: helm.toolkit.fluxcd.io/v2
  kind: HelmRelease
  metadata:
    name: gitlab-runner
    namespace: gitlab-runner
  spec:
    interval: 1h
    chart:
      spec:
        chart: gitlab-runner
        version: ">=0.66.0 <1.0.0"  # Latest stable
        sourceRef:
          kind: HelmRepository
          name: gitlab
          namespace: gitlab-system
        interval: 12h
    maxHistory: 3
    install:
      createNamespace: false
      remediation:
        retries: 3
    upgrade:
      cleanupOnFail: true
      remediation:
        retries: 3
        strategy: rollback
    values:
      # GitLab URL
      gitlabUrl: https://${GITLAB_HOST}

      # Runner registration token
      runnerRegistrationToken:
        secret: gitlab-runner-registration
        key: runner-registration-token

      # Service account
      rbac:
        create: false
        serviceAccountName: gitlab-runner

      # Runner configuration
      runners:
        # Executor type
        executor: kubernetes

        # Runner tags
        tags: "k8s,dind"

        # Run untagged jobs
        runUntagged: true

        # Kubernetes executor configuration
        config: |
          [[runners]]
            [runners.kubernetes]
              namespace = "gitlab-runner"
              image = "ubuntu:22.04"
              privileged = true  # Enable DIND

              # Service account for runner jobs
              service_account = "gitlab-runner"

              # Resource limits for runner jobs
              cpu_limit = "2"
              cpu_request = "500m"
              memory_limit = "4Gi"
              memory_request = "1Gi"

              # Helper image
              helper_image = "gitlab/gitlab-runner-helper:x86_64-latest"

              # Pull policy
              pull_policy = ["if-not-present"]

              # Node selector (optional)
              # node_selector = { "node-role.kubernetes.io/worker" = "true" }

              # Tolerations (optional)
              # tolerations = []

              # DNS policy
              dns_policy = "cluster-first"

            [runners.cache]
              Type = "s3"
              Shared = true
              [runners.cache.s3]
                ServerAddress = "${GITLAB_S3_ENDPOINT}"
                BucketName = "${GITLAB_S3_BUCKET_CACHE}"
                BucketLocation = "${GITLAB_S3_REGION}"
                Insecure = false
                AuthenticationType = "access-key"
                AccessKey = "${GITLAB_S3_ACCESS_KEY}"
                SecretKey = "${GITLAB_S3_SECRET_KEY}"

      # Resources for runner manager
      resources:
        requests:
          cpu: 100m
          memory: 128Mi
        limits:
          cpu: 500m
          memory: 512Mi

      # Metrics
      metrics:
        enabled: true
        port: 9252
        serviceMonitor:
          enabled: true
  ```

### T6: Gateway API HTTPRoutes

- [ ] **T6.1**: Create `infrastructure/networking/cilium/gateway/gitlab-httproutes.yaml`
  ```yaml
  apiVersion: gateway.networking.k8s.io/v1
  kind: HTTPRoute
  metadata:
    name: gitlab-web
    namespace: gitlab-system
  spec:
    parentRefs:
      - name: cilium-gateway
        namespace: cilium-gateway
    hostnames:
      - ${GITLAB_HOST}
    rules:
      - matches:
          - path:
              type: PathPrefix
              value: /
        backendRefs:
          - name: gitlab-webservice-default
            port: 8181
  ---
  apiVersion: gateway.networking.k8s.io/v1
  kind: HTTPRoute
  metadata:
    name: gitlab-registry
    namespace: gitlab-system
  spec:
    parentRefs:
      - name: cilium-gateway
        namespace: cilium-gateway
    hostnames:
      - ${GITLAB_REGISTRY_HOST}
    rules:
      - matches:
          - path:
              type: PathPrefix
              value: /
        backendRefs:
          - name: gitlab-registry
            port: 5000
  ```

- [ ] **T6.2**: Update `infrastructure/networking/cilium/gateway/kustomization.yaml`
  ```yaml
  # Add gitlab-httproutes.yaml to resources
  ```

### T7: NetworkPolicies

- [ ] **T7.1**: Create `gitlab/networkpolicy.yaml`
  ```yaml
  apiVersion: networking.k8s.io/v1
  kind: NetworkPolicy
  metadata:
    name: gitlab-egress
    namespace: gitlab-system
  spec:
    podSelector:
      matchLabels:
        app: gitlab
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

      # Allow Redis/Dragonfly
      - to:
          - namespaceSelector:
              matchLabels:
                kubernetes.io/metadata.name: dragonfly-system
        ports:
          - protocol: TCP
            port: 6379

      # Allow S3 (external, allow all HTTPS)
      - to:
          - namespaceSelector: {}
        ports:
          - protocol: TCP
            port: 443

      # Allow SMTP (optional)
      - to:
          - namespaceSelector: {}
        ports:
          - protocol: TCP
            port: 587
  ```

- [ ] **T7.2**: Create `gitlab-runner/networkpolicy.yaml`
  ```yaml
  apiVersion: networking.k8s.io/v1
  kind: NetworkPolicy
  metadata:
    name: gitlab-runner-egress
    namespace: gitlab-runner
  spec:
    podSelector:
      matchLabels:
        app: gitlab-runner
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

      # Allow GitLab API
      - to:
          - namespaceSelector:
              matchLabels:
                kubernetes.io/metadata.name: gitlab-system
        ports:
          - protocol: TCP
            port: 8181
          - protocol: TCP
            port: 5000

      # Allow registries (Harbor, GitLab, Docker Hub)
      - to:
          - namespaceSelector: {}
        ports:
          - protocol: TCP
            port: 443

      # Allow Spegel (Docker registry mirror)
      - to:
          - namespaceSelector:
              matchLabels:
                kubernetes.io/metadata.name: spegel-system
        ports:
          - protocol: TCP
            port: 5000
  ```

### T8: Monitoring and Alerting

- [ ] **T8.1**: Create `gitlab/monitoring/prometheusrule.yaml`
  ```yaml
  apiVersion: monitoring.coreos.com/v1
  kind: PrometheusRule
  metadata:
    name: gitlab
    namespace: gitlab-system
    labels:
      prometheus: vmagent
  spec:
    groups:
      - name: gitlab
        interval: 30s
        rules:
          # GitLab web unavailable
          - alert: GitLabWebUnavailable
            expr: |
              kube_deployment_status_replicas_available{namespace="gitlab-system",deployment="gitlab-webservice-default"} < 1
            for: 5m
            labels:
              severity: critical
              component: gitlab-web
            annotations:
              summary: "GitLab web is unavailable"
              description: "GitLab webservice has no available replicas for {{ $value }} minutes."

          # Sidekiq queue backlog
          - alert: GitLabSidekiqQueueBacklog
            expr: |
              gitlab_sidekiq_queue_size > 1000
            for: 15m
            labels:
              severity: warning
              component: gitlab-sidekiq
            annotations:
              summary: "GitLab Sidekiq queue backlog"
              description: "Sidekiq queue {{ $labels.queue }} has {{ $value }} jobs waiting."

          # Database connectivity
          - alert: GitLabDatabaseConnectivityIssue
            expr: |
              increase(gitlab_database_connection_errors_total[5m]) > 10
            for: 5m
            labels:
              severity: critical
              component: gitlab-db
            annotations:
              summary: "GitLab database connectivity issues"
              description: "{{ $value }} database connection errors in the last 5 minutes."

          # Redis connectivity
          - alert: GitLabRedisConnectivityIssue
            expr: |
              increase(gitlab_redis_connection_errors_total[5m]) > 10
            for: 5m
            labels:
              severity: critical
              component: gitlab-redis
            annotations:
              summary: "GitLab Redis connectivity issues"
              description: "{{ $value }} Redis connection errors in the last 5 minutes."

          # S3 errors
          - alert: GitLabS3Errors
            expr: |
              increase(gitlab_object_storage_errors_total[10m]) > 50
            for: 10m
            labels:
              severity: warning
              component: gitlab-s3
            annotations:
              summary: "GitLab S3 errors"
              description: "{{ $value }} S3 errors in the last 10 minutes."

          # Certificate expiry
          - alert: GitLabCertificateExpiringSoon
            expr: |
              (x509_cert_not_after{job="gitlab"} - time()) / 86400 < 30
            for: 1h
            labels:
              severity: warning
              component: gitlab-cert
            annotations:
              summary: "GitLab certificate expiring soon"
              description: "Certificate {{ $labels.subject }} expires in {{ $value | humanizeDuration }}."

          # High error rate
          - alert: GitLabHighErrorRate
            expr: |
              rate(gitlab_http_requests_total{status=~"5.."}[5m]) > 0.05
            for: 10m
            labels:
              severity: warning
              component: gitlab-web
            annotations:
              summary: "GitLab high error rate"
              description: "{{ $value | humanizePercentage }} of requests are returning 5xx errors."

          # Low success rate
          - alert: GitLabLowSuccessRate
            expr: |
              rate(gitlab_http_requests_total{status=~"2.."}[5m]) / rate(gitlab_http_requests_total[5m]) < 0.9
            for: 15m
            labels:
              severity: warning
              component: gitlab-web
            annotations:
              summary: "GitLab low success rate"
              description: "Only {{ $value | humanizePercentage }} of requests are successful."
  ```

- [ ] **T8.2**: Create `gitlab/monitoring/kustomization.yaml`
  ```yaml
  apiVersion: kustomize.config.k8s.io/v1beta1
  kind: Kustomization
  namespace: gitlab-system
  resources:
    - prometheusrule.yaml
  ```

### T9: Flux Kustomizations

- [ ] **T9.1**: Create `gitlab/ks.yaml`
  ```yaml
  apiVersion: kustomize.toolkit.fluxcd.io/v1
  kind: Kustomization
  metadata:
    name: gitlab
    namespace: flux-system
  spec:
    interval: 10m
    path: ./kubernetes/workloads/tenants/gitlab
    prune: true
    wait: true
    timeout: 15m  # GitLab takes time to initialize
    sourceRef:
      kind: GitRepository
      name: flux-system
    dependsOn:
      - name: cluster-apps-infrastructure
      - name: external-secrets
      - name: cert-manager
      - name: cilium-gateway
    healthChecks:
      - apiVersion: apps/v1
        kind: Deployment
        name: gitlab-webservice-default
        namespace: gitlab-system
    postBuild:
      substituteFrom:
        - kind: ConfigMap
          name: cluster-settings
  ```

- [ ] **T9.2**: Create `gitlab-runner/ks.yaml`
  ```yaml
  apiVersion: kustomize.toolkit.fluxcd.io/v1
  kind: Kustomization
  metadata:
    name: gitlab-runner
    namespace: flux-system
  spec:
    interval: 10m
    path: ./kubernetes/workloads/tenants/gitlab-runner
    prune: true
    wait: true
    timeout: 5m
    sourceRef:
      kind: GitRepository
      name: flux-system
    dependsOn:
      - name: gitlab
    healthChecks:
      - apiVersion: apps/v1
        kind: Deployment
        name: gitlab-runner
        namespace: gitlab-runner
    postBuild:
      substituteFrom:
        - kind: ConfigMap
          name: cluster-settings
  ```

### T10: Kustomizations

- [ ] **T10.1**: Create `gitlab/kustomization.yaml`
  ```yaml
  apiVersion: kustomize.config.k8s.io/v1beta1
  kind: Kustomization
  namespace: gitlab-system
  resources:
    - namespace.yaml
    - externalsecrets.yaml
    - helmrelease.yaml
    - networkpolicy.yaml
    - monitoring
  ```

- [ ] **T10.2**: Create `gitlab-runner/kustomization.yaml`
  ```yaml
  apiVersion: kustomize.config.k8s.io/v1beta1
  kind: Kustomization
  namespace: gitlab-runner
  resources:
    - namespace.yaml
    - externalsecrets.yaml
    - rbac.yaml
    - helmrelease.yaml
    - networkpolicy.yaml
  ```

### T11: Example DIND Pipeline

- [ ] **T11.1**: Create `gitlab/examples/dind-pipeline.yml`
  ```yaml
  # Example .gitlab-ci.yml for Docker-in-Docker pipeline
  # This demonstrates how to build and push Docker images using DIND

  stages:
    - build
    - push

  variables:
    DOCKER_HOST: tcp://docker:2375
    DOCKER_TLS_CERTDIR: ""
    DOCKER_DRIVER: overlay2

  # Build stage
  build-image:
    stage: build
    image: docker:27
    services:
      - docker:27-dind
    tags:
      - k8s
      - dind
    before_script:
      - docker info
      - docker version
    script:
      # Build image
      - docker build -t $CI_REGISTRY_IMAGE:$CI_COMMIT_SHORT_SHA .
      - docker build -t $CI_REGISTRY_IMAGE:latest .

      # Save image (optional, for artifacts)
      - docker save $CI_REGISTRY_IMAGE:$CI_COMMIT_SHORT_SHA -o image.tar
    artifacts:
      paths:
        - image.tar
      expire_in: 1 day

  # Push stage
  push-image:
    stage: push
    image: docker:27
    services:
      - docker:27-dind
    tags:
      - k8s
      - dind
    before_script:
      - docker info
      - echo "$CI_REGISTRY_PASSWORD" | docker login -u "$CI_REGISTRY_USER" --password-stdin "$CI_REGISTRY"
    script:
      # Load image from artifacts (if using)
      - docker load -i image.tar

      # Or re-build (if not using artifacts)
      # - docker build -t $CI_REGISTRY_IMAGE:$CI_COMMIT_SHORT_SHA .
      # - docker build -t $CI_REGISTRY_IMAGE:latest .

      # Push to registry
      - docker push $CI_REGISTRY_IMAGE:$CI_COMMIT_SHORT_SHA
      - docker push $CI_REGISTRY_IMAGE:latest
    dependencies:
      - build-image

  # Security best practices:
  # - Use CI variables for sensitive data (Settings > CI/CD > Variables)
  # - Mark sensitive variables as "Masked" and "Protected"
  # - Never echo secrets in script sections
  # - Use minimal images (alpine-based where possible)
  # - Scan images for vulnerabilities (use Trivy, Snyk, etc.)
  ```

### T12: Comprehensive README

- [ ] **T12.1**: Create `gitlab/README.md`
  ```markdown
  # GitLab Self-Managed with External State

  ## Overview

  Self-managed GitLab with external dependencies on the **apps cluster**:

  - **Database**: PostgreSQL via CNPG pooler (`gitlab-pooler-rw.cnpg-system`)
  - **Cache**: Redis-compatible Dragonfly (`dragonfly.dragonfly-system`)
  - **Object Storage**: S3-compatible (MinIO, Rook RGW, AWS S3)
  - **SSO**: Keycloak OIDC (just-in-time provisioning, auto-linking)
  - **Ingress**: Gateway API with Cilium (HTTPS via cert-manager)
  - **CI/CD**: GitLab Runner with privileged DIND support

  ## Architecture

  ```
  ┌─────────────────────────────────────────────────────────────┐
  │                     Apps Cluster                            │
  │                                                             │
  │  ┌──────────────┐     ┌──────────────┐     ┌──────────────┐ │
  │  │   Gateway    │────▶│    GitLab    │────▶│  CNPG Pooler │ │
  │  │   (Cilium)   │     │  (gitlab-    │     │  (Postgres)  │ │
  │  │              │     │   system)    │     │              │ │
  │  └──────────────┘     └──────────────┘     └──────────────┘ │
  │                              │                              │
  │                              │                              │
  │                       ┌──────▼────────┐                     │
  │                       │   Dragonfly   │                     │
  │                       │    (Redis)    │                     │
  │                       └───────────────┘                     │
  │                                                             │
  │  ┌──────────────┐                        ┌──────────────┐   │
  │  │ GitLab Runner│────▶ DIND Jobs ───────▶│   Harbor/    │   │
  │  │ (gitlab-     │     (privileged)       │   Registry   │   │
  │  │  runner)     │                        │              │   │
  │  └──────────────┘                        └──────────────┘   │
  └─────────────────────────────────────────────────────────────┘
                              │
                              │
                    ┌─────────▼─────────┐
                    │  S3 Object Store  │
                    │ (artifacts, LFS,  │
                    │  uploads, etc.)   │
                    └───────────────────┘
  ```

  ## Components

  ```
  gitlab/
  ├── namespace.yaml              # gitlab-system namespace
  ├── externalsecrets.yaml        # DB, Redis, S3, root, OIDC secrets
  ├── helmrelease.yaml            # GitLab chart with external state
  ├── networkpolicy.yaml          # Egress to DB/Redis/S3/SMTP
  ├── monitoring/                 # PrometheusRule (8 alerts)
  └── examples/                   # Sample DIND pipeline

  gitlab-runner/
  ├── namespace.yaml              # gitlab-runner namespace (PSA privileged)
  ├── externalsecrets.yaml        # Runner registration token
  ├── rbac.yaml                   # ServiceAccount, Role, RoleBinding
  ├── helmrelease.yaml            # GitLab Runner chart (Kubernetes executor)
  └── networkpolicy.yaml          # Egress to GitLab/registries
  ```

  ## External Dependencies

  ### 1. PostgreSQL (CNPG Pooler)

  **Service**: `gitlab-pooler-rw.cnpg-system.svc.cluster.local:5432`
  **Database**: `gitlab`
  **User**: `gitlab_app`
  **Required Extensions**: None (Rails handles schema)

  **Secret Path**: `${GITLAB_DB_SECRET_PATH}` (1Password)
  **Secret Keys**: `host`, `port`, `database`, `username`, `password`, `sslmode`

  **Testing**:
  ```bash
  kubectl -n gitlab-system exec -ti deploy/gitlab-toolbox -- bash -lc "psql 'host=gitlab-pooler-rw.cnpg-system.svc.cluster.local dbname=gitlab user=gitlab_app sslmode=require' -c 'select 1'"
  ```

  ### 2. Redis (Dragonfly)

  **Service**: `dragonfly.dragonfly-system.svc.cluster.local:6379`
  **Password**: Optional (set in secret if required)

  **Secret Path**: `${GITLAB_REDIS_SECRET_PATH}` (1Password)
  **Secret Keys**: `host`, `port`, `password`

  **Testing**:
  ```bash
  kubectl -n gitlab-system exec -ti deploy/gitlab-toolbox -- bash -lc "redis-cli -h dragonfly.dragonfly-system.svc.cluster.local -p 6379 ping"
  ```

  ### 3. S3 Object Storage

  **Buckets Required**:
  - `${GITLAB_S3_BUCKET_ARTIFACTS}` (CI/CD artifacts)
  - `${GITLAB_S3_BUCKET_LFS}` (Git LFS objects)
  - `${GITLAB_S3_BUCKET_UPLOADS}` (User uploads)
  - `${GITLAB_S3_BUCKET_PACKAGES}` (Package registry)
  - `${GITLAB_S3_BUCKET_REGISTRY}` (Container registry)
  - `${GITLAB_S3_BUCKET_CACHE}` (Runner cache, optional)

  **Secret Path**: `${GITLAB_S3_SECRET_PATH}` (1Password)
  **Secret Keys**: `endpoint`, `region`, `bucket`, `access_key`, `secret_key`

  **Testing**:
  ```bash
  aws --endpoint-url https://${GITLAB_S3_ENDPOINT} s3 ls s3://${GITLAB_S3_BUCKET_ARTIFACTS}
  ```

  ## Keycloak OIDC Integration

  ### Keycloak Client Setup

  1. **Create Client** in Keycloak realm:
     - Client ID: `gitlab` (or `${GITLAB_OIDC_CLIENT_ID}`)
     - Access Type: **Confidential**
     - Standard Flow: **Enabled**
     - Valid Redirect URIs: `https://${GITLAB_HOST}/users/auth/openid_connect/callback`
     - Web Origins: `https://${GITLAB_HOST}`

  2. **Configure Token Signature**:
     - Realm Settings → Tokens → Default Signature Algorithm: **RS256**

  3. **Generate Client Secret**:
     - Credentials tab → Copy client secret
     - Store in 1Password at `${GITLAB_OIDC_SECRET_PATH}` with keys: `client_id`, `client_secret`

  ### GitLab OIDC Configuration

  Already configured in `helmrelease.yaml`:
  - Provider: `openid_connect`
  - Issuer: `https://${KEYCLOAK_HOST}/realms/${KEYCLOAK_REALM}`
  - Scopes: `openid`, `profile`, `email`
  - JIT Provisioning: Enabled (`allowSingleSignOn`)
  - Auto-Linking: Enabled (`autoLinkUser`)
  - Profile Sync: Enabled (`syncProfileFromProvider`)

  ### Testing SSO

  1. Navigate to `https://${GITLAB_HOST}/users/sign_in`
  2. Click "Sign in with Keycloak"
  3. Authenticate with Keycloak credentials
  4. Verify user is created/logged in to GitLab

  ### Troubleshooting OIDC

  **Error: "Could not authenticate you from Keycloak"**
  - Check client secret is correct in `gitlab-oidc-credentials`
  - Verify redirect URI matches exactly: `https://${GITLAB_HOST}/users/auth/openid_connect/callback`
  - Check Keycloak realm signature algorithm (RS256 required)

  **Error: "TLS verification failed"**
  - If Keycloak uses private CA, mount CA certificate:
    ```yaml
    global:
      certificates:
        customCAs:
          - secret: keycloak-ca
    ```

  ## GitLab Runner DIND Usage

  ### Pipeline Configuration

  See `examples/dind-pipeline.yml` for a complete example.

  **Key Points**:
  - Image: `docker:27`
  - Service: `docker:27-dind`
  - Tags: `k8s`, `dind` (match runner tags)
  - Variables:
    - `DOCKER_HOST: tcp://docker:2375`
    - `DOCKER_TLS_CERTDIR: ""` (disable TLS for simplicity)
    - `DOCKER_DRIVER: overlay2`

  ### Security Considerations

  **Privileged Containers**:
  - Runner jobs run in `gitlab-runner` namespace with PSA `privileged` enforcement
  - Isolated from other workloads
  - Use tags to restrict DIND jobs: `tags: [k8s, dind]`

  **Alternatives to DIND**:
  - **Kaniko**: Build images without privileged containers
  - **BuildKit**: Rootless builds with better security
  - **img**: Unprivileged container builds

  **Best Practices**:
  - Use CI variables for secrets (masked + protected)
  - Never echo credentials in scripts
  - Scan images for vulnerabilities (Trivy, Snyk)
  - Use minimal base images (Alpine-based)
  - Set resource limits on runner jobs

  ## Troubleshooting

  ### Check GitLab Status

  ```bash
  # Check all pods
  kubectl -n gitlab-system get pods

  # Check webservice
  kubectl -n gitlab-system logs -l app=webservice

  # Check Sidekiq
  kubectl -n gitlab-system logs -l app=sidekiq

  # Check migrations
  kubectl -n gitlab-system logs -l app=migrations
  ```

  ### Database Connectivity

  ```bash
  # Exec into toolbox
  kubectl -n gitlab-system exec -ti deploy/gitlab-toolbox -- bash

  # Test DB connection
  gitlab-rake db:doctor

  # Check migrations
  gitlab-rake db:migrate:status
  ```

  ### Redis Connectivity

  ```bash
  # From toolbox
  redis-cli -h dragonfly.dragonfly-system.svc.cluster.local -p 6379 ping

  # Check Sidekiq processing
  gitlab-rake sidekiq:queues:clear
  ```

  ### S3 Object Storage

  ```bash
  # List artifacts bucket
  aws --endpoint-url https://${GITLAB_S3_ENDPOINT} s3 ls s3://${GITLAB_S3_BUCKET_ARTIFACTS}

  # Check SSE encryption
  aws --endpoint-url https://${GITLAB_S3_ENDPOINT} s3api head-object --bucket ${GITLAB_S3_BUCKET_ARTIFACTS} --key <object-key> | jq -r .ServerSideEncryption
  ```

  ### HTTPS Endpoints

  ```bash
  # Test GitLab web
  curl -Ik https://${GITLAB_HOST}

  # Test registry
  curl -Ik https://${GITLAB_REGISTRY_HOST}/v2/

  # Check certificate
  echo | openssl s_client -connect ${GITLAB_HOST}:443 -servername ${GITLAB_HOST} 2>/dev/null | openssl x509 -noout -text
  ```

  ### Runner Registration

  ```bash
  # Check runner pod
  kubectl -n gitlab-runner get pods

  # Check runner logs
  kubectl -n gitlab-runner logs -l app=gitlab-runner

  # Verify runner in GitLab UI
  # Admin → CI/CD → Runners
  ```

  ## Monitoring

  ### Metrics

  ```bash
  # Check ServiceMonitors
  kubectl -n gitlab-system get servicemonitor
  kubectl -n gitlab-runner get servicemonitor

  # Query VictoriaMetrics
  # up{job~"gitlab.*|gitlab-runner"}
  ```

  ### Alerts

  8 PrometheusRule alerts configured:
  - GitLab web unavailable (critical)
  - Sidekiq queue backlog (warning)
  - Database connectivity issues (critical)
  - Redis connectivity issues (critical)
  - S3 errors (warning)
  - Certificate expiring soon (warning)
  - High error rate (warning)
  - Low success rate (warning)

  ## References

  - [GitLab Helm Chart Docs](https://docs.gitlab.com/charts/)
  - [External PostgreSQL](https://docs.gitlab.com/charts/advanced/external-db/)
  - [External Redis](https://docs.gitlab.com/charts/advanced/external-redis/)
  - [External Object Storage](https://docs.gitlab.com/charts/advanced/external-object-storage/)
  - [OmniAuth OIDC](https://docs.gitlab.com/ee/administration/auth/oidc.html)
  - [GitLab Runner](https://docs.gitlab.com/runner/)
  - [Kubernetes Executor](https://docs.gitlab.com/runner/executors/kubernetes.html)
  ```

### T13: Cluster Settings Update

- [ ] **T13.1**: Update `kubernetes/clusters/apps/cluster-settings.yaml`
  ```yaml
  # GitLab configuration
  GITLAB_HOST: "gitlab.apps.example.com"
  GITLAB_REGISTRY_HOST: "registry.gitlab.apps.example.com"

  # Secret paths (1Password)
  GITLAB_DB_SECRET_PATH: "kubernetes/apps/gitlab/database"
  GITLAB_REDIS_SECRET_PATH: "kubernetes/apps/gitlab/redis"
  GITLAB_S3_SECRET_PATH: "kubernetes/apps/gitlab/s3"
  GITLAB_ROOT_SECRET_PATH: "kubernetes/apps/gitlab/root"
  GITLAB_OIDC_SECRET_PATH: "kubernetes/apps/gitlab/oidc"
  GITLAB_RUNNER_REG_TOKEN: "kubernetes/apps/gitlab/runner-token"

  # S3 buckets
  GITLAB_S3_ENDPOINT: "s3.apps.example.com"
  GITLAB_S3_REGION: "us-east-1"
  GITLAB_S3_BUCKET_ARTIFACTS: "gitlab-artifacts"
  GITLAB_S3_BUCKET_LFS: "gitlab-lfs"
  GITLAB_S3_BUCKET_UPLOADS: "gitlab-uploads"
  GITLAB_S3_BUCKET_PACKAGES: "gitlab-packages"
  GITLAB_S3_BUCKET_REGISTRY: "gitlab-registry"
  GITLAB_S3_BUCKET_CACHE: "gitlab-cache"

  # Keycloak OIDC
  KEYCLOAK_HOST: "keycloak.apps.example.com"
  KEYCLOAK_REALM: "master"
  GITLAB_OIDC_CLIENT_ID: "gitlab"
  ```

### T14: Validation and Git Commit

- [ ] **T14.1**: Validate all manifests with kustomize
  ```bash
  # Validate GitLab kustomization
  kustomize build kubernetes/workloads/tenants/gitlab

  # Validate GitLab Runner kustomization
  kustomize build kubernetes/workloads/tenants/gitlab-runner

  # Validate Gateway HTTPRoutes
  kustomize build kubernetes/infrastructure/networking/cilium/gateway
  ```

- [ ] **T14.2**: Validate Flux Kustomizations
  ```bash
  # Validate GitLab Flux Kustomization
  flux build kustomization gitlab \
    --path ./kubernetes/workloads/tenants/gitlab \
    --kustomization-file ./kubernetes/workloads/tenants/gitlab/ks.yaml

  # Validate GitLab Runner Flux Kustomization
  flux build kustomization gitlab-runner \
    --path ./kubernetes/workloads/tenants/gitlab-runner \
    --kustomization-file ./kubernetes/workloads/tenants/gitlab-runner/ks.yaml
  ```

- [ ] **T14.3**: Commit manifests to git
  ```bash
  git add kubernetes/workloads/tenants/gitlab/
  git add kubernetes/workloads/tenants/gitlab-runner/
  git add kubernetes/infrastructure/networking/cilium/gateway/gitlab-httproutes.yaml
  git commit -m "feat(gitlab): add GitLab manifests with external state and Keycloak OIDC

  - Create GitLab HelmRelease with external PostgreSQL/Redis/S3
  - Configure Keycloak OIDC integration (JIT, auto-linking, profile sync)
  - Create GitLab Runner with privileged DIND support
  - Set up Gateway API HTTPRoutes for HTTPS (web + registry)
  - Add External Secrets for all dependencies
  - Create NetworkPolicies for security isolation
  - Add PrometheusRule with 8 alerts
  - Document architecture, OIDC setup, and troubleshooting

  External dependencies:
  - PostgreSQL: CNPG pooler (gitlab-pooler-rw.cnpg-system)
  - Redis: Dragonfly (dragonfly.dragonfly-system)
  - S3: Object storage for artifacts/LFS/uploads/packages/registry
  - SSO: Keycloak OIDC (openid_connect provider)

  Security:
  - GitLab Runner in dedicated namespace with PSA privileged
  - Minimal RBAC for runner jobs
  - NetworkPolicies for egress restrictions

  Story: STORY-CICD-GITLAB-APPS (33/50)
  Related: STORY-DB-CNPG-APPS, STORY-DB-DRAGONFLY, STORY-NET-CILIUM-GATEWAY"
  ```

---

## 🧪 Runtime Validation (Deferred to Story 45)

**IMPORTANT**: The following validation steps are **NOT performed in this story**. They are documented here for reference and will be executed in Story 45 after deployment.

### Deployment Validation (Story 45)

```bash
# 1. Bootstrap infrastructure
task bootstrap:apps

# 2. Verify Flux reconciliation
flux --context=apps get kustomizations -A
flux --context=apps get helmreleases -n gitlab-system

# 3. Check GitLab pods
kubectl --context=apps -n gitlab-system get pods

# 4. Test HTTPS endpoints
curl -Ik https://${GITLAB_HOST}
curl -Ik https://${GITLAB_REGISTRY_HOST}/v2/

# 5. Test database connectivity (from toolbox)
kubectl --context=apps -n gitlab-system exec -ti deploy/gitlab-toolbox -- bash -lc "psql 'host=gitlab-pooler-rw.cnpg-system.svc.cluster.local dbname=gitlab user=gitlab_app sslmode=require' -c 'select 1'"

# 6. Test Redis connectivity
kubectl --context=apps -n gitlab-system exec -ti deploy/gitlab-toolbox -- bash -lc "redis-cli -h dragonfly.dragonfly-system.svc.cluster.local -p 6379 ping"

# 7. Test S3 connectivity
aws --endpoint-url https://${GITLAB_S3_ENDPOINT} s3 ls s3://${GITLAB_S3_BUCKET_ARTIFACTS}

# 8. Test Keycloak OIDC
# Navigate to: https://${GITLAB_HOST}/users/sign_in
# Click "Sign in with Keycloak"
# Authenticate with Keycloak credentials
# Verify user login

# 9. Check runner registration
kubectl --context=apps -n gitlab-runner get pods
# Verify in GitLab: Admin → CI/CD → Runners (should show online)

# 10. Test DIND pipeline
# Create project, add .gitlab-ci.yml from examples/dind-pipeline.yml
# Push commit, trigger pipeline
# Verify image built and pushed to registry

# 11. Check metrics
kubectl --context=apps -n gitlab-system port-forward svc/gitlab-webservice-default 8181:8181
curl http://localhost:8181/-/metrics
```

---

## ✅ Definition of Done

### Manifest Creation (This Story)
- [ ] All manifests created per AC1-AC14
- [ ] Kustomize validation passes (`kustomize build`)
- [ ] Flux validation passes (`flux build kustomization`)
- [ ] README.md comprehensive and accurate
- [ ] Example DIND pipeline created
- [ ] Git commit pushed to repository
- [ ] No deployment or cluster access performed

### Deployment and Validation (Story 45)
- [ ] GitLab web and registry HTTPS endpoints accessible
- [ ] Database connectivity verified (CNPG pooler)
- [ ] Redis connectivity verified (Dragonfly)
- [ ] S3 object storage functional (upload/download artifacts)
- [ ] Keycloak OIDC SSO login works (JIT provisioning, auto-linking)
- [ ] GitLab Runner registered and online
- [ ] DIND pipeline builds and pushes image successfully
- [ ] Metrics scraped by VictoriaMetrics
- [ ] All 8 alerts active

---

## 📐 Design Notes

### External State Architecture

**Why External PostgreSQL/Redis/S3?**

GitLab Helm chart includes PostgreSQL, Redis, and MinIO by default, but production deployments should use external services:

**Benefits**:
- **Separation of concerns**: Stateful services managed separately
- **Reliability**: CNPG provides HA PostgreSQL with automated failover
- **Performance**: Dedicated resources for database/cache/storage
- **Scalability**: Independent scaling of GitLab components vs storage
- **Backup/DR**: Centralized backup strategy for all databases

**Trade-offs**:
- More complex configuration (connection strings, secrets)
- Additional dependencies (CNPG, Dragonfly, S3 service must be running first)
- Cross-namespace communication (requires NetworkPolicies)

### Keycloak OIDC Integration

**Why OIDC instead of SAML?**

GitLab supports both OIDC and SAML for SSO, but OIDC is preferred:

**Advantages**:
- **Discovery**: OIDC supports auto-discovery via `.well-known/openid-configuration`
- **Modern**: JWT-based tokens, simpler than SAML XML
- **Standardized**: Better tooling and library support
- **Fine-grained scopes**: `openid`, `profile`, `email`

**OmniAuth Provider Configuration**:
- `allowSingleSignOn`: Enable JIT user provisioning (create GitLab account on first login)
- `autoLinkUser`: Auto-link existing GitLab users with matching email
- `blockAutoCreatedUsers`: Set `false` to allow immediate access, `true` to require admin approval
- `syncProfileFromProvider`: Sync name/email from Keycloak on each login

**Security Considerations**:
- Always use HTTPS for Keycloak (TLS certificate must be trusted by GitLab)
- Use confidential client (not public client)
- Validate redirect URIs strictly
- Use RS256/RS512 token signing (not HS256)

### GitLab Runner Privileged DIND

**Why Privileged Containers?**

Docker-in-Docker requires privileged containers to access the host's Docker daemon socket. This elevates security risk.

**Risk Mitigation**:
1. **Namespace Isolation**: Runner in dedicated `gitlab-runner` namespace with PSA `privileged`
2. **RBAC Minimization**: ServiceAccount limited to pod management in runner namespace only
3. **NetworkPolicy**: Egress restricted to GitLab API, registries, DNS
4. **Node Isolation** (optional): Use nodeSelector/tolerations to run DIND jobs on dedicated nodes
5. **Tag Restrictions**: Use tags (`k8s`, `dind`) to control which jobs can use privileged runner

**Alternatives to DIND**:
- **Kaniko**: Build images without privileged containers (uses user namespaces)
- **BuildKit**: Rootless builds with better caching
- **img**: Unprivileged container builds
- **Buildah**: Rootless image builds

**Selected: DIND** for compatibility with existing pipelines, but recommend migrating to Kaniko/BuildKit long-term.

### S3 Object Storage Structure

**Bucket Strategy**:

GitLab requires separate buckets (or prefixes) for different object types:

- **Artifacts**: CI/CD job artifacts (`.gitlab-ci.yml` artifacts)
- **LFS**: Git Large File Storage objects
- **Uploads**: User-uploaded files (issues, merge requests)
- **Packages**: Package registry (npm, Maven, NuGet, etc.)
- **Registry**: Container registry images
- **Cache**: Runner cache (optional, improves build performance)

**Why Separate Buckets?**
- **Access Control**: Fine-grained IAM/bucket policies
- **Retention Policies**: Different lifecycle rules per bucket
- **Monitoring**: Separate metrics/billing per bucket
- **Performance**: Independent scaling and tuning

**Alternative**: Single bucket with prefixes (`gitlab-artifacts/`, `gitlab-lfs/`, etc.) - simpler but less flexible.

### Gateway API vs Ingress

**Why Gateway API?**

GitLab Helm chart defaults to Ingress resources, but we use Gateway API:

**Advantages**:
- **Native Cilium integration**: Better performance and observability
- **Standardized**: Kubernetes-native API (GA in v1.29)
- **TLS termination**: Integrated with cert-manager
- **Multi-tenancy**: Separate Gateway resource from routes

**Configuration**:
- Disable chart Ingress: `global.ingress.enabled: false`
- Create HTTPRoutes manually (in `cilium/gateway/`)
- Attach to existing Gateway (`cilium-gateway`)

### Resource Sizing Guidance

**GitLab Components**:

| Component | Replicas | CPU Request | Memory Request | CPU Limit | Memory Limit |
|-----------|----------|-------------|----------------|-----------|--------------|
| Webservice | 2 | 500m | 2Gi | 2000m | 4Gi |
| Sidekiq | 1 | 500m | 1Gi | 2000m | 2Gi |
| Gitaly | 1 | 500m | 1Gi | 2000m | 2Gi |
| Registry | 1 | 100m | 256Mi | 500m | 512Mi |
| Shell | 1 | 100m | 128Mi | 500m | 256Mi |
| Toolbox | 1 | 100m | 256Mi | 500m | 512Mi |

**Total**: ~2 CPU / ~5Gi memory (minimum)

**GitLab Runner**:
- Manager: 100m CPU / 128Mi memory
- Jobs: Configurable per job (default: 500m CPU / 1Gi memory)

### Monitoring Strategy

**8 PrometheusRule Alerts**:

1. **GitLabWebUnavailable** (critical): No webservice replicas available
2. **GitLabSidekiqQueueBacklog** (warning): Sidekiq queue > 1000 jobs
3. **GitLabDatabaseConnectivityIssue** (critical): DB connection errors
4. **GitLabRedisConnectivityIssue** (critical): Redis connection errors
5. **GitLabS3Errors** (warning): S3 operation errors
6. **GitLabCertificateExpiringSoon** (warning): TLS cert expires in <30 days
7. **GitLabHighErrorRate** (warning): >5% 5xx responses
8. **GitLabLowSuccessRate** (warning): <90% 2xx responses

**Metrics Sources**:
- GitLab exposes Prometheus metrics at `/-/metrics`
- Runner exposes metrics at `:9252/metrics`
- ServiceMonitors auto-discovered by VictoriaMetrics

---

## 📝 Change Log

### v3.0 - 2025-10-26
- Refined to manifests-first architecture pattern
- Separated manifest creation (Story 33) from deployment (Story 45)
- Configured external PostgreSQL (CNPG pooler), Redis (Dragonfly), S3 object storage
- Added Keycloak OIDC integration (JIT, auto-linking, profile sync)
- Created Gateway API HTTPRoutes for HTTPS exposure
- Configured GitLab Runner with privileged DIND support in isolated namespace
- Created 8 PrometheusRule alerts for comprehensive monitoring
- Documented architecture, external dependencies, and security considerations
- Added comprehensive README with troubleshooting and example DIND pipeline

### v2.0 - 2025-10-21
- Original implementation-focused story with QA risk assessment
- Included deployment and validation tasks

---

**Story Owner:** Platform Engineering
**Last Updated:** 2025-10-26
**Status:** v3.0 (Manifests-first)
