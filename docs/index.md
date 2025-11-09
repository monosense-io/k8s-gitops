# k8s-gitops Documentation Index

> **Project:** Multi-Cluster Kubernetes GitOps Infrastructure
> **Generated:** 2025-11-09
> **Type:** Infrastructure (Monolithic)
> **Owner:** monosense

---

## 📊 Project Overview

**Type:** Monolithic Infrastructure-as-Code
**Primary Technology:** Kubernetes multi-cluster on Talos Linux with Flux CD GitOps
**Architecture:** Multi-cluster (infra + apps) with shared infrastructure layer

### Quick Reference

| Aspect | Details |
|--------|---------|
| **Operating System** | Talos Linux (immutable, API-driven) |
| **Orchestration** | Kubernetes (2x 3-node clusters) |
| **GitOps** | Flux CD (automated reconciliation) |
| **CNI** | Cilium (eBPF, BGP, ClusterMesh, Gateway API) |
| **Storage** | Rook-Ceph v1.18.6, OpenEBS v4.3.3 |
| **Databases** | CloudNativePG v0.26.1, DragonflyDB v1.3.0 |
| **Messaging** | Strimzi Kafka v0.48.0 |
| **Observability** | Victoria Metrics, Victoria Logs v0.11.12 |
| **Security** | cert-manager, external-secrets v0.20.4, NetworkPolicies |
| **Entry Points** | `kubernetes/clusters/{infra,apps}/` |
| **Nodes** | 6 bare-metal (3 infra + 3 apps) |

### Cluster Architecture

**Infra Cluster (10.25.11.11-13):**
- Platform services (storage, databases, observability, security)
- Pod CIDR: 10.244.0.0/16, Service CIDR: 10.245.0.0/16
- BGP ASN: 64512

**Apps Cluster (10.25.11.14-16):**
- Application workloads (GitLab, Harbor, Kafka, tenants)
- Pod CIDR: 10.246.0.0/16, Service CIDR: 10.247.0.0/16
- BGP ASN: 64513

---

## 📚 Generated Documentation

### Core Documentation
- **[Project Overview](./project-overview.md)** - Executive summary, technology stack, architecture, hardware
- **[Source Tree Analysis](./source-tree-analysis.md)** - Annotated directory structure with explanations
- **[Infrastructure Components](./infrastructure-components.md)** - Complete inventory of 30+ infrastructure components

### Operational Documentation
- **[Development Guide](./development-guide.md)** - Local development setup, validation, common tasks
- **[Deployment Guide](./deployment-guide.md)** - Cluster deployment, bootstrap, operations

---

## 📖 Existing Documentation

### Root Documentation
- **[README.md](../README.md)** - Main project overview, hardware specs, cluster status badges

### Component Documentation (Kubernetes)
- **[Network Policy Templates](../kubernetes/components/networkpolicy/README.md)** - Baseline security policies
- **[Network Policy: allow-dns](../kubernetes/components/networkpolicy/allow-dns/README.md)** - DNS egress policy
- **[Network Policy: deny-all](../kubernetes/components/networkpolicy/deny-all/README.md)** - Default deny baseline
- **[Network Policy: allow-fqdn](../kubernetes/components/networkpolicy/allow-fqdn/README.md)** - FQDN-based egress
- **[Network Policy: allow-kube-api](../kubernetes/components/networkpolicy/allow-kube-api/README.md)** - API server access
- **[Network Policy: allow-internal](../kubernetes/components/networkpolicy/allow-internal/README.md)** - Cluster-internal
- **[Dragonfly Component](../kubernetes/components/dragonfly/README.md)** - Dragonfly instance configuration

### Operator Documentation (Bases)
- **[Rook-Ceph Operator](../kubernetes/bases/rook-ceph-operator/operator/README.md)** - Distributed storage operator

### Workload Documentation
- **[GitHub Actions Runner System](../kubernetes/workloads/platform/cicd/actions-runner-system/README.md)** - Self-hosted runners
- **[Harbor Registry](../kubernetes/workloads/platform/registry/harbor/README.md)** - OCI artifact registry
- **[GitLab](../kubernetes/workloads/tenants/gitlab/README.md)** - Self-hosted Git and CI/CD
- **[GitLab Monitoring](../kubernetes/workloads/tenants/gitlab/monitoring/)** - GitLab observability

### Bootstrap Documentation
- **[Bootstrap Helmfile](../bootstrap/helmfile.d/README.md)** - Three-phase bootstrap strategy

### CI/CD & Automation
- **[Validate Infrastructure Workflow](../.github/workflows/validate-infrastructure.yaml)** - Multi-stage validation pipeline
- **[Backup Compliance Validation Workflow](../.github/workflows/backup-compliance-validation.yaml)** - OPA policy validation
- **[Validate Cilium Core Workflow](../.github/workflows/validate-cilium-core.yml)** - Cilium-specific validation
- **[Auto-add to Project Workflow](../.github/workflows/auto-add-to-project.yml)** - GitHub automation

### Scripts & Utilities
- **[validate-cilium-core.sh](../scripts/validate-cilium-core.sh)** - Cilium manifest validation
- **[validate-crd-waitset.sh](../scripts/validate-crd-waitset.sh)** - CRD establishment checker
- **[validate-story-sequences.sh](../scripts/validate-story-sequences.sh)** - Story dependency validation
- **[fix-story-sequences.sh](../scripts/fix-story-sequences.sh)** - Story sequence fixer
- **[resequence-stories.sh](../scripts/resequence-stories.sh)** - Story resequencing automation
- **[generate-clustermesh-1password-item.sh](../scripts/generate-clustermesh-1password-item.sh)** - ClusterMesh secret generation

---

## 🚀 Getting Started

### For Developers

1. **Understand the Repository Structure**
   - Read [Source Tree Analysis](./source-tree-analysis.md) for directory layout
   - Review [Project Overview](./project-overview.md) for architecture understanding
   - Explore [Infrastructure Components](./infrastructure-components.md) for component inventory

2. **Local Development Setup** _(Development Guide to be generated)_
   - Install prerequisites: Task, kubectl, flux, talosctl, kubeconform, yamllint
   - Configure environment: `.mise.toml` for environment management
   - Review Taskfile: `task --list` to see available automation

3. **Explore Component Documentation**
   - Check component-specific READMEs in `kubernetes/` directories
   - Understand GitOps workflow via Flux Kustomizations

### For Operators

1. **Cluster Lifecycle Operations** _(Deployment Guide to be generated)_
   - Review Task automation: `task --list`
   - Understand three-phase bootstrap: [Bootstrap Helmfile README](../bootstrap/helmfile.d/README.md)
   - Familiarize with Talos configuration: `talos/` directory

2. **Operational Tasks**
   - **Bootstrap new cluster:** `task cluster:create`
   - **Validate manifests:** `task validate-cilium-core`
   - **Reconcile Flux:** `task kubernetes:reconcile`
   - **Manage Talos nodes:** `task talos:*`
   - **Backup/restore:** `task volsync:*`

3. **Monitoring & Troubleshooting**
   - Check cluster status: Flux dashboards, Victoria Metrics
   - Review logs: Victoria Logs (centralized logging)
   - Network debugging: Hubble CLI (Cilium observability)

### For Contributors

1. **GitOps Workflow**
   - All infrastructure changes go through Git pull requests
   - Every PR validated by CI/CD pipelines (`.github/workflows/validate-infrastructure.yaml`)
   - Flux automatically reconciles approved changes

2. **Pre-commit Validation**
   - Run local validation: `./scripts/validate-cilium-core.sh`
   - Test Flux builds: `flux build kustomization <name> --path kubernetes/clusters/infra/`
   - Lint YAML: `yamllint kubernetes/`
   - Schema validation: `kubeconform <manifest>`

3. **Code Standards**
   - Follow existing directory structure patterns
   - Use Kustomize for composition (avoid Helm for cluster resources)
   - Apply baseline NetworkPolicies to all namespaces
   - Document changes in component READMEs

---

## 🏗️ Architecture Patterns

### GitOps Layering
```
kubernetes/bases/          → Reusable operators (version-pinned)
  ↓ referenced by
kubernetes/infrastructure/ → Shared infrastructure layer (both clusters)
  ↓ depends on
kubernetes/workloads/      → Application instances
```

### Multi-Cluster Configuration
```
kubernetes/clusters/{infra,apps}/cluster-settings.yaml
  ↓ (200+ variables)
postBuild.substituteFrom → Injects cluster-specific values
  ↓
Same infrastructure/ deployed to both clusters with different configs
```

### Three-Phase Bootstrap
```
Phase 0: CRDs only
  ↓
Phase 1: Core infrastructure (Cilium, Flux)
  ↓
Phase 2: Full stack deployment
```

### Health Check Dependencies
```yaml
dependsOn:
  - name: parent-kustomization
healthChecks:
  - apiVersion: apps/v1
    kind: Deployment
    name: component
```

---

## 🔍 Quick Navigation

### By Infrastructure Category

| Category | Components | Documentation |
|----------|-----------|---------------|
| **Networking** | Cilium, CoreDNS, ExternalDNS, Cloudflared, Spegel | [Infrastructure Components](./infrastructure-components.md#networking) |
| **Security** | cert-manager, external-secrets, NetworkPolicies | [Infrastructure Components](./infrastructure-components.md#security) |
| **Storage** | Rook-Ceph, OpenEBS | [Infrastructure Components](./infrastructure-components.md#storage) |
| **Databases** | CloudNativePG, DragonflyDB | [Infrastructure Components](./infrastructure-components.md#databases) |
| **Messaging** | Strimzi Kafka | [Infrastructure Components](./infrastructure-components.md#messaging) |
| **Observability** | Victoria Metrics, Victoria Logs, Fluent-bit | [Infrastructure Components](./infrastructure-components.md#observability) |
| **GitOps** | Flux CD, OCI Repositories | [Infrastructure Components](./infrastructure-components.md#gitops) |
| **Operations** | Reloader | [Infrastructure Components](./infrastructure-components.md#operations) |

### By Cluster

| Cluster | Workloads | Entry Point |
|---------|-----------|-------------|
| **Infra** | Platform services, storage, databases, observability | `kubernetes/clusters/infra/` |
| **Apps** | Application workloads, Kafka, GitLab, Harbor | `kubernetes/clusters/apps/` |

### By Use Case

| Use Case | Starting Point |
|----------|----------------|
| **Add new infrastructure component** | Create in `kubernetes/infrastructure/`, reference `kubernetes/bases/` if using operator |
| **Deploy new application** | Add to `kubernetes/workloads/platform/` or `kubernetes/workloads/tenants/` |
| **Modify cluster configuration** | Edit `kubernetes/clusters/{infra,apps}/cluster-settings.yaml` |
| **Update operator version** | Modify HelmRelease in `kubernetes/bases/{operator}/operator/` |
| **Add network policy** | Use templates from `kubernetes/components/networkpolicy/` |
| **Bootstrap new cluster** | Follow [Bootstrap Helmfile README](../bootstrap/helmfile.d/README.md), use `task cluster:create` |

---

## 📊 Project Metrics

- **Kubernetes Manifests:** 298+ YAML files
- **Infrastructure Components:** 30+ across 8 categories
- **Operators:** 5 (CloudNativePG, Dragonfly, Strimzi Kafka, Rook-Ceph, Fluent-bit)
- **Clusters:** 2 (infra, apps)
- **Nodes:** 6 bare-metal (ThinkCentre/ThinkStation)
- **GitHub Actions Workflows:** 4 (validation, compliance, Cilium, automation)
- **Task Modules:** 8 (cluster, bootstrap, kubernetes, talos, volsync, workstation, onepassword, synergyflow)
- **Validation Scripts:** 6 specialized validators
- **Existing Component READMEs:** 15+

---

## 🔗 External Resources

- **Status Page:** [status.monosense.io](https://status.monosense.io)
- **Cluster Template Inspiration:** [onedr0p/cluster-template](https://github.com/onedr0p/cluster-template)
- **Talos Linux:** [talos.dev](https://www.talos.dev/)
- **Flux CD:** [fluxcd.io](https://fluxcd.io)
- **Cilium:** [cilium.io](https://cilium.io)

---

## 📝 Documentation Maintenance

This documentation was auto-generated by the BMad document-project workflow using an **exhaustive scan**. To update:

1. **Re-run documentation workflow:** `/bmad:bmm:workflows:document-project`
2. **Manually edit specific files:** All markdown files in `docs/` are editable
3. **Component-specific docs:** Update READMEs in component directories

**Last Generated:** 2025-11-09
**Scan Level:** Exhaustive
**Files Generated:** 4 (index.md, project-overview.md, source-tree-analysis.md, infrastructure-components.md)

---

## 🎯 Next Steps

### Immediate Actions
1. Review the [Project Overview](./project-overview.md) for comprehensive architecture understanding
2. Explore the [Source Tree Analysis](./source-tree-analysis.md) to navigate the repository effectively
3. Check [Infrastructure Components](./infrastructure-components.md) for detailed component inventory

### For New Feature Development
1. Identify which cluster (infra vs apps) the feature belongs to
2. Determine if it's infrastructure (shared) or workload (instance-specific)
3. Check existing patterns in similar components
4. Create GitOps manifests in appropriate directory
5. Add NetworkPolicies from baseline templates
6. Test with Flux dry-run: `flux build kustomization <name> --path <path>`
7. Submit PR for CI/CD validation

### For Troubleshooting
1. Check Flux reconciliation status: `flux get kustomizations -A`
2. Review component health checks in Kustomization manifests
3. Inspect logs via Victoria Logs or `kubectl logs`
4. Use Hubble for network debugging: `hubble observe --namespace <ns>`
5. Validate manifests locally: `./scripts/validate-cilium-core.sh`
