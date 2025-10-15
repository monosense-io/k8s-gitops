# Phase-Based Bootstrap Architecture

This directory contains phase-separated helmfile configurations for the bootstrap process.

## 📁 File Structure

```
helmfile.d/
├── 00-crds.yaml        # Phase 0: CRD extraction
├── 01-core.yaml        # Phase 1: Core infrastructure
└── README.md           # This file
```

## 🎯 Architecture Overview

```
┌──────────────────────────────────────┐
│ Phase 0: CRD Extraction (00-crds)    │
│ - cert-manager CRDs                  │
│ - external-secrets CRDs              │
│ - victoria-metrics-operator CRDs     │
│   (includes PrometheusRule)          │
└──────────────────────────────────────┘
                   ↓
┌──────────────────────────────────────┐
│ Phase 1: Core Infrastructure (01)    │
│ - Cilium CNI                         │
│ - CoreDNS                            │
│ - Spegel                             │
│ - cert-manager (crds: false)         │
│ - external-secrets (crds: false)     │
│ - Flux Operator                      │
│ - Flux Instance                      │
└──────────────────────────────────────┘
```

## 🚀 Usage

### Automated (Recommended)

Use Taskfile automation which handles all phases:

```bash
# Complete cluster bootstrap
task cluster:create-infra
task cluster:create-apps

# Or just Kubernetes/CRD layer
task bootstrap:infra
task bootstrap:apps
```

### Manual Phase Control

If you need manual control over each phase:

#### Phase 0: CRD Extraction

```bash
# Extract and apply CRDs for infra cluster
helmfile -f bootstrap/helmfile.d/00-crds.yaml -e infra template | kubectl apply -f -

# Extract and apply CRDs for apps cluster
helmfile -f bootstrap/helmfile.d/00-crds.yaml -e apps template | kubectl apply -f -

# Verify CRDs are installed
kubectl get crds | grep -E "cert-manager|external-secrets|victoriametrics"
```

#### Phase 1: Core Infrastructure

```bash
# Deploy core infrastructure for infra cluster
helmfile -f bootstrap/helmfile.d/01-core.yaml -e infra sync

# Deploy core infrastructure for apps cluster
helmfile -f bootstrap/helmfile.d/01-core.yaml -e apps sync

# Verify deployments
kubectl get pods -A
```

### Using Top-Level Orchestrator

```bash
# Bootstrap complete cluster (all phases via helmfiles import)
helmfile -e infra sync
helmfile -e apps sync
```

## 🔍 CRD Extraction Pattern

### How It Works

The `00-crds.yaml` file uses a postRenderer pattern to extract ONLY CustomResourceDefinitions:

```yaml
helmDefaults:
  args: ['--include-crds', '--no-hooks']
  postRenderer: bash
  postRendererArgs:
    - -c
    - "yq ea --exit-status 'select(.kind == \"CustomResourceDefinition\")'"
```

**Process:**
1. Helm renders the chart with `--include-crds` flag
2. Output is piped to `yq` which filters only CRD resources
3. Result contains ONLY CustomResourceDefinitions
4. These are applied to cluster before deploying apps

### Why This Pattern?

1. **Prevents Race Conditions**: CRDs exist before resources that depend on them
2. **Solves PrometheusRule Issue**: Victoria Metrics CRDs installed before infrastructure layer needs them
3. **Clean Separation**: CRD lifecycle separated from application lifecycle
4. **Follows Best Practices**: Pattern used by buroa/k8s-gitops and other production repos

## 📊 CRDs Installed

### cert-manager (v1.16.2)

- Certificate
- CertificateRequest
- Issuer
- ClusterIssuer
- Challenge
- Order

### external-secrets (v0.12.1)

- ExternalSecret
- SecretStore
- ClusterSecretStore
- PushSecret
- ClusterExternalSecret

### victoria-metrics-operator (v0.37.4)

**Core CRDs:**
- VMAgent
- VMAlert
- VMAlertmanager
- VMSingle
- VMCluster

**Config CRDs:**
- VMRule
- VMServiceScrape
- VMPodScrape
- VMProbe
- VMNodeScrape
- VMStaticScrape
- VMAuth
- VMUser
- VMAlertmanagerConfig

**Compatibility CRDs (Prometheus):**
- **PrometheusRule** ← This solves the infrastructure layer issue!
- ServiceMonitor
- PodMonitor
- Probe

## 🔧 Configuration

### Cluster Values

Each cluster has its own values file:

- `bootstrap/clusters/infra/values.yaml`
- `bootstrap/clusters/apps/values.yaml`

**Example structure:**

```yaml
# Kubernetes API
k8sServiceHost: "infra-k8s.monosense.io"

# CoreDNS
corednsClusterIP: "10.245.0.10"
corednsReplicas: 2

# Cilium BGP
ciliumBGPEnabled: true
```

### Disabling Inline CRDs

In `01-core.yaml`, all charts have CRD installation disabled:

```yaml
# cert-manager
- name: cert-manager
  values:
    - crds:
        enabled: false  # CRDs installed via 00-crds.yaml

# external-secrets
- name: external-secrets
  values:
    - crds:
        createClusterSecretStore: false
```

## 🐛 Troubleshooting

### CRD Extraction Test

Test CRD extraction without applying:

```bash
# Preview CRDs that will be extracted
helmfile -f bootstrap/helmfile.d/00-crds.yaml -e infra template

# Count CRDs
helmfile -f bootstrap/helmfile.d/00-crds.yaml -e infra template | grep -c "kind: CustomResourceDefinition"
```

### Common Issues

**Issue**: CRD extraction returns empty output

```bash
# Check yq is installed
which yq

# Test yq filter manually
echo "kind: CustomResourceDefinition" | yq ea 'select(.kind == "CustomResourceDefinition")'
```

**Issue**: Chart version mismatch

```bash
# Update chart versions in 00-crds.yaml and 01-core.yaml
# Ensure versions match exactly
```

**Issue**: Namespace doesn't exist

```bash
# Create namespaces before applying CRDs
kubectl create namespace cert-manager
kubectl create namespace external-secrets
kubectl create namespace victoria-metrics
```

## 📚 Related Documentation

- [CRD Bootstrap Implementation Plan](../../docs/CRD-BOOTSTRAP-IMPLEMENTATION-PLAN.md)
- [CRD Bootstrap Best Practices](../../docs/CRD-BOOTSTRAP-BEST-PRACTICES.md)
- [Taskfile Bootstrap Guide](../../docs/TASKFILE-BOOTSTRAP-GUIDE.md)
- [Complete Cluster Bootstrap Guide](../../docs/COMPLETE-CLUSTER-BOOTSTRAP-GUIDE.md)

## 🔄 Migration from Old Structure

If migrating from single `helmfile.yaml`:

1. ✅ Original `helmfile.yaml` backed up to `helmfile.yaml.backup`
2. ✅ New phased structure created in `helmfile.d/`
3. ✅ Top-level `helmfile.yaml` now orchestrates phases
4. ✅ Taskfile automation updated to use new structure

**No action required** - Taskfile automation handles everything!

## 📝 Version History

- **v1.0** (2025-10-15): Initial phased structure implementation
  - Added 00-crds.yaml for CRD extraction
  - Added 01-core.yaml for core infrastructure
  - Migrated from single helmfile.yaml
  - Integrated with Taskfile automation

---

**Pattern inspired by:** [buroa/k8s-gitops](https://github.com/buroa/k8s-gitops)
