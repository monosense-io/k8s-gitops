# k8s-gitops Documentation Index

> **Your AI-Assisted Development Entry Point** 👈
>
> This index provides comprehensive documentation for the k8s-gitops multi-cluster infrastructure project.

---

## 📋 Quick Navigation

<details open>
<summary><b>🚀 Getting Started (Click to expand)</b></summary>

- **New to this project?** Start with [Project Overview](./project-overview.md)
- **Want to bootstrap a cluster?** See [Development Guide § Bootstrap](./development-guide.md#cluster-bootstrap-process)
- **Looking for architecture details?** Read [Architecture Documentation](./architecture.md)
- **Need to make changes?** Follow [Development Guide](./development-guide.md)

</details>

---

## 🎯 Project At A Glance

| Attribute | Value |
|-----------|-------|
| **Project Type** | Multi-Cluster Kubernetes GitOps Infrastructure |
| **Clusters** | 2x 3-node Talos clusters (infra + apps) |
| **Architecture** | Platform services (infra) + Application workloads (apps) |
| **GitOps Engine** | Flux CD v2 |
| **Tech Stack** | 50+ technologies (Talos, K8s, Cilium, Rook-Ceph, Victoria Metrics, PostgreSQL) |
| **Repository Type** | Monolith (single repo manages both clusters) |

**Quick Tech Summary:**
- **OS**: Talos Linux (immutable, API-only)
- **Networking**: Cilium (eBPF, BGP, Gateway API, ClusterMesh)
- **Storage**: Rook-Ceph (distributed) + OpenEBS (local)
- **Databases**: CloudNativePG (PostgreSQL), Dragonfly (Redis)
- **Observability**: Victoria Metrics + Victoria Logs + Fluent Bit
- **Security**: cert-manager, External Secrets (1Password), SOPS

---

## 📚 Core Documentation

### 🏢 Project Documentation
| Document | Description | When to Read |
|----------|-------------|--------------|
| **[Project Overview](./project-overview.md)** | High-level project summary, purpose, and goals | **Start here if new to the project** |
| **[Architecture](./architecture.md)** | Complete architecture documentation (network, storage, security, etc.) | When you need to understand system design |
| **[Technology Stack](./technology-stack.md)** | Comprehensive inventory of all technologies used | When evaluating tech choices or versions |
| **[Source Tree Analysis](./source-tree-analysis.md)** | Repository structure deep-dive with explanations | When navigating the codebase |

### 🛠️ Operational Documentation
| Document | Description | When to Read |
|----------|-------------|--------------|
| **[Development Guide](./development-guide.md)** | Development workflow, tasks, debugging, troubleshooting | **Daily development reference** |
| **[Bootstrap README](../bootstrap/helmfile.d/README.md)** | Phased bootstrap architecture and process | When bootstrapping clusters |

### 📖 Reference Documentation
| Document | Description | When to Read |
|----------|-------------|--------------|
| **[Main README](../README.md)** | Project README with quick start | GitHub landing page |
| **[LICENSE](../LICENSE)** | Apache 2.0 license | Legal/licensing questions |
| **[Taskfile.yaml](../Taskfile.yaml)** | Main task automation orchestrator | Finding available tasks |

---

## 🗂️ Documentation by Topic

### Networking
- **[Architecture § Network Architecture](./architecture.md#network-architecture)** - Cilium, BGP, Gateway API
- **[Technology Stack § Networking](./technology-stack.md#networking)** - Complete networking stack

### Storage
- **[Architecture § Storage Architecture](./architecture.md#storage-architecture)** - Rook-Ceph, OpenEBS
- **[Technology Stack § Storage](./technology-stack.md#storage)** - Storage technologies

### Databases
- **[Architecture § Database Architecture](./architecture.md#database-architecture)** - CloudNativePG, Dragonfly
- **[Technology Stack § Databases](./technology-stack.md#databases)** - Database stack

### Observability
- **[Architecture § Observability Architecture](./architecture.md#observability-architecture)** - Victoria Metrics, Victoria Logs
- **[Technology Stack § Observability](./technology-stack.md#observability)** - Observability stack

### Security
- **[Architecture § Security Architecture](./architecture.md#security-architecture)** - Secrets, certificates, encryption
- **[Technology Stack § Security](./technology-stack.md#security)** - Security technologies

### GitOps
- **[Architecture § GitOps-First Architecture](./architecture.md#1-gitops-first-architecture)** - Flux CD patterns
- **[Development Guide § Making Infrastructure Changes](./development-guide.md#making-infrastructure-changes)** - GitOps workflow

### Bootstrap Process
- **[Bootstrap README](../bootstrap/helmfile.d/README.md)** - Complete bootstrap documentation
- **[Development Guide § Cluster Bootstrap](./development-guide.md#cluster-bootstrap-process)** - Bootstrap commands

---

## 🚀 Common Tasks (Quick Reference)

### Bootstrap a Cluster
```bash
# Complete infra cluster bootstrap
task bootstrap:infra

# Complete apps cluster bootstrap
task bootstrap:apps

# Check status
task bootstrap:status CLUSTER=infra
```

**Documentation**: [Development Guide § Bootstrap Process](./development-guide.md#cluster-bootstrap-process)

### Make Infrastructure Changes
```bash
# 1. Edit manifests
vim kubernetes/infrastructure/networking/cilium/core/app/helmrelease.yaml

# 2. Validate locally
kubectl kustomize kubernetes/infrastructure | kubeconform -strict

# 3. Commit and push
git add . && git commit -m "feat(cilium): update config" && git push

# 4. Force reconciliation (or wait 10m for auto-sync)
task kubernetes:reconcile CLUSTER=infra
```

**Documentation**: [Development Guide § Making Infrastructure Changes](./development-guide.md#making-infrastructure-changes)

### Debug Flux Issues
```bash
# Check Flux status
flux get all -A

# Check for failures
flux get kustomizations -A --status-selector ready=false

# Force reconciliation
flux reconcile kustomization <name> -n flux-system --with-source

# View logs
kubectl logs -n flux-system deploy/kustomize-controller -f
```

**Documentation**: [Development Guide § Debugging](./development-guide.md#debugging)

### Apply Talos Node Changes
```bash
# Apply config to a node
task talos:apply-node NODE=10.25.11.11 CLUSTER=infra

# Reboot node
task talos:reboot-node NODE=10.25.11.11

# Upgrade Talos
task talos:upgrade-node NODE=10.25.11.11
```

**Documentation**: [Development Guide § Apply Node Configuration](./development-guide.md#apply-node-configuration)

---

## 📂 Repository Structure

```
k8s-gitops/
├── bootstrap/              # Bootstrap configs (Phase 0-2)
├── talos/                  # Talos node configurations
├── kubernetes/             # ☸️ GitOps source (Flux watches this)
│   ├── clusters/           # Per-cluster entry points
│   ├── infrastructure/     # Shared infrastructure
│   ├── workloads/          # Applications (platform + tenants)
│   ├── bases/              # Operator bases (6 operators)
│   └── components/         # Reusable Kustomize components
├── scripts/                # Utility scripts
├── .taskfiles/             # Modular tasks (8 modules)
├── .github/workflows/      # CI/CD validation
├── docs/                   # 📚 Documentation (THIS FOLDER)
├── Taskfile.yaml           # Main task orchestrator
└── README.md               # Main README
```

**Deep Dive**: [Source Tree Analysis](./source-tree-analysis.md)

---

## 🔧 Development Workflow

### 1. Initial Setup
```bash
# Install tools
brew install kubectl talosctl flux helmfile helm task yq jq

# Clone repo
git clone https://github.com/trosvald/k8s-gitops.git
cd k8s-gitops

# Configure credentials (1Password, SOPS)
# See: Development Guide § Environment Setup
```

### 2. Bootstrap Cluster (One-Time)
```bash
task bootstrap:infra   # or task bootstrap:apps
```

### 3. Daily Development
```bash
# Edit manifests → Validate → Commit → Push → Reconcile
# See: Development Guide § Making Infrastructure Changes
```

### 4. Monitor & Debug
```bash
flux get all -A          # Check Flux status
kubectl get pods -A      # Check pod status
task bootstrap:status    # Bootstrap status
```

**Full Workflow**: [Development Guide](./development-guide.md)

---

## 🎓 Learning Path

### For New Team Members

1. **Week 1: Understanding**
   - Read [Project Overview](./project-overview.md)
   - Read [Architecture Documentation](./architecture.md)
   - Explore [Source Tree Analysis](./source-tree-analysis.md)
   - Review [Technology Stack](./technology-stack.md)

2. **Week 2: Hands-On**
   - Bootstrap a test cluster: [Development Guide § Bootstrap](./development-guide.md#cluster-bootstrap-process)
   - Make a simple change: [Development Guide § Making Changes](./development-guide.md#making-infrastructure-changes)
   - Debug an issue: [Development Guide § Debugging](./development-guide.md#debugging)

3. **Week 3+: Mastery**
   - Understand Flux reconciliation loops
   - Learn Talos node management
   - Explore advanced networking (BGP, ClusterMesh)
   - Deep-dive into storage (Rook-Ceph operations)

### For AI-Assisted Development

**Best Practice**: Always provide this `index.md` to AI agents when working on this project. It contains:
- ✅ Complete technology stack
- ✅ Repository structure
- ✅ Links to detailed documentation
- ✅ Common tasks and commands

**Example prompt to AI**:
```
I'm working on the k8s-gitops project. Here's the documentation index:
[paste docs/index.md]

I need to [your specific task].
```

---

## 🌐 External Resources

### Upstream Documentation
- **Talos Linux**: https://www.talos.dev/
- **Flux CD**: https://fluxcd.io/
- **Cilium**: https://cilium.io/
- **Rook**: https://rook.io/
- **CloudNativePG**: https://cloudnative-pg.io/
- **Victoria Metrics**: https://victoriametrics.com/

### Inspiration Projects
- **buroa/k8s-gitops**: https://github.com/buroa/k8s-gitops (phased bootstrap pattern)
- **onedr0p/cluster-template**: https://github.com/onedr0p/cluster-template (Flux structure)

---

## 🐛 Troubleshooting Quick Links

| Issue | Documentation |
|-------|---------------|
| Flux Kustomization stuck | [Development Guide § Flux Kustomization Stuck](./development-guide.md#flux-kustomization-stuck) |
| HelmRelease failed | [Development Guide § HelmRelease Failed](./development-guide.md#helmrelease-failed) |
| Node not ready | [Development Guide § Node Not Ready](./development-guide.md#node-not-ready) |
| CRD not found | [Development Guide § CRD Not Found](./development-guide.md#crd-not-found) |
| Bootstrap failures | [Bootstrap README § Troubleshooting](../bootstrap/helmfile.d/README.md#troubleshooting) |

---

## 📊 Project Statistics

| Metric | Value |
|--------|-------|
| **Total Files** | ~500+ (excluding node_modules, .backup, .git) |
| **Kubernetes Manifests** | ~300+ YAML files |
| **Flux Kustomizations** | ~50+ ks.yaml files |
| **HelmReleases** | ~30+ helmrelease.yaml files |
| **Operators** | 6 (CNPG, Dragonfly, Fluent Bit, Keycloak, Rook-Ceph, Strimzi) |
| **Infrastructure Components** | 8 categories (databases, gitops, messaging, networking, observability, operations, security, storage) |
| **Platform Services** | 5 (CI/CD, databases, identity, messaging, registry) |
| **Tenant Applications** | 2 (GitLab, GitLab Runner) |
| **Task Modules** | 8 (.taskfiles/\*) |
| **Scripts** | 7 (scripts/\*) |
| **GitHub Workflows** | 4 (.github/workflows/\*) |

---

## 🎯 Status & Roadmap

### ✅ Production-Ready Features
- Multi-cluster Talos Kubernetes (infra + apps)
- Flux CD GitOps automation
- Cilium CNI (BGP, Gateway API, ClusterMesh)
- Rook-Ceph distributed storage
- CloudNativePG PostgreSQL
- Victoria Metrics observability
- cert-manager + External Secrets
- Keycloak SSO
- GitLab, Harbor, Kafka

### 🚧 In Progress
- SPIRE/SPIFFE workload identity
- Enhanced ArgoCD integration

### 📋 Planned
- Dev/staging/prod separation
- Multi-region deployment
- Advanced service mesh
- Distributed tracing

**Full Roadmap**: [Project Overview § Project Status](./project-overview.md#project-status)

---

## 🤝 Contributing

Contributions welcome! See [Project Overview § How to Contribute](./project-overview.md#how-to-contribute)

---

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/trosvald/k8s-gitops/issues)
- **Discussions**: [GitHub Discussions](https://github.com/trosvald/k8s-gitops/discussions)

---

## 📄 License

Apache License 2.0 - See [LICENSE](../LICENSE)

---

## 📅 Document Metadata

| Attribute | Value |
|-----------|-------|
| **Last Generated** | 2025-11-12 |
| **Documentation Version** | v2.0 |
| **Workflow** | BMAD document-project (exhaustive scan) |
| **Project Version** | v2.0 (Multi-Cluster Architecture) |

---

**🎯 Pro Tip**: Bookmark this page! It's your central hub for all k8s-gitops documentation.
