# Architecture Documentation

## Executive Summary

This is a **multi-cluster Kubernetes GitOps infrastructure** running on bare-metal hardware with **Talos Linux**. The architecture separates platform services (infra cluster) from application workloads (apps cluster), providing isolation, scalability, and security.

**Key Characteristics:**
- **Platform**: 2x 3-node Talos Kubernetes clusters (infra + apps)
- **GitOps**: Flux CD manages all cluster state declaratively from Git
- **Networking**: Cilium CNI with eBPF, BGP, Gateway API, and ClusterMesh
- **Storage**: Rook-Ceph (distributed) + OpenEBS (local)
- **Observability**: Victoria Metrics + Victoria Logs
- **Security**: cert-manager, External Secrets (1Password), SOPS encryption, Network Policies

---

## Architecture Overview

### Multi-Cluster Topology

```
┌──────────────────────────────────────┐    ┌──────────────────────────────────────┐
│       INFRA CLUSTER (10.244/16)      │    │       APPS CLUSTER (10.246/16)       │
│  ┌────────────────────────────────┐  │    │  ┌────────────────────────────────┐  │
│  │   Control Plane Nodes (3)      │  │    │  │   Control Plane Nodes (3)      │  │
│  │   10.25.11.11-13               │  │    │  │   10.25.11.14-16               │  │
│  └────────────────────────────────┘  │    │  └────────────────────────────────┘  │
│                                       │    │                                       │
│  📦 PLATFORM SERVICES                │    │  💼 APPLICATION WORKLOADS             │
│  ├─ Storage: Rook-Ceph              │    │  ├─ GitLab (SCM, CI/CD)              │
│  ├─ Databases: PostgreSQL (CNPG)   │    │  ├─ GitLab Runner                     │
│  ├─ Cache: Dragonfly                │    │  ├─ Kafka (Messaging)                │
│  ├─ Observability: VM + VL          │    │  ├─ Harbor (Registry)                │
│  ├─ Security: cert-manager, ExSec  │    │  └─ (+ Shared Infrastructure)        │
│  ├─ Networking: Cilium, DNS         │    │                                       │
│  └─ Identity: Keycloak (SSO)        │    │  📦 SHARED INFRASTRUCTURE             │
└───────────────────────────────────────┘    │  ├─ Cilium CNI                       │
                  ↕                          │  ├─ CoreDNS                          │
         Cilium ClusterMesh                  │  ├─ cert-manager                     │
    (Cross-cluster networking)                │  ├─ External Secrets                │
                  ↕                          │  ├─ Observability Agents             │
┌───────────────────────────────────────┐    │  └─ Storage (OpenEBS)                │
│          SHARED SERVICES              │    └──────────────────────────────────────┘
│  - Shared PostgreSQL Cluster         │
│  - Centralized Observability         │               ↓
│  - Centralized Identity (Keycloak)   │        GitHub Repository
└───────────────────────────────────────┘    (Source of Truth - GitOps)
                  ↓                                    ↓
          Juniper SRX320                         Flux CD v2
        (BGP Peer, Router)                  (Reconciles clusters)
```

---

## Architecture Patterns

### 1. GitOps-First Architecture

**All cluster state is defined in Git and reconciled by Flux CD.**

```
┌─────────────────┐
│ Git Repository  │  ← Single source of truth
│  (GitHub)       │
└────────┬────────┘
         │
         ↓  Flux watches Git
┌────────────────────────────────────────┐
│         Flux CD Controllers            │
│  ┌──────────────┬──────────────────┐  │
│  │ Source       │ Kustomize        │  │
│  │ Controller   │ Controller       │  │
│  └──────────────┴──────────────────┘  │
│  ┌──────────────┬──────────────────┐  │
│  │ Helm         │ Image            │  │
│  │ Controller   │ Controller       │  │
│  └──────────────┴──────────────────┘  │
└────────────────────────────────────────┘
         │
         ↓  Applies desired state
┌────────────────────────────────────────┐
│      Kubernetes Cluster                │
│  ┌──────────────────────────────────┐  │
│  │  Infrastructure Components       │  │
│  │  - Cilium, CoreDNS, Rook-Ceph   │  │
│  │  - Victoria Metrics, Keycloak   │  │
│  └──────────────────────────────────┘  │
│  ┌──────────────────────────────────┐  │
│  │  Application Workloads           │  │
│  │  - GitLab, Harbor, Kafka        │  │
│  └──────────────────────────────────┘  │
└────────────────────────────────────────┘
```

**Benefits:**
- ✅ Declarative infrastructure
- ✅ Version-controlled changes
- ✅ Audit trail (Git history)
- ✅ Easy rollbacks (Git revert)
- ✅ Pull-based security model

---

### 2. Immutable Infrastructure (Talos Linux)

**Talos is a purpose-built immutable OS for Kubernetes with no SSH, no shell, and API-only management.**

```
┌──────────────────────────────────┐
│     Talos Linux (Immutable)      │
│  ┌────────────────────────────┐  │
│  │  Kernel + System Services  │  │
│  │  - containerd              │  │
│  │  - kubelet                 │  │
│  │  - CRI (no Docker)         │  │
│  └────────────────────────────┘  │
│           ↕ API-only              │
│  ┌────────────────────────────┐  │
│  │   talosctl CLI             │  │
│  │   (Machine API)            │  │
│  └────────────────────────────┘  │
└──────────────────────────────────┘
```

**Benefits:**
- ✅ Reduced attack surface (no SSH)
- ✅ Atomic updates
- ✅ Consistent configuration
- ✅ Fast reboots (<30s)
- ✅ Minimal maintenance

---

### 3. Phased Bootstrap Pattern

**Bootstrap happens in phases to prevent CRD race conditions.**

```
Phase -1: Talos                   Phase 0: Prerequisites
┌─────────────────────┐           ┌─────────────────────┐
│ - Apply machine     │           │ - Namespaces        │
│   configs           │           │ - Initial secrets   │
│ - Generate kubeconf │──────────▶│ - 1Password token   │
└─────────────────────┘           └─────────────────────┘
                                           │
                                           ↓
Phase 1: CRDs                     Phase 2: Core Infrastructure
┌─────────────────────┐           ┌─────────────────────┐
│ - cert-manager CRDs │           │ - Cilium CNI        │
│ - external-secrets  │           │ - CoreDNS           │
│ - VM operator CRDs  │──────────▶│ - Spegel            │
│ - Gateway API CRDs  │           │ - cert-manager app  │
└─────────────────────┘           │ - external-secrets  │
                                  │ - Flux controllers  │
                                  └─────────────────────┘
                                           │
                                           ↓
                                  Phase 3: GitOps Takeover
                                  ┌─────────────────────┐
                                  │ - Flux bootstrapped │
                                  │ - Flux reconciles   │
                                  │   infrastructure/   │
                                  └─────────────────────┘
```

**Benefits:**
- ✅ CRDs exist before resources
- ✅ Prevents race conditions
- ✅ Reproducible bootstraps
- ✅ Clear separation of concerns

---

### 4. Multi-Cluster Separation Pattern

**Separate clusters for platform services vs application workloads.**

| Concern | Infra Cluster | Apps Cluster |
|---------|---------------|--------------|
| **Purpose** | Platform services | Application workloads |
| **Stability** | High (rarely changes) | Medium (frequent deploys) |
| **Resource Isolation** | Dedicated storage/DB resources | Dedicated app resources |
| **Blast Radius** | Isolated failures | Isolated failures |
| **Scaling** | Vertical (storage, DB) | Horizontal (stateless apps) |

**Cross-Cluster Communication:**
- **Cilium ClusterMesh**: Service discovery and connectivity
- **Shared PostgreSQL**: CNPG cluster in infra, accessed from apps via poolers
- **Centralized Observability**: Victoria Metrics in infra scrapes both clusters

---

## Network Architecture

### Cilium eBPF-Based CNI

```
┌───────────────────────────────────────────────────────┐
│                  Cilium Architecture                  │
│                                                       │
│  ┌─────────────┐      ┌──────────────┐              │
│  │ Gateway API │      │ Network      │              │
│  │ (Ingress)   │──────│ Policies     │              │
│  └─────────────┘      │ (L3/L4/L7)   │              │
│         │             └──────────────┘              │
│         ↓                     │                      │
│  ┌─────────────────────────────┐                    │
│  │   Cilium Agent (eBPF)       │                    │
│  │  - Datapath                 │                    │
│  │  - Service Mesh             │                    │
│  │  - Observability            │                    │
│  └─────────────────────────────┘                    │
│         │                                            │
│         ↓                                            │
│  ┌─────────────────────────────┐                    │
│  │   BGP Control Plane         │                    │
│  │  - Advertise LoadBalancer   │                    │
│  │  - Peer with SRX320         │                    │
│  └─────────────────────────────┘                    │
│         │                                            │
│         ↓                                            │
│  ┌─────────────────────────────┐                    │
│  │   ClusterMesh               │                    │
│  │  - Cross-cluster services   │                    │
│  │  - Global services          │                    │
│  └─────────────────────────────┘                    │
└───────────────────────────────────────────────────────┘
                   │
                   ↓
          Juniper SRX320 Router
           (BGP Peer, Gateway)
```

### Network CIDRs

| Cluster | Pod CIDR | Service CIDR | Load Balancer Pool |
|---------|----------|--------------|---------------------|
| **infra** | 10.244.0.0/16 | 10.245.0.0/16 | 10.25.11.200-249 |
| **apps** | 10.246.0.0/16 | 10.247.0.0/16 | 10.25.11.100-199 |

### BGP Load Balancer Advertising

```
Cilium (BGP Control Plane)
    ↓ Advertises LoadBalancer IPs
Juniper SRX320 (AS 64512)
    ↓ Routes traffic
External Network
```

---

## Storage Architecture

### Rook-Ceph Distributed Storage

```
┌────────────────────────────────────────┐
│         Rook-Ceph Cluster              │
│  ┌──────────────────────────────────┐  │
│  │   Ceph Monitors (3)              │  │
│  │   - Cluster state                │  │
│  │   - PAXOS consensus              │  │
│  └──────────────────────────────────┘  │
│  ┌──────────────────────────────────┐  │
│  │   Ceph OSDs (per node)           │  │
│  │   - Data storage                 │  │
│  │   - Replication (3x)             │  │
│  └──────────────────────────────────┘  │
│  ┌──────────────────────────────────┐  │
│  │   Ceph MDS (CephFS)              │  │
│  │   - Metadata server              │  │
│  └──────────────────────────────────┘  │
└────────────────────────────────────────┘
               │
               ↓  Provisions PVCs
┌────────────────────────────────────────┐
│         StorageClasses                 │
│  - rook-ceph-block (RBD)              │
│  - rook-ceph-filesystem (CephFS)      │
└────────────────────────────────────────┘
               │
               ↓  Consumed by
┌────────────────────────────────────────┐
│      Application Workloads             │
│  - GitLab (CephFS)                    │
│  - Harbor (RBD)                       │
│  - PostgreSQL (RBD)                   │
└────────────────────────────────────────┘
```

### OpenEBS Local Storage

```
┌────────────────────────────────────────┐
│         OpenEBS LocalPV                │
│  - Hostpath (direct node storage)     │
│  - LVM (local volume manager)          │
└────────────────────────────────────────┘
               │
               ↓  Used for
┌────────────────────────────────────────┐
│      High-Performance Workloads        │
│  - Victoria Metrics (fast local SSD)  │
│  - Dragonfly (low-latency cache)      │
└────────────────────────────────────────┘
```

---

## Database Architecture

### CloudNativePG (PostgreSQL)

```
┌────────────────────────────────────────┐
│    CNPG Shared Cluster (Infra)        │
│  ┌──────────────────────────────────┐  │
│  │   Primary Instance               │  │
│  │   - Read/Write                   │  │
│  └──────────────────────────────────┘  │
│  ┌──────────────────────────────────┐  │
│  │   Replica Instance (HA)          │  │
│  │   - Read-only                    │  │
│  └──────────────────────────────────┘  │
│  ┌──────────────────────────────────┐  │
│  │   PgBouncer Poolers              │  │
│  │   - harbor-pooler                │  │
│  │   - keycloak-pooler              │  │
│  │   - gitlab-pooler                │  │
│  └──────────────────────────────────┘  │
└────────────────────────────────────────┘
               │
               ↓  Connected from Apps Cluster
┌────────────────────────────────────────┐
│      Application Workloads (Apps)      │
│  - GitLab                             │
│  - Harbor                             │
│  - Keycloak (Infra)                   │
└────────────────────────────────────────┘
```

**Benefits:**
- ✅ Automated backups (scheduled, on-demand)
- ✅ Point-in-time recovery (PITR)
- ✅ High availability (automated failover)
- ✅ Connection pooling (PgBouncer)
- ✅ Cross-cluster access (ClusterMesh)

---

## Observability Architecture

### Victoria Metrics + Victoria Logs

```
┌───────────────────────────────────────────┐
│       Victoria Metrics Operator           │
│  ┌─────────────────────────────────────┐  │
│  │   VMSingle (Time-series DB)         │  │
│  │   - Metrics storage                 │  │
│  └─────────────────────────────────────┘  │
│  ┌─────────────────────────────────────┐  │
│  │   VMAgent (Scraper)                 │  │
│  │   - Scrapes ServiceMonitors         │  │
│  │   - Scrapes PodMonitors             │  │
│  └─────────────────────────────────────┘  │
│  ┌─────────────────────────────────────┐  │
│  │   VMAlert (Alerting)                │  │
│  │   - PrometheusRule evaluation       │  │
│  └─────────────────────────────────────┘  │
└───────────────────────────────────────────┘
               │
               ↓  Stores metrics
┌───────────────────────────────────────────┐
│       Victoria Logs (Log Storage)         │
│  - Log aggregation                        │
│  - Native VM integration                  │
└───────────────────────────────────────────┘
               ↑  Sends logs
┌───────────────────────────────────────────┐
│       Fluent Bit (Log Collector)          │
│  - Runs on every node                     │
│  - Collects container logs                │
│  - Ships to Victoria Logs                 │
└───────────────────────────────────────────┘
```

---

## Security Architecture

### Secrets Management

```
┌────────────────────────────────────────┐
│        1Password (Secrets Vault)       │
│  - Centralized secrets                 │
│  - Human-managed secrets               │
└────────────────────────────────────────┘
               │
               ↓  1Password Connect
┌────────────────────────────────────────┐
│    External Secrets Operator           │
│  - Syncs secrets to K8s                │
│  - ClusterSecretStore                  │
└────────────────────────────────────────┘
               │
               ↓  Creates
┌────────────────────────────────────────┐
│      Kubernetes Secrets                │
│  - Consumed by applications            │
└────────────────────────────────────────┘
```

### Certificate Management

```
┌────────────────────────────────────────┐
│         cert-manager                   │
│  ┌──────────────────────────────────┐  │
│  │   ClusterIssuers                 │  │
│  │   - letsencrypt-prod             │  │
│  │   - letsencrypt-staging          │  │
│  └──────────────────────────────────┘  │
└────────────────────────────────────────┘
               │
               ↓  ACME DNS-01 Challenge
┌────────────────────────────────────────┐
│         Cloudflare DNS                 │
│  - Automated DNS challenge             │
│  - Wildcard certificate support        │
└────────────────────────────────────────┘
               │
               ↓  Issues
┌────────────────────────────────────────┐
│      TLS Certificates                  │
│  - *.monosense.io                     │
│  - Auto-renewal                        │
└────────────────────────────────────────┘
```

### Encryption at Rest (SOPS)

```
Git Repository (GitHub)
    │
    ├─ *.sops.yaml files (encrypted with Age)
    │
    ↓  Decrypted by Flux
Kubernetes Cluster
    │
    └─ Secrets (decrypted in-memory)
```

---

## CI/CD Architecture

### GitLab CI/CD + GitHub Actions

```
┌────────────────────────────────────────┐
│          GitLab (Apps Cluster)         │
│  ┌──────────────────────────────────┐  │
│  │   GitLab Server                  │  │
│  │   - Source control               │  │
│  │   - CI/CD pipelines              │  │
│  │   - Container registry           │  │
│  └──────────────────────────────────┘  │
│  ┌──────────────────────────────────┐  │
│  │   GitLab Runners (Kubernetes)    │  │
│  │   - Execute CI/CD jobs           │  │
│  │   - DinD (Docker-in-Docker)      │  │
│  └──────────────────────────────────┘  │
└────────────────────────────────────────┘

┌────────────────────────────────────────┐
│       GitHub Actions (External)        │
│  ┌──────────────────────────────────┐  │
│  │   Self-Hosted Runners (K8s)      │  │
│  │   - Actions Runner Controller    │  │
│  │   - Execute GitHub workflows     │  │
│  └──────────────────────────────────┘  │
└────────────────────────────────────────┘
```

---

## Messaging Architecture (Kafka)

```
┌────────────────────────────────────────┐
│    Strimzi Kafka (Apps Cluster)        │
│  ┌──────────────────────────────────┐  │
│  │   Kafka Cluster (3 brokers)     │  │
│  │   - Event streaming              │  │
│  │   - Topic management             │  │
│  └──────────────────────────────────┘  │
│  ┌──────────────────────────────────┐  │
│  │   ZooKeeper (3 nodes)            │  │
│  │   - Cluster coordination         │  │
│  └──────────────────────────────────┘  │
│  ┌──────────────────────────────────┐  │
│  │   Kafka Connect (optional)       │  │
│  │   - Connectors                   │  │
│  └──────────────────────────────────┘  │
└────────────────────────────────────────┘
```

---

## Identity & Access Management

```
┌────────────────────────────────────────┐
│        Keycloak (Infra Cluster)        │
│  ┌──────────────────────────────────┐  │
│  │   Keycloak Server                │  │
│  │   - SSO/SAML/OIDC                │  │
│  │   - User federation              │  │
│  │   - Identity brokering           │  │
│  └──────────────────────────────────┘  │
│  ┌──────────────────────────────────┐  │
│  │   PostgreSQL Backend (CNPG)      │  │
│  │   - User/realm storage           │  │
│  └──────────────────────────────────┘  │
└────────────────────────────────────────┘
               │
               ↓  Provides authentication
┌────────────────────────────────────────┐
│      Applications                      │
│  - GitLab (OIDC)                      │
│  - Harbor (OIDC)                      │
│  - Grafana (OIDC)                     │
└────────────────────────────────────────┘
```

---

## Deployment Architecture

### GitOps Deployment Flow

```
Developer
    │
    ↓  git push
GitHub Repository (Main Branch)
    │
    ↓  Flux watches (interval: 10m)
Flux Source Controller
    │
    ↓  Fetches latest manifests
Flux Kustomize Controller
    │
    ↓  Applies Kustomizations
Kubernetes API Server
    │
    ↓  Reconciles resources
Kubernetes Controllers
    │
    ↓  Creates/updates resources
Running Workloads
```

---

## Disaster Recovery Architecture

### Backup Strategy

```
┌────────────────────────────────────────┐
│      CloudNativePG Backups             │
│  - Scheduled backups (daily)           │
│  - WAL archiving (continuous)          │
│  - PITR (point-in-time recovery)       │
│  - Backup to S3-compatible storage     │
└────────────────────────────────────────┘

┌────────────────────────────────────────┐
│      Rook-Ceph Snapshots               │
│  - Volume snapshots                    │
│  - CephFS snapshots                    │
│  - Off-cluster replication (future)    │
└────────────────────────────────────────┘

┌────────────────────────────────────────┐
│      Git Repository                    │
│  - All configuration in Git            │
│  - Disaster recovery: redeploy from Git│
└────────────────────────────────────────┘
```

---

## Scalability Patterns

### Horizontal Scaling
- **Stateless workloads**: Scale replicas (GitLab Runner, Harbor, etc.)
- **Kafka**: Add brokers
- **Cilium**: Automatic with node addition

### Vertical Scaling
- **Databases**: Increase PostgreSQL resources (CPU, memory)
- **Storage**: Add Ceph OSDs
- **Observability**: Scale Victoria Metrics

### Cluster Scaling
- **Add nodes**: Apply Talos config to new nodes, join cluster
- **Multi-cluster**: Deploy additional clusters, connect via ClusterMesh

---

## High Availability

### Control Plane HA
- **3 control plane nodes per cluster**
- **etcd HA**: 3-member quorum (tolerates 1 failure)
- **Load-balanced API servers**: BGP-advertised VIP

### Application HA
- **Multiple replicas**: Critical services have 2+ replicas
- **Pod Disruption Budgets**: Prevent simultaneous disruption
- **Anti-affinity**: Spread replicas across nodes

### Data HA
- **PostgreSQL**: Primary + replica (automated failover)
- **Ceph**: 3x replication
- **Kafka**: 3 brokers, 3 ZooKeeper nodes

---

## Performance Optimizations

### Network Performance
- **eBPF datapath**: Cilium bypasses iptables
- **Spegel**: Peer-to-peer image distribution (reduces registry load)

### Storage Performance
- **OpenEBS LocalPV**: Fast local NVMe for performance-critical workloads
- **Ceph tuning**: Optimized for SSD/NVMe

### Observability Performance
- **Victoria Metrics**: Efficient metrics storage (10x less than Prometheus)
- **Victoria Logs**: Compressed log storage

---

## Technology Stack Summary

| Layer | Technologies |
|-------|--------------|
| **OS** | Talos Linux (immutable) |
| **Container Runtime** | containerd |
| **Orchestration** | Kubernetes |
| **GitOps** | Flux CD v2, Kustomize, Helm |
| **Networking** | Cilium (eBPF, BGP, Gateway API, ClusterMesh) |
| **Storage** | Rook-Ceph, OpenEBS |
| **Databases** | CloudNativePG (PostgreSQL), Dragonfly (Redis) |
| **Observability** | Victoria Metrics, Victoria Logs, Fluent Bit |
| **Security** | cert-manager, External Secrets, SOPS, Network Policies |
| **Identity** | Keycloak |
| **Messaging** | Strimzi (Kafka) |
| **CI/CD** | GitLab, GitLab Runner, Actions Runner Controller |
| **Registry** | Harbor |

---

## Decision Rationale

### Why Talos Linux?
- **Immutable**: Reduced attack surface, consistent state
- **API-driven**: No SSH/shell = more secure
- **Kubernetes-native**: Purpose-built for K8s

### Why Flux CD?
- **Pull-based**: More secure than push-based (ArgoCD available as supplement)
- **Kubernetes-native**: CRDs, no external dependencies
- **Multi-tenancy**: Easy RBAC per Kustomization

### Why Cilium?
- **eBPF performance**: Faster than iptables-based CNIs
- **Built-in observability**: No need for separate service mesh
- **Gateway API support**: Modern ingress alternative
- **BGP support**: Load balancer IP advertisement
- **ClusterMesh**: Native multi-cluster networking

### Why Rook-Ceph?
- **Cloud-native**: Kubernetes operator, automated
- **Self-healing**: Automatic recovery from failures
- **Scalable**: Add OSDs dynamically

### Why Victoria Metrics?
- **Cost-effective**: 10x less storage than Prometheus
- **Prometheus-compatible**: Drop-in replacement
- **Scalable**: Better performance at scale

### Why CloudNativePG?
- **Kubernetes-native**: True operator pattern
- **Automated backups**: PITR, S3 integration
- **Connection pooling**: Built-in PgBouncer

---

## Future Enhancements

### Planned
- **SPIRE/SPIFFE**: Workload identity and mTLS
- **External storage replication**: Off-site Ceph backups
- **Additional clusters**: Dev/staging/prod separation
- **ArgoCD enhancement**: More visual workflows

### Under Consideration
- **Multi-region**: Geographical distribution
- **Service mesh**: Full Cilium service mesh features
- **Advanced observability**: Distributed tracing (Tempo/Jaeger)

---

## References

- **README**: `README.md`
- **Technology Stack**: `docs/technology-stack.md`
- **Source Tree**: `docs/source-tree-analysis.md`
- **Development Guide**: `docs/development-guide.md`
