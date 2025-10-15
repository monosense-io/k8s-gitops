# Component Library - Quick Reference Card

## 🚀 Quick Start Template

Copy this template to create a new application:

```yaml
# kubernetes/infrastructure/YOUR-APP/kustomization.yaml
---
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: YOUR-NAMESPACE

components:
  # Core
  - ../../components/namespace

  # High Availability
  - ../../components/pdb-maxunavailable-1

  # Monitoring
  - ../../components/monitoring/servicemonitor
  - ../../components/monitoring/prometheusrule-basic

  # Security (zero-trust)
  - ../../components/networkpolicy/deny-all
  - ../../components/networkpolicy/allow-dns
  - ../../components/networkpolicy/allow-internal

resources:
  - deployment.yaml
  - service.yaml

commonLabels:
  app.kubernetes.io/name: YOUR-APP
```

## 📦 Component Catalog

| Component | What It Does | When To Use |
|-----------|--------------|-------------|
| `namespace` | Creates namespace with restricted PSS | ✅ All apps |
| `namespace-privileged` | Creates privileged namespace | System components only |
| `pdb-maxunavailable-1` | Auto-configured PodDisruptionBudget | ✅ HA applications |
| `monitoring/servicemonitor` | Prometheus metrics scraping | ✅ Apps with `/metrics` endpoint |
| `monitoring/podmonitor` | Direct pod metrics | DaemonSets without Service |
| `monitoring/prometheusrule-basic` | Common alert rules | ✅ All apps |
| `externalsecret` | 1Password secret sync | Apps needing secrets |
| `networkpolicy/deny-all` | Block all traffic | ✅ Zero-trust baseline |
| `networkpolicy/allow-dns` | Allow DNS queries | ✅ With deny-all |
| `networkpolicy/allow-internal` | Allow same-namespace traffic | ✅ With deny-all |

## ✅ Requirements Checklist

### For All Components
- [ ] `namespace` field set in kustomization.yaml

### For PDB Component
- [ ] Deployment has `spec.template.metadata.labels.[app.kubernetes.io/name]`
- [ ] At least 2 replicas for HA

### For ServiceMonitor
- [ ] Service exists with `metadata.labels.[app.kubernetes.io/name]`
- [ ] Service has port named `metrics`

### For PodMonitor
- [ ] Workload has `spec.template.metadata.labels.[app.kubernetes.io/name]`
- [ ] Pods expose metrics port

## 🎯 Common Patterns

### Pattern 1: Simple App (No HA)
```yaml
components:
  - ../../components/namespace
  - ../../components/monitoring/servicemonitor
```

### Pattern 2: HA App
```yaml
components:
  - ../../components/namespace
  - ../../components/pdb-maxunavailable-1
  - ../../components/monitoring/servicemonitor
  - ../../components/monitoring/prometheusrule-basic
```

### Pattern 3: Secure HA App (Recommended)
```yaml
components:
  - ../../components/namespace
  - ../../components/pdb-maxunavailable-1
  - ../../components/monitoring/servicemonitor
  - ../../components/monitoring/prometheusrule-basic
  - ../../components/networkpolicy/deny-all
  - ../../components/networkpolicy/allow-dns
  - ../../components/networkpolicy/allow-internal
```

### Pattern 4: System DaemonSet
```yaml
components:
  - ../../components/namespace-privileged
  - ../../components/monitoring/podmonitor
```

## 🔧 Common Customizations

### Override PDB maxUnavailable
```yaml
patches:
  - patch: |-
      - op: replace
        path: /spec/maxUnavailable
        value: 2
    target:
      kind: PodDisruptionBudget
```

### Custom ServiceMonitor interval
```yaml
patches:
  - patch: |-
      - op: replace
        path: /spec/endpoints/0/interval
        value: 60s
    target:
      kind: ServiceMonitor
```

### Additional NetworkPolicy
```yaml
resources:
  - custom-networkpolicy.yaml  # Your custom policy
```

## 🐛 Troubleshooting

### PDB Not Created
- ✅ Check Deployment has `app.kubernetes.io/name` label
- ✅ Check `spec.replicas >= 2`
- ✅ Run `kustomize build .` to see generated resources

### ServiceMonitor Not Scraping
- ✅ Check Service has port named `metrics`
- ✅ Check Service has `app.kubernetes.io/name` label
- ✅ Verify metrics endpoint exists: `curl http://pod-ip:port/metrics`

### NetworkPolicy Blocking Traffic
- ✅ Ensure `allow-dns` component is included
- ✅ Add `allow-internal` for same-namespace communication
- ✅ Create custom allow policy for external dependencies

### Build Fails
```bash
# Validate kustomization
kustomize build . --enable-alpha-plugins

# Check for errors
kustomize build . 2>&1 | less
```

## 📝 Validation

```bash
# Build and preview
kustomize build .

# Count resources generated
kustomize build . | grep -c '^kind:'

# Dry-run apply
kustomize build . | kubectl apply --dry-run=client -f -

# Server-side dry-run
kubectl apply --dry-run=server -k .
```

## 📚 More Help

- Full guide: `kubernetes/components/README.md`
- Examples: `kubernetes/infrastructure/*/kustomization.yaml`
- Phase 2 summary: `docs/PHASE2-IMPLEMENTATION-SUMMARY.md`

---

**Keep This Handy!** Bookmark for quick reference when creating new apps.
