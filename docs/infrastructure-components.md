# Infrastructure Components Inventory

> **Generated:** 2025-11-09
> **Project:** k8s-gitops Multi-Cluster Infrastructure
> **Total Components:** 30+

This document catalogs all infrastructure components deployed across the infra and apps clusters.

## Component Categories

1. [Networking](#networking)
2. [Security](#security)
3. [Storage](#storage)
4. [Databases](#databases)
5. [Messaging](#messaging)
6. [Observability](#observability)
7. [GitOps](#gitops)
8. [Operations](#operations)
9. [Platform Workloads](#platform-workloads)
10. [Tenant Workloads](#tenant-workloads)

---

## Networking

### Cilium CNI
**Location:** `kubernetes/infrastructure/networking/cilium/`
**Version:** Variable (`${CILIUM_VERSION}` from cluster-settings)
**Type:** eBPF-based CNI with advanced networking features
**Source:** OCI Registry

**Features:**
- **CNI:** Native routing with IPv4 native routing CIDR
- **Kube-proxy replacement:** Full kube-proxy replacement enabled
- **Encryption:** WireGuard node-to-node encryption
- **DNS Proxy:** Required for FQDN-based NetworkPolicies
- **Hubble:** Observability platform (relay enabled, UI disabled)
- **Gateway API:** Kubernetes Gateway API support
- **BGP Control Plane:** Dynamic routing with BGP
- **ClusterMesh:** Multi-cluster service discovery with API server (2 replicas, LoadBalancer service)
- **IPAM:** Kubernetes IPAM mode
- **Metrics:** Prometheus ServiceMonitor enabled

**Configuration per cluster:**
- Cluster ID (infra: 1, apps: 2)
- Cluster name
- Pod CIDR
- BGP ASN (infra: 64512, apps: 64513)
- ClusterMesh LoadBalancer IP
- API server endpoint

### CoreDNS
**Location:** `kubernetes/infrastructure/networking/coredns/`
**Version:** 1.45.0
**Type:** DNS server for Kubernetes cluster
**Source:** Helm chart

**Purpose:** Cluster DNS resolution

### ExternalDNS
**Location:** `kubernetes/infrastructure/networking/external-dns/`
**Type:** Automatic DNS record management
**Integration:** Cloudflare DNS provider

**Purpose:** Automatically sync Ingress/Service DNS records to Cloudflare

### Cloudflared
**Location:** `kubernetes/infrastructure/networking/cloudflared/`
**Type:** Cloudflare tunnel
**Purpose:** Secure access to services via Cloudflare tunnels

### Spegel
**Location:** `kubernetes/infrastructure/networking/spegel/`
**Version:** 0.4.0
**Type:** Stateless cluster-local OCI registry mirror
**Source:** Helm chart

**Purpose:** Reduce external registry traffic, improve image pull performance

---

## Security

### cert-manager
**Location:** `kubernetes/infrastructure/security/cert-manager/`
**Type:** X.509 certificate automation
**Purpose:** TLS certificate provisioning and management (Let's Encrypt integration)

**Features:**
- Automated certificate issuance
- Certificate renewal
- Let's Encrypt ACME support
- Cloudflare DNS01 challenge support

### external-secrets
**Location:** `kubernetes/infrastructure/security/external-secrets/`
**Version:** 0.20.4
**Type:** External secret management operator
**Integration:** 1Password Connect

**Purpose:** Sync secrets from 1Password vault to Kubernetes Secrets

**Configuration:**
- Vault: "Infra" (1Password)
- Secret paths: `kubernetes/infra/*` and `kubernetes/apps/*` per cluster
- ExternalSecret CRDs define secret mappings

### NetworkPolicy Baseline
**Location:** `kubernetes/infrastructure/security/networkpolicy/`
**Type:** Cilium NetworkPolicy templates
**Purpose:** Network segmentation and security

**Components:**
- **deny-all:** Default deny baseline (`kubernetes/components/networkpolicy/deny-all/`)
- **allow-dns:** DNS egress policy (`kubernetes/components/networkpolicy/allow-dns/`)
- **allow-fqdn:** FQDN-based egress (`kubernetes/components/networkpolicy/allow-fqdn/`)
- **allow-kube-api:** API server access (`kubernetes/components/networkpolicy/allow-kube-api/`)
- **allow-internal:** Cluster-internal communication (`kubernetes/components/networkpolicy/allow-internal/`)

**Pattern:** Apply baseline deny-all to all namespaces, then add explicit allow policies per workload

---

## Storage

### Rook-Ceph
**Location:** `kubernetes/infrastructure/storage/rook-ceph/`
**Operator Version:** v1.18.6
**Type:** Distributed block, object, and file storage
**Source:** Helm chart

**Components:**
- Rook-Ceph operator (`kubernetes/bases/rook-ceph-operator/`)
- Ceph cluster instances

**Purpose:** High-availability distributed storage for StatefulSets

### OpenEBS
**Location:** `kubernetes/infrastructure/storage/openebs/`
**Version:** 4.3.3
**Type:** Local persistent volume provisioner
**Source:** Helm chart

**Purpose:** Local PV provisioning for workloads requiring node-local storage

**Storage Classes:**
- Block storage class (variable: `${BLOCK_SC}`)
- OpenEBS local storage class (variable: `${OPENEBS_LOCAL_SC}`)

---

## Databases

### CloudNativePG Operator
**Location:** `kubernetes/bases/cnpg-operator/`
**Version:** 0.26.1
**Type:** PostgreSQL operator for Kubernetes
**Source:** OCI Registry

**Purpose:** Manage PostgreSQL clusters with high availability

**Features:**
- Automated backups
- Point-in-time recovery (PITR)
- Connection pooling (PgBouncer)
- Monitoring integration
- Multi-version support (configurable via `${CNPG_POSTGRES_VERSION}`)

**Instances:**
- **Shared PostgreSQL cluster:** `kubernetes/workloads/platform/databases/cloudnative-pg/`
  - Multi-tenant shared database
  - Used by platform services (Keycloak, GitLab, Harbor, etc.)

### DragonflyDB Operator
**Location:** `kubernetes/bases/dragonfly-operator/`
**Version:** v1.3.0 (image tag)
**Type:** Redis-compatible in-memory data store operator
**Source:** OCI Registry (ghcr.io/dragonflydb/operator)

**Purpose:** Manage DragonflyDB clusters (high-performance Redis alternative)

**Features:**
- High availability (replication)
- Persistence
- ServiceMonitor for metrics
- Pod anti-affinity
- PodDisruptionBudget (minAvailable: 1)

**Instances:**
- **Shared Dragonfly cluster:** `kubernetes/workloads/platform/databases/dragonfly/`
  - Multi-tenant shared cache/data store
  - Used by platform services

**Storage:** Uses `${DRAGONFLY_STORAGE_CLASS}` variable

---

## Messaging

### Strimzi Kafka Operator
**Location:** `kubernetes/bases/strimzi-operator/`
**Version:** 0.48.0
**Type:** Apache Kafka operator for Kubernetes
**Source:** Helm chart

**Purpose:** Manage Kafka clusters, topics, users, and connectors

**Features:**
- Kafka cluster provisioning
- Topic management
- User (authentication/authorization) management
- Kafka Connect
- Metrics integration

**Instances:**
- **Kafka cluster (apps cluster):** `kubernetes/workloads/platform/messaging/kafka/`
  - Deployed only to apps cluster (Story 38)
  - Platform messaging backbone

---

## Observability

### Victoria Metrics
**Location:** `kubernetes/infrastructure/observability/victoria-metrics/`
**Version:** Variable (`${VICTORIAMETRICS_K8S_STACK_VERSION}`)
**Type:** Time-series metrics database and monitoring stack
**Source:** Helm chart

**Components:**
- **vmcluster:** Victoria Metrics cluster (storage)
- **vmagent:** Metrics collection agent

**Purpose:** Prometheus-compatible metrics storage and querying

**Features:**
- High-performance time-series database
- PromQL support
- Long-term retention (variable: `${VM_RETENTION_PERIOD}`)
- ServiceMonitor for auto-discovery
- Multi-tenancy support (tenant per cluster: `${OBSERVABILITY_LOGS_TENANT}`)

### Victoria Logs
**Location:** `kubernetes/infrastructure/observability/victoria-logs/`
**Version:** 0.11.12
**Type:** Centralized log aggregation
**Source:** Helm chart

**Purpose:** LogQL-compatible log storage and querying (Loki alternative)

**Features:**
- High-performance log ingestion
- LogQL support
- Long-term retention
- Multi-tenancy (tenant: `${OBSERVABILITY_LOG_TENANT}`)
- Storage size: `${OBSERVABILITY_LOGS_STORAGE_SIZE}`

### Fluent-bit Operator
**Location:** `kubernetes/bases/fluent-bit-operator/`
**Type:** Log collection operator
**Source:** Helm chart

**Purpose:** Manage Fluent-bit log collectors per node

**Features:**
- DaemonSet-based log collection
- Output to Victoria Logs
- Automatic configuration via CRDs

**Instances:**
- Fluent-bit collectors deployed via operator

### Dashboards
**Location:** `kubernetes/infrastructure/observability/dashboards/`
**Type:** Grafana dashboard definitions (ConfigMaps)

**Purpose:** Pre-configured Grafana dashboards for infrastructure monitoring

---

## GitOps

### Flux CD
**Built-in:** Installed via bootstrap
**Purpose:** GitOps continuous deployment

**Components:**
- **source-controller:** Artifact acquisition (Git, Helm, OCI)
- **kustomize-controller:** Kustomization reconciliation
- **helm-controller:** HelmRelease reconciliation
- **notification-controller:** Event notifications

**Architecture:**
- Cluster entry points: `kubernetes/clusters/{infra,apps}/`
- Watches repository for changes
- Reconciles every 5 minutes (configurable per Kustomization)

### OCI Repositories
**Location:** `kubernetes/infrastructure/gitops/oci-repositories/`
**Type:** OCIRepository CRDs for Flux

**Purpose:** Define OCI registries as Helm chart sources

**Examples:**
- Cilium charts (OCI registry)
- CloudNativePG charts (OCI registry)
- Dragonfly charts (OCI registry)

### ArgoCD (Optional)
**Location:** `kubernetes/infrastructure/gitops/argocd/`
**Type:** Alternative GitOps controller
**Status:** Optional (not primary)

---

## Operations

### Reloader
**Location:** `kubernetes/infrastructure/operations/reloader/`
**Type:** ConfigMap/Secret change detector
**Purpose:** Automatically reload Deployments/StatefulSets when ConfigMaps or Secrets change

**Features:**
- Watches ConfigMaps and Secrets
- Triggers rolling restart on changes
- Annotation-based opt-in

---

## Platform Workloads

### GitHub Actions Runner Controller
**Location:** `kubernetes/workloads/platform/cicd/actions-runner-system/`
**Type:** Self-hosted GitHub Actions runners
**Components:**
- **Controller:** Runner lifecycle management
- **Runners:** Ephemeral runner pods

**Purpose:** Execute GitHub Actions workflows on self-hosted infrastructure

**Features:**
- Ephemeral runners (fresh environment per job)
- Auto-scaling based on workflow queue
- Docker-in-Docker (rootless DIND)
- Multiple runner configurations (e.g., `pilar` runner set)

### Harbor
**Location:** `kubernetes/workloads/platform/registry/harbor/`
**Type:** OCI artifact registry (container images, Helm charts)

**Purpose:** Private container registry for platform

**Features:**
- Image vulnerability scanning
- Image signing (Notary)
- Helm chart repository
- Replication
- RBAC

### Keycloak
**Location:** `kubernetes/workloads/platform/identity/keycloak/`
**Type:** Identity and access management (IAM)
**Operator:** Keycloak operator (`kubernetes/bases/keycloak-operator/`)

**Purpose:** Single sign-on (SSO) for platform services

**Features:**
- OpenID Connect (OIDC)
- SAML 2.0
- User federation
- Multi-realm support
- Integration with platform databases (CloudNativePG)

**Admin secret path:** `${KEYCLOAK_ADMIN_SECRET_PATH}` (1Password)

---

## Tenant Workloads

### GitLab CE
**Location:** `kubernetes/workloads/tenants/gitlab/`
**Type:** Self-hosted Git repository manager and CI/CD platform

**Purpose:** Alternative Git hosting and CI/CD (independent from GitHub)

**Features:**
- Git repository hosting
- GitLab CI/CD pipelines
- Issue tracking
- Merge requests
- Container registry (integrated with Harbor)
- Integration with shared PostgreSQL (CloudNativePG)

**Monitoring:** `gitlab/monitoring/` subfolder

### GitLab Runner
**Location:** `kubernetes/workloads/tenants/gitlab-runner/`
**Type:** GitLab CI/CD job executors

**Purpose:** Execute GitLab CI/CD pipelines

**Features:**
- Kubernetes executor
- Docker-in-Docker support
- Auto-scaling based on CI/CD queue

---

## Component Relationships

### Operator → Instance Pattern
```
bases/{operator-name}/operator/
  ↓ (referenced by)
infrastructure/{category}/{operator-name}/
  ↓ (depends on)
workloads/platform/{category}/{instance}/
```

**Example (CloudNativePG):**
```
bases/cnpg-operator/operator/       (HelmRelease v0.26.1)
  ↓
infrastructure/databases/cloudnative-pg/  (Kustomization)
  ↓
workloads/platform/databases/cloudnative-pg/  (Cluster instance)
```

### Shared Services
These platform services are shared across tenant workloads:
- **PostgreSQL** (CloudNativePG shared cluster)
- **Redis** (Dragonfly shared cluster)
- **Storage** (Rook-Ceph distributed storage)
- **Observability** (Victoria Metrics/Logs)
- **Secrets** (external-secrets + 1Password)
- **TLS** (cert-manager)

### Network Isolation
- Baseline deny-all NetworkPolicies applied to all namespaces
- Explicit allow rules per workload
- Cilium enforces L3/L4/L7 policies

---

## Version Management

Component versions are managed via:
1. **Cluster-settings ConfigMap:** `kubernetes/clusters/{infra,apps}/cluster-settings.yaml` (200+ variables)
2. **Pinned versions:** Direct version specification in HelmRelease manifests
3. **Variable substitution:** `${VERSION_VAR}` placeholders replaced via `postBuild.substituteFrom`

**Examples:**
- `${CILIUM_VERSION}` - Cilium chart version
- `${CNPG_OPERATOR_VERSION}` - CloudNativePG operator version
- `${VICTORIAMETRICS_K8S_STACK_VERSION}` - Victoria Metrics stack version

## Health Checks

All Kustomizations declare expected resources via health checks:
```yaml
healthChecks:
  - apiVersion: apps/v1
    kind: Deployment
    name: component-name
    namespace: component-namespace
```

**Purpose:** Flux waits for health checks before reconciling dependent resources

---

## Documentation References

- **Component-specific READMEs:** Each component directory may have a README with detailed configuration
- **Helm chart values:** See HelmRelease manifests for full values configuration
- **Upstream documentation:** Refer to official project docs for component details

## Summary

This multi-cluster infrastructure deploys **30+ components** across networking, security, storage, databases, messaging, observability, and application workloads. The architecture emphasizes:
- **Declarative configuration:** All components defined in Git
- **Operator pattern:** Controllers manage complex stateful workloads
- **High availability:** Multi-replica deployments, distributed storage, multi-master control planes
- **Observability:** Comprehensive metrics and logging
- **Security:** Network policies, encrypted traffic, secret management, TLS automation
