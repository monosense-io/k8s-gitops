# Flux Repositories

Centralized Helm chart source management for all infrastructure and workload deployments.

## 📁 Structure

```
repositories/
├── [removed] ks.yaml          # Removed to avoid duplication; clusters reconcile this path directly
├── kustomization.yaml         # Root kustomization
├── oci/                       # OCI registry sources (6 charts)
│   ├── cert-manager.yaml
│   ├── cilium.yaml
│   ├── coredns.yaml
│   ├── external-secrets.yaml
│   ├── spegel.yaml
│   └── victoria-metrics.yaml
└── helm/                      # Traditional Helm repositories (4 charts)
    ├── fluent.yaml
    ├── gitlab.yaml
    ├── openebs.yaml
    └── rook-ceph.yaml
```

## 🎯 Purpose

1. **Single Source of Truth** - All chart sources defined in one place
2. **Consistent Configuration** - Same namespace (flux-system), same interval (12h)
3. **Dependency Management** - Ensures repositories available before infrastructure
4. **Easy Auditing** - `kubectl get ocirepositories,helmrepositories -n flux-system`

## 📊 Chart Sources

### OCI Repositories (Preferred)

| Chart | Registry | Semver Range |
|-------|----------|--------------|
| cert-manager | quay.io/jetstack | >=1.15.0 <2.0.0 |
| cilium | ghcr.io/cilium/charts | >=1.18.0 <1.19.0 |
| coredns | ghcr.io/coredns/charts | >=1.35.0 <2.0.0 |
| external-secrets | ghcr.io/external-secrets/charts | >=0.9.0 <1.0.0 |
| spegel | ghcr.io/onedr0p/charts | >=0.0.27 <1.0.0 |
| victoria-metrics | ghcr.io/victoriametrics/helm-charts | >=0.38.0 <1.0.0 |

**Benefits:**
- ✅ Semver-based auto-updates
- ✅ Faster chart fetching
- ✅ Better caching
- ✅ Native Kubernetes artifact format

### Helm Repositories (Legacy)

| Chart | URL | Reason |
|-------|-----|--------|
| fluent-bit | https://fluent.github.io/helm-charts | No OCI support upstream |
| gitlab | https://charts.gitlab.io/ | No OCI support upstream |
| openebs | https://openebs.github.io/charts | No OCI support upstream |
| rook-ceph | https://charts.rook.io/release | No OCI support upstream |

## 🔄 Dependency Chain

```
cluster-settings (ConfigMap)
      ↓
flux-repositories (wait: true, interval: 1h)
      ↓
cluster-infrastructure (wait: false, interval: 10m)
      ↓
cluster-workloads
```

## 📝 Usage

### Adding New OCI Chart

1. **Create OCIRepository resource:**

```yaml
# kubernetes/infrastructure/repositories/oci/new-chart.yaml
---
apiVersion: source.toolkit.fluxcd.io/v1
kind: OCIRepository
metadata:
  name: new-chart
  namespace: flux-system
spec:
  interval: 12h
  layerSelector:
    mediaType: application/vnd.cncf.helm.chart.content.v1.tar+gzip
    operation: copy
  ref:
    semver: ">=1.0.0 <2.0.0"
  url: oci://ghcr.io/vendor/charts/new-chart
```

2. **Add to oci/kustomization.yaml:**

```yaml
resources:
  # ... existing
  - new-chart.yaml
```

3. **Create HelmRelease with chartRef:**

```yaml
# kubernetes/bases/new-chart/helmrelease.yaml
---
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: new-chart
spec:
  chartRef:
    kind: OCIRepository
    name: new-chart
    namespace: flux-system
  values:
    # ... configuration
```

### Adding New HelmRepository Chart

1. **Create HelmRepository resource:**

```yaml
# kubernetes/infrastructure/repositories/helm/new-repo.yaml
---
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: HelmRepository
metadata:
  name: new-repo
  namespace: flux-system
spec:
  interval: 12h
  url: https://charts.example.com
```

2. **Add to helm/kustomization.yaml:**

```yaml
resources:
  # ... existing
  - new-repo.yaml
```

3. **Create HelmRelease with chart.spec:**

```yaml
# kubernetes/bases/new-chart/helmrelease.yaml
---
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: new-chart
spec:
  chart:
    spec:
      chart: new-chart
      version: 1.0.0
      sourceRef:
        kind: HelmRepository
        name: new-repo
        namespace: flux-system
  values:
    # ... configuration
```

### Migrating HelmRepository → OCI

When upstream adds OCI support:

1. **Create OCIRepository** (as shown above)
2. **Update HelmRelease:**

```yaml
# Before
spec:
  chart:
    spec:
      chart: new-chart
      version: 1.0.0
      sourceRef:
        kind: HelmRepository
        name: new-repo
        namespace: flux-system

# After
spec:
  chartRef:
    kind: OCIRepository
    name: new-chart
    namespace: flux-system
```

3. **Remove HelmRepository** (if no longer used)
4. **Test in non-production cluster first**

## 🔍 Validation

```bash
# Validate entire repositories structure
kustomize build kubernetes/infrastructure/repositories

# Validate OCI repositories only
kustomize build kubernetes/infrastructure/repositories/oci

# Validate Helm repositories only
kustomize build kubernetes/infrastructure/repositories/helm

# List all repository resources
kustomize build kubernetes/infrastructure/repositories | \
  yq e 'select(.kind == "OCIRepository" or .kind == "HelmRepository") | .metadata.name' -
```

## 📈 Monitoring

```bash
# Check flux-repositories Kustomization status
kubectl get kustomization -n flux-system flux-repositories

# List all OCI repositories
kubectl get ocirepositories -n flux-system

# List all Helm repositories
kubectl get helmrepositories -n flux-system

# Check specific repository status
kubectl describe ocirepository cert-manager -n flux-system
kubectl describe helmrepository openebs -n flux-system

# Force reconciliation
flux reconcile kustomization flux-repositories --with-source
```

## 🎨 Best Practices

1. **Prefer OCI over Helm** - Use OCIRepository when available
2. **Use semver ranges** - Enable automatic patch/minor updates
3. **12-hour intervals** - Balance freshness with API load
4. **Centralize in flux-system** - Single namespace for all repositories
5. **Document upstream status** - Track when charts add OCI support
6. **Test in apps cluster** - Validate changes before production

## 📚 References

- [Phase 4 Implementation Summary](../../../docs/PHASE4-IMPLEMENTATION-SUMMARY.md)
- [Flux OCIRepository API](https://fluxcd.io/flux/components/source/ocirepositories/)
- [Flux HelmRepository API](https://fluxcd.io/flux/components/source/helmrepositories/)
- [Migration Plan](../../../docs/flux-operator-migration-plan.md)
