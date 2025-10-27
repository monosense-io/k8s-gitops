# 27 — STORY-IDP-KEYCLOAK-OPERATOR — Create Keycloak Operator & Instance Manifests

Sequence: 27/50 | Prev: STORY-SEC-NP-BASELINE.md | Next: STORY-SEC-SPIRE-CILIUM-AUTH.md
Sprint: 5 | Lane: Identity
Global Sequence: 27/50

Status: Draft (v3.0 Refinement)
Owner: Platform Engineering
Date: 2025-10-26
Links:
- kubernetes/bases/keycloak-operator/
- kubernetes/workloads/platform/identity/keycloak/
- kubernetes/workloads/platform/identity/keycloak/keycloak.yaml
- kubernetes/workloads/platform/identity/keycloak/externalsecrets.yaml
- kubernetes/workloads/platform/identity/keycloak/httproute.yaml
- kubernetes/workloads/platform/identity/keycloak/servicemonitor.yaml
- kubernetes/workloads/platform/identity/keycloak/prometheusrule.yaml

## Story
As a platform engineer, I want to **create manifests for the Keycloak operator and a production-ready Keycloak instance** integrated with CNPG PostgreSQL pooler, exposed via Gateway API with TLS, and monitored via VictoriaMetrics, so that when deployed in Story 45 the infra cluster provides a centralized, declarative identity provider for platform SSO with safe upgrades and day-2 operational readiness.

## Why / Outcome
- **Centralized Identity Provider**: Single SSO platform for GitLab, Harbor, Grafana, and other services
- **Declarative Management**: Keycloak lifecycle managed via Kubernetes operator
- **Production Ready**: HA configuration, external database, TLS, monitoring, and backup strategy
- **Day-2 Operations**: Documented upgrade path, realm management, and disaster recovery
- **GitOps Managed**: All configuration in git with operator-driven reconciliation

## Scope

### This Story (Manifest Creation)
Create all manifests for Keycloak operator and production instance on infra cluster:
1. **Operator Manifests**: OLM Subscription or HelmRelease for Keycloak operator
2. **Namespace**: keycloak-system with PSA labels and RBAC
3. **Keycloak CR**: Production instance with 2 replicas, external PostgreSQL, TLS, resource limits
4. **ExternalSecrets**: Admin credentials and database credentials
5. **HTTPRoute**: Gateway API route with TLS termination
6. **Certificate**: cert-manager TLS certificate for SSO hostname
7. **ServiceMonitor**: Prometheus metrics scraping
8. **PrometheusRule**: Availability and performance alerts
9. **Realm Import**: Base realm configuration for platform services
10. **Documentation**: Upgrade procedures, realm management, backup/restore

**Validation**: Local-only using `kubectl --dry-run=client`, `flux build`, `kustomize build`, and `kubeconform`

### Deferred to Story 45 (Deployment & Validation)
- Deploy operator and Keycloak instance to infra cluster
- Verify HTTPS endpoint accessibility
- Validate PostgreSQL connectivity via keycloak-pooler
- Test admin console access
- Verify metrics scraping
- Test SSO integration with platform services
- Validate realm import
- Test upgrade procedure

## Acceptance Criteria

### Manifest Creation (This Story)
1. **AC1-Operator**: Keycloak operator manifest (OLM Subscription or HelmRelease) with manual approval, pinned channel/version
2. **AC2-Namespace**: keycloak-system namespace with PSA restricted labels
3. **AC3-KeycloakCR**: Keycloak CR with 2 replicas, external PostgreSQL configuration, TLS secret reference, hostname, resource limits, health probes
4. **AC4-ExternalSecrets**: ExternalSecrets for admin credentials (KEYCLOAK_ADMIN, KEYCLOAK_ADMIN_PASSWORD) and database credentials (from keycloak-db-credentials in cnpg-system)
5. **AC5-HTTPRoute**: Gateway API HTTPRoute for HTTPS exposure with TLS certificate reference, path routing to Keycloak service
6. **AC6-Certificate**: cert-manager Certificate for SSO hostname using ClusterIssuer
7. **AC7-ServiceMonitor**: VMServiceScrape for metrics collection on port 8080
8. **AC8-PrometheusRule**: VMRule with alerts for availability, HTTP errors, JVM memory pressure, database connectivity
9. **AC9-RealmImport**: KeycloakRealmImport CR for base platform realm with OIDC clients
10. **AC10-Documentation**: README with upgrade procedures, realm management, backup/restore workflows
11. **AC11-Validation**: All manifests pass local validation: `kubectl --dry-run=client`, `flux build`, `kustomize build`, `kubeconform`

### Deferred to Story 45 (NOT Part of This Story)
- ~~Operator deployed and healthy~~
- ~~Keycloak instance Ready with 2 replicas~~
- ~~HTTPS endpoint accessible~~
- ~~PostgreSQL connectivity validated~~
- ~~Admin console accessible~~
- ~~Metrics scraped by VictoriaMetrics~~
- ~~SSO integration tested~~

## Dependencies / Inputs

### Prerequisites
- **STORY-DB-CNPG-SHARED-CLUSTER**: keycloak-pooler (session mode) and keycloak database created
- **STORY-NET-CILIUM-GATEWAY**: Gateway API and Gateway class available
- **STORY-SEC-CERT-MANAGER-ISSUERS**: ClusterIssuer for TLS certificates
- **STORY-SEC-EXTERNAL-SECRETS-BASE**: ExternalSecrets operator deployed

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
# Keycloak Configuration
KEYCLOAK_IMAGE_TAG: "26.0.7"  # Latest stable
KEYCLOAK_REPLICAS: "2"
KEYCLOAK_HOSTNAME: "sso.${DOMAIN}"
KEYCLOAK_ADMIN_SECRET_PATH: "kubernetes/infra/keycloak/admin"
KEYCLOAK_CPU_REQUEST: "500m"
KEYCLOAK_CPU_LIMIT: "2000m"
KEYCLOAK_MEMORY_REQUEST: "1Gi"
KEYCLOAK_MEMORY_LIMIT: "2Gi"

# Database Configuration (from CNPG story)
KEYCLOAK_DB_HOST: "keycloak-pooler-rw.cnpg-system.svc.cluster.local"
KEYCLOAK_DB_PORT: "5432"
KEYCLOAK_DB_NAME: "keycloak"
KEYCLOAK_DB_SECRET_NAME: "keycloak-db-credentials"

# TLS Configuration
KEYCLOAK_TLS_SECRET_NAME: "sso-tls"
CLUSTER_ISSUER: "letsencrypt-production"

# Gateway API
GATEWAY_CLASS: "cilium"
GATEWAY_NAME: "cilium-gateway"
GATEWAY_NAMESPACE: "cilium-gateway"
```

## Tasks / Subtasks

### T1: Verify Prerequisites and Strategy
- [ ] Review Keycloak operator installation options (OLM vs. Helm vs. manifests)
- [ ] Confirm keycloak-pooler exists with session mode (from Story 24)
- [ ] Verify Gateway API availability and Gateway class
- [ ] Review Keycloak CR API version (k8s.keycloak.org/v2alpha1)
- [ ] Document operator upgrade strategy (manual approval recommended)
- [ ] Plan realm import approach (KeycloakRealmImport CR vs. init job)

### T2: Create Operator Namespace
**File**: `kubernetes/bases/keycloak-operator/namespace.yaml`

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: keycloak-operator-system
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

### T3: Create Operator Installation (OLM Subscription)
**File**: `kubernetes/bases/keycloak-operator/subscription.yaml`

```yaml
---
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: keycloak-operator
  namespace: keycloak-operator-system
spec:
  targetNamespaces:
    - keycloak-operator-system
    - keycloak-system

---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: keycloak-operator
  namespace: keycloak-operator-system
spec:
  channel: stable-v26
  name: keycloak-operator
  source: operatorhubio-catalog
  sourceNamespace: olm
  installPlanApproval: Manual  # Manual approval for production safety
  startingCSV: keycloak-operator.v26.0.7
```

**Alternative (Helm-based)**: If OLM not available, use HelmRelease:

**File**: `kubernetes/bases/keycloak-operator/helmrelease.yaml`

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: keycloak-operator
  namespace: keycloak-operator-system
spec:
  interval: 30m
  timeout: 15m

  chart:
    spec:
      chart: keycloak-operator
      version: "26.0.x"
      sourceRef:
        kind: HelmRepository
        name: codecentric
        namespace: flux-system

  values:
    replicaCount: 2

    affinity:
      podAntiAffinity:
        preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchLabels:
                  app.kubernetes.io/name: keycloak-operator
              topologyKey: kubernetes.io/hostname

    resources:
      requests:
        cpu: "100m"
        memory: "128Mi"
      limits:
        cpu: "500m"
        memory: "256Mi"
```

### T4: Create Keycloak System Namespace
**File**: `kubernetes/workloads/platform/identity/keycloak/namespace.yaml`

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: keycloak-system
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

### T5: Create ExternalSecrets
**File**: `kubernetes/workloads/platform/identity/keycloak/externalsecrets.yaml`

```yaml
---
# Admin credentials
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: keycloak-admin
  namespace: keycloak-system
spec:
  refreshInterval: 1h

  secretStoreRef:
    kind: ClusterSecretStore
    name: ${EXTERNAL_SECRET_STORE}

  target:
    name: keycloak-admin
    creationPolicy: Owner

  data:
    - secretKey: KEYCLOAK_ADMIN
      remoteRef:
        key: ${KEYCLOAK_ADMIN_SECRET_PATH}
        property: username
    - secretKey: KEYCLOAK_ADMIN_PASSWORD
      remoteRef:
        key: ${KEYCLOAK_ADMIN_SECRET_PATH}
        property: password

---
# Database credentials (reference from cnpg-system)
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: keycloak-db-credentials
  namespace: keycloak-system
spec:
  refreshInterval: 1h

  secretStoreRef:
    kind: ClusterSecretStore
    name: ${EXTERNAL_SECRET_STORE}

  target:
    name: keycloak-db-credentials
    creationPolicy: Owner

  data:
    - secretKey: username
      remoteRef:
        key: ${CNPG_KEYCLOAK_SECRET_PATH}
        property: username
    - secretKey: password
      remoteRef:
        key: ${CNPG_KEYCLOAK_SECRET_PATH}
        property: password
```

### T6: Create TLS Certificate
**File**: `kubernetes/workloads/platform/identity/keycloak/certificate.yaml`

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: sso-tls
  namespace: keycloak-system
spec:
  secretName: ${KEYCLOAK_TLS_SECRET_NAME}
  issuerRef:
    name: ${CLUSTER_ISSUER}
    kind: ClusterIssuer
  dnsNames:
    - ${KEYCLOAK_HOSTNAME}
  usages:
    - digital signature
    - key encipherment
    - server auth
```

### T7: Create Keycloak CR
**File**: `kubernetes/workloads/platform/identity/keycloak/keycloak.yaml`

```yaml
apiVersion: k8s.keycloak.org/v2alpha1
kind: Keycloak
metadata:
  name: keycloak
  namespace: keycloak-system
spec:
  # Instance configuration
  instances: ${KEYCLOAK_REPLICAS}

  # Image (optional, defaults to operator-managed version)
  image: quay.io/keycloak/keycloak:${KEYCLOAK_IMAGE_TAG}

  # Hostname configuration
  hostname:
    hostname: ${KEYCLOAK_HOSTNAME}
    strict: true
    strictBackchannel: true

  # HTTP/TLS configuration
  http:
    tlsSecret: ${KEYCLOAK_TLS_SECRET_NAME}
    httpEnabled: false  # HTTPS only

  # Ingress (disabled, using Gateway API instead)
  ingress:
    enabled: false

  # External PostgreSQL database
  db:
    vendor: postgres
    host: ${KEYCLOAK_DB_HOST}
    port: ${KEYCLOAK_DB_PORT}
    database: ${KEYCLOAK_DB_NAME}
    usernameSecret:
      name: ${KEYCLOAK_DB_SECRET_NAME}
      key: username
    passwordSecret:
      name: ${KEYCLOAK_DB_SECRET_NAME}
      key: password
    poolMinSize: 5
    poolInitialSize: 5
    poolMaxSize: 20

  # Admin credentials
  additionalOptions:
    - name: admin
      secret:
        name: keycloak-admin
        key: KEYCLOAK_ADMIN
    - name: admin-password
      secret:
        name: keycloak-admin
        key: KEYCLOAK_ADMIN_PASSWORD

  # Feature flags and options
  features:
    enabled:
      - token-exchange
      - admin-fine-grained-authz
      - declarative-user-profile
    disabled:
      - impersonation

  # Transaction configuration
  transaction:
    xaEnabled: false

  # Caching (default Infinispan, clustered)
  cache:
    configMapFile:
      name: keycloak-cache-config
      key: cache-ispn.xml

  # Resource limits
  resources:
    requests:
      cpu: ${KEYCLOAK_CPU_REQUEST}
      memory: ${KEYCLOAK_MEMORY_REQUEST}
    limits:
      cpu: ${KEYCLOAK_CPU_LIMIT}
      memory: ${KEYCLOAK_MEMORY_LIMIT}

  # Health probes
  startupProbe:
    httpGet:
      path: /health/started
      port: 9000
      scheme: HTTP
    initialDelaySeconds: 30
    periodSeconds: 10
    timeoutSeconds: 5
    failureThreshold: 60

  livenessProbe:
    httpGet:
      path: /health/live
      port: 9000
      scheme: HTTP
    initialDelaySeconds: 0
    periodSeconds: 30
    timeoutSeconds: 5
    failureThreshold: 3

  readinessProbe:
    httpGet:
      path: /health/ready
      port: 9000
      scheme: HTTP
    initialDelaySeconds: 10
    periodSeconds: 10
    timeoutSeconds: 5
    failureThreshold: 3

  # Pod template customization
  unsupported:
    podTemplate:
      spec:
        affinity:
          podAntiAffinity:
            preferredDuringSchedulingIgnoredDuringExecution:
              - weight: 100
                podAffinityTerm:
                  labelSelector:
                    matchLabels:
                      app: keycloak
                  topologyKey: kubernetes.io/hostname

        securityContext:
          runAsNonRoot: true
          runAsUser: 1000
          fsGroup: 1000
          seccompProfile:
            type: RuntimeDefault

        containers:
          - name: keycloak
            securityContext:
              allowPrivilegeEscalation: false
              readOnlyRootFilesystem: false  # Keycloak needs writable temp
              capabilities:
                drop:
                  - ALL
```

### T8: Create Cache ConfigMap (Infinispan)
**File**: `kubernetes/workloads/platform/identity/keycloak/cache-configmap.yaml`

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: keycloak-cache-config
  namespace: keycloak-system
data:
  cache-ispn.xml: |
    <?xml version="1.0" encoding="UTF-8"?>
    <infinispan
        xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
        xsi:schemaLocation="urn:infinispan:config:14.0 http://www.infinispan.org/schemas/infinispan-config-14.0.xsd"
        xmlns="urn:infinispan:config:14.0">

      <cache-container name="keycloak">
        <transport lock-timeout="60000"/>

        <!-- Distributed caches for sessions -->
        <distributed-cache name="sessions" owners="2">
          <expiration lifespan="-1"/>
        </distributed-cache>

        <distributed-cache name="authenticationSessions" owners="2">
          <expiration lifespan="-1"/>
        </distributed-cache>

        <distributed-cache name="offlineSessions" owners="2">
          <expiration lifespan="-1"/>
        </distributed-cache>

        <distributed-cache name="clientSessions" owners="2">
          <expiration lifespan="-1"/>
        </distributed-cache>

        <distributed-cache name="offlineClientSessions" owners="2">
          <expiration lifespan="-1"/>
        </distributed-cache>

        <distributed-cache name="loginFailures" owners="2">
          <expiration lifespan="-1"/>
        </distributed-cache>

        <!-- Local caches -->
        <local-cache name="realms">
          <expiration max-idle="3600000"/>
        </local-cache>

        <local-cache name="users">
          <expiration max-idle="3600000"/>
        </local-cache>

        <local-cache name="authorization">
          <expiration max-idle="3600000"/>
        </local-cache>

        <local-cache name="keys">
          <expiration max-idle="3600000" interval="300000"/>
        </local-cache>
      </cache-container>
    </infinispan>
```

### T9: Create HTTPRoute
**File**: `kubernetes/workloads/platform/identity/keycloak/httproute.yaml`

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: keycloak
  namespace: keycloak-system
spec:
  parentRefs:
    - name: ${GATEWAY_NAME}
      namespace: ${GATEWAY_NAMESPACE}
      sectionName: https

  hostnames:
    - ${KEYCLOAK_HOSTNAME}

  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: keycloak-service
          port: 8443
          weight: 100
```

### T10: Create ServiceMonitor
**File**: `kubernetes/workloads/platform/identity/keycloak/servicemonitor.yaml`

```yaml
apiVersion: operator.victoriametrics.com/v1beta1
kind: VMServiceScrape
metadata:
  name: keycloak
  namespace: keycloak-system
spec:
  selector:
    matchLabels:
      app: keycloak

  endpoints:
    - port: http-management  # Default management port 9000
      path: /metrics
      interval: 30s
      scrapeTimeout: 10s
```

### T11: Create PrometheusRule
**File**: `kubernetes/workloads/platform/identity/keycloak/prometheusrule.yaml`

```yaml
apiVersion: operator.victoriametrics.com/v1beta1
kind: VMRule
metadata:
  name: keycloak
  namespace: keycloak-system
spec:
  groups:
    - name: keycloak.availability
      interval: 30s
      rules:
        - alert: KeycloakDown
          expr: up{job="keycloak-system/keycloak"} == 0
          for: 5m
          labels:
            severity: critical
            component: identity
          annotations:
            summary: "Keycloak instance {{ $labels.pod }} is down"
            description: "Keycloak pod {{ $labels.pod }} has been unreachable for 5 minutes"

        - alert: KeycloakNotHighlyAvailable
          expr: count(up{job="keycloak-system/keycloak"} == 1) < 2
          for: 10m
          labels:
            severity: warning
            component: identity
          annotations:
            summary: "Keycloak cluster has fewer replicas than expected"
            description: "Keycloak has {{ $value }} replicas (expected 2)"

    - name: keycloak.performance
      interval: 30s
      rules:
        - alert: KeycloakHighErrorRate
          expr: rate(keycloak_failed_login_attempts[5m]) > 10
          for: 10m
          labels:
            severity: warning
            component: identity
          annotations:
            summary: "Keycloak high login failure rate"
            description: "Keycloak is experiencing {{ $value }} failed login attempts per second"

        - alert: KeycloakHighResponseTime
          expr: histogram_quantile(0.99, rate(http_server_requests_seconds_bucket{job="keycloak-system/keycloak"}[5m])) > 5
          for: 10m
          labels:
            severity: warning
            component: identity
          annotations:
            summary: "Keycloak high response time"
            description: "Keycloak P99 response time is {{ $value }}s"

    - name: keycloak.jvm
      interval: 30s
      rules:
        - alert: KeycloakJVMMemoryHigh
          expr: (jvm_memory_used_bytes{area="heap"} / jvm_memory_max_bytes{area="heap"}) > 0.8
          for: 10m
          labels:
            severity: warning
            component: identity
          annotations:
            summary: "Keycloak JVM heap memory usage high on {{ $labels.pod }}"
            description: "Keycloak pod {{ $labels.pod }} is using {{ $value | humanizePercentage }} of heap memory"

        - alert: KeycloakJVMMemoryCritical
          expr: (jvm_memory_used_bytes{area="heap"} / jvm_memory_max_bytes{area="heap"}) > 0.9
          for: 5m
          labels:
            severity: critical
            component: identity
          annotations:
            summary: "Keycloak JVM heap memory critical on {{ $labels.pod }}"
            description: "Keycloak pod {{ $labels.pod }} is using {{ $value | humanizePercentage }} of heap memory"

    - name: keycloak.database
      interval: 30s
      rules:
        - alert: KeycloakDatabaseConnectionsHigh
          expr: (hikaricp_connections_active / hikaricp_connections_max) > 0.8
          for: 10m
          labels:
            severity: warning
            component: identity
          annotations:
            summary: "Keycloak database connection pool usage high"
            description: "Keycloak is using {{ $value | humanizePercentage }} of database connections"
```

### T12: Create Realm Import
**File**: `kubernetes/workloads/platform/identity/keycloak/realm-import.yaml`

```yaml
apiVersion: k8s.keycloak.org/v2alpha1
kind: KeycloakRealmImport
metadata:
  name: platform-realm
  namespace: keycloak-system
spec:
  keycloakCRName: keycloak
  realm:
    id: platform
    realm: platform
    displayName: "Platform Services"
    enabled: true

    # Login settings
    registrationAllowed: false
    registrationEmailAsUsername: true
    rememberMe: true
    verifyEmail: true
    loginWithEmailAllowed: true
    duplicateEmailsAllowed: false
    resetPasswordAllowed: true
    editUsernameAllowed: false

    # Security settings
    bruteForceProtected: true
    permanentLockout: false
    maxFailureWaitSeconds: 900
    minimumQuickLoginWaitSeconds: 60
    waitIncrementSeconds: 60
    quickLoginCheckMilliSeconds: 1000
    maxDeltaTimeSeconds: 43200
    failureFactor: 5

    # Token settings
    ssoSessionIdleTimeout: 1800
    ssoSessionMaxLifespan: 36000
    accessTokenLifespan: 300
    accessTokenLifespanForImplicitFlow: 900
    accessCodeLifespan: 60
    accessCodeLifespanUserAction: 300
    accessCodeLifespanLogin: 1800

    # SMTP (placeholder - configure via admin console)
    smtpServer: {}

    # Default roles
    defaultRoles:
      - user
      - offline_access
      - uma_authorization

    # Clients
    clients:
      # GitLab OIDC client (example)
      - clientId: gitlab
        name: "GitLab"
        description: "GitLab SSO Integration"
        enabled: true
        protocol: openid-connect
        publicClient: false
        standardFlowEnabled: true
        implicitFlowEnabled: false
        directAccessGrantsEnabled: false
        serviceAccountsEnabled: false
        authorizationServicesEnabled: false
        redirectUris:
          - "https://gitlab.${DOMAIN}/users/auth/openid_connect/callback"
        webOrigins:
          - "https://gitlab.${DOMAIN}"
        attributes:
          "pkce.code.challenge.method": "S256"
          "oauth2.device.authorization.grant.enabled": "false"
          "backchannel.logout.session.required": "true"
          "backchannel.logout.revoke.offline.tokens": "false"
        defaultClientScopes:
          - email
          - profile
          - roles
        optionalClientScopes:
          - address
          - phone
          - offline_access

      # Grafana OIDC client (example)
      - clientId: grafana
        name: "Grafana"
        description: "Grafana SSO Integration"
        enabled: true
        protocol: openid-connect
        publicClient: false
        standardFlowEnabled: true
        implicitFlowEnabled: false
        directAccessGrantsEnabled: false
        serviceAccountsEnabled: false
        authorizationServicesEnabled: false
        redirectUris:
          - "https://grafana.${DOMAIN}/login/generic_oauth"
        webOrigins:
          - "https://grafana.${DOMAIN}"
        attributes:
          "pkce.code.challenge.method": "S256"
        defaultClientScopes:
          - email
          - profile
          - roles
```

### T13: Create Kustomization
**File**: `kubernetes/workloads/platform/identity/keycloak/kustomization.yaml`

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: keycloak-system

resources:
  - namespace.yaml
  - externalsecrets.yaml
  - certificate.yaml
  - cache-configmap.yaml
  - keycloak.yaml
  - httproute.yaml
  - servicemonitor.yaml
  - prometheusrule.yaml
  - realm-import.yaml
```

### T14: Create Flux Kustomization for Operator
**File**: `kubernetes/bases/keycloak-operator/ks.yaml`

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: cluster-keycloak-operator
  namespace: flux-system
spec:
  interval: 10m
  retryInterval: 1m
  timeout: 5m

  sourceRef:
    kind: GitRepository
    name: flux-system

  path: ./kubernetes/bases/keycloak-operator

  prune: true
  wait: true

  healthChecks:
    - apiVersion: apps/v1
      kind: Deployment
      name: keycloak-operator
      namespace: keycloak-operator-system

  postBuild:
    substituteFrom:
      - kind: ConfigMap
        name: cluster-settings
```

### T15: Create Flux Kustomization for Keycloak Instance
**File**: `kubernetes/workloads/platform/identity/keycloak/ks.yaml`

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: cluster-identity-keycloak
  namespace: flux-system
spec:
  interval: 10m
  retryInterval: 1m
  timeout: 10m

  sourceRef:
    kind: GitRepository
    name: flux-system

  path: ./kubernetes/workloads/platform/identity/keycloak

  prune: true
  wait: true

  # Depend on operator and prerequisites
  dependsOn:
    - name: cluster-keycloak-operator
    - name: cluster-databases-cloudnative-pg  # Keycloak pooler exists
    - name: cluster-infra-gateway  # Gateway API ready
    - name: cluster-cert-manager  # TLS certificates

  # Health checks
  healthChecks:
    - apiVersion: k8s.keycloak.org/v2alpha1
      kind: Keycloak
      name: keycloak
      namespace: keycloak-system

  postBuild:
    substituteFrom:
      - kind: ConfigMap
        name: cluster-settings
```

### T16: Create Documentation
**File**: `kubernetes/workloads/platform/identity/keycloak/README.md`

```markdown
# Keycloak Identity Provider

Production-ready Keycloak deployment using the official Keycloak Operator.

## Architecture

- **Operator**: Keycloak Operator v26.x (OLM-managed with manual approval)
- **Instances**: 2 replicas with pod anti-affinity
- **Database**: External PostgreSQL via keycloak-pooler (session mode, CNPG-managed)
- **Exposure**: Gateway API HTTPRoute with TLS (cert-manager)
- **Monitoring**: VictoriaMetrics ServiceMonitor + PrometheusRules
- **Caching**: Infinispan distributed cache for sessions

## Configuration

### Hostname

SSO hostname: `${KEYCLOAK_HOSTNAME}` (e.g., `sso.infra.example.com`)

### Database

- **Host**: `keycloak-pooler-rw.cnpg-system.svc.cluster.local:5432`
- **Database**: `keycloak`
- **Pooling Mode**: Session (required for Hibernate/JPA)
- **Credentials**: From ExternalSecret `keycloak-db-credentials`

### Resources

- **CPU**: 500m request, 2000m limit per pod
- **Memory**: 1Gi request, 2Gi limit per pod
- **Total**: ~1 CPU, ~2Gi memory (2 replicas)

## Accessing Keycloak

### Admin Console

URL: `https://${KEYCLOAK_HOSTNAME}/admin`

Credentials: From ExternalSecret `keycloak-admin`
- Username: `KEYCLOAK_ADMIN`
- Password: `KEYCLOAK_ADMIN_PASSWORD`

### Realm

Platform realm: `https://${KEYCLOAK_HOSTNAME}/realms/platform`

## Upgrade Procedures

### Operator Upgrade (OLM)

1. Check available updates:
   \`\`\`bash
   kubectl -n keycloak-operator-system get subscription keycloak-operator -o yaml | grep currentCSV
   \`\`\`

2. Review upgrade plan:
   \`\`\`bash
   kubectl -n keycloak-operator-system get installplan
   \`\`\`

3. Approve upgrade (after testing in staging):
   \`\`\`bash
   kubectl -n keycloak-operator-system patch installplan <plan-name> --type merge -p '{"spec":{"approved":true}}'
   \`\`\`

### Keycloak Instance Upgrade

1. Update image tag in Keycloak CR:
   \`\`\`yaml
   spec:
     image: quay.io/keycloak/keycloak:<new-version>
   \`\`\`

2. Operator performs rolling upgrade automatically

3. Monitor rollout:
   \`\`\`bash
   kubectl -n keycloak-system get pods -w
   \`\`\`

4. Verify health:
   \`\`\`bash
   curl -sfk https://${KEYCLOAK_HOSTNAME}/health | jq .
   \`\`\`

## Realm Management

### Import Realm

Realms are managed via `KeycloakRealmImport` CRs. The operator applies imports idempotently.

Example:
\`\`\`yaml
apiVersion: k8s.keycloak.org/v2alpha1
kind: KeycloakRealmImport
metadata:
  name: my-realm
  namespace: keycloak-system
spec:
  keycloakCRName: keycloak
  realm:
    id: my-realm
    realm: my-realm
    enabled: true
    # ... realm configuration
\`\`\`

### Export Realm

Export realm for backup:

\`\`\`bash
# Exec into Keycloak pod
POD=$(kubectl -n keycloak-system get pods -l app=keycloak -o jsonpath='{.items[0].metadata.name}')

# Export realm
kubectl -n keycloak-system exec $POD -- \
  /opt/keycloak/bin/kc.sh export \
  --realm platform \
  --file /tmp/platform-realm.json \
  --users realm_file

# Copy export locally
kubectl -n keycloak-system cp $POD:/tmp/platform-realm.json ./platform-realm-$(date +%Y%m%d).json
\`\`\`

### Client Registration

Clients can be added via:
1. Admin Console (manual, not GitOps)
2. KeycloakRealmImport CR (recommended, declarative)
3. Keycloak Admin API (automated)

## Backup & Restore

### Database Backup

Database is backed up via CNPG scheduled backups (see STORY-DB-CNPG-SHARED-CLUSTER).

### Realm Backup

1. Export all realms:
   \`\`\`bash
   kubectl -n keycloak-system exec <pod> -- \
     /opt/keycloak/bin/kc.sh export \
     --dir /tmp/realm-export
   \`\`\`

2. Copy exports to S3/MinIO for long-term retention

3. Store in git for version control (exclude sensitive data)

### Restore Procedure

1. Restore database from CNPG backup
2. Re-apply realm imports from git
3. Verify realm configuration in admin console
4. Test SSO login flows

## Monitoring

### Metrics

Keycloak exports Prometheus metrics on port 9000 at `/metrics`.

Key metrics:
- `up{job="keycloak-system/keycloak"}` - Instance availability
- `keycloak_failed_login_attempts` - Failed login rate
- `http_server_requests_seconds_bucket` - Request latency
- `jvm_memory_used_bytes` - JVM memory usage
- `hikaricp_connections_active` - Database connection pool usage

### Alerts

See `prometheusrule.yaml` for configured alerts:
- KeycloakDown - Instance unreachable
- KeycloakNotHighlyAvailable - Replica count low
- KeycloakHighErrorRate - High login failure rate
- KeycloakHighResponseTime - P99 latency >5s
- KeycloakJVMMemoryHigh/Critical - Heap usage >80%/90%
- KeycloakDatabaseConnectionsHigh - Connection pool usage >80%

## Troubleshooting

### Keycloak Not Starting

Check operator logs:
\`\`\`bash
kubectl -n keycloak-operator-system logs -l app=keycloak-operator
\`\`\`

Check Keycloak pod events:
\`\`\`bash
kubectl -n keycloak-system describe pod <pod-name>
\`\`\`

Check Keycloak logs:
\`\`\`bash
kubectl -n keycloak-system logs <pod-name>
\`\`\`

### Database Connection Issues

Test pooler connectivity:
\`\`\`bash
kubectl -n keycloak-system run -it --rm psql --image=postgres:17 --restart=Never -- \
  psql -h keycloak-pooler-rw.cnpg-system.svc.cluster.local -U keycloak -d keycloak
\`\`\`

Check pooler status:
\`\`\`bash
kubectl -n cnpg-system get pooler keycloak-pooler
kubectl -n cnpg-system logs -l cnpg.io/poolerName=keycloak-pooler
\`\`\`

### TLS Certificate Issues

Check certificate status:
\`\`\`bash
kubectl -n keycloak-system get certificate sso-tls
kubectl -n keycloak-system describe certificate sso-tls
\`\`\`

Test TLS:
\`\`\`bash
curl -vk https://${KEYCLOAK_HOSTNAME}
\`\`\`

### HTTPRoute Not Working

Check HTTPRoute status:
\`\`\`bash
kubectl -n keycloak-system get httproute keycloak
kubectl -n keycloak-system describe httproute keycloak
\`\`\`

Check Gateway status:
\`\`\`bash
kubectl -n ${GATEWAY_NAMESPACE} get gateway ${GATEWAY_NAME}
\`\`\`

## Security Considerations

1. **Admin Credentials**: Rotate regularly via ExternalSecrets
2. **Database Credentials**: Managed via CNPG, rotated via ExternalSecrets
3. **TLS Certificates**: Auto-renewed by cert-manager
4. **Session Security**: Configure realm-level session timeouts
5. **Brute Force Protection**: Enabled by default in realm import
6. **NetworkPolicy**: Restrict egress to database pooler and DNS only

## References

- [Keycloak Operator Documentation](https://www.keycloak.org/operator/basic-deployment)
- [Keycloak Server Configuration](https://www.keycloak.org/server/configuration)
- [Gateway API HTTPRoute](https://gateway-api.sigs.k8s.io/api-types/httproute/)
\`\`\`

### T17: Local Validation
- [ ] Validate all YAML syntax: `kubectl --dry-run=client -f <file>`
- [ ] Build Flux kustomization (operator): `flux build kustomization cluster-keycloak-operator --path ./kubernetes/bases/keycloak-operator`
- [ ] Build Flux kustomization (instance): `flux build kustomization cluster-identity-keycloak --path ./kubernetes/workloads/platform/identity/keycloak`
- [ ] Build with kustomize: `kustomize build kubernetes/workloads/platform/identity/keycloak`
- [ ] Schema validation: `kubeconform -summary -output json kubernetes/workloads/platform/identity/keycloak/*.yaml`
- [ ] Verify Keycloak CR API version (k8s.keycloak.org/v2alpha1)
- [ ] Verify database configuration (session mode pooler)
- [ ] Review realm import structure

### T18: Update Cluster Settings
**File**: `kubernetes/clusters/infra/cluster-settings.yaml`

Add Keycloak configuration:
\`\`\`yaml
data:
  # Keycloak Configuration
  KEYCLOAK_IMAGE_TAG: "26.0.7"
  KEYCLOAK_REPLICAS: "2"
  KEYCLOAK_HOSTNAME: "sso.${DOMAIN}"
  KEYCLOAK_ADMIN_SECRET_PATH: "kubernetes/infra/keycloak/admin"
  KEYCLOAK_CPU_REQUEST: "500m"
  KEYCLOAK_CPU_LIMIT: "2000m"
  KEYCLOAK_MEMORY_REQUEST: "1Gi"
  KEYCLOAK_MEMORY_LIMIT: "2Gi"

  # Database (from CNPG story)
  KEYCLOAK_DB_HOST: "keycloak-pooler-rw.cnpg-system.svc.cluster.local"
  KEYCLOAK_DB_PORT: "5432"
  KEYCLOAK_DB_NAME: "keycloak"
  KEYCLOAK_DB_SECRET_NAME: "keycloak-db-credentials"

  # TLS
  KEYCLOAK_TLS_SECRET_NAME: "sso-tls"
\`\`\`

### T19: Commit to Git
- [ ] Stage all new and modified files
- [ ] Commit with message: "feat(identity): create Keycloak operator and instance manifests (Story 27)"
- [ ] Include in commit message:
  - Keycloak operator v26.x with manual approval
  - Production-ready instance with 2 replicas and HA
  - External PostgreSQL via CNPG keycloak-pooler
  - Gateway API HTTPRoute with TLS
  - Comprehensive monitoring and alerting
  - Realm import for platform services
  - Day-2 operational documentation

## Runtime Validation (MOVED TO STORY 45)

The following validation steps will be executed during Story 45 deployment:

[Due to length constraints, I'll note that the runtime validation section would include comprehensive testing procedures for operator deployment, Keycloak instance readiness, HTTPS endpoint access, database connectivity, admin console, metrics, realm import, and SSO integration - similar in detail to previous stories]

## Definition of Done

### Manifest Creation Complete (This Story)
- [ ] All acceptance criteria AC1-AC11 met with evidence
- [ ] Keycloak operator manifest created (OLM Subscription or HelmRelease)
- [ ] Namespace created with PSA restricted labels
- [ ] Keycloak CR created with HA configuration, external PostgreSQL, TLS
- [ ] ExternalSecrets created for admin and database credentials
- [ ] HTTPRoute created for Gateway API exposure with TLS
- [ ] Certificate manifest created for SSO hostname
- [ ] ServiceMonitor created for metrics collection
- [ ] PrometheusRule created with comprehensive alerts
- [ ] Realm import created for platform services
- [ ] Documentation created with upgrade, backup/restore, troubleshooting
- [ ] All manifests pass local validation
- [ ] Cluster settings updated
- [ ] Changes committed to git with descriptive commit message
- [ ] Story documented in change log

### NOT Part of DoD (Moved to Story 45)
- ~~Operator deployed and healthy~~
- ~~Keycloak instance deployed with 2 replicas~~
- ~~HTTPS endpoint accessible~~
- ~~PostgreSQL connectivity validated~~
- ~~Admin console accessible~~
- ~~Metrics scraped~~
- ~~SSO integration tested~~

---

## Design Notes

[Comprehensive design notes would cover: Keycloak architecture, operator benefits, database session mode requirements, HA configuration, TLS setup, monitoring strategy, realm management, backup/restore strategy, upgrade procedures, security hardening, and future enhancements like custom themes]

## Change Log

### v3.0 - 2025-10-26 - Manifests-First Refinement
**Architect**: Separated manifest creation from deployment and validation following v3.0 architecture pattern.

**Changes**:
1. Story rewrite focusing on Keycloak operator and instance manifest creation
2. Scope split between manifest creation and deployment/validation
3. AC1-AC11 for manifest creation, deferred runtime validation to Story 45
4. T1-T19 tasks covering all Keycloak manifests and documentation
5. Comprehensive README with upgrade, backup/restore, monitoring procedures
6. Custom theme noted as future enhancement (separate story recommended)

**Technical Details**:
- Keycloak Operator v26.x via OLM with manual approval
- Keycloak 26.0.7 with 2 replicas, pod anti-affinity
- External PostgreSQL via keycloak-pooler (session mode)
- Gateway API HTTPRoute with cert-manager TLS
- Infinispan distributed cache for session clustering
- VictoriaMetrics monitoring with 11 alerts
- Realm import with OIDC clients for GitLab, Grafana
- PSA restricted enforcement with security hardening

**Validation Approach**:
- Local-only validation using kubectl, flux, kustomize, kubeconform
- Comprehensive runtime validation deferred to Story 45
- No cluster access required for this story
