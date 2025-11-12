# Development Guide

## Prerequisites

### Required Tools

| Tool | Version | Installation | Purpose |
|------|---------|--------------|---------|
| **kubectl** | v1.28+ | `brew install kubectl` | Kubernetes CLI |
| **talosctl** | Latest | `brew install siderolabs/tap/talosctl` | Talos CLI |
| **flux** | v2.x | `brew install fluxcd/tap/flux` | Flux CLI |
| **helmfile** | Latest | `brew install helmfile` | Helmfile automation |
| **helm** | v3.x | `brew install helm` | Helm package manager |
| **task** | v3.x | `brew install go-task` | Task automation |
| **yq** | v4.x | `brew install yq` | YAML processor |
| **jq** | Latest | `brew install jq` | JSON processor |
| **kustomize** | Latest | `brew install kustomize` | Kustomize CLI |
| **minijinja-cli** | Latest | `brew install minijinja-cli` | Template renderer |

### Optional Tools

| Tool | Purpose | Installation |
|------|---------|--------------|
| **op** (1Password CLI) | Secret injection | [1Password CLI](https://1password.com/downloads/command-line/) |
| **kubeconform** | Manifest validation | `brew install kubeconform` |
| **age** | SOPS encryption | `brew install age` |
| **sops** | Secrets encryption | `brew install sops` |

---

## Environment Setup

### 1. Clone Repository

```bash
git clone https://github.com/trosvald/k8s-gitops.git
cd k8s-gitops
```

### 2. Configure Credentials

#### 1Password CLI Setup
```bash
# Sign in to 1Password
eval $(op signin)

# Test secret injection
op inject -i bootstrap/prerequisites/resources.yaml
```

#### SOPS/Age Setup (for encrypted files)
```bash
# Generate Age key
age-keygen -o ~/.config/sops/age/keys.txt

# Add public key to .sops.yaml
```

### 3. Configure Kubeconfig

```bash
# Kubeconfig will be generated during bootstrap
export KUBECONFIG=$PWD/kubernetes/kubeconfig

# After bootstrap:
kubectl config get-contexts
kubectl config use-context admin@infra  # or admin@apps
```

### 4. Configure Talosconfig

```bash
# Talosconfig will be generated during Talos bootstrap
export TALOSCONFIG=$PWD/talos/talosconfig

# List nodes
talosctl config info
```

---

## Development Workflow

### Task-Based Development

All operations use `task` automation:

```bash
# List all available tasks
task --list

# List bootstrap tasks
task bootstrap --list

# List Talos tasks
task talos --list
```

### Common Development Tasks

#### **View Cluster Status**
```bash
# Show bootstrap status
task bootstrap:status CLUSTER=infra

# Show Flux status
flux get kustomizations -A

# Show all resources
kubectl get all -A
```

#### **Reconcile Changes**
```bash
# Force Flux reconciliation
task kubernetes:reconcile CLUSTER=infra

# Reconcile specific Kustomization
flux reconcile kustomization <name> -n flux-system
```

#### **Validate Manifests Locally**
```bash
# Validate Cilium core (no cluster required)
task validate-cilium-core

# Validate all manifests with kubeconform
kubectl kustomize kubernetes/infrastructure | kubeconform -strict -summary
```

#### **Apply Node Configuration**
```bash
# Apply Talos config to a node
task talos:apply-node NODE=10.25.11.11 CLUSTER=infra

# Reboot node
task talos:reboot-node NODE=10.25.11.11

# Upgrade Talos
task talos:upgrade-node NODE=10.25.11.11
```

---

## Cluster Bootstrap Process

### Full Bootstrap (Recommended)

```bash
# Bootstrap complete infra cluster (Talos + K8s + Flux)
task bootstrap:infra

# Bootstrap complete apps cluster
task bootstrap:apps
```

### Phase-by-Phase Bootstrap (Advanced)

```bash
# Phase -1: Talos only
task bootstrap:talos CLUSTER=infra

# Phase 0: Prerequisites (namespaces, secrets)
task bootstrap:phase:0 CLUSTER=infra

# Phase 1: CRDs
task bootstrap:phase:1 CLUSTER=infra

# Phase 2: Core infrastructure (Cilium, CoreDNS, Flux)
task bootstrap:phase:2 CLUSTER=infra

# Phase 3: Validate deployment
task bootstrap:phase:3 CLUSTER=infra
```

### Dry-Run Mode

```bash
# Preview what bootstrap will do
task bootstrap:dry-run CLUSTER=infra

# Dry-run specific phase
task bootstrap:phase:1 CLUSTER=infra DRY_RUN=true
```

---

## Making Infrastructure Changes

### 1. Modify Manifests

```bash
# Edit infrastructure component
vim kubernetes/infrastructure/networking/cilium/core/app/helmrelease.yaml

# Edit workload
vim kubernetes/workloads/platform/databases/cloudnative-pg/shared-cluster/cluster.yaml
```

### 2. Validate Changes

```bash
# Validate with kustomize build
kubectl kustomize kubernetes/infrastructure/networking/cilium/core/app

# Validate with kubeconform
kubectl kustomize kubernetes/infrastructure | kubeconform -strict
```

### 3. Commit and Push

```bash
git add .
git commit -m "feat(cilium): update to v1.19.0"
git push origin main
```

### 4. Flux Auto-Reconciles

Flux watches the main branch and reconciles changes automatically (default interval: 10m).

**Force immediate reconciliation:**
```bash
task kubernetes:reconcile CLUSTER=infra
```

---

## Working with Helm Charts

### Update Chart Versions

```bash
# Edit HelmRelease
vim kubernetes/infrastructure/observability/victoria-metrics/app/helmrelease.yaml

# Change version
spec:
  chart:
    spec:
      version: 0.38.0  # Update this
```

### Test Helm Template Locally

```bash
# Render Helm chart
helm template my-release oci://ghcr.io/victoriametrics/charts/victoria-metrics-operator \
  --version 0.38.0 \
  -f kubernetes/infrastructure/observability/victoria-metrics/app/values.yaml
```

---

## Debugging

### View Logs

```bash
# Flux controller logs
kubectl logs -n flux-system deploy/source-controller -f
kubectl logs -n flux-system deploy/kustomize-controller -f
kubectl logs -n flux-system deploy/helm-controller -f

# Application logs
kubectl logs -n <namespace> <pod-name> -f

# Talos system logs
talosctl logs --context infra --nodes 10.25.11.11
```

### Describe Resources

```bash
# Describe Flux Kustomization
kubectl describe kustomization -n flux-system <name>

# Describe HelmRelease
kubectl describe helmrelease -n <namespace> <name>

# Describe pod
kubectl describe pod -n <namespace> <pod-name>
```

### Check Flux Status

```bash
# Get all Flux resources
flux get all -A

# Check for failed reconciliations
flux get kustomizations -A --status-selector ready=false

# Get Flux events
kubectl get events -n flux-system --sort-by='.lastTimestamp'
```

### Suspend/Resume Flux Reconciliation

```bash
# Suspend (for maintenance)
flux suspend kustomization <name> -n flux-system

# Resume
flux resume kustomization <name> -n flux-system
```

---

## Testing

### Unit Testing (Manifest Validation)

```bash
# Validate all manifests
kubectl kustomize kubernetes/infrastructure | kubeconform -strict -summary

# Validate specific component
kubectl kustomize kubernetes/infrastructure/networking/cilium/core/app | kubeconform -strict
```

### Integration Testing (CI/CD)

GitHub Actions workflows run on every PR:
- `validate-infrastructure.yaml` - Validates all Kubernetes manifests
- `validate-cilium-core.yml` - Validates Cilium configuration
- `backup-compliance-validation.yaml` - Validates backup policies

```bash
# Run locally using act (GitHub Actions locally)
act pull_request -W .github/workflows/validate-infrastructure.yaml
```

---

## Common Troubleshooting

### Flux Kustomization Stuck

```bash
# Check status
kubectl describe kustomization -n flux-system <name>

# Force reconciliation
flux reconcile kustomization <name> -n flux-system --with-source

# Check dependencies
kubectl get kustomization -n flux-system -o yaml | yq '.items[] | select(.metadata.name == "<name>") | .spec.dependsOn'
```

### HelmRelease Failed

```bash
# Check HelmRelease status
kubectl describe helmrelease -n <namespace> <name>

# Check Helm release
helm list -n <namespace>

# Check Helm history
helm history -n <namespace> <release-name>

# Rollback
helm rollback -n <namespace> <release-name> <revision>
```

### Node Not Ready

```bash
# Check node status
kubectl get nodes
talosctl health --context infra

# Check kubelet logs
talosctl logs --context infra --nodes <node-ip> kubelet

# Reboot node
task talos:reboot-node NODE=<node-ip>
```

### CRD Not Found

```bash
# Check if CRDs are installed
kubectl get crds | grep <crd-name>

# Re-apply CRDs
task bootstrap:phase:1 CLUSTER=infra
```

---

## Best Practices

### 1. Always Validate Before Commit

```bash
# Run local validation
task validate-cilium-core
kubectl kustomize kubernetes/infrastructure | kubeconform -strict
```

### 2. Use Feature Branches

```bash
git checkout -b feature/update-cilium
# Make changes
git commit -m "feat(cilium): update to v1.19.0"
git push origin feature/update-cilium
# Create PR on GitHub
```

### 3. Test in Infra Cluster First

Test infrastructure changes in the infra cluster before applying to apps cluster.

### 4. Monitor Flux Reconciliation

```bash
# Watch Flux status
watch -n 5 "flux get kustomizations -A"

# Watch pod status
watch -n 5 "kubectl get pods -A"
```

### 5. Use Dry-Run for Risky Changes

```bash
# Preview changes without applying
kubectl diff -k kubernetes/infrastructure/networking/cilium/core/app

# Dry-run Helm upgrade
helm upgrade --dry-run --debug <release> <chart>
```

---

## Directory-Specific Development

### Adding New Infrastructure Component

```bash
# Create directory structure
mkdir -p kubernetes/infrastructure/<category>/<component>/app

# Create Flux Kustomization (ks.yaml)
cat > kubernetes/infrastructure/<category>/<component>/ks.yaml <<EOF
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: <component>
  namespace: flux-system
spec:
  interval: 10m
  path: ./kubernetes/infrastructure/<category>/<component>/app
  prune: true
  sourceRef:
    kind: GitRepository
    name: flux-system
  wait: false
  timeout: 5m
EOF

# Create kustomization.yaml
cat > kubernetes/infrastructure/<category>/<component>/app/kustomization.yaml <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - helmrelease.yaml
  - namespace.yaml
EOF

# Add to parent kustomization
echo "  - <component>/ks.yaml" >> kubernetes/infrastructure/<category>/kustomization.yaml
```

### Adding New Workload

```bash
# Create directory
mkdir -p kubernetes/workloads/platform/<service>/app

# Follow same pattern as infrastructure components
```

---

## Performance Tips

### Reduce Flux Reconciliation Interval (Development)

```yaml
# Edit Flux Kustomization
spec:
  interval: 1m  # Default is 10m
```

### Parallel Reconciliation

Flux reconciles Kustomizations in parallel unless `dependsOn` is set.

### Suspend Unused Kustomizations

```bash
flux suspend kustomization <name> -n flux-system
```

---

## Useful Aliases

Add to `~/.bashrc` or `~/.zshrc`:

```bash
# Kubectl
alias k='kubectl'
alias kgp='kubectl get pods'
alias kgpa='kubectl get pods -A'
alias kgs='kubectl get svc'
alias kgn='kubectl get nodes'

# Flux
alias fga='flux get all -A'
alias fgk='flux get kustomizations -A'
alias fgh='flux get helmreleases -A'

# Task
alias t='task'
alias tl='task --list'

# Talos
alias tc='talosctl'
alias tch='talosctl health'
```

---

## References

- **Main README**: `README.md`
- **Bootstrap Architecture**: `bootstrap/helmfile.d/README.md`
- **Taskfile**: `Taskfile.yaml`
- **Technology Stack**: `docs/technology-stack.md`
- **Source Tree**: `docs/source-tree-analysis.md`
