# Repository Architecture Pattern

**IMPORTANT:** This implementation uses a **Flux-standard multi-cluster shared-base pattern**, not per-cluster configurations.

##  Directory Structure

```
kubernetes/
├── bases/                      # Shared HelmReleases (cluster-agnostic)
│   ├── cilium/
│   ├── cert-manager/
│   ├── rook-ceph-operator/
│   └── ...
│
├── infrastructure/             # Platform capabilities (composed from bases)
│   ├── networking/
│   │   ├── cilium/            # References bases/cilium + cluster config
│   │   ├── coredns/
│   │   └── spegel/
│   ├── security/
│   │   ├── cert-manager/
│   │   ├── external-secrets/
│   │   └── rbac/
│   └── storage/
│       ├── rook-ceph/
│       └── openebs/
│
├── workloads/                  # Applications
│   ├── platform/              # Platform services (databases, observability)
│   │   ├── databases/
│   │   │   ├── cloudnative-pg/
│   │   │   └── dragonfly/
│   │   └── observability/
│   │       ├── victoria-metrics/
│   │       ├── victoria-logs/
│   │       └── fluent-bit/
│   └── tenants/               # User applications
│       └── gitlab/
│
└── clusters/                   # Flux entry points (per-cluster)
    ├── infra/
    │   ├── flux-system/
    │   ├── infrastructure.yaml    # Kustomization with postBuild.substitute
    │   └── workloads.yaml
    └── apps/
        ├── flux-system/
        ├── infrastructure.yaml
        └── workloads.yaml
```

## How Variable Substitution Works

Each cluster defines its own variables in `clusters/<name>/infrastructure.yaml`:

**Example: `clusters/infra/infrastructure.yaml`**
```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
spec:
  path: ./kubernetes/infrastructure
  postBuild:
    substitute:
      CLUSTER: infra
      CLUSTER_ID: "1"
      POD_CIDR: "10.244.0.0/16"
      SERVICE_CIDR: "10.245.0.0/16"
      CLUSTERMESH_IP: "10.25.11.100"
      CILIUM_BGP_LOCAL_ASN: "64512"
      # ... 30+ more variables
```

**Example: `clusters/apps/infrastructure.yaml`**
```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
spec:
  path: ./kubernetes/infrastructure
  postBuild:
    substitute:
      CLUSTER: apps
      CLUSTER_ID: "2"
      POD_CIDR: "10.246.0.0/16"
      SERVICE_CIDR: "10.247.0.0/16"
      CLUSTERMESH_IP: "10.25.11.150"
      CILIUM_BGP_LOCAL_ASN: "64513"
      # ... different values for apps cluster
```

**Same manifests + different variables = cluster-specific deployments.**

## Benefits of This Pattern

1. **DRY (Don't Repeat Yourself):** Single source of truth for each component
2. **Easy scaling:** Add third cluster by creating `clusters/staging/` with new variables
3. **Clear differences:** Variables explicitly show what differs between clusters
4. **Standard pattern:** Follows FluxCD multi-cluster best practices
5. **Reduced maintenance:** Update one file instead of per-cluster copies

## Deployment Flow

```
1. Flux bootstraps: flux bootstrap github --path=clusters/infra
   ↓
2. Flux reads: clusters/infra/infrastructure.yaml
   ↓
3. Flux applies: kubernetes/infrastructure/ with variable substitution
   ↓
4. Components reference: kubernetes/bases/ for shared HelmReleases
   ↓
5. Result: Infra-specific deployment from shared manifests
```

## Impact on Stories

**Stories that say "Deploy on Apps Cluster":**
- **Old approach:** Copy configs, change values, apply to apps
- **New approach:** Already deployed! Shared configs + different variables

**Example:** Story 4.4 (Deploy OpenEBS on Apps)
- Configs in `kubernetes/infrastructure/storage/openebs/` deploy to **BOTH** clusters
- No separate files needed for apps cluster
- Apps cluster just uses different `CLUSTER` variable value

---
