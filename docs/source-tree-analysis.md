# Source Tree Analysis

## Project Root Structure

```
k8s-gitops/                            # Project root
├── .backup/                           # 📦 Archived documentation (stories, runbooks, guides)
├── .bmad/                             # 🤖 BMAD development workflow automation
│   ├── bmm/                          # Business Method Methodology workflows
│   ├── core/                         # Core BMAD tasks and agents
│   └── _cfg/                         # BMAD configuration
├── .claude/                          # 🤖 Claude Code integration
│   ├── agents/                       # Custom AI agents
│   └── commands/                     # Slash commands
├── .github/                          # ⚙️ GitHub automation
│   └── workflows/                    # CI/CD pipelines
│       ├── auto-add-to-project.yml              # Auto-assign issues to projects
│       ├── backup-compliance-validation.yaml     # Validate backup compliance
│       ├── validate-cilium-core.yml             # Validate Cilium manifests
│       └── validate-infrastructure.yaml          # Infrastructure validation
├── .opencode/                        # 🤖 OpenCode agent definitions
│   ├── agent/                        # Agent configurations
│   └── command/                      # Command definitions
├── .taskfiles/                       # 📋 Modular Taskfile includes
│   ├── bootstrap/Taskfile.yaml       # Bootstrap orchestration tasks
│   ├── cluster/Taskfile.yaml         # Cluster management tasks
│   ├── kubernetes/Taskfile.yaml      # Kubernetes operations
│   ├── onepassword/Taskfile.yaml     # 1Password secret management
│   ├── synergyflow/Taskfile.yaml     # SynergyFlow app tasks
│   ├── talos/Taskfile.yaml          # Talos node management
│   ├── volsync/Taskfile.yaml        # Backup/restore operations
│   └── workstation/Taskfile.yaml     # Local workstation setup
├── .vscode/                          # 📝 VS Code workspace settings
├── bmad-bak/                         # 📦 BMAD backup files
├── bootstrap/                        # 🚀 Initial cluster bootstrap
│   ├── clusters/                     # Cluster-specific bootstrap configs
│   │   ├── apps/                     # Apps cluster values
│   │   │   ├── cilium-values.yaml           # Cilium CNI configuration
│   │   │   └── values.yaml                  # Cluster bootstrap values
│   │   └── infra/                    # Infra cluster values
│   │       ├── cilium-values.yaml           # Cilium CNI configuration
│   │       └── values.yaml                  # Cluster bootstrap values
│   ├── helmfile.d/                   # Phased helmfile configs
│   │   ├── 00-crds.yaml              # Phase 0: CRD extraction
│   │   ├── 01-core.yaml.gotmpl       # Phase 1: Core infrastructure
│   │   └── README.md                 # Bootstrap architecture docs
│   ├── prerequisites/                # Pre-bootstrap resources
│   │   └── resources.yaml            # Namespaces, secrets
│   ├── helmfile.yaml                 # Main helmfile orchestrator
│   └── validate.sh                   # Bootstrap validation script
├── docs/                             # 📚 Project documentation
│   ├── project-scan-report.json      # Documentation workflow state
│   ├── technology-stack.md           # THIS FILE
│   └── source-tree-analysis.md       # THIS FILE
├── kubernetes/                       # ☸️ Kubernetes manifests (GitOps source)
│   ├── bases/                        # 🔧 Reusable operator bases (shared CRDs/operators)
│   │   ├── cnpg-operator/            # CloudNativePG operator
│   │   ├── dragonfly-operator/       # Dragonfly operator
│   │   ├── fluent-bit-operator/      # Fluent Bit operator
│   │   ├── keycloak-operator/        # Keycloak operator
│   │   ├── rook-ceph-operator/       # Rook-Ceph operator
│   │   └── strimzi-operator/         # Strimzi Kafka operator
│   ├── clusters/                     # 🎯 Cluster entry points (Flux roots)
│   │   ├── apps/                     # Apps cluster Flux root
│   │   │   ├── cluster-settings.yaml         # Flux ConfigMap (substitutions)
│   │   │   ├── infrastructure.yaml           # Infrastructure Kustomization
│   │   │   └── messaging-kafka.yaml          # Kafka Kustomization
│   │   └── infra/                    # Infra cluster Flux root
│   │       ├── cluster-settings.yaml         # Flux ConfigMap (substitutions)
│   │       └── infrastructure.yaml           # Infrastructure Kustomization
│   ├── components/                   # 🧩 Reusable Kustomize components
│   │   ├── dragonfly/                # Dragonfly instance component
│   │   └── networkpolicy/            # Network policy component
│   ├── infrastructure/               # 🏗️ Shared infrastructure layer (deployed to both clusters)
│   │   ├── databases/                # Database operators and configs
│   │   │   ├── cloudnative-pg/       # CNPG operator deployment
│   │   │   └── dragonfly-operator/   # Dragonfly operator deployment
│   │   ├── gitops/                   # GitOps tooling
│   │   │   ├── argocd/               # ArgoCD deployment
│   │   │   └── oci-repositories/     # OCI Flux sources
│   │   ├── messaging/                # Messaging infrastructure
│   │   │   └── strimzi-operator/     # Strimzi Kafka operator
│   │   ├── networking/               # Networking stack
│   │   │   ├── cilium/               # Cilium CNI (BGP, Gateway, IPAM, ClusterMesh)
│   │   │   │   ├── bgp/              # BGP control plane
│   │   │   │   ├── clustermesh/      # Multi-cluster mesh
│   │   │   │   ├── core/             # Core Cilium deployment
│   │   │   │   ├── gateway/          # Gateway API resources
│   │   │   │   └── ipam/             # IP address management (per-cluster pools)
│   │   │   ├── cloudflared/          # Cloudflare Tunnel
│   │   │   ├── coredns/              # CoreDNS deployment
│   │   │   ├── external-dns/         # External DNS sync
│   │   │   │   ├── cloudflare/       # Cloudflare provider
│   │   │   │   └── rfc2136/          # RFC2136 (BIND) provider
│   │   │   └── spegel/               # OCI registry mirror
│   │   ├── observability/            # Monitoring and logging
│   │   │   ├── dashboards/           # Grafana dashboards
│   │   │   ├── fluent-bit-operator/  # Fluent Bit operator
│   │   │   ├── victoria-logs/        # Victoria Logs deployment
│   │   │   └── victoria-metrics/     # Victoria Metrics stack
│   │   ├── operations/               # Operational tools
│   │   │   └── reloader/             # Config/Secret auto-reloader
│   │   ├── security/                 # Security infrastructure
│   │   │   ├── cert-manager/         # Certificate management
│   │   │   ├── external-secrets/     # External secrets operator
│   │   │   └── networkpolicy/        # Network policy baselines
│   │   └── storage/                  # Storage infrastructure
│   │       ├── openebs/              # OpenEBS local storage
│   │       └── rook-ceph/            # Rook-Ceph distributed storage
│   │           ├── cluster/          # Ceph cluster config
│   │           └── operator/         # Rook operator
│   └── workloads/                    # 💼 Application workloads
│       ├── platform/                 # 🏢 Platform services (shared services)
│       │   ├── cicd/                 # CI/CD infrastructure
│       │   │   └── actions-runner-system/  # GitHub Actions runners
│       │   ├── databases/            # Database instances
│       │   │   ├── cloudnative-pg/   # Shared PostgreSQL cluster + poolers
│       │   │   └── dragonfly/        # Dragonfly instances
│       │   ├── identity/             # Identity and access
│       │   │   └── keycloak/         # Keycloak SSO
│       │   ├── messaging/            # Messaging platform
│       │   │   └── kafka/            # Kafka cluster (apps cluster)
│       │   └── registry/             # Container registry
│       │       └── harbor/           # Harbor registry
│       └── tenants/                  # 👥 Tenant applications
│           ├── gitlab/               # GitLab instance
│           │   ├── examples/         # Pipeline examples
│           │   └── monitoring/       # GitLab monitoring
│           └── gitlab-runner/        # GitLab CI runners
├── scripts/                          # 🛠️ Utility scripts
│   ├── fix-story-sequences.sh                # Story file management
│   ├── generate-clustermesh-1password-item.sh # ClusterMesh secret generation
│   ├── resequence_stories.py                # Story resequencing
│   ├── resequence-stories.sh                # Story resequencing wrapper
│   ├── validate-cilium-core.sh              # Cilium validation
│   ├── validate-crd-waitset.sh              # CRD validation
│   └── validate-story-sequences.sh          # Story validation
├── talos/                            # 🐧 Talos Linux configurations
│   ├── apps/                         # Apps cluster node configs
│   │   ├── 10.25.11.14.yaml          # Apps node 1 patch
│   │   ├── 10.25.11.15.yaml          # Apps node 2 patch
│   │   └── 10.25.11.16.yaml          # Apps node 3 patch
│   ├── infra/                        # Infra cluster node configs
│   │   ├── 10.25.11.11.yaml          # Infra node 1 patch
│   │   ├── 10.25.11.12.yaml          # Infra node 2 patch
│   │   └── 10.25.11.13.yaml          # Infra node 3 patch
│   ├── machineconfig-multicluster.yaml.j2  # Main Talos template (Jinja2)
│   ├── machineconfig.yaml.j2.backup         # Template backup
│   └── schematic.yaml                # Talos schematic definition
├── terraform/                        # 🏗️ Terraform (currently unused/planned)
├── .editorconfig                     # Editor configuration
├── .gitattributes                   # Git attributes
├── .gitignore                       # Git ignore rules
├── .minijinja.toml                  # Minijinja template config
├── .mise.toml                       # Mise version manager config
├── .sops.yaml                       # SOPS encryption rules (Age)
├── .sourceignore                    # Source control ignore
├── LICENSE                          # Apache 2.0 license
├── notes.txt                        # Development notes
├── opencode.jsonc                   # OpenCode configuration
├── README.md                        # **Main project documentation**
└── Taskfile.yaml                    # **Main task automation entry point**
```

---

## Critical Directories Explained

### 🚀 `bootstrap/` - Cluster Initialization
**Purpose:** Initial cluster bootstrap before Flux takeover

**Key Files:**
- `helmfile.yaml` - Orchestrates phased bootstrap
- `helmfile.d/00-crds.yaml` - Extracts and installs CRDs first (prevents race conditions)
- `helmfile.d/01-core.yaml.gotmpl` - Installs Cilium, CoreDNS, Flux, external-secrets
- `clusters/{infra,apps}/values.yaml` - Cluster-specific configurations
- `clusters/{infra,apps}/cilium-values.yaml` - Cilium CNI configurations
- `prerequisites/resources.yaml` - Namespaces and initial secrets

**Bootstrap Flow:**
```
Phase 0: CRDs Extraction    Phase 1: Core Infrastructure    Phase 2: Flux Bootstrap
┌──────────────────────┐    ┌──────────────────────────┐    ┌─────────────────────┐
│ cert-manager CRDs    │───▶│ Cilium CNI               │───▶│ GitRepository       │
│ external-secrets CRDs│    │ CoreDNS                  │    │ Flux controllers    │
│ VM operator CRDs     │    │ Spegel                   │    │ Cluster Kustomiz... │
│ Gateway API CRDs     │    │ cert-manager (no CRDs)   │    │                     │
└──────────────────────┘    │ external-secrets (no...)  │    └─────────────────────┘
                            │ Flux operator            │
                            └──────────────────────────┘
```

---

### 🐧 `talos/` - Talos Linux Node Configurations
**Purpose:** Bare-metal node configuration

**Structure:**
- `machineconfig-multicluster.yaml.j2` - **Main template** (Jinja2 templated)
- `{infra,apps}/*.yaml` - **Per-node patches** (node-specific configs: hostname, IP, disks)
- `schematic.yaml` - Talos image customization (kernel modules, system extensions)

**Node Mapping:**
| Cluster | Nodes | IP Addresses | Config Patches |
|---------|-------|-------------|----------------|
| **infra** | 3 | 10.25.11.11-13 | `talos/infra/*.yaml` |
| **apps** | 3 | 10.25.11.14-16 | `talos/apps/*.yaml` |

**Applied via:**
```bash
task talos:apply-node NODE=10.25.11.11 CLUSTER=infra
```

---

### ☸️ `kubernetes/` - GitOps Source of Truth
**Purpose:** Flux reconciles this directory to manage cluster state

#### 📂 `kubernetes/clusters/` - **Flux Entry Points**
Each cluster has its own Flux root:

**infra cluster:**
```yaml
# kubernetes/clusters/infra/infrastructure.yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: cluster-infra-infrastructure
spec:
  path: ./kubernetes/infrastructure  # ← Points to shared infra
  postBuild:
    substituteFrom:
      - name: cluster-settings  # ← Cluster-specific vars
```

**apps cluster:**
```yaml
# kubernetes/clusters/apps/infrastructure.yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: cluster-apps-infrastructure
spec:
  path: ./kubernetes/infrastructure  # ← Same shared infra
  postBuild:
    substituteFrom:
      - name: cluster-settings  # ← Different cluster vars
```

**Flux Kustomization Flow:**
```
Flux watches clusters/{infra,apps}/
          ↓
Reconciles infrastructure.yaml Kustomization
          ↓
Applies kubernetes/infrastructure/ (with cluster-specific substitutions)
          ↓
Infrastructure stacks deploy to cluster
```

---

#### 📂 `kubernetes/infrastructure/` - **Shared Infrastructure**
**Purpose:** Infrastructure components deployed to BOTH clusters

**Organized by category:**
- **databases/** - Operators for PostgreSQL (CNPG) and Dragonfly
- **gitops/** - ArgoCD, OCI repositories
- **messaging/** - Strimzi Kafka operator
- **networking/** - Cilium (BGP, Gateway, IPAM, ClusterMesh), CoreDNS, external-dns, Cloudflared, Spegel
- **observability/** - Victoria Metrics, Victoria Logs, Fluent Bit, Grafana dashboards
- **operations/** - Reloader (auto-restart pods on config changes)
- **security/** - cert-manager, external-secrets, network policies
- **storage/** - Rook-Ceph, OpenEBS

**Each component structure:**
```
infrastructure/networking/cilium/
├── core/
│   ├── app/
│   │   ├── helmrelease.yaml          # Flux HelmRelease
│   │   ├── ocirepository.yaml        # OCI chart source
│   │   └── kustomization.yaml        # Kustomize resources
│   └── ks.yaml                       # Flux Kustomization (entry)
├── bgp/
│   └── cplane/                       # BGP control plane config
├── gateway/                          # Gateway API resources
├── ipam/                             # IP pool management
│   ├── apps/                         # Apps cluster IP pools
│   └── infra/                        # Infra cluster IP pools
├── clustermesh/                      # Multi-cluster mesh
└── kustomization.yaml                # Parent kustomize
```

---

#### 📂 `kubernetes/workloads/` - **Application Workloads**
**Purpose:** Actual applications and services

**Platform services (`workloads/platform/`):**
- `cicd/` - GitHub Actions runners
- `databases/` - Actual database instances (CNPG shared cluster, Dragonfly instances)
- `identity/` - Keycloak SSO
- `messaging/` - Kafka cluster (apps cluster only)
- `registry/` - Harbor container registry

**Tenant applications (`workloads/tenants/`):**
- `gitlab/` - Self-hosted GitLab
- `gitlab-runner/` - GitLab CI runners

---

#### 📂 `kubernetes/bases/` - **Operator Definitions**
**Purpose:** Reusable operator CRDs and deployments (referenced by infrastructure/)

**6 operators:**
1. **cnpg-operator** - CloudNativePG (PostgreSQL)
2. **dragonfly-operator** - Dragonfly (Redis-compatible)
3. **fluent-bit-operator** - Fluent Bit log collection
4. **keycloak-operator** - Keycloak IAM
5. **rook-ceph-operator** - Rook Ceph storage
6. **strimzi-operator** - Strimzi Kafka messaging

**Usage pattern:**
```yaml
# infrastructure/databases/cloudnative-pg/ks.yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
spec:
  path: ./kubernetes/bases/cnpg-operator  # ← References base
```

---

#### 📂 `kubernetes/components/` - **Reusable Kustomize Components**
**Purpose:** Reusable configuration components (mixed into other kustomizations)

**Available components:**
- `dragonfly/` - Dragonfly instance component (reusable Dragonfly config)
- `networkpolicy/` - Network policy templates

**Usage (Kustomize components feature):**
```yaml
# kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
components:
  - ../../components/networkpolicy  # ← Mixin network policies
```

---

### 📋 `.taskfiles/` - Modular Task Automation
**Purpose:** Task-based automation for all operations

**8 task modules:**

| Module | Purpose | Key Tasks |
|--------|---------|-----------|
| **bootstrap/** | Cluster bootstrap | `task bootstrap:infra`, `task bootstrap:apps` |
| **cluster/** | Cluster lifecycle | `task cluster:create-infra`, `task cluster:delete` |
| **kubernetes/** | K8s operations | `task kubernetes:reconcile`, `task kubernetes:bootstrap` |
| **talos/** | Node management | `task talos:apply-node`, `task talos:upgrade-node` |
| **onepassword/** | Secret management | `task op:inject`, `task op:sync` |
| **volsync/** | Backup/restore | `task volsync:backup`, `task volsync:restore` |
| **synergyflow/** | SynergyFlow app | App-specific tasks |
| **workstation/** | Local setup | `task workstation:install` |

**Main orchestrator:** `Taskfile.yaml` includes all task modules

---

### 🛠️ `scripts/` - Utility Scripts
**Purpose:** Standalone scripts for specific tasks

| Script | Purpose |
|--------|---------|
| `validate-cilium-core.sh` | Validate Cilium manifests locally (no cluster needed) |
| `validate-crd-waitset.sh` | Validate CRD installation order |
| `generate-clustermesh-1password-item.sh` | Generate ClusterMesh secret for 1Password |
| `fix-story-sequences.sh` | Fix story file numbering |
| `validate-story-sequences.sh` | Validate story sequences |
| `resequence-stories.sh` | Resequence story files |

---

### ⚙️ `.github/workflows/` - CI/CD Pipelines
**Purpose:** Automated validation and compliance checks

**4 GitHub Actions workflows:**

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `auto-add-to-project.yml` | Issue/PR creation | Auto-assign to GitHub project |
| `backup-compliance-validation.yaml` | Push to `main` | Validate backup compliance |
| `validate-cilium-core.yml` | PR to `main` | Validate Cilium core manifests |
| `validate-infrastructure.yaml` | PR to `main` | Kubeconform validation of all manifests |

---

## Multi-Cluster Separation Pattern

### Flux Reconciliation per Cluster

**Infra Cluster Flow:**
```
Flux (infra context)
    ↓
Watches: kubernetes/clusters/infra/
    ↓
Reconciles: infrastructure.yaml
    ↓
Applies: kubernetes/infrastructure/ (with infra cluster-settings)
    ↓
Result: Infrastructure deployed to infra cluster
```

**Apps Cluster Flow:**
```
Flux (apps context)
    ↓
Watches: kubernetes/clusters/apps/
    ↓
Reconciles: infrastructure.yaml + messaging-kafka.yaml
    ↓
Applies: kubernetes/infrastructure/ + kafka workload (with apps cluster-settings)
    ↓
Result: Infrastructure + Kafka deployed to apps cluster
```

### Cluster-Specific Overrides

**Method 1: Flux postBuild substitution**
```yaml
# kubernetes/clusters/infra/cluster-settings.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: cluster-settings
data:
  CLUSTER_NAME: infra
  POD_CIDR: "10.244.0.0/16"
  SERVICE_CIDR: "10.245.0.0/16"
```

**Method 2: IPAM per-cluster folders**
```
infrastructure/networking/cilium/ipam/
├── apps/                # Apps cluster IP pools (deployed only to apps)
│   └── app/
│       └── lb-ippool-apps.yaml
└── infra/               # Infra cluster IP pools (deployed only to infra)
    └── app/
        └── lb-ippool-infra.yaml
```

---

## Entry Points Summary

### 🎯 Bootstrap Entry Point
```bash
task bootstrap:infra     # Bootstrap infra cluster (Phase 0 → 1 → 2 → 3)
task bootstrap:apps      # Bootstrap apps cluster (Phase 0 → 1 → 2 → 3)
```

### 🎯 Flux Entry Points (per cluster)
- **Infra cluster:** `kubernetes/clusters/infra/infrastructure.yaml`
- **Apps cluster:** `kubernetes/clusters/apps/infrastructure.yaml` + `messaging-kafka.yaml`

### 🎯 Application Entry Points
- **Shared infrastructure:** `kubernetes/infrastructure/{category}/{component}/ks.yaml`
- **Platform services:** `kubernetes/workloads/platform/{service}/ks.yaml`
- **Tenant apps:** `kubernetes/workloads/tenants/{app}/ks.yaml`

---

## Integration Points

### Bootstrap → Flux Handoff
1. **Bootstrap** installs Cilium imperatively via Helm CLI
2. **Bootstrap** installs Flux controllers + FluxInstance
3. **Bootstrap** creates GitRepository pointing to this repo
4. **Flux** reconciles `kubernetes/clusters/{cluster}/`
5. **Flux** takes over Cilium management declaratively (core/app/helmrelease.yaml)

### Cross-Cluster Communication
- **Cilium ClusterMesh**: Service discovery across infra ↔ apps clusters
- **Shared PostgreSQL**: CNPG shared-cluster in infra, accessed by apps via poolers + ClusterMesh
- **Centralized Observability**: Victoria Metrics in infra scrapes apps cluster

---

## Summary Statistics

| Category | Count |
|----------|-------|
| **Total directories** | ~150+ |
| **Kubernetes manifests** | ~300+ YAML files |
| **Flux Kustomizations** | ~50+ ks.yaml files |
| **HelmReleases** | ~30+ helmrelease.yaml files |
| **Operators** | 6 (bases/) |
| **Infrastructure components** | 8 categories |
| **Platform services** | 5 types |
| **Tenant applications** | 2 (GitLab, GitLab Runner) |
| **Task modules** | 8 |
| **Scripts** | 7 |
| **GitHub workflows** | 4 |

**Total project size:** ~500+ files (excluding node_modules, .backup, .git)
