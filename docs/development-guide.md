# Development Guide - k8s-gitops

> **Generated:** 2025-11-09
> **Project:** Multi-Cluster Kubernetes GitOps Infrastructure
> **For:** Local development and contribution

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Environment Setup](#environment-setup)
3. [Local Development Workflow](#local-development-workflow)
4. [Validation & Testing](#validation--testing)
5. [Common Development Tasks](#common-development-tasks)
6. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required Tools

| Tool | Version | Purpose | Installation |
|------|---------|---------|--------------|
| **Task** | Latest | Automation orchestration | `brew install go-task/tap/go-task` |
| **kubectl** | 1.28+ | Kubernetes CLI | `brew install kubectl` |
| **flux** | 2.x | Flux CD CLI | `brew install fluxcd/tap/flux` |
| **talosctl** | Latest | Talos Linux CLI | `brew install siderolabs/tap/talosctl` |
| **kubeconform** | Latest | Kubernetes manifest validation | `brew install kubeconform` |
| **yamllint** | Latest | YAML linting | `brew install yamllint` |
| **yq** | 4.x | YAML processor | `brew install yq` |
| **kustomize** | 5.x | Kustomize CLI | `brew install kustomize` |
| **mise** | Latest | Environment manager | `brew install mise` |

### Optional Tools

| Tool | Purpose | Installation |
|------|---------|--------------|
| **trivy** | Container image scanning | `brew install aquasecurity/trivy/trivy` |
| **gitleaks** | Secret scanning | `brew install gitleaks` |
| **helm** | Helm chart management | `brew install helm` |
| **jq** | JSON processor | `brew install jq` |
| **age** | Encryption (for SOPS) | `brew install age` |
| **sops** | Secret encryption | `brew install sops` |

### Access Requirements

- **1Password:** Access to "Infra" vault for secrets
- **Cloudflare:** API token for DNS management (if testing DNS automation)
- **GitHub:** Repository access with write permissions
- **SSH Keys:** Configured for Git operations

---

## Environment Setup

### 1. Clone Repository

```bash
git clone https://github.com/trosvald/home-ops.git k8s-gitops
cd k8s-gitops
```

### 2. Configure Environment Variables

The repository uses **mise** (formerly rtx) for environment management:

```bash
# Install mise (if not already installed)
brew install mise

# Load environment configuration
mise install
```

**Environment variables automatically set by `.mise.toml`:**
- `KUBECONFIG` → `kubernetes/kubeconfig`
- `TALOSCONFIG` → `talos/talosconfig`
- `MINIJINJA_CONFIG_FILE` → `.minijinja.toml`

### 3. Verify Task Installation

```bash
task --list
```

**Expected output:** List of available task modules:
- `cluster:*` - Cluster lifecycle operations
- `bootstrap:*` - Bootstrap procedures
- `kubernetes:*` - Kubernetes operations
- `talos:*` - Talos node management
- `volsync:*` - Backup/restore automation
- `workstation:*` - Local environment setup
- `op:*` - 1Password integration
- `synergyflow:*` - Workflow orchestration

### 4. Install Pre-commit Hooks (Optional)

Create `.git/hooks/pre-commit`:

```bash
#!/bin/bash
set -e

echo "Running validation checks..."

# YAML linting
yamllint kubernetes/

# Cilium core validation
./scripts/validate-cilium-core.sh

echo "✓ All checks passed"
```

Make executable:
```bash
chmod +x .git/hooks/pre-commit
```

---

## Local Development Workflow

### 1. Create Feature Branch

```bash
git checkout -b feature/add-new-component
```

### 2. Make Changes

**For infrastructure changes:**
- Add manifests to `kubernetes/infrastructure/{category}/`
- Reference operators from `kubernetes/bases/` if needed
- Update cluster-specific variables in `kubernetes/clusters/{infra,apps}/cluster-settings.yaml`

**For workload changes:**
- Add manifests to `kubernetes/workloads/platform/` or `kubernetes/workloads/tenants/`
- Include NetworkPolicy baseline (reference `kubernetes/components/networkpolicy/`)

**For Talos changes:**
- Modify Jinja2 template: `talos/machineconfig-multicluster.yaml.j2`
- Regenerate node configs (if applicable)

### 3. Validate Changes Locally

```bash
# Validate YAML syntax
yamllint kubernetes/

# Validate Kubernetes schemas
kubeconform -summary -output json kubernetes/infrastructure/**/*.yaml

# Validate Flux builds
flux build kustomization infra-infrastructure \
  --path kubernetes/clusters/infra/ \
  --kustomization-file kubernetes/clusters/infra/infrastructure.yaml

# Validate Cilium core
./scripts/validate-cilium-core.sh
```

### 4. Test with Dry Run (if cluster access available)

```bash
# Flux dry-run reconciliation
flux reconcile kustomization <name> --with-source --dry-run

# Kubectl dry-run
kubectl apply -f <manifest> --dry-run=client
kubectl apply -f <manifest> --dry-run=server
```

### 5. Commit Changes

```bash
git add .
git commit -m "feat(networking): add external-dns configuration for apps cluster"
```

**Commit message conventions:**
- `feat(category):` - New feature
- `fix(category):` - Bug fix
- `docs:` - Documentation changes
- `refactor(category):` - Code refactoring
- `chore:` - Maintenance tasks

### 6. Push and Create Pull Request

```bash
git push origin feature/add-new-component
```

Create PR on GitHub. CI/CD will automatically:
- Validate YAML syntax
- Validate Kubernetes schemas with kubeconform
- Run Flux builds for both clusters
- Scan for secrets with Gitleaks
- Scan container images with Trivy
- Validate Talos configs
- Check for configuration drift

---

## Validation & Testing

### Local Validation Scripts

#### Cilium Core Validation
```bash
./scripts/validate-cilium-core.sh
```

**What it validates:**
1. YAML syntax (yamllint)
2. Kustomize build (kustomize build)
3. Kubernetes schema (kubeconform)
4. Flux build with variable substitution

#### CRD Wait Set Validation
```bash
./scripts/validate-crd-waitset.sh
```

**Validates CRD establishment for:**
- `monitoring.coreos.com`
- `external-secrets.io`
- `cert-manager.io`
- `gateway.networking.k8s.io`

#### Story Sequence Validation
```bash
./scripts/validate-story-sequences.sh
```

**Validates:** Story/epic dependency ordering

### CI/CD Validation Pipeline

**Triggered on:** Every pull request

**Stages:**
1. **Flux Build Validation** - Validates Kustomization builds for infra and apps clusters
2. **YAML Linting** - yamllint with 160-char line limit
3. **Schema Validation** - kubeconform validates against OpenAPI schemas
4. **Secret Scanning** - Gitleaks detects leaked credentials
5. **Image Scanning** - Trivy scans container images for vulnerabilities
6. **Talos Validation** - Jinja2 template syntax validation
7. **Drift Detection** - flux diff checks for configuration drift

**View workflow:** `.github/workflows/validate-infrastructure.yaml`

### Manual Testing Commands

```bash
# Test Flux reconciliation (dry-run)
flux reconcile kustomization infra-infrastructure --with-source --dry-run

# Test Kustomize build
kustomize build kubernetes/clusters/infra/ | less

# Test variable substitution
flux build kustomization infra-infrastructure \
  --path kubernetes/clusters/infra/ \
  --kustomization-file kubernetes/clusters/infra/infrastructure.yaml \
  | grep -A 5 "CILIUM_VERSION"

# Validate all YAML files
find kubernetes/ -name "*.yaml" -exec yamllint {} \;

# Validate specific manifest against schema
kubeconform -summary kubernetes/infrastructure/networking/cilium/core/app/helmrelease.yaml
```

---

## Common Development Tasks

### Add New Infrastructure Component

1. **Create directory structure:**
   ```bash
   mkdir -p kubernetes/infrastructure/{category}/{component}
   ```

2. **Add Kustomization:**
   ```yaml
   # kubernetes/infrastructure/{category}/{component}/kustomization.yaml
   apiVersion: kustomize.config.k8s.io/v1beta1
   kind: Kustomization
   resources:
     - ./app
   ```

3. **Add HelmRelease or manifests:**
   ```bash
   mkdir kubernetes/infrastructure/{category}/{component}/app
   # Add helmrelease.yaml or plain manifests
   ```

4. **Reference in parent Kustomization:**
   Edit `kubernetes/infrastructure/{category}/kustomization.yaml`:
   ```yaml
   resources:
     - existing-component
     - {component}  # Add this line
   ```

5. **Test build:**
   ```bash
   kustomize build kubernetes/infrastructure/{category}/{component}/
   ```

### Add New Operator (via bases/)

1. **Create base structure:**
   ```bash
   mkdir -p kubernetes/bases/{operator-name}/operator
   ```

2. **Add HelmRelease:**
   ```yaml
   # kubernetes/bases/{operator-name}/operator/helmrelease.yaml
   apiVersion: helm.toolkit.fluxcd.io/v2
   kind: HelmRelease
   metadata:
     name: {operator-name}
     namespace: {operator-namespace}
   spec:
     interval: 30m
     chart:
       spec:
         chart: {chart-name}
         version: {version}
         sourceRef:
           kind: HelmRepository
           name: {repo-name}
           namespace: flux-system
   ```

3. **Add Kustomization:**
   ```yaml
   # kubernetes/bases/{operator-name}/operator/kustomization.yaml
   apiVersion: kustomize.config.k8s.io/v1beta1
   kind: Kustomization
   resources:
     - helmrelease.yaml
   ```

4. **Reference from infrastructure:**
   ```yaml
   # kubernetes/infrastructure/{category}/{operator-name}/kustomization.yaml
   apiVersion: kustomize.config.k8s.io/v1beta1
   kind: Kustomization
   resources:
     - ../../../bases/{operator-name}/operator
   ```

### Update Cluster Configuration

1. **Edit cluster-settings:**
   ```bash
   vim kubernetes/clusters/infra/cluster-settings.yaml
   # or
   vim kubernetes/clusters/apps/cluster-settings.yaml
   ```

2. **Add or modify variables:**
   ```yaml
   data:
     EXAMPLE_VAR: "value"
   ```

3. **Use in manifests with substitution:**
   ```yaml
   spec:
     values:
       example: ${EXAMPLE_VAR}
   ```

4. **Validate substitution:**
   ```bash
   flux build kustomization infra-infrastructure \
     --path kubernetes/clusters/infra/ \
     --kustomization-file kubernetes/clusters/infra/infrastructure.yaml \
     | grep "EXAMPLE_VAR"
   ```

### Add Network Policy

1. **Use baseline templates:**
   ```yaml
   # In your workload namespace
   apiVersion: kustomize.config.k8s.io/v1beta1
   kind: Kustomization
   resources:
     - ../../components/networkpolicy/deny-all
     - ../../components/networkpolicy/allow-dns
     - ../../components/networkpolicy/allow-kube-api
   ```

2. **Add workload-specific policies:**
   ```yaml
   # custom-policy.yaml
   apiVersion: cilium.io/v2
   kind: CiliumNetworkPolicy
   metadata:
     name: allow-specific-egress
   spec:
     endpointSelector:
       matchLabels:
         app: myapp
     egress:
       - toEndpoints:
           - matchLabels:
               app: backend
   ```

### Update Component Version

1. **For operators in bases/:**
   ```bash
   vim kubernetes/bases/{operator}/operator/helmrelease.yaml
   ```
   Update `spec.chart.spec.version`

2. **For infrastructure components:**
   Update version in HelmRelease or cluster-settings ConfigMap variable

3. **Commit with semantic version:**
   ```bash
   git commit -m "chore(databases): upgrade cnpg-operator to v0.27.0"
   ```

---

## Troubleshooting

### Common Issues

#### 1. Flux Build Fails with "unable to find variable"

**Cause:** Missing variable in cluster-settings ConfigMap

**Solution:**
```bash
# Check cluster-settings for the variable
grep "MISSING_VAR" kubernetes/clusters/infra/cluster-settings.yaml

# Add missing variable
vim kubernetes/clusters/infra/cluster-settings.yaml
```

#### 2. Kustomize Build Fails

**Cause:** Invalid Kustomization structure

**Solution:**
```bash
# Test individual kustomization
kustomize build kubernetes/infrastructure/{category}/{component}/

# Check for syntax errors
yamllint kubernetes/infrastructure/{category}/{component}/kustomization.yaml
```

#### 3. Schema Validation Fails

**Cause:** Manifest doesn't match Kubernetes schema

**Solution:**
```bash
# Validate specific manifest
kubeconform -summary -verbose kubernetes/path/to/manifest.yaml

# Check CRD schema
kubectl explain <resource>.<field>
```

#### 4. Secret Scanning False Positive

**Cause:** Gitleaks detects pattern that isn't a real secret

**Solution:**
Add to `.gitleaks.toml`:
```toml
[allowlist]
paths = [
    '''path/to/false/positive\.yaml''',
]
```

#### 5. Pre-commit Hook Blocks Commit

**Cause:** Validation failure in pre-commit hook

**Solution:**
```bash
# Fix validation errors, or skip hook (not recommended)
git commit --no-verify -m "message"
```

### Getting Help

1. **Check existing component READMEs:** Many components have specific documentation
2. **Review Flux documentation:** [fluxcd.io/docs](https://fluxcd.io/docs)
3. **Check Talos documentation:** [talos.dev](https://www.talos.dev/)
4. **Review CI/CD logs:** GitHub Actions workflow logs show detailed validation errors
5. **Ask in repository discussions:** Use GitHub Discussions for questions

---

## Next Steps

After setting up your local development environment:

1. **Explore the codebase:** Review [Source Tree Analysis](./source-tree-analysis.md)
2. **Understand architecture:** Read [Project Overview](./project-overview.md)
3. **Review components:** Check [Infrastructure Components](./infrastructure-components.md)
4. **Try a small change:** Update a component version or add a simple NetworkPolicy
5. **Run validation:** Test local validation scripts before pushing

For deployment operations, see [Deployment Guide](./deployment-guide.md).
