# Technology Stack

## Overview

This document provides a comprehensive inventory of all technologies, tools, and frameworks used in the k8s-gitops multi-cluster infrastructure project.

---

## Core Infrastructure

### Operating System
| Technology | Version | Purpose | Justification |
|------------|---------|---------|---------------|
| **Talos Linux** | Latest | Immutable Kubernetes OS | Purpose-built for Kubernetes, API-driven, secure by default, ephemeral design |

### Container Orchestration
| Technology | Version | Purpose | Justification |
|------------|---------|---------|---------------|
| **Kubernetes** | v1.x | Container orchestration | Industry standard, rich ecosystem, GitOps-friendly |

### Multi-Cluster Architecture
| Cluster | Nodes | IP Range | Pod CIDR | Service CIDR | Purpose |
|---------|-------|----------|----------|--------------|---------|
| **infra** | 3x control plane (10.25.11.11-13) | 10.25.11.0/24 | 10.244.0.0/16 | 10.245.0.0/16 | Platform services (storage, databases, observability, security) |
| **apps** | 3x control plane (10.25.11.14-16) | 10.25.11.0/24 | 10.246.0.0/16 | 10.247.0.0/16 | Application workloads (GitLab, Harbor) |

---

## GitOps & Deployment

| Technology | Version | Purpose | Justification |
|------------|---------|---------|---------------|
| **Flux CD v2** | Latest | GitOps continuous delivery | Kubernetes-native, pull-based, multi-tenant, supports Kustomize & Helm |
| **Kustomize** | Built-in to kubectl | Kubernetes configuration management | Template-free, overlay-based customization |
| **Helm** | v3.x | Kubernetes package manager | Industry standard for chart distribution |
| **Helmfile** | Latest | Declarative Helm releases | Environment-based values, dependency management |
| **ArgoCD** | Latest | Supplementary GitOps UI | Visual workflow management, application visualization |

---

## Automation & Task Management

| Technology | Version | Purpose | Justification |
|------------|---------|---------|---------------|
| **Task (Taskfile)** | v3 | Task automation | Modern make alternative, cross-platform, YAML-based |
| **minijinja-cli** | Latest | Template rendering | Jinja2 templates for Talos configs |

---

## Networking

### CNI & Service Mesh
| Technology | Version | Purpose | Justification |
|------------|---------|---------|---------------|
| **Cilium** | v1.18.3 | eBPF-based CNI | High performance, built-in observability, Gateway API support, BGP, ClusterMesh |
| **Cilium BGP Control Plane** | Included | BGP routing | Load balancer IP advertisement to external infrastructure |
| **Cilium Gateway API** | v1.4.0 | Kubernetes Gateway API | Modern ingress/L7 routing, standardized API |
| **Cilium ClusterMesh** | Included | Multi-cluster networking | Service discovery and connectivity across clusters |

### DNS & Service Discovery
| Technology | Version | Purpose | Justification |
|------------|---------|---------|---------------|
| **CoreDNS** | Latest | Cluster DNS | Kubernetes default, plugin-based, customizable |
| **external-dns** | Latest | Automated DNS record management | Sync K8s resources to external DNS (Cloudflare, RFC2136) |
| **Cloudflared** | Latest | Cloudflare Tunnel | Secure external access without exposing ports |

### Registry & Distribution
| Technology | Version | Purpose | Justification |
|------------|---------|---------|---------------|
| **Spegel** | Latest | Stateless OCI registry mirror | Peer-to-peer image distribution, reduces external bandwidth |

---

## Storage

| Technology | Version | Purpose | Justification |
|------------|---------|---------|---------------|
| **Rook-Ceph** | Latest | Distributed block storage | Cloud-native Ceph operator, highly available, self-healing |
| **OpenEBS** | Latest | Local persistent volumes | Dynamic local storage provisioning |

---

## Databases

### PostgreSQL
| Technology | Version | Purpose | Justification |
|------------|---------|---------|---------------|
| **CloudNativePG (CNPG)** | Latest | PostgreSQL operator | Kubernetes-native, automated backups, HA, pooling |
| **PgBouncer Poolers** | Included in CNPG | Connection pooling | Efficient connection management for Harbor, Keycloak, GitLab |

### Redis/Dragonfly
| Technology | Version | Purpose | Justification |
|------------|---------|---------|---------------|
| **Dragonfly** | Latest | Redis-compatible in-memory datastore | High performance, modern architecture, drop-in Redis replacement |
| **Dragonfly Operator** | Latest | Kubernetes operator for Dragonfly | Automated deployment and management |

---

## Messaging & Streaming

| Technology | Version | Purpose | Justification |
|------------|---------|---------|---------------|
| **Apache Kafka** | v4.1.0 | Event streaming platform | Industry standard for event-driven architecture |
| **Strimzi Operator** | Latest | Kafka operator | Kubernetes-native Kafka deployment and management |

---

## Observability

### Metrics
| Technology | Version | Purpose | Justification |
|------------|---------|---------|---------------|
| **Victoria Metrics** | v0.6.0 | Time-series database | Prometheus-compatible, efficient storage, cost-effective |
| **Victoria Metrics Operator** | v0.37.4 | VM operator | CRD-based Victoria Metrics management |

### Logging
| Technology | Version | Purpose | Justification |
|------------|---------|---------|---------------|
| **Victoria Logs** | Latest | Log aggregation | Native integration with Victoria Metrics, efficient storage |
| **Fluent Bit** | Latest | Log collection | Lightweight, Kubernetes-native, multi-destination |
| **Fluent Bit Operator** | Latest | Fluent Bit operator | CRD-based log pipeline configuration |

### Monitoring
| Technology | Version | Purpose | Justification |
|------------|---------|---------|---------------|
| **Grafana Dashboards** | Latest | Visualization | Industry standard dashboarding, integrates with VM |
| **PrometheusRule CRDs** | From VM Operator | Alert rules | Compatible with Prometheus alert syntax |

---

## Security

### Secrets Management
| Technology | Version | Purpose | Justification |
|------------|---------|---------|---------------|
| **External Secrets Operator** | v0.12.1 | External secrets sync | Sync from 1Password to Kubernetes secrets |
| **1Password Connect** | Latest | Secrets backend | Centralized secrets management |
| **SOPS** | Latest | File-level encryption | Age-encrypted YAML files, Git-friendly |

### Certificate Management
| Technology | Version | Purpose | Justification |
|------------|---------|---------|---------------|
| **cert-manager** | v1.16.2 | TLS certificate automation | ACME, Let's Encrypt, wildcard certificate automation |
| **ClusterIssuers** | From cert-manager | Certificate issuers | Cloudflare DNS-01 challenge for wildcard certificates |

### Network Security
| Technology | Version | Purpose | Justification |
|------------|---------|---------|---------------|
| **Cilium Network Policies** | Included | L3/L4/L7 network policies | eBPF-based, identity-aware segmentation |

---

## Identity & Access Management

| Technology | Version | Purpose | Justification |
|------------|---------|---------|---------------|
| **Keycloak** | Latest | Identity provider (SSO/SAML/OIDC) | Open-source IAM, enterprise-grade, customizable |
| **Keycloak Operator** | Latest | Kubernetes operator | Automated Keycloak deployment and realm management |

---

## CI/CD & DevOps Tools

### Continuous Integration
| Technology | Version | Purpose | Justification |
|------------|---------|---------|---------------|
| **GitLab** | Latest | Source control, CI/CD pipelines | Self-hosted, integrated CI/CD, container registry |
| **GitLab Runner** | Latest | CI/CD job executor | Kubernetes-native execution |
| **GitHub Actions** | N/A | External CI/CD | GitHub-hosted runners |
| **Actions Runner Controller (ARC)** | Latest | Self-hosted GitHub runners | Run GitHub Actions in Kubernetes |

### Container Registry
| Technology | Version | Purpose | Justification |
|------------|---------|---------|---------------|
| **Harbor** | Latest | Container registry | Enterprise features, vulnerability scanning, replication |

---

## Operations

| Technology | Version | Purpose | Justification |
|------------|---------|---------|---------------|
| **Reloader** | Latest | Auto-restart on config changes | Automatic pod restarts when ConfigMaps/Secrets change |
| **Renovate** | Latest (GitHub App) | Dependency automation | Automated dependency updates via PRs |

---

## Development Tools

### Local Development
| Technology | Version | Purpose | Justification |
|------------|---------|---------|---------------|
| **talosctl** | Latest | Talos CLI | Machine configuration and management |
| **kubectl** | Latest | Kubernetes CLI | Cluster interaction |
| **flux** | Latest | Flux CLI | GitOps management |
| **helmfile** | Latest | Helmfile CLI | Declarative Helm release management |
| **yq** | Latest | YAML processor | YAML parsing and transformation |
| **jq** | Latest | JSON processor | JSON parsing and transformation |
| **op** (1Password CLI) | Latest | 1Password CLI | Secret injection |

### Validation Tools
| Technology | Version | Purpose | Justification |
|------------|---------|---------|---------------|
| **kubeconform** | Latest | Kubernetes manifest validation | Schema validation |
| **kustomize** | Built-in | Kustomization building | Manifest generation |

---

## Version Control & Collaboration

| Technology | Version | Purpose | Justification |
|------------|---------|---------|---------------|
| **Git** | Latest | Version control | Industry standard |
| **GitHub** | N/A | Remote repository | Flux source, Renovate integration |

---

## Hardware Infrastructure

### Compute Nodes
| Device | Quantity | CPU | RAM | OS Disk | Data Disks | Purpose |
|--------|----------|-----|-----|---------|------------|---------|
| ThinkCentre M920x | 2 | i7-8700T | 64GB | 500GB SSD | 1TB NVMe + 512GB NVMe | Kubernetes nodes |
| ThinkStation P330 | 4 | i7-8700T | 64GB | 500GB SSD | 1TB NVMe + 512GB NVMe | Kubernetes nodes |

### Network Infrastructure
| Device | Quantity | Purpose |
|--------|----------|---------|
| Juniper SRX320 | 1 | Edge router (BGP peer) |
| TPLINK SX3008F | 2 | 10GbE ToR switches |
| TPLINK SG2210MP | 1 | PoE switch |
| TPLINK SG3428X | 1 | Aggregation switch |

### Storage Infrastructure
| Device | Quantity | Capacity | Purpose |
|--------|----------|----------|---------|
| Synology RS1221+ | 1 | 8x12TB HDD (96TB raw) | NFS storage backend |
| IBM TS-3200 Tape Library | 1 | 24xLTO-6 + 24xLTO-7 | Long-term backup |

### Power & Management
| Device | Quantity | Purpose |
|--------|----------|---------|
| APC SURT2000RM XL + 2x BP | 1 | UPS power |
| APC AP4421 | 1 | ATS/PDU |
| TESmart 8-Port KVM | 1 | Console access |

---

## Architecture Patterns

### Design Patterns
- **GitOps**: All configuration in Git, declarative state
- **Multi-Cluster**: Separate infra and apps clusters for isolation
- **Phased Bootstrap**: CRDs → Core → Infrastructure → Workloads
- **Immutable Infrastructure**: Talos Linux ephemeral nodes
- **Infrastructure as Code**: Everything defined as code
- **Declarative Configuration**: Kustomize overlays, Helm values
- **Operator Pattern**: Kubernetes operators for complex stateful apps

### Network Architecture
- **BGP Control Plane**: Cilium BGP for load balancer IPs
- **Service Mesh**: Cilium mesh networking
- **Multi-Cluster Networking**: Cilium ClusterMesh for cross-cluster communication
- **Zero-Trust**: Network policies, mTLS in progress

---

## Entry Points

### Bootstrap Entry Points
| File/Directory | Purpose |
|----------------|---------|
| `Taskfile.yaml` | Main automation orchestrator |
| `bootstrap/helmfile.yaml` | Bootstrap orchestration |
| `bootstrap/helmfile.d/00-crds.yaml` | CRD extraction phase |
| `bootstrap/helmfile.d/01-core.yaml` | Core infrastructure phase |
| `talos/machineconfig-multicluster.yaml.j2` | Talos configuration template |

### Flux Entry Points (per cluster)
| Cluster | Entry Point | Purpose |
|---------|-------------|---------|
| **infra** | `kubernetes/clusters/infra/infrastructure.yaml` | Flux Kustomization for infrastructure layer |
| **apps** | `kubernetes/clusters/apps/infrastructure.yaml` | Flux Kustomization for infrastructure layer |
| **apps** | `kubernetes/clusters/apps/messaging-kafka.yaml` | Flux Kustomization for Kafka |

### Application Entry Points
- `kubernetes/infrastructure/` - Shared infrastructure components
- `kubernetes/workloads/platform/` - Platform services
- `kubernetes/workloads/tenants/` - Tenant applications
- `kubernetes/bases/` - Reusable operator bases
- `kubernetes/components/` - Reusable Kustomize components

---

## Configuration Management

### Templating & Variable Substitution
| Method | Tool | Purpose |
|--------|------|---------|
| Jinja2 | minijinja-cli | Talos machine configs |
| Helm | Helm/Helmfile | Chart value templating |
| Kustomize | kubectl/Kustomize | Overlay-based config |
| Flux postBuild | Flux | Runtime variable substitution via ConfigMaps |

### Environment-Specific Values
- **Bootstrap**: `bootstrap/clusters/{infra,apps}/values.yaml`
- **Cilium**: `bootstrap/clusters/{infra,apps}/cilium-values.yaml`
- **Flux substitution**: `kubernetes/clusters/{infra,apps}/cluster-settings.yaml`

---

## Summary

This infrastructure leverages modern cloud-native technologies with a strong focus on:

✅ **Automation**: Task-based workflows, GitOps, automated updates
✅ **Observability**: Comprehensive metrics, logs, and alerting
✅ **Security**: Secrets management, certificate automation, network policies
✅ **Resilience**: Multi-cluster, distributed storage, high availability
✅ **Cost Efficiency**: Self-hosted, open-source stack on bare-metal
✅ **Developer Experience**: Declarative configs, clear separation of concerns

**Total Technologies**: 50+ distinct technologies and tools
**Architecture Style**: Cloud-native, Kubernetes-centric, GitOps-driven, Multi-cluster
**Maturity Level**: Production-ready with enterprise features
