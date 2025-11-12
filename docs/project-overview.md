# Project Overview

## Introduction

**k8s-gitops** is a production-ready, multi-cluster Kubernetes infrastructure running on bare-metal hardware with Talos Linux. This repository serves as the single source of truth for declarative infrastructure management using GitOps principles with Flux CD.

---

## Quick Facts

| Attribute | Value |
|-----------|-------|
| **Project Name** | k8s-gitops |
| **Type** | Multi-Cluster Kubernetes GitOps Infrastructure |
| **Architecture** | 2x 3-node Talos clusters (infra + apps) |
| **GitOps Engine** | Flux CD v2 |
| **Operating System** | Talos Linux (immutable, API-only) |
| **Repository** | https://github.com/trosvald/k8s-gitops |
| **License** | Apache 2.0 |
| **Status** | ✅ Production-ready |

---

## Project Purpose

This infrastructure provides a **self-hosted, enterprise-grade platform** for running:

✅ **Platform Services**: Databases, caching, observability, security, identity management
✅ **Application Workloads**: GitLab, Harbor, CI/CD runners, messaging (Kafka)
✅ **Developer Tools**: Self-hosted CI/CD, container registry, source control
✅ **Operational Excellence**: GitOps automation, backup/restore, monitoring, alerting

---

## Architecture at a Glance

### Multi-Cluster Topology

```
┌──────────────────────────┐    ┌──────────────────────────┐
│     INFRA CLUSTER        │    │      APPS CLUSTER        │
│  Platform Services       │◄──►│  Application Workloads   │
│  - Storage (Rook-Ceph)   │    │  - GitLab                │
│  - Databases (PostgreSQL)│    │  - Harbor                │
│  - Observability (VM)    │    │  - Kafka                 │
│  - Security              │    │  - GitLab Runner         │
│  - Identity (Keycloak)   │    │  + Shared Infrastructure │
└──────────────────────────┘    └──────────────────────────┘
         3 nodes                        3 nodes
     10.25.11.11-13                 10.25.11.14-16
```

**Cross-Cluster Networking**: Cilium ClusterMesh enables service discovery and connectivity between clusters.

---

## Key Technologies

| Category | Technologies |
|----------|--------------|
| **OS & Runtime** | Talos Linux, Kubernetes, containerd |
| **GitOps** | Flux CD v2, Kustomize, Helm, Helmfile |
| **Networking** | Cilium (eBPF, BGP, Gateway API, ClusterMesh) |
| **Storage** | Rook-Ceph (distributed), OpenEBS (local) |
| **Databases** | CloudNativePG (PostgreSQL), Dragonfly (Redis) |
| **Observability** | Victoria Metrics, Victoria Logs, Fluent Bit |
| **Security** | cert-manager, External Secrets (1Password), SOPS |
| **Identity** | Keycloak |
| **Messaging** | Strimzi (Kafka) |
| **CI/CD** | GitLab, GitLab Runner, Actions Runner Controller |
| **Registry** | Harbor |

**Total**: 50+ distinct technologies

---

## Repository Structure

```
k8s-gitops/
├── bootstrap/              # Initial cluster bootstrap (Phase 0-2)
│   ├── helmfile.d/         # Phased helmfile configs (CRDs, core)
│   └── clusters/           # Per-cluster values (infra, apps)
├── talos/                  # Talos Linux node configurations
│   ├── infra/              # Infra cluster nodes (10.25.11.11-13)
│   └── apps/               # Apps cluster nodes (10.25.11.14-16)
├── kubernetes/             # ☸️ GitOps source of truth (Flux watches this)
│   ├── clusters/           # Flux entry points (per cluster)
│   ├── infrastructure/     # Shared infrastructure components
│   ├── workloads/          # Application workloads (platform + tenants)
│   ├── bases/              # Reusable operator bases (6 operators)
│   └── components/         # Reusable Kustomize components
├── scripts/                # Utility scripts (validation, helpers)
├── .taskfiles/             # Modular Taskfile includes (8 modules)
├── .github/workflows/      # CI/CD validation pipelines
├── docs/                   # 📚 Project documentation (THIS FOLDER)
├── Taskfile.yaml           # Main task automation orchestrator
└── README.md               # Main project README
```

**Total Files**: ~500+ (excluding node_modules, .backup, .git)

---

## Core Features

### ✅ GitOps-First
- **Declarative infrastructure**: All cluster state defined in Git
- **Automated reconciliation**: Flux syncs Git → Kubernetes every 10 minutes
- **Version control**: Full audit trail, easy rollbacks (Git revert)
- **Pull-based security**: Clusters pull from Git (vs push from CI/CD)

### ✅ Multi-Cluster Isolation
- **Platform vs Apps separation**: Isolated failure domains
- **Resource isolation**: Dedicated resources per cluster
- **Cross-cluster communication**: Cilium ClusterMesh for service discovery

### ✅ Immutable Infrastructure
- **Talos Linux**: No SSH, no shell, API-only management
- **Atomic updates**: Entire OS replaced on update
- **Fast boot**: <30 second reboots
- **Secure by default**: Minimal attack surface

### ✅ Phased Bootstrap
- **Phase 0**: CRDs extracted and installed first (prevents race conditions)
- **Phase 1**: Core infrastructure (Cilium, CoreDNS, Flux, external-secrets)
- **Phase 2**: GitOps takeover (Flux reconciles kubernetes/)
- **Phase 3**: Validation and monitoring

### ✅ Production-Ready Networking
- **Cilium eBPF**: High-performance CNI, bypasses iptables
- **BGP Load Balancing**: Advertise LoadBalancer IPs to Juniper SRX320
- **Gateway API**: Modern ingress alternative
- **ClusterMesh**: Multi-cluster service mesh

### ✅ Enterprise Storage
- **Rook-Ceph**: Distributed storage with 3x replication, self-healing
- **OpenEBS**: Local NVMe storage for performance-critical workloads
- **Automated backups**: Scheduled backups, PITR (point-in-time recovery)

### ✅ Comprehensive Observability
- **Victoria Metrics**: Prometheus-compatible, 10x more efficient storage
- **Victoria Logs**: Log aggregation with native VM integration
- **Fluent Bit**: Lightweight log collection on every node
- **Grafana Dashboards**: Pre-configured dashboards for all components

### ✅ Robust Security
- **cert-manager**: Automated TLS certificate management (Let's Encrypt)
- **External Secrets**: Sync secrets from 1Password to Kubernetes
- **SOPS**: Age-encrypted secrets in Git
- **Network Policies**: Cilium L3/L4/L7 policies
- **Keycloak**: Centralized SSO/SAML/OIDC identity provider

### ✅ Self-Hosted DevOps
- **GitLab**: Source control, CI/CD, container registry
- **Harbor**: Enterprise container registry with vulnerability scanning
- **GitHub Actions**: Self-hosted runners in Kubernetes
- **Kafka**: Event streaming for event-driven architecture

---

## Hardware Infrastructure

### Compute
- **6 nodes total**: 2x ThinkCentre M920x + 4x ThinkStation P330
- **CPU**: Intel i7-8700T per node
- **RAM**: 64GB per node
- **OS Disk**: 500GB SSD per node
- **Data Disks**: 1TB NVMe + 512GB NVMe per node

### Network
- **Juniper SRX320**: Edge router, BGP peer
- **2x TPLINK SX3008F**: 10GbE ToR switches
- **TPLINK SG2210MP**: PoE switch
- **TPLINK SG3428X**: Aggregation switch

### Storage
- **Synology RS1221+**: 8x12TB HDD (96TB raw) for NFS
- **IBM TS-3200**: Tape library (24xLTO-6 + 24xLTO-7) for long-term backups

### Power
- **APC SURT2000RM XL + 2x BP**: UPS power
- **APC AP4421**: ATS/PDU

---

## Deployment Model

### GitOps Workflow

```
Developer
    ↓ git push
GitHub Repository (main branch)
    ↓ Flux watches (10m interval)
Flux Source Controller
    ↓ Fetches manifests
Flux Kustomize Controller
    ↓ Applies changes
Kubernetes API Server
    ↓ Reconciles
Running Workloads
```

### Multi-Environment Strategy

Currently: **Single production environment** (infra + apps clusters)

**Future**: Separate dev/staging/prod clusters

---

## Operational Model

### Maintenance Windows
- **Talos updates**: Rolling updates (one node at a time)
- **Kubernetes updates**: Controlled via Talos updates
- **Application updates**: GitOps-driven (commit to main → auto-deploy)

### Backup Strategy
- **PostgreSQL**: Scheduled backups (daily) + WAL archiving (continuous)
- **Rook-Ceph**: Volume snapshots
- **Git**: All configuration in Git (disaster recovery: redeploy from Git)
- **Long-term**: IBM tape library for archival

### Monitoring & Alerting
- **Metrics**: Victoria Metrics scrapes all components
- **Logs**: Fluent Bit → Victoria Logs
- **Alerts**: PrometheusRule CRDs → VMAlert
- **Dashboards**: Grafana with pre-configured dashboards

---

## Getting Started

### Prerequisites
```bash
# Install required tools
brew install kubectl talosctl flux helmfile helm task yq jq

# Clone repository
git clone https://github.com/trosvald/k8s-gitops.git
cd k8s-gitops
```

### Bootstrap Cluster
```bash
# Bootstrap infra cluster (complete)
task bootstrap:infra

# Bootstrap apps cluster (complete)
task bootstrap:apps

# Check status
task bootstrap:status CLUSTER=infra
```

### Make Changes
```bash
# Edit manifests
vim kubernetes/infrastructure/networking/cilium/core/app/helmrelease.yaml

# Validate
kubectl kustomize kubernetes/infrastructure | kubeconform -strict

# Commit and push
git add .
git commit -m "feat(cilium): update configuration"
git push origin main

# Force reconciliation (or wait 10m for auto-sync)
task kubernetes:reconcile CLUSTER=infra
```

---

## Documentation Index

| Document | Description |
|----------|-------------|
| **[README.md](../README.md)** | Main project README with quick start |
| **[docs/index.md](./index.md)** | Master documentation index (THIS FILE) |
| **[docs/project-overview.md](./project-overview.md)** | Project overview and purpose |
| **[docs/architecture.md](./architecture.md)** | Comprehensive architecture documentation |
| **[docs/technology-stack.md](./technology-stack.md)** | Complete technology inventory |
| **[docs/source-tree-analysis.md](./source-tree-analysis.md)** | Repository structure deep-dive |
| **[docs/development-guide.md](./development-guide.md)** | Development workflow and tasks |
| **[bootstrap/helmfile.d/README.md](../bootstrap/helmfile.d/README.md)** | Bootstrap architecture and process |

---

## Project Status

### ✅ Completed Features
- [x] Multi-cluster Talos Kubernetes (infra + apps)
- [x] Flux CD GitOps automation
- [x] Cilium CNI with BGP, Gateway API, ClusterMesh
- [x] Rook-Ceph distributed storage
- [x] CloudNativePG PostgreSQL with automated backups
- [x] Victoria Metrics + Victoria Logs observability
- [x] cert-manager automated TLS
- [x] External Secrets with 1Password integration
- [x] Keycloak SSO
- [x] GitLab self-hosted
- [x] Harbor container registry
- [x] Kafka messaging platform
- [x] Automated validation pipelines (GitHub Actions)

### 🚧 In Progress
- [ ] SPIRE/SPIFFE workload identity
- [ ] Enhanced ArgoCD integration
- [ ] External storage replication

### 📋 Planned
- [ ] Dev/staging/prod cluster separation
- [ ] Multi-region deployment
- [ ] Advanced service mesh features
- [ ] Distributed tracing (Tempo/Jaeger)

---

## Team & Contributions

**Maintainer**: @trosvald
**Contributors**: Community contributions welcome via PRs

### How to Contribute
1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make changes and validate (`task validate-cilium-core`)
4. Commit changes (`git commit -m 'feat: add amazing feature'`)
5. Push to branch (`git push origin feature/amazing-feature`)
6. Open a Pull Request

---

## Support & Resources

### Documentation
- **GitHub Repository**: https://github.com/trosvald/k8s-gitops
- **Documentation**: `docs/` directory
- **Bootstrap Guide**: `bootstrap/helmfile.d/README.md`

### Community
- **Issues**: [GitHub Issues](https://github.com/trosvald/k8s-gitops/issues)
- **Discussions**: [GitHub Discussions](https://github.com/trosvald/k8s-gitops/discussions)

### Upstream Projects
- **Talos Linux**: https://www.talos.dev/
- **Flux CD**: https://fluxcd.io/
- **Cilium**: https://cilium.io/
- **Rook**: https://rook.io/

---

## License

This project is licensed under the **Apache License 2.0** - see the [LICENSE](../LICENSE) file for details.

---

## Acknowledgments

This project draws inspiration from:
- **[buroa/k8s-gitops](https://github.com/buroa/k8s-gitops)** - Phased bootstrap pattern
- **[onedr0p/cluster-template](https://github.com/onedr0p/cluster-template)** - Flux structure patterns
- **Talos Linux community** - Immutable infrastructure best practices

---

**Last Updated**: 2025-11-12
**Project Version**: v2.0 (Multi-Cluster Architecture)
