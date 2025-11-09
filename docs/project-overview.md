# Project Overview - k8s-gitops

> **Generated:** 2025-11-09
> **Repository:** Multi-Cluster Kubernetes GitOps Infrastructure
> **Owner:** monosense

## Executive Summary

This repository implements a **production-grade, multi-cluster Kubernetes platform** running on bare-metal infrastructure using Talos Linux and Flux CD GitOps. The architecture consists of two separate 3-node clusters (infra and apps) managing platform services and application workloads respectively, with sophisticated GitOps automation, compliance validation, and operational tooling.

The platform serves as a complete home operations infrastructure featuring high-availability databases (PostgreSQL, Redis), message brokers (Kafka), identity management (Keycloak), CI/CD systems (GitHub Actions, GitLab), container registry (Harbor), and comprehensive observability (Victoria Metrics, Victoria Logs). Infrastructure is entirely declarative, version-controlled, and automatically validated through multi-stage CI/CD pipelines.

## Project Purpose

Build and maintain a **self-hosted, enterprise-grade Kubernetes platform** for:
- Platform services (databases, messaging, identity, observability)
- Development tooling (GitLab, Harbor, CI/CD runners)
- Tenant applications with multi-tenancy and network isolation
- Learning and experimenting with cloud-native technologies

Key principles:
- **GitOps-first:** All infrastructure changes go through Git
- **Immutable infrastructure:** Talos Linux provides declarative, API-driven nodes
- **Multi-cluster:** Separation of platform concerns (infra vs apps workloads)
- **Automated validation:** Every commit validated before deployment
- **Compliance-aware:** Automated backup policy validation (GDPR, HIPAA, PCI-DSS, SOX)

## Technology Stack Summary

| Category | Technologies | Version/Notes |
|----------|-------------|---------------|
| **Operating System** | Talos Linux | Immutable, API-driven Kubernetes OS |
| **Container Orchestration** | Kubernetes | Multi-cluster (2x 3-node control planes) |
| **GitOps** | Flux CD | Automated reconciliation from Git |
| **CNI & Networking** | Cilium | eBPF-based, with BGP, Gateway API, ClusterMesh |
| **DNS** | CoreDNS, ExternalDNS | v1.45.0, Cloudflare integration |
| **Ingress** | Cloudflared | Cloudflare tunnels for secure access |
| **Storage** | Rook-Ceph, OpenEBS | Distributed block storage (v1.18.6), local PV (v4.3.3) |
| **Databases** | CloudNativePG, DragonflyDB | PostgreSQL operator (v0.26.1), Redis alternative (v1.3.0) |
| **Messaging** | Strimzi Kafka | Kafka operator (v0.48.0) |
| **Identity** | Keycloak | SSO and identity management |
| **Observability** | Victoria Metrics, Victoria Logs | Time-series metrics, centralized logging (v0.11.12) |
| **Log Collection** | Fluent-bit | Operator-based log aggregation |
| **Security** | cert-manager, external-secrets | TLS automation, 1Password integration (v0.20.4) |
| **CI/CD** | GitHub Actions, GitLab, Actions Runner Controller | Self-hosted runners, GitLab CE |
| **Registry** | Harbor | OCI artifact storage |
| **Automation** | Task (Taskfile) | Cluster lifecycle automation |
| **Validation** | kubeconform, Flux, yamllint, Trivy, Gitleaks | Multi-layer manifest validation |
| **Compliance** | Open Policy Agent (OPA) | Automated backup policy validation |
| **Network Security** | Cilium NetworkPolicies | Baseline deny-all + explicit allow rules |

## Architecture Type Classification

**Primary Architecture:** Multi-Cluster GitOps Infrastructure

**Patterns:**
- **GitOps Layering:** Operators (bases/) → Infrastructure (shared) → Workloads (instances)
- **Multi-cluster via variable substitution:** Single infrastructure definition + ConfigMap-based injection
- **Operator pattern:** CRD separation from operator deployment
- **Three-phase bootstrap:** CRDs → Core infrastructure → Full stack deployment
- **Defense-in-depth validation:** Syntax → Schema → Security → Compliance
- **Network security:** Baseline deny-all NetworkPolicies with explicit allow rules
- **Health check dependencies:** Explicit `dependsOn` with resource health validation

## Repository Structure

```
k8s-gitops/
├── kubernetes/         # All Kubernetes manifests (Flux-managed)
│   ├── clusters/       # Per-cluster entry points (infra, apps)
│   ├── infrastructure/ # Shared infrastructure layer (both clusters)
│   ├── workloads/      # Application instances
│   ├── bases/          # Reusable operator definitions
│   └── components/     # Reusable Kustomize components
├── talos/              # Talos OS node configurations (6 nodes)
├── bootstrap/          # Initial cluster provisioning
├── .taskfiles/         # Task automation modules (8 modules)
├── scripts/            # Validation & utility scripts
├── .github/workflows/  # CI/CD automation (4 workflows)
├── bmad/               # BMad Method documentation system
└── docs/               # Project documentation
```

**Repository Type:** Monolithic Infrastructure-as-Code

## Multi-Cluster Architecture

### Infra Cluster (10.25.11.11-13)
**Purpose:** Platform services and shared infrastructure

**Components:**
- Storage: Rook-Ceph distributed storage, OpenEBS local PV
- Databases: CloudNativePG operator, Dragonfly operator
- Observability: Victoria Metrics, Victoria Logs, Fluent-bit
- Security: cert-manager, external-secrets, NetworkPolicies
- Networking: Cilium, CoreDNS, ExternalDNS, Cloudflared, Spegel
- GitOps: Flux CD, OCI repositories

### Apps Cluster (10.25.11.14-16)
**Purpose:** Application workloads and tenant services

**Components:**
- Platform databases: PostgreSQL clusters, Redis clusters
- Platform messaging: Kafka clusters (Strimzi)
- Platform identity: Keycloak SSO
- Platform CI/CD: GitHub Actions Runner Controller
- Platform registry: Harbor
- Tenants: GitLab, GitLab Runner

### Cluster Differentiation
Both clusters share the same infrastructure layer but use different:
- IP addressing (Pod CIDR, Service CIDR)
- BGP autonomous system numbers (ASN)
- Observability tenant identifiers
- Feature flags (IPAM pools, workload placement)

Configuration differentiation achieved through `postBuild.substituteFrom` reading cluster-specific ConfigMaps.

## Hardware Infrastructure

### Production Cluster Nodes (6 nodes total)
| Device | Count | OS Disk | Data Disk | RAM | OS | Purpose |
|--------|-------|---------|-----------|-----|-----|---------|
| ThinkCentre M920x, i7-8700t | 2 | 500GB SSD | 1TB NVME + 512GB NVME | 64GB | Talos | Kubernetes |
| ThinkStation P330, i7-8700t | 4 | 500GB SSD | 1TB NVME + 512GB NVME | 64GB | Talos | Kubernetes |

### Shared Infrastructure
| Device | Count | Purpose |
|--------|-------|---------|
| ThinkCentre M910q | 1 | Infra Services (Fedora IoT) |
| Synology RS1221+ NAS | 1 | NFS (8x12TB HDD, 32GB RAM) |
| IBM Tape Library TS-3200 | 1 | Long-term archive (24xLTO-6 + 24xLTO-7) |
| TESmart 8-Port KVM | 1 | Network KVM |
| Juniper SRX320 | 1 | Router (JUNOS) |
| TPLINK SX3008F | 2 | 10Gb ToR Switch |
| TPLINK SG2210MP | 1 | PoE Switch |
| TPLINK SG3428X | 1 | Aggregation Switch |
| APC AP4421 | 1 | ATS/PDU |
| APC SURT2000RM XL + 2x BP | 1 | UPS |

## Key Features

✅ **GitOps Automation:** Flux CD reconciles infrastructure from Git every 5 minutes
✅ **Multi-Cluster:** Separate platform and application concerns across 2 clusters
✅ **Immutable OS:** Talos Linux provides declarative, API-driven node management
✅ **High Availability:** Multi-master control planes, distributed storage
✅ **Service Mesh:** Cilium ClusterMesh for cross-cluster service discovery
✅ **Automated DNS:** ExternalDNS syncs DNS records to Cloudflare
✅ **Automated TLS:** cert-manager provisions Let's Encrypt certificates
✅ **Secret Management:** External-secrets integrates with 1Password vault
✅ **Observability:** Victoria Metrics/Logs with Grafana dashboards
✅ **CI/CD Validation:** Multi-stage pipelines (syntax, schema, security, compliance)
✅ **Compliance Automation:** OPA-based backup policy validation (GDPR, HIPAA, PCI-DSS, SOX)
✅ **Network Security:** Baseline deny-all NetworkPolicies with explicit allow rules
✅ **Registry Mirror:** Spegel provides cluster-local OCI mirror
✅ **Operator Pattern:** 5+ operators managing databases, messaging, logging, storage

## Documentation Navigation

- **[Source Tree Analysis](./source-tree-analysis.md)** - Annotated directory structure
- **[Development Guide](./development-guide.md)** - Local development setup _(To be generated)_
- **[Deployment Guide](./deployment-guide.md)** - Cluster deployment procedures _(To be generated)_
- **[Infrastructure Components](./infrastructure-components.md)** - Component inventory _(To be generated)_
- **[README.md](../README.md)** - Original project overview

## Getting Started

### For Developers
1. Review [Source Tree Analysis](./source-tree-analysis.md) to understand repository structure
2. Check [Development Guide](./development-guide.md) for local environment setup _(To be generated)_
3. Explore existing component READMEs in `kubernetes/` directories

### For Operators
1. Review [Deployment Guide](./deployment-guide.md) for cluster lifecycle operations _(To be generated)_
2. Familiarize with Task automation: `task --list`
3. Understand three-phase bootstrap strategy: `bootstrap/helmfile.d/README.md`

### For Contributors
1. Understand GitOps workflow: All changes via Git PRs
2. Review CI/CD pipelines: `.github/workflows/validate-infrastructure.yaml`
3. Test locally: `task validate-cilium-core` before pushing

## Project Metrics

- **Kubernetes Manifests:** 298+ YAML files
- **Infrastructure Components:** 30+ (networking, storage, databases, observability, security)
- **Operators Deployed:** 5 (CloudNativePG, Dragonfly, Strimzi Kafka, Rook-Ceph, Fluent-bit)
- **GitHub Actions Workflows:** 4 (infrastructure validation, compliance validation, Cilium validation, project automation)
- **Task Modules:** 8 (cluster, bootstrap, kubernetes, talos, volsync, workstation, onepassword, synergyflow)
- **Validation Scripts:** 6 specialized validators
- **Existing Documentation:** 15+ READMEs (component-specific)

## External Links

- **Status Page:** https://status.monosense.io
- **Cluster Template Inspiration:** [onedr0p/cluster-template](https://github.com/onedr0p/cluster-template)
