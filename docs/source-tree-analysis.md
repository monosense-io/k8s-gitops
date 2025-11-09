# Source Tree Analysis - k8s-gitops

> **Generated:** 2025-11-09
> **Project Type:** Multi-Cluster Kubernetes GitOps Infrastructure
> **Architecture:** Flux CD GitOps on Talos Linux

## Repository Structure Overview

```
k8s-gitops/                           # Root: Multi-cluster Kubernetes GitOps repository
├── kubernetes/                        # 🎯 CORE: All Kubernetes manifests (Flux-managed)
│   ├── clusters/                     # 🔧 Per-cluster entry points (2 clusters)
│   │   ├── infra/                   # Infra cluster (10.25.11.11-13)
│   │   │   ├── cluster-settings.yaml     # 📝 200+ cluster-specific variables
│   │   │   ├── infrastructure.yaml       # Kustomization → shared infra layer
│   │   │   └── flux-system/              # Flux bootstrap manifests
│   │   └── apps/                    # Apps cluster (10.25.11.14-16)
│   │       ├── cluster-settings.yaml     # Different IPs, BGP ASN, observability tenant
│   │       ├── infrastructure.yaml       # Same infra, different substitutions
│   │       └── messaging-kafka.yaml      # Apps-specific workload (Story 38)
│   │
│   ├── infrastructure/               # 🏗️ Shared infrastructure layer (both clusters)
│   │   ├── databases/               # Database operators
│   │   │   ├── cloudnative-pg/      # CloudNativePG operator (v0.26.1)
│   │   │   └── dragonfly-operator/  # Dragonfly operator (v1.3.0)
│   │   ├── messaging/               # Message brokers
│   │   │   └── strimzi-operator/    # Kafka operator (v0.48.0)
│   │   ├── networking/              # CNI & networking
│   │   │   ├── cilium/              # Cilium CNI (eBPF, BGP, ClusterMesh, Gateway API)
│   │   │   ├── coredns/             # DNS (v1.45.0)
│   │   │   ├── external-dns/        # Cloudflare DNS automation
│   │   │   ├── cloudflared/         # Cloudflare tunnel
│   │   │   └── spegel/              # OCI registry mirror (v0.4.0)
│   │   ├── observability/           # Monitoring & logging
│   │   │   ├── victoria-metrics/    # Time-series metrics (vmcluster + vmagent)
│   │   │   ├── victoria-logs/       # Centralized logging (v0.11.12)
│   │   │   ├── fluent-bit-operator/ # Log collection operator
│   │   │   └── dashboards/          # Grafana dashboards
│   │   ├── operations/              # Operational tools
│   │   │   └── reloader/            # ConfigMap/Secret reloader
│   │   ├── security/                # Security infrastructure
│   │   │   ├── cert-manager/        # TLS certificate automation
│   │   │   ├── external-secrets/    # 1Password integration (v0.20.4)
│   │   │   └── networkpolicy/       # Baseline network policies
│   │   ├── storage/                 # Persistent storage
│   │   │   ├── rook-ceph/           # Ceph distributed storage (v1.18.6)
│   │   │   └── openebs/             # Local PV provisioner (v4.3.3)
│   │   ├── gitops/                  # GitOps tools
│   │   │   ├── argocd/              # ArgoCD (optional)
│   │   │   └── oci-repositories/    # OCI chart sources
│   │   └── kustomization.yaml       # Root infrastructure composition
│   │
│   ├── workloads/                   # 🚀 Application instances
│   │   ├── platform/                # Platform services
│   │   │   ├── databases/          # Database instances
│   │   │   │   ├── cloudnative-pg/ # Shared PostgreSQL cluster
│   │   │   │   └── dragonfly/      # Shared Redis cluster
│   │   │   ├── identity/           # Identity & access
│   │   │   │   └── keycloak/       # Keycloak SSO
│   │   │   ├── messaging/          # Message broker instances
│   │   │   │   └── kafka/          # Kafka cluster (apps cluster, Story 38)
│   │   │   ├── cicd/               # CI/CD infrastructure
│   │   │   │   └── actions-runner-system/  # GitHub Actions runners
│   │   │   └── registry/           # Container registry
│   │   │       └── harbor/         # Harbor OCI registry
│   │   └── tenants/                # Tenant applications
│   │       ├── gitlab/             # GitLab CE
│   │       └── gitlab-runner/      # GitLab Runner
│   │
│   ├── bases/                       # 📦 Reusable operator definitions
│   │   ├── cnpg-operator/          # CloudNativePG base (shared config)
│   │   ├── dragonfly-operator/     # Dragonfly base
│   │   ├── fluent-bit-operator/    # Fluent-bit base
│   │   ├── keycloak-operator/      # Keycloak base
│   │   ├── rook-ceph-operator/     # Rook-Ceph base
│   │   └── strimzi-operator/       # Strimzi Kafka base
│   │
│   └── components/                  # 🧩 Reusable Kustomize components
│       ├── dragonfly/              # Dragonfly instance templates
│       └── networkpolicy/          # Network policy templates
│           ├── allow-dns/          # DNS egress policy
│           ├── deny-all/           # Default deny policy
│           ├── allow-fqdn/         # FQDN-based egress
│           ├── allow-kube-api/     # API server access
│           └── allow-internal/     # Cluster-internal communication
│
├── talos/                           # 🖥️ Talos OS cluster configuration
│   ├── infra/                      # Infra cluster node configs
│   │   ├── 10.25.11.11.yaml       # Node 1 (control plane + worker)
│   │   ├── 10.25.11.12.yaml       # Node 2 (control plane + worker)
│   │   └── 10.25.11.13.yaml       # Node 3 (control plane + worker)
│   ├── apps/                       # Apps cluster node configs
│   │   ├── 10.25.11.14.yaml       # Node 1 (control plane + worker)
│   │   ├── 10.25.11.15.yaml       # Node 2 (control plane + worker)
│   │   └── 10.25.11.16.yaml       # Node 3 (control plane + worker)
│   ├── machineconfig-multicluster.yaml.j2  # Jinja2 template for machine configs
│   └── schematic.yaml              # Talos image schematic
│
├── bootstrap/                       # ⚡ Initial cluster bootstrap
│   ├── prerequisites/              # Pre-bootstrap setup
│   ├── clusters/                   # Per-cluster bootstrap configs
│   └── helmfile.d/                 # Helmfile-based bootstrap
│       └── README.md               # Three-phase bootstrap strategy
│
├── .taskfiles/                      # 🛠️ Task automation modules
│   ├── bootstrap/                  # Bootstrap automation
│   ├── cluster/                    # Cluster lifecycle (create/destroy)
│   ├── kubernetes/                 # Kubernetes operations
│   ├── talos/                      # Talos node management
│   ├── volsync/                    # Backup/restore automation
│   ├── workstation/                # Local dev environment
│   ├── onepassword/                # Secret management
│   └── synergyflow/                # Workflow orchestration
│
├── scripts/                         # 🔍 Validation & utility scripts
│   ├── validate-cilium-core.sh     # Cilium manifest validation
│   ├── validate-crd-waitset.sh     # CRD establishment checker
│   ├── validate-story-sequences.sh # Story dependency validation
│   ├── fix-story-sequences.sh      # Story sequence fixer
│   ├── resequence-stories.sh       # Story resequencing automation
│   └── generate-clustermesh-1password-item.sh  # ClusterMesh secret gen
│
├── .github/workflows/               # 🤖 CI/CD automation
│   ├── validate-infrastructure.yaml         # Multi-stage validation pipeline
│   ├── backup-compliance-validation.yaml    # GDPR/HIPAA/PCI-DSS/SOX validation
│   ├── validate-cilium-core.yml            # Cilium-specific validation
│   └── auto-add-to-project.yml             # GitHub project automation
│
├── bmad/                            # 📋 BMad Method documentation system
│   ├── core/                       # Core workflow engine
│   ├── bmm/                        # BMad Method workflows
│   └── docs/                       # Methodology documentation
│
├── docs/                            # 📚 Project documentation
│   ├── project-scan-report.json    # Workflow state (this scan)
│   └── stories/                    # User stories (GitOps workflow)
│
├── Taskfile.yaml                    # Task orchestration master file
├── README.md                        # Project overview & hardware specs
├── .sops.yaml                       # SOPS encryption configuration
├── .mise.toml                       # Environment management
└── .gitignore                       # Git ignore rules

```

## Critical Directory Explanations

### Kubernetes Structure

#### `kubernetes/clusters/`
**Purpose:** Per-cluster entry points for Flux CD
**Pattern:** Each cluster (infra, apps) has:
- `cluster-settings.yaml` - ConfigMap with 200+ variables (IPs, CIDRs, versions, feature flags)
- `infrastructure.yaml` - Kustomization referencing shared `/infrastructure` layer
- Cluster-specific workloads (e.g., `messaging-kafka.yaml` only in apps cluster)

**Multi-cluster differentiation:** Same infrastructure layer deployed to both clusters with different variable substitutions via `postBuild.substituteFrom`.

#### `kubernetes/infrastructure/`
**Purpose:** Shared infrastructure layer applied to both clusters
**Architecture:** Domain-driven organization (databases, messaging, networking, observability, operations, security, storage, gitops)
**Deployment:** Each domain has hierarchical Kustomizations with operator deployment + instance configuration

#### `kubernetes/bases/`
**Purpose:** Version-pinned operator definitions without cluster-specific logic
**Usage:** Referenced by `infrastructure/` via Kustomization `resources:`
**Pattern:** Each base contains HelmRelease + health checks for operators (CNPG, Dragonfly, Strimzi, Rook-Ceph, Keycloak, Fluent-bit)

#### `kubernetes/workloads/`
**Purpose:** Application instances (databases, identity, CI/CD, messaging, tenants)
**Structure:**
- `platform/` - Core platform services (databases, identity, messaging, CI/CD, registry)
- `tenants/` - Multi-tenant applications (GitLab, GitLab-Runner)

#### `kubernetes/components/`
**Purpose:** Reusable Kustomize components for cross-cutting concerns
**Examples:**
- Network policy templates (deny-all, allow-dns, allow-fqdn, allow-kube-api)
- Dragonfly instance configurations

### Talos & Bootstrap

#### `talos/`
**Purpose:** Talos Linux node configurations for 6 bare-metal nodes
**Structure:**
- `infra/` - 3-node control plane cluster (10.25.11.11-13)
- `apps/` - 3-node control plane cluster (10.25.11.14-16)
- `machineconfig-multicluster.yaml.j2` - Jinja2 template for generating machine configs

#### `bootstrap/`
**Purpose:** Initial cluster provisioning and Flux installation
**Strategy:** Three-phase bootstrap (Phase 0: CRDs → Phase 1: Core infra → Phase 2: Full stack)
**Tool:** Helmfile-based with cluster-specific environments

### Automation

#### `.taskfiles/`
**Purpose:** Modular Task automation for cluster lifecycle operations
**Modules:**
- `cluster/` - End-to-end cluster creation (Talos → K8s → Flux)
- `bootstrap/` - Three-phase bootstrap orchestration
- `kubernetes/` - Flux installation & reconciliation
- `talos/` - Machine config generation & node provisioning
- `volsync/` - Backup/restore automation
- `workstation/` - Local development environment
- `onepassword/` - Secret management integration
- `synergyflow/` - Workflow orchestration

#### `scripts/`
**Purpose:** Specialized validation and utility scripts
**Key scripts:**
- `validate-cilium-core.sh` - Multi-layer Cilium validation (syntax → build → schema → Flux dry-run)
- `validate-crd-waitset.sh` - CRD establishment verification
- `validate-story-sequences.sh` - Story dependency validation for GitOps workflow

#### `.github/workflows/`
**Purpose:** CI/CD automation via GitHub Actions
**Workflows:**
- `validate-infrastructure.yaml` - Flux builds, YAML linting, schema validation, secret scanning, image scanning, Talos validation, drift detection
- `backup-compliance-validation.yaml` - OPA policy validation (GDPR, HIPAA, PCI-DSS, SOX) with automated alerting
- `validate-cilium-core.yml` - Cilium-specific validation
- `auto-add-to-project.yml` - GitHub project automation

## Integration Points

### Flux CD → Kubernetes Clusters
- **Entry:** `kubernetes/clusters/{infra,apps}/`
- **Flow:** Cluster-specific Kustomizations → `infrastructure/` layer → `bases/` operators → `workloads/` instances
- **Config injection:** `postBuild.substituteFrom` reads `cluster-settings` ConfigMap

### Talos → Kubernetes
- **Bootstrap:** Task automation → Helmfile → Flux installation → GitOps handoff
- **Node configs:** `talos/{infra,apps}/*.yaml` generated from Jinja2 template

### CI/CD → Repository
- **Validation:** GitHub Actions validate every PR (Flux builds, schema, secrets, images, compliance)
- **Deployment:** Flux watches repository → reconciles clusters

### Secrets → Workloads
- **Source:** 1Password vault (separate "Infra" vault)
- **Integration:** external-secrets operator (v0.20.4)
- **Path structure:** `kubernetes/{infra,apps}/*` secrets per cluster

## Entry Points

| Entry Point | Purpose |
|-------------|---------|
| `Taskfile.yaml` | Operational automation (cluster creation, bootstrap, management) |
| `kubernetes/clusters/infra/` | Flux entry for infra cluster |
| `kubernetes/clusters/apps/` | Flux entry for apps cluster |
| `talos/machineconfig-multicluster.yaml.j2` | Talos node config template |
| `bootstrap/helmfile.d/` | Initial cluster bootstrap |
| `.github/workflows/validate-infrastructure.yaml` | CI/CD validation entry |

## Key Architectural Patterns

1. **GitOps Layering:** Operators (bases/) → Infrastructure (shared) → Workloads (instances)
2. **Multi-cluster via substitution:** Single infrastructure definition + ConfigMap-based variable injection
3. **Three-phase bootstrap:** CRDs → Core → Full stack (prevents dependency races)
4. **Health check dependencies:** Explicit `dependsOn` + resource health checks
5. **Defense-in-depth validation:** Multi-stage CI/CD (syntax → schema → security → compliance)
6. **Operator pattern:** CRD separation from operator deployment
7. **Network security:** Baseline deny-all NetworkPolicies with explicit allow rules

