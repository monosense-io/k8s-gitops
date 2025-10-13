# Keycloak Implementation Plan - Complete Guide

> **Status**: Planning Phase
> **Author**: Alex (DevOps Infrastructure Specialist)
> **Date**: 2025-10-13
> **Objective**: Replace Authentik with Keycloak operator-based deployment with custom Red Hat portal-style login theme

---

## 📋 Table of Contents

- [Executive Summary](#executive-summary)
- [Current Repository Analysis](#current-repository-analysis)
- [Proposed Keycloak Architecture](#proposed-keycloak-architecture)
- [Implementation Plan](#implementation-plan)
  - [Phase 1: Operator Installation](#phase-1-operator-installation)
  - [Phase 2: Custom Theme Creation](#phase-2-custom-theme-creation)
  - [Phase 3: Keycloak Deployment](#phase-3-keycloak-deployment)
  - [Phase 4: Database & Cache Configuration](#phase-4-database--cache-configuration)
  - [Phase 5: Migration from Authentik](#phase-5-migration-from-authentik)
- [Spring Boot Integration](#spring-boot-integration)
- [Custom Theme Development](#custom-theme-development)
- [Production Considerations](#production-considerations)
- [Deployment Steps](#deployment-steps)
- [Monitoring & Operations](#monitoring--operations)
- [Migration Strategy](#migration-strategy)
- [Troubleshooting](#troubleshooting)
- [Resources](#resources)

---

## Executive Summary

### Key Findings

After comprehensive research on implementing Keycloak with operator-based deployment in the GitOps repository, here are the key findings:

- ✅ **Upstream Keycloak Operator** (v26.4.0) is production-ready with multi-AZ HA support
- ✅ Existing infrastructure (CloudNativePG, Dragonfly, Envoy Gateway) perfectly supports Keycloak
- ✅ Spring Boot integration uses standard OAuth2/OIDC (no Keycloak-specific adapters needed)
- ✅ Custom Red Hat-style themes can be deployed via init containers with PatternFly 4
- ✅ Clean migration path from Authentik with minimal downtime

### Why Replace Authentik with Keycloak?

1. **Spring Boot Mandate**: Spring Boot applications have deprecated Keycloak adapters in favor of standard Spring Security OAuth2, making Keycloak the natural choice for OIDC/OAuth2 identity management
2. **Industry Standard**: Keycloak is the most widely adopted open-source identity and access management solution
3. **Enterprise Features**: Better suited for enterprise requirements with extensive protocol support (OIDC, SAML, OAuth2)
4. **Red Hat Backing**: Strong community and enterprise support (Red Hat build available)
5. **Operator Pattern**: Kubernetes-native operator provides better GitOps integration and operational excellence

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                     Envoy Gateway (networking)                   │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ HTTPRoute: sso.monosense.dev → keycloak-service:8080      │ │
│  │ TLS: monosense-dev-tls (existing)                          │ │
│  └────────────────────────────────────────────────────────────┘ │
└──────────────────────────┬──────────────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────────┐
│                 Keycloak (security namespace)                    │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ Keycloak CR (k8s.keycloak.org/v2alpha1)                    │ │
│  │ - Instances: 2 (HA with multi-AZ)                          │ │
│  │ - Image: quay.io/keycloak/keycloak:26.4.0                 │ │
│  │ - Custom Theme: Init container → emptyDir mount            │ │
│  │ - Proxy: X-Forwarded-* headers enabled                     │ │
│  └────┬─────────────────────────────────┬───────────────────┘  │
│       │                                  │                      │
│   ┌───▼──────────────┐           ┌──────▼──────────────┐      │
│   │  PostgreSQL DB    │           │ Dragonfly Cache     │      │
│   │  (databases ns)   │           │ (security ns)       │      │
│   │  via CNPG         │           │ Session replication │      │
│   └───────────────────┘           └─────────────────────┘      │
└─────────────────────────────────────────────────────────────────┘
```

---

## Current Repository Analysis

### Infrastructure Patterns Identified

**GitOps Stack:**
- **Flux CD**: HelmRelease + OCIRepository pattern
- **Networking**: Envoy Gateway with Gateway API (HTTPRoute)
- **Secrets**: External Secrets Operator with 1Password (ClusterSecretStore: `onepassword`)
- **Database**: CloudNativePG cluster (`postgres-rw.databases.svc.cluster.local`)
- **Cache**: Dragonfly operator for Redis-compatible caching
- **DNS**: external-dns with Cloudflare
- **TLS**: Existing `monosense-dev-tls` wildcard certificate
- **Monitoring**: Victoria Metrics with ServiceMonitor support

**Component Reusability:**

Located at `/kubernetes/components/`:
- `cnpg/` - CloudNativePG database initialization patterns
- `dragonfly/` - Dragonfly Redis instance patterns
- `gatus/external` - Health check monitoring
- `common/` - Shared configurations

**Current Authentik Setup:**
- **Location**: `kubernetes/apps/security/authentik/**`
- **Status**: Commented out in `security/kustomization.yaml`
- **Uses**: PostgreSQL (CNPG), Dragonfly, HTTPRoute to `auth.monosense.dev`
- **Components**: HelmRelease (OCI), ExternalSecrets, HTTPRoute, ReferenceGrant

**Repository File Structure:**
```
kubernetes/
├── apps/
│   ├── security/
│   │   ├── authentik/          # Current IAM/IDP (to be replaced)
│   │   └── kustomization.yaml
│   ├── databases/
│   │   ├── cloudnative-pg/
│   │   └── dragonfly/
│   └── networking/
│       └── envoy-gateway/
├── components/
│   ├── cnpg/
│   ├── dragonfly/
│   └── common/
└── flux/
    └── repositories/
        └── helm/
```

---

## Proposed Keycloak Architecture

### Component Breakdown

#### 1. Keycloak Operator

- **Version**: 26.4.0 (latest stable as of October 2025)
- **Type**: Upstream Keycloak (not Red Hat build)
- **Installation Method**: Raw manifests via Flux Kustomization
- **Source**: https://github.com/keycloak/keycloak-k8s-resources
- **Namespace**: `security` (alongside existing auth components)

**Key Features:**
- Multi-AZ pod distribution (automatic)
- NetworkPolicy for distributed cache security
- Rolling updates with manual approval support
- CR-based configuration (k8s.keycloak.org/v2alpha1)

**Why Upstream vs Red Hat Build?**
- Minimal differences since version 22
- CRs are fully compatible between both
- Upstream is free and community-supported
- Red Hat build primarily adds commercial support and different packaging
- Both use same Quarkus-based architecture

#### 2. Keycloak Instances

- **Replicas**: 2 (for high availability)
- **Image**: `quay.io/keycloak/keycloak:26.4.0`
- **Resource Requests**:
  - CPU: 500m-1000m per pod
  - Memory: 1Gi per pod
- **Resource Limits**:
  - Memory: 2Gi per pod
- **Storage**: Stateless (all state in PostgreSQL)
- **Cache**: Distributed via Infinispan (built-in) + optional Dragonfly for external session storage

#### 3. Database Configuration

- **Type**: PostgreSQL 17 via CloudNativePG
- **Connection**: Reuse existing `postgres` cluster in `databases` namespace
- **Database Name**: `keycloak`
- **Schema**: Auto-initialized by Keycloak on first boot
- **Secrets**: Managed via External Secrets (1Password)
- **Connection String**: `postgres-rw.databases.svc.cluster.local:5432`
- **Pool Size**: Initial 5, Min 5, Max 20 connections

#### 4. Custom Theme (Red Hat Portal Style)

- **Base Theme**: Keycloak (extends PatternFly 4)
- **Design System**: PatternFly 4 (same as Red Hat portal)
- **Customizations**:
  - Logo: Red Hat logo or custom branding
  - Colors: Red Hat palette (#EE0000 red, #151515 dark gray)
  - Fonts: Red Hat Display/Text fonts
  - Templates: Optional FreeMarker template overrides
- **Deployment Method**: Init container with theme Docker image
- **Mount Path**: `/opt/keycloak/themes/custom-redhat`
- **Volume**: emptyDir shared between init and main container

**Why Init Container vs ConfigMap?**
- ConfigMaps have 1MB size limit (too small for most themes with images)
- Init containers allow larger themes with images, fonts, etc.
- Easier to version and deploy theme updates independently
- Better separation of concerns

#### 5. Networking & Ingress

- **Ingress Type**: Gateway API (HTTPRoute)
- **Gateway**: `envoy-external` in `networking` namespace
- **Hostname**: `sso.monosense.dev`
- **TLS**: Wildcard certificate `monosense-dev-tls` (already exists)
- **Protocol**: HTTP backend (8080), TLS terminated at Envoy Gateway
- **Proxy Headers**: X-Forwarded-* headers trusted from Envoy

#### 6. Secrets Management

All secrets managed via External Secrets Operator with 1Password:

1. **Database Credentials** (`keycloak-pguser-secret`):
   - PostgreSQL username
   - PostgreSQL password
   - Connection details

2. **Admin Credentials** (`keycloak-admin-secret`):
   - Keycloak admin username
   - Keycloak admin password

3. **Database Initialization** (`keycloak-initdb-secret`):
   - PostgreSQL superuser password
   - Database initialization parameters

**1Password Vaults Required:**
- `dev-cnpg`: Add `keycloak_postgres_username` and `keycloak_postgres_password`
- `keycloak` (new vault): Add `keycloak_admin_username` and `keycloak_admin_password`

---

## Implementation Plan

### Phase 1: Operator Installation

#### 1.1 Create Keycloak Operator Kustomization

**Location**: `kubernetes/apps/security/keycloak-operator/ks.yaml`

```yaml
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: keycloak-operator
  namespace: security
spec:
  interval: 30m
  path: ./kubernetes/apps/security/keycloak-operator/app
  prune: true
  sourceRef:
    kind: GitRepository
    name: flux-system
    namespace: flux-system
  targetNamespace: security
  wait: true
  timeout: 5m
```

#### 1.2 Create Operator Resources Kustomization

**Location**: `kubernetes/apps/security/keycloak-operator/app/kustomization.yaml`

```yaml
---
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: security
resources:
  # Official Keycloak CRDs and Operator
  - https://raw.githubusercontent.com/keycloak/keycloak-k8s-resources/26.4.0/kubernetes/keycloaks.k8s.keycloak.org-v1.yml
  - https://raw.githubusercontent.com/keycloak/keycloak-k8s-resources/26.4.0/kubernetes/keycloakrealmimports.k8s.keycloak.org-v1.yml
```

#### 1.3 Update Security Kustomization

**Location**: `kubernetes/apps/security/kustomization.yaml`

```yaml
---
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: security
components:
  - ../../components/common
resources:
  - ./keycloak-operator/ks.yaml  # Add this line
  # - ./authentik/ks.yaml         # Keep commented during migration
```

---

### Phase 2: Custom Theme Creation

#### 2.1 Create Theme Directory Structure

Create directory: `kubernetes/apps/security/keycloak/theme/`

**Directory Structure:**
```
theme/
├── Dockerfile
├── build.sh
└── custom-redhat/
    ├── login/
    │   ├── theme.properties
    │   ├── resources/
    │   │   ├── css/
    │   │   │   └── custom.css
    │   │   └── img/
    │   │       ├── logo.png
    │   │       └── favicon.ico
    │   └── messages/
    │       └── messages_en.properties
    └── account/
        └── (similar structure for account management)
```

#### 2.2 Theme Dockerfile

**Location**: `kubernetes/apps/security/keycloak/theme/Dockerfile`

```dockerfile
FROM busybox:latest
COPY custom-redhat/ /theme/custom-redhat/
CMD ["sh", "-c", "cp -r /theme/* /themes/"]
```

#### 2.3 Theme Properties

**Location**: `kubernetes/apps/security/keycloak/theme/custom-redhat/login/theme.properties`

```properties
parent=keycloak
import=common/keycloak

styles=css/custom.css

# Social provider icons already defined in base theme
stylesCommon=web_modules/@patternfly/react-core/dist/styles/base.css
```

#### 2.4 Custom CSS (Red Hat Style)

**Location**: `kubernetes/apps/security/keycloak/theme/custom-redhat/login/resources/css/custom.css`

```css
/* ================================================
   Red Hat Portal Style for Keycloak Login
   ================================================ */

/* Import Red Hat fonts */
@import url('https://fonts.googleapis.com/css2?family=Red+Hat+Display:wght@400;500;700;900&family=Red+Hat+Text:wght@400;500;700&display=swap');

/* Color palette */
:root {
  /* Red Hat colors */
  --rh-red: #EE0000;
  --rh-red-dark: #A30000;
  --rh-black: #151515;
  --rh-gray-dark: #3C3F42;
  --rh-gray: #6A6E73;
  --rh-gray-light: #D2D2D2;
  --rh-white: #FFFFFF;

  /* PatternFly overrides */
  --pf-global--Color--100: var(--rh-black);
  --pf-global--Color--200: var(--rh-red);
  --pf-global--primary-color--100: var(--rh-red);
  --pf-global--link--Color: var(--rh-red);
  --pf-global--link--Color--hover: var(--rh-red-dark);

  /* Typography */
  --pf-global--FontFamily--sans-serif: 'Red Hat Text', 'Overpass', 'Helvetica Neue', Arial, sans-serif;
  --pf-global--FontFamily--heading--sans-serif: 'Red Hat Display', 'Overpass', 'Helvetica Neue', Arial, sans-serif;
}

/* Global styles */
body {
  font-family: var(--pf-global--FontFamily--sans-serif);
  background: linear-gradient(135deg, #151515 0%, #3C3F42 100%);
  color: var(--rh-black);
}

/* Header */
#kc-header-wrapper {
  background-color: var(--rh-black);
  padding: 2rem 0;
  box-shadow: 0 2px 8px rgba(0,0,0,0.15);
}

#kc-header {
  color: var(--rh-white);
  font-size: 1.5rem;
  font-weight: 500;
  font-family: var(--pf-global--FontFamily--heading--sans-serif);
}

/* Login card */
.login-pf-page .card-pf {
  background-color: var(--rh-white);
  border-top: 4px solid var(--rh-red);
  border-radius: 8px;
  box-shadow: 0 8px 24px rgba(0,0,0,0.15);
  padding: 2.5rem;
  max-width: 450px;
}

/* Form title */
#kc-form-login h1,
#kc-register h1,
.login-pf-page h1 {
  font-family: var(--pf-global--FontFamily--heading--sans-serif);
  font-size: 2rem;
  font-weight: 700;
  color: var(--rh-black);
  margin-bottom: 1.5rem;
}

/* Input fields */
.pf-c-form-control,
input[type="text"],
input[type="password"],
input[type="email"] {
  border: 2px solid var(--rh-gray-light);
  border-radius: 4px;
  padding: 0.75rem 1rem;
  font-size: 1rem;
  transition: border-color 0.2s ease;
}

.pf-c-form-control:focus,
input:focus {
  border-color: var(--rh-red);
  outline: none;
  box-shadow: 0 0 0 3px rgba(238, 0, 0, 0.1);
}

/* Primary button (Sign In) */
.pf-c-button.pf-m-primary,
button[type="submit"],
#kc-login {
  background-color: var(--rh-red);
  border: 2px solid var(--rh-red);
  color: var(--rh-white);
  font-weight: 700;
  font-size: 1rem;
  padding: 0.75rem 2rem;
  border-radius: 4px;
  cursor: pointer;
  transition: all 0.2s ease;
  text-transform: uppercase;
  letter-spacing: 0.5px;
}

.pf-c-button.pf-m-primary:hover,
button[type="submit"]:hover {
  background-color: var(--rh-red-dark);
  border-color: var(--rh-red-dark);
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(238, 0, 0, 0.3);
}

/* Links */
a,
.pf-c-button.pf-m-link {
  color: var(--rh-red);
  text-decoration: none;
  font-weight: 500;
  transition: color 0.2s ease;
}

a:hover,
.pf-c-button.pf-m-link:hover {
  color: var(--rh-red-dark);
  text-decoration: underline;
}

/* Alert messages */
.pf-c-alert.pf-m-danger,
.alert-error {
  background-color: #FAEAE8;
  border-left: 4px solid var(--rh-red);
  color: var(--rh-red-dark);
}

.pf-c-alert.pf-m-success,
.alert-success {
  background-color: #E8F5E9;
  border-left: 4px solid #4CAF50;
  color: #2E7D32;
}

/* Responsive design */
@media (max-width: 768px) {
  .login-pf-page .card-pf {
    padding: 1.5rem;
    margin: 1rem;
  }

  #kc-form-login h1 {
    font-size: 1.5rem;
  }
}

/* Animation for card appearance */
@keyframes fadeInUp {
  from {
    opacity: 0;
    transform: translateY(20px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

.login-pf-page .card-pf {
  animation: fadeInUp 0.4s ease-out;
}
```

#### 2.5 Build Script

**Location**: `kubernetes/apps/security/keycloak/theme/build.sh`

```bash
#!/bin/bash
set -e

THEME_NAME="custom-redhat"
VERSION="1.0.0"
REGISTRY="ghcr.io/trosvald"
IMAGE_NAME="keycloak-theme"

echo "Building Keycloak theme: ${THEME_NAME}"

# Build Docker image
docker build -t ${REGISTRY}/${IMAGE_NAME}:${VERSION} .
docker tag ${REGISTRY}/${IMAGE_NAME}:${VERSION} ${REGISTRY}/${IMAGE_NAME}:latest

echo "Pushing to registry..."
docker push ${REGISTRY}/${IMAGE_NAME}:${VERSION}
docker push ${REGISTRY}/${IMAGE_NAME}:latest

echo "✅ Theme built and pushed successfully!"
echo "Image: ${REGISTRY}/${IMAGE_NAME}:${VERSION}"
```

Make executable:
```bash
chmod +x kubernetes/apps/security/keycloak/theme/build.sh
```

---

### Phase 3: Keycloak Deployment

#### 3.1 Create External Secrets

**Location**: `kubernetes/apps/security/keycloak/app/externalsecret.yaml`

```yaml
---
# Database initialization secret
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: keycloak-initdb
spec:
  secretStoreRef:
    kind: ClusterSecretStore
    name: onepassword
  target:
    name: keycloak-initdb-secret
    template:
      data:
        INIT_POSTGRES_DBNAME: keycloak
        INIT_POSTGRES_HOST: postgres-rw.databases.svc.cluster.local
        INIT_POSTGRES_USER: "{{ .keycloak_postgres_username }}"
        INIT_POSTGRES_PASS: "{{ .keycloak_postgres_password }}"
        INIT_POSTGRES_SUPER_PASS: "{{ .POSTGRES_SUPER_PASS }}"
  dataFrom:
    - extract:
        key: dev-cnpg
---
# Database user secret
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: keycloak-pguser
spec:
  secretStoreRef:
    kind: ClusterSecretStore
    name: onepassword
  target:
    name: keycloak-pguser-secret
    template:
      data:
        username: "{{ .keycloak_postgres_username }}"
        password: "{{ .keycloak_postgres_password }}"
  dataFrom:
    - extract:
        key: dev-cnpg
---
# Keycloak admin secret
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: keycloak-admin
spec:
  secretStoreRef:
    kind: ClusterSecretStore
    name: onepassword
  target:
    name: keycloak-admin-secret
    template:
      data:
        username: "{{ .keycloak_admin_username }}"
        password: "{{ .keycloak_admin_password }}"
  dataFrom:
    - extract:
        key: keycloak
```

**Prerequisites**: Add these secrets to 1Password:
- Vault: `dev-cnpg` → Add fields: `keycloak_postgres_username`, `keycloak_postgres_password`
- Vault: `keycloak` (new) → Add fields: `keycloak_admin_username`, `keycloak_admin_password`

#### 3.2 Create Database Initialization Job

**Location**: `kubernetes/apps/security/keycloak/app/init-db-job.yaml`

```yaml
---
apiVersion: batch/v1
kind: Job
metadata:
  name: keycloak-init-db
  namespace: security
spec:
  template:
    spec:
      restartPolicy: OnFailure
      containers:
        - name: init-db
          image: ghcr.io/home-operations/postgres-init:17.6
          envFrom:
            - secretRef:
                name: keycloak-initdb-secret
```

#### 3.3 Create Keycloak Custom Resource

**Location**: `kubernetes/apps/security/keycloak/app/keycloak.yaml`

```yaml
---
apiVersion: k8s.keycloak.org/v2alpha1
kind: Keycloak
metadata:
  name: keycloak
  namespace: security
spec:
  instances: 2  # HA with 2 replicas

  # Database configuration
  db:
    vendor: postgres
    host: postgres-rw.databases.svc.cluster.local
    database: keycloak
    port: 5432
    usernameSecret:
      name: keycloak-pguser-secret
      key: username
    passwordSecret:
      name: keycloak-pguser-secret
      key: password

  # HTTP configuration
  http:
    httpEnabled: true  # Backend uses HTTP, Envoy handles TLS termination

  # Hostname configuration
  hostname:
    hostname: sso.monosense.dev
    strict: false  # Allow access via cluster DNS for internal services
    strictBackchannel: false

  # Proxy configuration for Envoy Gateway
  proxy:
    headers: xforwarded  # Trust X-Forwarded-* headers from Envoy

  # Disable default ingress (using Gateway API instead)
  ingress:
    enabled: false

  # Container image configuration
  image: quay.io/keycloak/keycloak:26.4.0

  # Init containers for custom theme
  unsupported:
    podTemplate:
      spec:
        initContainers:
          - name: theme-provider
            image: ghcr.io/trosvald/keycloak-theme:latest
            imagePullPolicy: Always
            command:
              - sh
              - -c
              - |
                echo "Copying custom theme..."
                cp -rv /theme/* /themes/
                echo "Theme copied successfully"
            volumeMounts:
              - name: themes
                mountPath: /themes

        # Main container modifications
        containers:
          - name: keycloak
            env:
              # Admin credentials from secret
              - name: KEYCLOAK_ADMIN
                valueFrom:
                  secretKeyRef:
                    name: keycloak-admin-secret
                    key: username
              - name: KEYCLOAK_ADMIN_PASSWORD
                valueFrom:
                  secretKeyRef:
                    name: keycloak-admin-secret
                    key: password

            # Resource limits
            resources:
              requests:
                cpu: 500m
                memory: 1Gi
              limits:
                memory: 2Gi

            # Volume mounts
            volumeMounts:
              - name: themes
                mountPath: /opt/keycloak/themes

        # Volumes
        volumes:
          - name: themes
            emptyDir: {}

  # Additional Keycloak options
  additionalOptions:
    # Cache configuration
    - name: cache
      value: ispn
    - name: cache-stack
      value: kubernetes

    # Theme configuration
    - name: spi-theme-default
      value: custom-redhat

    # Performance tuning
    - name: http-pool-max-threads
      value: "200"

    # Database connection pool
    - name: db-pool-initial-size
      value: "5"
    - name: db-pool-max-size
      value: "20"
    - name: db-pool-min-size
      value: "5"

    # Metrics
    - name: metrics-enabled
      value: "true"

    # Health checks
    - name: health-enabled
      value: "true"

    # Logging
    - name: log-level
      value: INFO
    - name: log-console-output
      value: json

    # Session timeouts
    - name: sso-session-idle-timeout
      value: 30m
    - name: sso-session-max-lifespan
      value: 10h
```

#### 3.4 Create HTTPRoute

**Location**: `kubernetes/apps/security/keycloak/app/httproute.yaml`

```yaml
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: keycloak
  namespace: security
spec:
  hostnames:
    - sso.monosense.dev
  parentRefs:
    - name: envoy-external
      namespace: networking
      sectionName: https
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: keycloak-service
          namespace: security
          port: 8080
```

#### 3.5 Create ReferenceGrant

**Location**: `kubernetes/apps/security/keycloak/app/referencegrant.yaml`

```yaml
---
apiVersion: gateway.networking.k8s.io/v1beta1
kind: ReferenceGrant
metadata:
  name: keycloak
  namespace: security
spec:
  from:
    - group: gateway.networking.k8s.io
      kind: HTTPRoute
      namespace: networking
  to:
    - group: ""
      kind: Service
```

#### 3.6 Create ServiceMonitor

**Location**: `kubernetes/apps/security/keycloak/app/servicemonitor.yaml`

```yaml
---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: keycloak
  namespace: security
  labels:
    app.kubernetes.io/name: keycloak
spec:
  selector:
    matchLabels:
      app: keycloak
  endpoints:
    - port: http
      path: /metrics
      interval: 30s
      scrapeTimeout: 10s
```

#### 3.7 Create Victoria Metrics Alerts

**Location**: `kubernetes/apps/security/keycloak/app/vmrule.yaml`

```yaml
---
apiVersion: operator.victoriametrics.com/v1beta1
kind: VMRule
metadata:
  name: keycloak-alerts
  namespace: security
spec:
  groups:
    - name: keycloak
      interval: 30s
      rules:
        - alert: KeycloakDown
          expr: up{job="keycloak"} == 0
          for: 5m
          labels:
            severity: critical
          annotations:
            summary: "Keycloak instance is down"
            description: "Keycloak instance {{ $labels.instance }} is down for more than 5 minutes"

        - alert: KeycloakHighMemoryUsage
          expr: (jvm_memory_used_bytes{job="keycloak", area="heap"} / jvm_memory_max_bytes{job="keycloak", area="heap"}) > 0.85
          for: 10m
          labels:
            severity: warning
          annotations:
            summary: "Keycloak high memory usage"
            description: "Keycloak instance {{ $labels.instance }} memory usage is above 85%"

        - alert: KeycloakHighCPUUsage
          expr: rate(process_cpu_seconds_total{job="keycloak"}[5m]) > 0.8
          for: 10m
          labels:
            severity: warning
          annotations:
            summary: "Keycloak high CPU usage"
            description: "Keycloak instance {{ $labels.instance }} CPU usage is above 80%"

        - alert: KeycloakDatabaseConnectionErrors
          expr: increase(keycloak_database_connection_errors_total{job="keycloak"}[5m]) > 5
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "Keycloak database connection errors"
            description: "Keycloak instance {{ $labels.instance }} has {{ $value }} database connection errors in the last 5 minutes"

        - alert: KeycloakLoginFailures
          expr: rate(keycloak_login_attempts{outcome="error"}[5m]) > 10
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "High rate of Keycloak login failures"
            description: "Keycloak realm {{ $labels.realm }} has {{ $value }} failed login attempts per second"
```

#### 3.8 Create Pod Disruption Budget

**Location**: `kubernetes/apps/security/keycloak/app/pdb.yaml`

```yaml
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: keycloak
  namespace: security
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app: keycloak
```

#### 3.9 Create App Kustomization

**Location**: `kubernetes/apps/security/keycloak/app/kustomization.yaml`

```yaml
---
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: security
components:
  - ../../../../components/cnpg
  - ../../../../components/dragonfly
  - ../../../../components/gatus/external
resources:
  - externalsecret.yaml
  - init-db-job.yaml
  - keycloak.yaml
  - httproute.yaml
  - referencegrant.yaml
  - servicemonitor.yaml
  - vmrule.yaml
  - pdb.yaml
commonLabels:
  app.kubernetes.io/name: keycloak
  app.kubernetes.io/instance: keycloak
```

#### 3.10 Create Flux Kustomization

**Location**: `kubernetes/apps/security/keycloak/ks.yaml`

```yaml
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: keycloak
  namespace: security
spec:
  commonMetadata:
    labels:
      app.kubernetes.io/name: keycloak

  components:
    - ../../../components/cnpg
    - ../../../components/dragonfly
    - ../../../components/gatus/external

  dependsOn:
    - name: keycloak-operator
      namespace: security
    - name: cloudnative-pg-cluster
      namespace: databases
    - name: dragonfly-operator
      namespace: databases
    - name: external-secrets
      namespace: external-secrets

  healthChecks:
    - apiVersion: k8s.keycloak.org/v2alpha1
      kind: Keycloak
      name: keycloak
      namespace: security

  interval: 30m
  path: ./kubernetes/apps/security/keycloak/app

  postBuild:
    substitute:
      APP: keycloak
      GATUS_SUBDOMAIN: sso
      GATUS_PATH: /health/ready
      CNPG_NAME: postgres

  prune: true
  retryInterval: 1m

  sourceRef:
    kind: GitRepository
    name: flux-system
    namespace: flux-system

  targetNamespace: security
  timeout: 10m
  wait: true
```

#### 3.11 Update Security Kustomization

**Location**: `kubernetes/apps/security/kustomization.yaml`

```yaml
---
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: security
components:
  - ../../components/common
resources:
  - ./keycloak-operator/ks.yaml
  - ./keycloak/ks.yaml  # Add this line
  # - ./authentik/ks.yaml  # Keep commented during migration
```

---

### Phase 4: Database & Cache Configuration

The database and cache are already configured via the Keycloak CR and component references. CloudNativePG will automatically create the database, and Dragonfly can be used for external session storage if needed.

For Dragonfly (optional for external sessions):

**Location**: `kubernetes/apps/security/keycloak/app/dragonfly.yaml`

```yaml
---
apiVersion: dragonflydb.io/v1alpha1
kind: Dragonfly
metadata:
  name: keycloak-dragonfly
  namespace: security
spec:
  replicas: 2  # HA setup
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      memory: 512Mi
```

Add to `kustomization.yaml` if using Dragonfly for session storage.

---

### Phase 5: Migration from Authentik

#### Migration Timeline

**Week 1: Parallel Deployment**
- Deploy Keycloak alongside Authentik
- Both systems operational (different hostnames)
- No changes to existing Spring Boot apps

**Week 2: Data Migration**
- Export users/groups from Authentik
- Import to Keycloak
- Configure OAuth2 clients in Keycloak
- Create test realm for validation

**Week 3: Application Migration**
- Update Spring Boot apps one by one
- Test each app thoroughly
- Keep Authentik as fallback

**Week 4: Cutover**
- Switch production traffic to Keycloak
- Monitor closely for issues
- Keep Authentik running for 48-72 hours

**Week 5: Cleanup**
- Remove Authentik resources
- Archive configuration
- Update documentation

#### Detailed Migration Steps

##### Step 1: Export from Authentik

```bash
# Export users via Authentik API
curl -H "Authorization: Bearer ${AUTHENTIK_TOKEN}" \
  https://auth.monosense.dev/api/v3/core/users/ > authentik-users.json

# Export groups
curl -H "Authorization: Bearer ${AUTHENTIK_TOKEN}" \
  https://auth.monosense.dev/api/v3/core/groups/ > authentik-groups.json

# Document OAuth2 clients
curl -H "Authorization: Bearer ${AUTHENTIK_TOKEN}" \
  https://auth.monosense.dev/api/v3/oauth2/providers/ > authentik-clients.json
```

##### Step 2: Create Keycloak Realm Configuration

**Location**: `kubernetes/apps/security/keycloak/app/realm-import.yaml`

```yaml
---
apiVersion: k8s.keycloak.org/v2alpha1
kind: KeycloakRealmImport
metadata:
  name: home-ops-realm
  namespace: security
spec:
  keycloakCRName: keycloak
  realm:
    id: home-ops
    realm: home-ops
    enabled: true
    displayName: "Home Operations"

    # Login settings
    loginTheme: custom-redhat
    accountTheme: custom-redhat

    # Password policy
    passwordPolicy: "length(12) and digits(2) and lowerCase(1) and upperCase(1) and specialChars(1) and notUsername(undefined) and notEmail(undefined)"

    # Session settings
    ssoSessionIdleTimeout: 1800  # 30 minutes
    ssoSessionMaxLifespan: 36000  # 10 hours

    # Users (import from Authentik export)
    users:
      - username: admin
        enabled: true
        emailVerified: true
        firstName: Admin
        lastName: User
        email: admin@monosense.dev
        credentials:
          - type: password
            value: changeme
            temporary: true
        realmRoles:
          - admin

    # OAuth2 Clients for Spring Boot apps
    clients:
      - clientId: spring-app
        name: Spring Boot Application
        enabled: true
        protocol: openid-connect
        publicClient: false
        standardFlowEnabled: true  # Authorization Code Flow
        serviceAccountsEnabled: true  # Client Credentials Flow
        directAccessGrantsEnabled: false
        redirectUris:
          - "https://app.monosense.dev/*"
          - "http://localhost:8080/*"
        webOrigins:
          - "https://app.monosense.dev"
        attributes:
          "access.token.lifespan": "300"  # 5 minutes
          "refresh.token.max.reuse": "0"
        defaultClientScopes:
          - profile
          - email
          - roles
        protocolMappers:
          - name: realm-roles
            protocol: openid-connect
            protocolMapper: oidc-usermodel-realm-role-mapper
            config:
              claim.name: realm_access.roles
              access.token.claim: "true"
              id.token.claim: "true"

    # Roles
    roles:
      realm:
        - name: admin
          description: Administrator role
        - name: user
          description: Standard user role
        - name: developer
          description: Developer role

    # Groups
    groups:
      - name: administrators
        realmRoles:
          - admin
      - name: users
        realmRoles:
          - user
      - name: developers
        realmRoles:
          - developer
```

##### Step 3: Import Users via Script

**Location**: `kubernetes/apps/security/keycloak/scripts/import-users.sh`

```bash
#!/bin/bash
set -e

KEYCLOAK_URL="https://sso.monosense.dev"
ADMIN_USER="${KEYCLOAK_ADMIN_USER}"
ADMIN_PASSWORD="${KEYCLOAK_ADMIN_PASSWORD}"
REALM="home-ops"

# Get admin token
echo "Getting admin token..."
TOKEN=$(curl -s -X POST "${KEYCLOAK_URL}/realms/master/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=${ADMIN_USER}" \
  -d "password=${ADMIN_PASSWORD}" \
  -d "grant_type=password" \
  -d "client_id=admin-cli" | jq -r '.access_token')

if [ -z "$TOKEN" ] || [ "$TOKEN" == "null" ]; then
  echo "Failed to get admin token"
  exit 1
fi

echo "Token obtained successfully"

# Import users from JSON file
echo "Importing users..."
jq -c '.[]' authentik-users.json | while read user; do
  USERNAME=$(echo $user | jq -r '.username')
  EMAIL=$(echo $user | jq -r '.email')
  FIRST_NAME=$(echo $user | jq -r '.name // .username')

  echo "Creating user: $USERNAME"

  curl -s -X POST "${KEYCLOAK_URL}/admin/realms/${REALM}/users" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{
      \"username\": \"${USERNAME}\",
      \"email\": \"${EMAIL}\",
      \"firstName\": \"${FIRST_NAME}\",
      \"enabled\": true,
      \"emailVerified\": true,
      \"credentials\": [{
        \"type\": \"password\",
        \"value\": \"ChangeMe123!\",
        \"temporary\": true
      }]
    }"

  echo "Created user: $USERNAME"
done

echo "User import completed!"
```

---

## Spring Boot Integration

### Dependencies

#### For OAuth2 Client (Web Applications with Login)

**Maven (`pom.xml`):**
```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-oauth2-client</artifactId>
</dependency>
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-security</artifactId>
</dependency>
```

**Gradle (`build.gradle`):**
```gradle
implementation 'org.springframework.boot:spring-boot-starter-oauth2-client'
implementation 'org.springframework.boot:spring-boot-starter-security'
```

#### For Resource Server (REST APIs)

**Maven (`pom.xml`):**
```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-oauth2-resource-server</artifactId>
</dependency>
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-security</artifactId>
</dependency>
```

### Configuration

#### OAuth2 Client Configuration

**`application.yml`:**
```yaml
spring:
  application:
    name: my-spring-app

  security:
    oauth2:
      client:
        provider:
          keycloak:
            issuer-uri: https://sso.monosense.dev/realms/home-ops
            user-name-attribute: preferred_username

        registration:
          keycloak:
            client-id: spring-app
            client-secret: ${KEYCLOAK_CLIENT_SECRET}
            scope:
              - openid
              - profile
              - email
              - roles
            authorization-grant-type: authorization_code
            redirect-uri: "{baseUrl}/login/oauth2/code/{registrationId}"

# Optional: Logging for debugging
logging:
  level:
    org.springframework.security: DEBUG
    org.springframework.security.oauth2: DEBUG
```

#### Resource Server Configuration

**`application.yml`:**
```yaml
spring:
  application:
    name: my-api-server

  security:
    oauth2:
      resourceserver:
        jwt:
          issuer-uri: https://sso.monosense.dev/realms/home-ops
          jwk-set-uri: https://sso.monosense.dev/realms/home-ops/protocol/openid-connect/certs
```

### Security Configuration Classes

#### OAuth2 Client Security

**`SecurityConfig.java`:**
```java
package com.example.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.web.SecurityFilterChain;

@Configuration
@EnableWebSecurity
public class SecurityConfig {

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
            .authorizeHttpRequests(auth -> auth
                .requestMatchers("/", "/public/**", "/error").permitAll()
                .requestMatchers("/admin/**").hasRole("ADMIN")
                .anyRequest().authenticated()
            )
            .oauth2Login(oauth2 -> oauth2
                .defaultSuccessUrl("/dashboard", true)
            )
            .logout(logout -> logout
                .logoutSuccessUrl("/")
                .invalidateHttpSession(true)
                .clearAuthentication(true)
            );

        return http.build();
    }
}
```

#### Resource Server Security

**`ResourceServerConfig.java`:**
```java
package com.example.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationConverter;
import org.springframework.security.oauth2.server.resource.authentication.JwtGrantedAuthoritiesConverter;
import org.springframework.security.web.SecurityFilterChain;

@Configuration
@EnableWebSecurity
@EnableMethodSecurity
public class ResourceServerConfig {

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
            .authorizeHttpRequests(auth -> auth
                .requestMatchers("/api/public/**").permitAll()
                .requestMatchers("/api/admin/**").hasRole("ADMIN")
                .anyRequest().authenticated()
            )
            .oauth2ResourceServer(oauth2 -> oauth2
                .jwt(jwt -> jwt
                    .jwtAuthenticationConverter(jwtAuthenticationConverter())
                )
            );

        return http.build();
    }

    @Bean
    public JwtAuthenticationConverter jwtAuthenticationConverter() {
        JwtGrantedAuthoritiesConverter grantedAuthoritiesConverter =
            new JwtGrantedAuthoritiesConverter();

        // Extract roles from Keycloak realm_access.roles claim
        grantedAuthoritiesConverter.setAuthoritiesClaimName("realm_access.roles");
        grantedAuthoritiesConverter.setAuthorityPrefix("ROLE_");

        JwtAuthenticationConverter jwtAuthenticationConverter =
            new JwtAuthenticationConverter();
        jwtAuthenticationConverter.setJwtGrantedAuthoritiesConverter(
            grantedAuthoritiesConverter
        );

        return jwtAuthenticationConverter;
    }
}
```

### Controller Examples

**Accessing User Information:**

```java
package com.example.controller;

import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@RestController
@RequestMapping("/api")
public class UserController {

    @GetMapping("/user")
    public Map<String, Object> getCurrentUser(
        @AuthenticationPrincipal Jwt jwt
    ) {
        return Map.of(
            "username", jwt.getClaimAsString("preferred_username"),
            "email", jwt.getClaimAsString("email"),
            "roles", jwt.getClaimAsStringList("realm_access.roles"),
            "sub", jwt.getSubject()
        );
    }

    @GetMapping("/admin/users")
    @PreAuthorize("hasRole('ADMIN')")
    public String adminOnly() {
        return "Admin-only content";
    }
}
```

---

## Custom Theme Development

### Theme File Structure

```
custom-redhat/
├── login/                          # Login pages theme
│   ├── theme.properties            # Theme configuration
│   ├── resources/
│   │   ├── css/
│   │   │   └── custom.css          # Custom styles
│   │   ├── img/
│   │   │   ├── logo.png            # Header logo
│   │   │   ├── favicon.ico
│   │   │   └── background.jpg      # Optional background
│   │   └── js/
│   │       └── custom.js           # Custom JavaScript (optional)
│   ├── messages/
│   │   ├── messages_en.properties  # English translations
│   │   └── messages_es.properties  # Spanish translations (optional)
│   └── (optional) *.ftl templates  # Override default templates
├── account/                        # Account management theme
│   └── (similar structure)
├── admin/                          # Admin console theme (optional)
│   └── (similar structure)
└── email/                          # Email templates
    └── (similar structure)
```

### Customization Options

#### Logo Replacement

Place your logo at `custom-redhat/login/resources/img/logo.png` (recommended size: 200x50px, transparent PNG)

#### Color Scheme

Modify CSS variables in `custom.css`:

```css
:root {
  --rh-red: #EE0000;          /* Primary color */
  --rh-red-dark: #A30000;     /* Hover state */
  --rh-black: #151515;        /* Header/footer */
  --rh-gray-dark: #3C3F42;    /* Text */
  --rh-gray-light: #D2D2D2;   /* Borders */
}
```

#### Custom Messages

Edit `custom-redhat/login/messages/messages_en.properties`:

```properties
loginTitle=Sign In to Home Operations
loginAccountTitle=Sign In
usernameOrEmail=Username or Email
doLogIn=SIGN IN
registerTitle=Create Account
```

#### Override Templates (Advanced)

To customize HTML structure, copy templates from Keycloak base theme and modify:

```bash
# Copy base template
cp /opt/keycloak/themes/keycloak/login/login.ftl \
   custom-redhat/login/login.ftl

# Edit as needed
```

---

## Production Considerations

### Security Best Practices

#### 1. TLS Configuration
- ✅ TLS termination at Envoy Gateway
- ✅ Use wildcard certificate `monosense-dev-tls`
- Enable HSTS headers in Envoy Gateway
- TLS 1.2+ only (already configured)

#### 2. Database Security
- Dedicated PostgreSQL user with limited permissions
- Enable SSL for database connections:
  ```yaml
  additionalOptions:
    - name: db-ssl-mode
      value: require
  ```
- Regular backups via CloudNativePG

#### 3. Password Policies
- Minimum length: 12 characters
- Require: digits, lowercase, uppercase, special chars
- Not username or email
- Configured via KeycloakRealmImport

#### 4. Brute Force Protection
- Enabled by default
- Max failures: 5
- Wait time: 15 minutes
- Quick login check: 1000ms

### High Availability

#### Multi-AZ Deployment
- Keycloak operator v26.4.0 has built-in multi-AZ support
- Pods automatically distributed across availability zones
- No additional configuration required

#### Pod Disruption Budget
- Ensures at least 1 pod always available during updates
- Prevents all pods from being evicted simultaneously

#### Database HA
- CloudNativePG provides PostgreSQL high availability
- Automatic failover to standby instances
- Point-in-time recovery capability

### Monitoring & Observability

#### Metrics
- JVM metrics (heap, GC, threads)
- HTTP request metrics
- Database connection pool metrics
- Cache metrics
- Login attempt metrics

#### Alerts
- KeycloakDown: Instance unavailable
- HighMemoryUsage: > 85% heap usage
- HighCPUUsage: > 80% CPU
- DatabaseConnectionErrors: Connection issues
- LoginFailures: High failure rate

#### Logging
- Structured JSON logging
- Security audit logs enabled
- Log level: INFO (production)
- DEBUG for security events

### Backup & Disaster Recovery

#### Database Backups
- Automated via CloudNativePG ScheduledBackup
- Daily backups with retention policy
- Point-in-time recovery available

#### Realm Configuration Backup
- Export realm configuration via CronJob
- Store in persistent volume
- Version control realm import files in Git

#### Recovery Procedures
1. Database restore: Use CloudNativePG restore procedure
2. Realm restore: Apply KeycloakRealmImport CR
3. Full cluster rebuild: Flux CD will recreate all resources

### Performance Tuning

#### Database Connection Pool
```yaml
additionalOptions:
  - name: db-pool-initial-size
    value: "5"
  - name: db-pool-max-size
    value: "20"
  - name: db-pool-min-size
    value: "5"
```

#### Cache Configuration
```yaml
additionalOptions:
  - name: cache
    value: ispn  # Infinispan
  - name: cache-stack
    value: kubernetes
```

#### JVM Tuning
```yaml
env:
  - name: JAVA_OPTS_APPEND
    value: >-
      -XX:+UseG1GC
      -XX:MaxGCPauseMillis=100
      -XX:+ParallelRefProcEnabled
      -XX:InitiatingHeapOccupancyPercent=45
```

---

## Deployment Steps

### Prerequisites

1. **Create 1Password Secrets:**

In 1Password, add the following secrets:

**Vault: `dev-cnpg`** (add fields):
- `keycloak_postgres_username` → e.g., `keycloak`
- `keycloak_postgres_password` → generate strong password

**Vault: `keycloak`** (new vault):
- `keycloak_admin_username` → e.g., `admin`
- `keycloak_admin_password` → generate strong password (min 12 chars)

2. **Build and Push Theme Image:**

```bash
cd kubernetes/apps/security/keycloak/theme/
chmod +x build.sh
./build.sh

# Verify image was pushed
docker images | grep keycloak-theme
```

### Step 1: Deploy Keycloak Operator

```bash
# Commit operator files
git add kubernetes/apps/security/keycloak-operator/
git add kubernetes/apps/security/kustomization.yaml
git commit -m "feat(security): add Keycloak operator v26.4.0"
git push

# Wait for Flux to reconcile
flux reconcile kustomization flux-system --with-source

# Wait for operator to be ready (may take 2-3 minutes)
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=keycloak-operator \
  -n security --timeout=300s

# Verify operator is running
kubectl get pods -n security -l app.kubernetes.io/name=keycloak-operator
```

### Step 2: Deploy Keycloak Instance

```bash
# Commit Keycloak application files
git add kubernetes/apps/security/keycloak/
git add kubernetes/apps/security/kustomization.yaml
git commit -m "feat(security): deploy Keycloak with custom Red Hat theme"
git push

# Force Flux reconciliation
flux reconcile kustomization flux-system --with-source

# Monitor deployment
kubectl get keycloak -n security -w

# Watch pods come up (Ctrl+C to stop)
kubectl get pods -n security -l app=keycloak -w

# Check logs
kubectl logs -n security -l app=keycloak --tail=100 -f
```

### Step 3: Verify Deployment

```bash
# Check Keycloak CR status
kubectl describe keycloak keycloak -n security

# Check HTTPRoute
kubectl get httproute keycloak -n security

# Test DNS resolution
nslookup sso.monosense.dev

# Test HTTPS access
curl -I https://sso.monosense.dev

# Check health endpoint
curl https://sso.monosense.dev/health/ready

# Expected output: {"status":"UP"}
```

### Step 4: Access Admin Console

1. Open browser: https://sso.monosense.dev
2. Click **"Administration Console"**
3. Login with credentials from 1Password:
   - Username: Value of `keycloak_admin_username`
   - Password: Value of `keycloak_admin_password`
4. **Verify theme is applied** - login page should have Red Hat styling

### Step 5: Create Realm and Configure

1. **Create Realm:**
   - Click "Master" dropdown (top-left)
   - Click "Create Realm"
   - Name: `home-ops`
   - Click "Create"

2. **Configure Realm Settings:**
   - Go to Realm Settings → Login
   - Set User registration: Disabled (or as needed)
   - Require SSL: all requests
   - Login with email: Enabled

3. **Create OAuth2 Client:**
   - Go to Clients → Create client
   - Client ID: `spring-app`
   - Client Protocol: openid-connect
   - Click "Next"
   - Client authentication: ON
   - Authorization: ON
   - Authentication flow:
     - ✅ Standard flow
     - ✅ Direct access grants
     - ✅ Service accounts roles
   - Click "Save"

4. **Configure Client:**
   - Valid redirect URIs: `https://app.monosense.dev/*`
   - Valid post logout URIs: `https://app.monosense.dev/*`
   - Web origins: `https://app.monosense.dev`
   - Go to "Credentials" tab → Copy "Client secret"

5. **Create Test User:**
   - Go to Users → Add user
   - Username: `testuser`
   - Email: `test@monosense.dev`
   - First name: `Test`
   - Last name: `User`
   - Email verified: ON
   - Click "Create"
   - Go to Credentials tab
   - Set password: `Test123!`
   - Temporary: OFF
   - Click "Set password"

### Step 6: Test with Spring Boot Application

Update your Spring Boot `application.yml`:

```yaml
spring:
  security:
    oauth2:
      client:
        provider:
          keycloak:
            issuer-uri: https://sso.monosense.dev/realms/home-ops
        registration:
          keycloak:
            client-id: spring-app
            client-secret: <PASTE_CLIENT_SECRET_HERE>
            scope:
              - openid
              - profile
              - email
```

Start your app and test login:
1. Navigate to protected endpoint
2. Should redirect to Keycloak login
3. Login with test user credentials
4. Should redirect back to app after successful authentication

### Step 7: Import Realm Configuration (GitOps)

After manual configuration, export realm for GitOps:

```bash
# Get admin token
ADMIN_TOKEN=$(kubectl exec -n security deployment/keycloak -- \
  /opt/keycloak/bin/kcadm.sh config credentials \
  --server http://localhost:8080 \
  --realm master \
  --user admin \
  --password "${KEYCLOAK_ADMIN_PASSWORD}" && \
  kubectl exec -n security deployment/keycloak -- \
  /opt/keycloak/bin/kcadm.sh get realms/home-ops)

# Save to realm-import.yaml and commit to Git
```

### Step 8: Monitor and Verify

```bash
# Check metrics endpoint
curl https://sso.monosense.dev/metrics | grep keycloak

# Check Victoria Metrics scraping
kubectl get servicemonitor keycloak -n security

# View logs
kubectl logs -n security -l app=keycloak --tail=50

# Check resource usage
kubectl top pods -n security -l app=keycloak
```

---

## Monitoring & Operations

### Daily Operations

#### Check Keycloak Health
```bash
# Health check
curl https://sso.monosense.dev/health

# Metrics
curl https://sso.monosense.dev/metrics
```

#### View Logs
```bash
# Tail logs
kubectl logs -n security -l app=keycloak --tail=100 -f

# Search for errors
kubectl logs -n security -l app=keycloak --tail=1000 | grep ERROR
```

#### Check Pod Status
```bash
# Pod status
kubectl get pods -n security -l app=keycloak

# Resource usage
kubectl top pods -n security -l app=keycloak

# Describe pod for events
kubectl describe pod -n security -l app=keycloak
```

### Grafana Dashboards

Import Keycloak dashboard from Grafana Labs:
- Dashboard ID: **10441** (Keycloak Metrics)
- Datasource: Victoria Metrics

Key metrics to monitor:
- JVM Heap Usage
- HTTP Request Rate
- Login Success/Failure Rate
- Database Connection Pool
- Cache Hit Rate

### Backup Procedures

#### Manual Realm Export
```bash
# Export realm configuration
kubectl exec -n security deployment/keycloak -- \
  /opt/keycloak/bin/kc.sh export \
  --realm home-ops \
  --file /tmp/realm-export.json

# Copy to local
kubectl cp security/keycloak-pod:/tmp/realm-export.json \
  ./realm-export-$(date +%Y%m%d).json
```

#### Database Backup
CloudNativePG handles automated backups. To trigger manual backup:
```bash
# Trigger manual backup
kubectl create job --from=cronjob/postgres-backup \
  manual-backup-$(date +%Y%m%d-%H%M%S) -n databases
```

### Scaling Operations

#### Scale Up/Down
```bash
# Scale to 3 instances
kubectl patch keycloak keycloak -n security \
  --type='json' \
  -p='[{"op": "replace", "path": "/spec/instances", "value": 3}]'

# Verify
kubectl get pods -n security -l app=keycloak
```

#### Resource Adjustment
Edit the Keycloak CR to adjust resources:
```bash
kubectl edit keycloak keycloak -n security
```

### Upgrade Procedures

#### Upgrade Keycloak Version

1. **Test in staging first!**

2. Update Keycloak CR:
```yaml
spec:
  image: quay.io/keycloak/keycloak:26.5.0  # New version
```

3. Apply changes:
```bash
git add kubernetes/apps/security/keycloak/app/keycloak.yaml
git commit -m "chore(security): upgrade Keycloak to v26.5.0"
git push

# Monitor rolling update
kubectl rollout status statefulset/keycloak -n security
```

4. Verify after upgrade:
```bash
# Check version
kubectl exec -n security keycloak-0 -- \
  /opt/keycloak/bin/kc.sh --version

# Test login
curl -I https://sso.monosense.dev
```

---

## Migration Strategy

### Pre-Migration Checklist

- [ ] Keycloak deployed and accessible
- [ ] Admin console working
- [ ] Custom theme applied correctly
- [ ] Database connectivity verified
- [ ] Monitoring/alerts configured
- [ ] Test realm created and validated
- [ ] Spring Boot test app successfully authenticated
- [ ] Backup procedures tested
- [ ] Rollback plan documented

### Migration Phases

#### Phase 1: Parallel Operation (Week 1)

**Objective**: Run Keycloak alongside Authentik with no production impact

- ✅ Keycloak: `sso.monosense.dev`
- ✅ Authentik: `auth.monosense.dev` (unchanged)
- ✅ Both systems fully operational
- ✅ No changes to existing applications

**Tasks**:
1. Deploy Keycloak (already done)
2. Create test realm and users
3. Configure test OAuth2 clients
4. Test login flows thoroughly
5. Validate JWT tokens
6. Performance baseline testing

#### Phase 2: Data Migration (Week 2)

**Objective**: Migrate users and configuration from Authentik to Keycloak

**Export from Authentik**:
```bash
# Export users
curl -H "Authorization: Bearer ${AUTHENTIK_TOKEN}" \
  https://auth.monosense.dev/api/v3/core/users/ > authentik-users.json

# Export groups
curl -H "Authorization: Bearer ${AUTHENTIK_TOKEN}" \
  https://auth.monosense.dev/api/v3/core/groups/ > authentik-groups.json
```

**Import to Keycloak**:
1. Use import script (see Phase 5 of implementation)
2. Verify all users imported correctly
3. Test user login with existing passwords
4. Map groups to Keycloak roles

**Tasks**:
- [ ] Export all users from Authentik
- [ ] Export groups/roles
- [ ] Document OAuth2 client configurations
- [ ] Import users to Keycloak
- [ ] Recreate groups and roles
- [ ] Configure OAuth2/OIDC clients
- [ ] Apply KeycloakRealmImport CR for GitOps
- [ ] Verify user can login to Keycloak
- [ ] Test password reset flow
- [ ] Test role-based access

#### Phase 3: Application Migration (Week 3)

**Objective**: Migrate Spring Boot applications one by one

**For each application**:

1. **Update Configuration**:

Old (Authentik):
```yaml
spring:
  security:
    oauth2:
      client:
        provider:
          authentik:
            issuer-uri: https://auth.monosense.dev/application/o/my-app/
```

New (Keycloak):
```yaml
spring:
  security:
    oauth2:
      client:
        provider:
          keycloak:
            issuer-uri: https://sso.monosense.dev/realms/home-ops
        registration:
          keycloak:
            client-id: spring-app
            client-secret: ${KEYCLOAK_CLIENT_SECRET}
```

2. **Deploy and Test**:
   - Deploy to staging first
   - Test all authentication flows
   - Test authorization (roles/permissions)
   - Verify API endpoints work
   - Check logs for errors

3. **Production Deployment**:
   - Deploy during low-traffic period
   - Monitor closely for 24 hours
   - Be ready to rollback if issues

**Migration Order** (suggested):
1. Non-critical internal tools first
2. API services (test JWT validation)
3. User-facing applications
4. Critical production services last

**Rollback Plan**:
- Keep Authentik configuration in Git (commented out)
- Revert application configuration to Authentik
- Update DNS if needed

#### Phase 4: Cutover (Week 4)

**Objective**: Switch production traffic to Keycloak

**Pre-Cutover**:
- [ ] All applications migrated and tested
- [ ] No issues reported for 48 hours
- [ ] Performance metrics acceptable
- [ ] Backup verified
- [ ] Team briefed
- [ ] Rollback plan ready

**Cutover Steps**:

1. **Announce maintenance window** (if needed)

2. **Update HTTPRoute** (if using same hostname):
```yaml
# Update authentik HTTPRoute to point to Keycloak
# Or switch DNS to point auth.monosense.dev to Keycloak
```

3. **Monitor closely**:
```bash
# Watch Keycloak logs
kubectl logs -n security -l app=keycloak -f

# Monitor metrics
watch kubectl top pods -n security -l app=keycloak

# Check alerts
kubectl get vmrule keycloak-alerts -n security
```

4. **Verify all services**:
   - Test login on all applications
   - Check API authentication
   - Verify metrics being collected
   - Check audit logs

5. **Keep Authentik running** for 48-72 hours as rollback option

**Rollback Procedure** (if needed):
```bash
# Revert HTTPRoute
kubectl apply -f kubernetes/apps/security/authentik/app/httproute.yaml

# Or revert DNS changes
# Update external-dns annotation

# Notify team
# Investigate issues
# Plan retry
```

#### Phase 5: Cleanup (Week 5+)

**Objective**: Remove Authentik after successful migration

**Tasks**:
- [ ] Verify Keycloak stable for 1 week
- [ ] No rollback needed
- [ ] All applications working correctly
- [ ] User feedback positive

**Cleanup Steps**:

1. **Remove Authentik Resources**:
```bash
# Delete Authentik
kubectl delete kustomization authentik -n security

# Remove from kustomization
git rm kubernetes/apps/security/authentik/
git commit -m "chore(security): remove Authentik after Keycloak migration"
git push
```

2. **Archive Configuration**:
```bash
# Create archive branch
git checkout -b archive/authentik
git push origin archive/authentik

# Document migration
# Update runbooks
# Update team wiki
```

3. **Update Documentation**:
   - Update architecture diagrams
   - Update API documentation
   - Update developer onboarding docs
   - Update incident response procedures

---

## Troubleshooting

### Common Issues

#### Issue: Keycloak Pods Not Starting

**Symptoms**:
- Pods in `CrashLoopBackOff`
- Error in logs: "Failed to connect to database"

**Diagnosis**:
```bash
kubectl describe pod -n security -l app=keycloak
kubectl logs -n security -l app=keycloak --tail=100
```

**Solutions**:
1. Check database connectivity:
```bash
kubectl exec -n security keycloak-0 -- \
  psql -h postgres-rw.databases.svc.cluster.local -U keycloak -d keycloak
```

2. Verify secrets exist:
```bash
kubectl get secret keycloak-pguser-secret -n security
kubectl get secret keycloak-admin-secret -n security
```

3. Check ExternalSecrets:
```bash
kubectl get externalsecret -n security
kubectl describe externalsecret keycloak-pguser -n security
```

#### Issue: Theme Not Loading

**Symptoms**:
- Login page shows default Keycloak theme instead of custom theme
- No errors in logs

**Solutions**:
1. Check init container ran successfully:
```bash
kubectl describe pod -n security keycloak-0 | grep -A 20 "Init Containers"
```

2. Verify theme files copied:
```bash
kubectl exec -n security keycloak-0 -- ls -la /opt/keycloak/themes/
kubectl exec -n security keycloak-0 -- ls -la /opt/keycloak/themes/custom-redhat/
```

3. Check theme configuration:
```bash
# Verify spi-theme-default is set
kubectl get keycloak keycloak -n security -o yaml | grep -A 5 additionalOptions
```

4. Rebuild theme image:
```bash
cd kubernetes/apps/security/keycloak/theme/
./build.sh
```

5. Force pod restart:
```bash
kubectl rollout restart statefulset/keycloak -n security
```

#### Issue: Login Fails with 401/403

**Symptoms**:
- User enters correct credentials
- Returns 401 Unauthorized or 403 Forbidden

**Solutions**:
1. Check user exists and is enabled:
   - Login to Admin Console
   - Go to Users
   - Search for user
   - Verify "Enabled" toggle is ON

2. Check realm is correct:
   - Verify application is using correct realm in issuer-uri
   - Check realm exists in Keycloak

3. Check client configuration:
   - Verify client ID matches
   - Check redirect URIs are correct
   - Ensure client secret is correct

4. Check logs:
```bash
kubectl logs -n security -l app=keycloak | grep ERROR
```

#### Issue: High Memory Usage

**Symptoms**:
- Keycloak pods using > 1.5Gi memory
- OOMKilled events in pod events

**Solutions**:
1. Check current usage:
```bash
kubectl top pods -n security -l app=keycloak
```

2. Increase memory limits:
```yaml
spec:
  unsupported:
    podTemplate:
      spec:
        containers:
          - name: keycloak
            resources:
              limits:
                memory: 3Gi  # Increase from 2Gi
```

3. Tune JVM:
```yaml
env:
  - name: JAVA_OPTS_APPEND
    value: >-
      -Xms1g
      -Xmx2g
      -XX:+UseG1GC
```

4. Check for memory leaks:
```bash
# Get heap dump
kubectl exec -n security keycloak-0 -- \
  jmap -dump:format=b,file=/tmp/heap.hprof 1

# Analyze with tools like Eclipse MAT
```

#### Issue: Database Connection Pool Exhausted

**Symptoms**:
- Slow login times
- Error: "Unable to acquire JDBC connection"

**Solutions**:
1. Increase pool size:
```yaml
additionalOptions:
  - name: db-pool-max-size
    value: "30"  # Increase from 20
```

2. Check database connections:
```bash
kubectl exec -n databases postgres-0 -- \
  psql -U postgres -c "SELECT count(*) FROM pg_stat_activity WHERE datname='keycloak';"
```

3. Monitor connection pool metrics in Grafana

#### Issue: HTTPRoute Not Working

**Symptoms**:
- Cannot access sso.monosense.dev
- Connection timeout or DNS errors

**Solutions**:
1. Check HTTPRoute status:
```bash
kubectl get httproute keycloak -n security
kubectl describe httproute keycloak -n security
```

2. Verify Gateway:
```bash
kubectl get gateway envoy-external -n networking
kubectl describe gateway envoy-external -n networking
```

3. Check ReferenceGrant:
```bash
kubectl get referencegrant keycloak -n security
```

4. Test service directly:
```bash
kubectl port-forward -n security svc/keycloak-service 8080:8080
curl http://localhost:8080/health
```

5. Check external-dns:
```bash
kubectl logs -n networking -l app.kubernetes.io/name=external-dns
```

---

## Resources

### Official Documentation

- [Keycloak Operator Installation](https://www.keycloak.org/operator/installation)
- [Keycloak Server Administration Guide](https://www.keycloak.org/docs/latest/server_admin/)
- [Keycloak High Availability Guide](https://www.keycloak.org/high-availability/deploy-keycloak-kubernetes)
- [Spring Security OAuth2 Guide](https://spring.io/guides/tutorials/spring-boot-oauth2)
- [Gateway API Documentation](https://gateway-api.sigs.k8s.io/)

### Theme Development

- [Keycloak Theme Development](https://www.keycloak.org/ui-customization/themes)
- [PatternFly Design System](https://www.patternfly.org/)
- [Red Hat Brand Guidelines](https://www.redhat.com/en/about/brand/standards)
- [Apache FreeMarker Documentation](https://freemarker.apache.org/docs/)

### Monitoring & Operations

- [Keycloak Metrics Configuration](https://www.keycloak.org/server/configuration-metrics)
- [Victoria Metrics Documentation](https://docs.victoriametrics.com/)
- [Grafana Keycloak Dashboard](https://grafana.com/grafana/dashboards/10441)

### Community Resources

- [Keycloak GitHub Repository](https://github.com/keycloak/keycloak)
- [Keycloak Operator GitHub](https://github.com/keycloak/keycloak-k8s-resources)
- [Keycloak Discourse Community](https://keycloak.discourse.group/)
- [Stack Overflow - Keycloak Tag](https://stackoverflow.com/questions/tagged/keycloak)

### Related Projects

- [CloudNativePG](https://cloudnative-pg.io/)
- [Dragonfly](https://www.dragonflydb.io/)
- [Envoy Gateway](https://gateway.envoyproxy.io/)
- [External Secrets Operator](https://external-secrets.io/)

---

## Appendix

### Complete File Structure

```
kubernetes/apps/security/
├── keycloak-operator/
│   ├── ks.yaml
│   └── app/
│       └── kustomization.yaml
│
├── keycloak/
│   ├── ks.yaml
│   ├── theme/
│   │   ├── Dockerfile
│   │   ├── build.sh
│   │   └── custom-redhat/
│   │       └── login/
│   │           ├── theme.properties
│   │           ├── resources/
│   │           │   ├── css/custom.css
│   │           │   └── img/logo.png
│   │           └── messages/
│   │               └── messages_en.properties
│   ├── scripts/
│   │   └── import-users.sh
│   └── app/
│       ├── kustomization.yaml
│       ├── externalsecret.yaml
│       ├── init-db-job.yaml
│       ├── keycloak.yaml
│       ├── httproute.yaml
│       ├── referencegrant.yaml
│       ├── servicemonitor.yaml
│       ├── vmrule.yaml
│       ├── pdb.yaml
│       └── realm-import.yaml
│
└── kustomization.yaml
```

### Version Matrix

| Component | Version | Notes |
|-----------|---------|-------|
| Keycloak | 26.4.0 | Latest stable (Oct 2025) |
| Keycloak Operator | 26.4.0 | Matches Keycloak version |
| PostgreSQL | 17 | Via CloudNativePG |
| Spring Boot | 3.4.x | Latest LTS |
| Java | 17+ | Minimum for Spring Boot 3 |

### Success Criteria

**Deployment Success**:
- ✅ Keycloak pods running (2/2)
- ✅ Database connectivity verified
- ✅ HTTPRoute responding (200 OK)
- ✅ Admin console accessible
- ✅ Custom theme applied
- ✅ Metrics endpoint scraped

**Performance Targets**:
- Login latency: < 500ms (p95)
- Token validation: < 50ms (p95)
- Memory usage: < 1.5Gi per pod
- CPU usage: < 60% average
- Uptime: 99.9%

**Security Verification**:
- ✅ TLS certificate valid
- ✅ Database credentials secured
- ✅ Admin password strong
- ✅ Brute force protection enabled
- ✅ Audit logging active

---

## Changelog

| Date | Version | Changes |
|------|---------|---------|
| 2025-10-13 | 1.0.0 | Initial implementation plan created |

---

**End of Document**
