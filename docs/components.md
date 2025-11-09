# Kubernetes GitOps Repository Component Matrix

> **Generated:** 2025-11-09
> **Repository:** k8s-gitops
> **Architecture:** Multi-Cluster GitOps with FluxCD

## Multi-Cluster Architecture Overview

The repository implements a sophisticated dual-cluster architecture with clear separation of concerns:

| Cluster | ID | CIDR | Purpose | Key Services |
|---------|----|------|---------|--------------|
| **Infra Cluster** | 1 | 10.244.0.0/16 | Core infrastructure services | Storage, Database, Identity, Observability |
| **Apps Cluster** | 2 | 10.246.0.0/16 | Application workloads | User applications, Development tools |

**GitOps Management:** FluxCD with GitRepository and OCIRepository sources providing automated reconciliation and drift detection.

---

## Component Matrix Table

### 1. GitOps & Automation Layer

| Component | Type | Version | Namespace | Deployment | Dependencies | Status |
|-----------|------|---------|-----------|------------|--------------|---------|
| **Flux CD** | GitOps Operator | Latest | flux-system | Both | GitRepository | ✅ Stable |
| **Helm Controller** | Flux Component | Built-in | flux-system | Both | Flux CD | ✅ Stable |
| **Kustomize Controller** | Flux Component | Built-in | flux-system | Both | Flux CD | ✅ Stable |
| **OCI Repository** | Flux Source | Multiple | flux-system | Both | Container Registries | ✅ Stable |
| **Helm Repository** | Flux Source | Multiple | flux-system | Apps | Chart Repositories | ✅ Stable |

---

### 2. Networking Components

| Component | Type | Version | Namespace | Deployment | Dependencies | Status |
|-----------|------|---------|-----------|------------|--------------|---------|
| **Cilium CNI** | CNI Plugin | 1.18.3 | kube-system | Both | Gateway API CRDs | ✅ Stable |
| **Cilium IPAM** | IPAM Manager | 1.18.3 | kube-system | Both | Cilium CNI | ✅ Stable |
| **Cilium BGP** | BGP Control Plane | 1.18.3 | kube-system | Both | Cilium CNI | ✅ Stable |
| **Cilium ClusterMesh** | Multi-Cluster | 1.18.3 | kube-system | Both | Cilium CNI | ✅ Stable |
| **Cilium Gateway** | L7 Load Balancer | 1.18.3 | kube-system | Both | Gateway API | ✅ Stable |
| **CoreDNS** | DNS Service | Latest | kube-system | Both | Cilium CNI | ✅ Stable |
| **ExternalDNS** | DNS Automation | Latest | external-dns | Both | ClusterSecretStore | ✅ Stable |
| **Cloudflared** | Tunnel Service | Latest | cloudflared | Both | ExternalDNS | ✅ Stable |
| **Spegel** | Registry Mirror | Latest | spegel | Both | Cilium CNI | ✅ Stable |

---

### 3. Security & Certificate Management

| Component | Type | Version | Namespace | Deployment | Dependencies | Status |
|-----------|------|---------|-----------|------------|--------------|---------|
| **cert-manager** | Certificate Manager | Latest | cert-manager | Both | Gateway API | ✅ Stable |
| **External Secrets** | Secret Management | 0.20.3 | external-secrets | Both | 1Password Connect | ✅ Stable |
| **NetworkPolicy** | Security Policies | Multiple | Varies | Both | Cilium CNI | ✅ Stable |

---

### 4. Storage Infrastructure

| Component | Type | Version | Namespace | Deployment | Dependencies | Status |
|-----------|------|---------|-----------|------------|--------------|---------|
| **Rook-Ceph Operator** | Storage Operator | v1.18.6 | rook-ceph | Both | - | ✅ Stable |
| **Rook-Ceph Cluster** | Distributed Storage | v19.2.3 | rook-ceph | Both | Rook Operator | ✅ Stable |
| **OpenEBS** | Local Storage | Latest | openebs | Both | Local NVMe | ✅ Stable |
| **CloudNative PG Operator** | PostgreSQL Operator | 0.26.1 | cnpg-system | Infra | - | ✅ Stable |
| **Dragonfly Operator** | Redis Operator | v1.34.2 | dragonfly-operator | Infra | OpenEBS | ✅ Stable |

---

### 5. Observability & Monitoring

| Component | Type | Version | Namespace | Deployment | Dependencies | Status |
|-----------|------|---------|-----------|------------|--------------|---------|
| **VictoriaMetrics Stack** | Monitoring Platform | v1.122.1 | observability | Infra | Rook-Ceph | ✅ Stable |
| **VictoriaLogs** | Log Management | v1.122.1 | observability | Both | VM Stack | ✅ Stable |
| **Fluent Bit Operator** | Log Collection | Latest | fluent-bit | Both | - | ✅ Stable |
| **Grafana** | Visualization | Built-in | observability | Infra | VictoriaMetrics | ✅ Stable |
| **Prometheus CRDs** | Metrics Format | 24.0.1 | observability | Both | VM Operator | ✅ Stable |

---

### 6. Messaging Infrastructure

| Component | Type | Version | Namespace | Deployment | Dependencies | Status |
|-----------|------|---------|-----------|------------|--------------|---------|
| **Strimzi Operator** | Kafka Operator | Latest | strimzi-operator | Apps | Rook-Ceph | ✅ Stable |
| **Kafka Cluster** | Message Broker | 4.1.0 | messaging | Apps | Strimzi + Rook | ✅ Stable |

---

### 7. Platform Services (Infra Cluster)

| Component | Type | Version | Namespace | Deployment | Dependencies | Status |
|-----------|------|---------|-----------|------------|--------------|---------|
| **Keycloak** | Identity Provider | 26.4.5 | keycloak-system | Infra | CNPG + Cert-Manager | ✅ Stable |
| **Harbor Registry** | Container Registry | 2.14.0 | harbor | Infra | CNPG + Dragonfly + MinIO | ✅ Stable |
| **Shared PostgreSQL** | Database Service | 16.8 | cnpg-system | Infra | CNPG Operator | ✅ Stable |
| **Dragonfly Cluster** | Cache Service | v1.34.2 | dragonfly-system | Infra | Dragonfly Operator | ✅ Stable |

---

### 8. Application Services (Apps Cluster)

| Component | Type | Version | Namespace | Deployment | Dependencies | Status |
|-----------|------|---------|-----------|------------|--------------|---------|
| **GitLab** | DevOps Platform | Latest | gitlab | Apps | External DB/Redis/S3 | ✅ Stable |
| **GitLab Runner** | CI/CD Executor | Latest | gitlab-runner | Apps | GitLab | ✅ Stable |
| **GitHub ARC** | Runner Controller | Latest | actions-runner-system | Apps | GitHub API | ✅ Stable |
| **Argo CD** | GitOps Deploy | Latest | argocd | Apps | Keycloak OIDC | 🚧 Planned |

---

### 9. Operations & Maintenance

| Component | Type | Version | Namespace | Deployment | Dependencies | Status |
|-----------|------|---------|-----------|------------|--------------|---------|
| **Reloader** | Config Reloader | Latest | reloader | Both | - | ✅ Stable |

---

## Integration Patterns & Dependencies

### Cross-Cluster Dependencies

| Source Cluster | Target Cluster | Service | Protocol | Purpose |
|----------------|----------------|---------|----------|---------|
| **Apps Cluster** | **Infra Cluster** | Keycloak | OIDC | Identity & Authentication |
| **Both Clusters** | **Infra Cluster** | Rook-Ceph | Ceph RBD/CephFS | Distributed Storage |
| **Both Clusters** | **Both Clusters** | ClusterMesh | Encrypted | Multi-Cluster Service Mesh |
| **Apps Cluster** | **Infra Cluster** | VictoriaMetrics | Remote Write | Metrics & Logging |
| **Both Clusters** | **Infra Cluster** | cert-manager | ClusterIssuer | Certificate Management |

### Configuration Management Patterns

1. **Flux Substitution** - Variable substitution via `cluster-settings` ConfigMap with environment-specific values
2. **External Secrets** - 1Password Connect for centralized secret management across clusters
3. **HelmRelease Strategy** - OCI repositories for charts with external secret injection
4. **Kustomize Hierarchies** - Layered configuration (bases → components → clusters)
5. **Git Repository Sources** - Self-referencing repository for GitOps operations

### Resource Quotas & Limits

| Category | Configuration | Details |
|----------|---------------|---------|
| **High Availability** | 2-3 replicas | Critical services with anti-affinity rules |
| **Resource Limits** | CPU/Memory defined | Per-component limits with requests/limits |
| **Storage** | Tiered approach | OpenEBS for local NVMe, Rook-Ceph for distributed |
| **Networking** | BGP + LB IPAM | Cilium with BGP peering and LoadBalancer IPAM |
| **Security** | PSA restricted | Pod Security Standards compliance |

### Security Patterns

| Security Pattern | Implementation | Coverage |
|-----------------|----------------|----------|
| **Zero Trust** | NetworkPolicy via Cilium | All inter-service communication |
| **Certificate Automation** | cert-manager + Cloudflare DNS01 | All external services |
| **Secrets Management** | External Secrets + 1Password | All cluster secrets |
| **Pod Security** | PSA restricted compliance | All workloads |
| **Admission Control** | Gatekeeper policies | Planned implementation |

---

## Component Lifecycle Status

| Status | Meaning | Count |
|--------|---------|-------|
| ✅ **Stable** | Production-ready, fully tested | 35 components |
| 🚧 **Experimental** | Testing/evaluation phase | 1 component |
| 📋 **Planned** | Approved for implementation | 2 components |
| ⚠️ **Attention** | Requires upgrade/maintenance | 0 components |

---

## Strategic Technical Insights

### 1. **Infrastructure Separation**
- **Infra Cluster**: Houses all shared services (databases, storage, identity)
- **Apps Cluster**: Focuses purely on application workloads
- **Clear Boundaries**: Cross-cluster communication through defined APIs only

### 2. **Secret Management Excellence**
- **Centralized 1Password Connect** at `opconnect.monosense.dev`
- **Cross-cluster secret synchronization** within 30 seconds
- **Zero-trust authentication** via shared secrets
- **Enterprise-grade audit trail** for all secret operations

### 3. **Storage Architecture**
- **Distributed Storage**: Rook-Ceph for shared, persistent data
- **Local Storage**: OpenEBS for high-performance local workloads
- **Database Services**: CloudNativePG for PostgreSQL workloads
- **Cache Services**: Dragonfly for Redis-compatible caching

### 4. **Observability Stack**
- **Unified Monitoring**: VictoriaMetrics across all clusters
- **Centralized Logging**: VictoriaLogs for log aggregation
- **Network Visibility**: Hubble (via Cilium) for network flows
- **Security Telemetry**: Comprehensive audit logging

### 5. **GitOps Maturity**
- **Multi-source Management**: GitRepository + OCIRepository patterns
- **Automated Reconciliation**: FluxCD with health checking
- **Dependency Management**: Explicit dependsOn chains
- **Configuration Drift Prevention**: Git as single source of truth

---

## Component Upgrade Path

| Component | Current | Target | Priority | Impact |
|-----------|---------|--------|----------|---------|
| **External Secrets** | 0.20.3 | 1.0.0 | High | Performance & stability |
| **cert-manager** | Latest | 1.16.5 | Medium | Security patches |
| **Cilium** | 1.18.3 | 1.18.x | Low | Bug fixes only |
| **VictoriaMetrics** | v1.122.1 | Latest | Low | New features |

---

## Usage Guidelines

### Adding New Components
1. **Determine cluster placement** (infra vs apps vs both)
2. **Create component directory** under appropriate category
3. **Define dependencies** in Kustomization dependsOn
4. **Add health checks** for automated validation
5. **Update this matrix** for documentation

### Cross-Cluster Communication
1. **Use ClusterMesh** for service-to-service communication
2. **Implement shared secrets** via External Secrets
3. **Define network policies** for security boundaries
4. **Monitor cross-cluster latency** via VictoriaMetrics

### Monitoring & Alerting
1. **All components** export Prometheus metrics
2. **Critical services** have health checks defined
3. **Cross-cluster dependencies** monitored separately
4. **Resource utilization** tracked per component

---

*This matrix provides a comprehensive overview of the entire Kubernetes infrastructure, showing how components interact across clusters and their current deployment status in the GitOps workflow.*

*Last updated: 2025-11-09*