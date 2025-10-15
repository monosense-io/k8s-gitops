# Greenfield Bootstrap - Quick Start

**For detailed guide, see [BOOTSTRAP-GUIDE.md](./BOOTSTRAP-GUIDE.md)**

## Prerequisites

```bash
# Verify tools
helmfile --version
kubectl version --client
op --version  # Optional: 1Password CLI

# Verify cluster access
kubectl cluster-info
```

## Bootstrap in 3 Steps

### Step 1: Apply Prerequisites

```bash
# Option A: Using 1Password CLI (recommended)
op inject -i bootstrap/prerequisites/resources.yaml | kubectl apply -f -

# Option B: Manual (edit file first)
kubectl apply -f bootstrap/prerequisites/resources.yaml
```

### Step 2: Run Helmfile Bootstrap

```bash
# Navigate to bootstrap directory
cd bootstrap

# For INFRA cluster
helmfile -e infra sync

# For APPS cluster
helmfile -e apps sync
```

### Step 3: Validate

```bash
# Run validation script
./validate.sh

# Check Flux
flux get all -A --watch
```

## What Gets Installed

1. **Cilium** (CNI) - Pod networking
2. **CoreDNS** - DNS resolution
3. **Spegel** - Registry mirror
4. **cert-manager** - Certificates
5. **external-secrets** - Secret management
6. **flux-operator** - Flux lifecycle
7. **flux-instance** - Flux controllers

## Expected Timeline

- Prerequisites: ~1 minute
- Helmfile sync: ~5-10 minutes
- Full reconciliation: ~10-15 minutes

## Monitoring Progress

```bash
# Watch all pods
watch -n 2 'kubectl get pods -A'

# Watch Flux
flux get kustomizations --watch

# Check specific component
kubectl get pods -n flux-system
kubectl get fluxinstance -n flux-system flux
```

## Troubleshooting

### Helmfile Fails

```bash
# Check specific release
helmfile -e infra status

# Re-sync failed release
helmfile -e infra -l name=<release> sync
```

### Flux Not Starting

```bash
# Check operator logs
kubectl logs -n flux-system deployment/flux-operator

# Check instance
kubectl describe fluxinstance -n flux-system flux
```

### GitRepository Not Syncing

```bash
# Check status
kubectl describe gitrepository -n flux-system flux-system

# Force reconcile
flux reconcile source git flux-system
```

## Post-Bootstrap

```bash
# Verify everything is ready
./validate.sh

# Configure GitHub webhook (optional)
# See BOOTSTRAP-GUIDE.md Step 6

# Monitor infrastructure deployment
flux get kustomizations
kubectl get helmreleases -A
```

## Quick Commands Reference

```bash
# Flux status
flux check
flux get all -A

# Force reconciliation
flux reconcile kustomization <name> --with-source

# View logs
flux logs --all-namespaces --follow

# Suspend/Resume
flux suspend kustomization <name>
flux resume kustomization <name>
```

## Success Indicators

✅ All helmfile releases deployed
✅ flux-operator running
✅ flux-instance ready
✅ All 6 Flux controllers running
✅ GitRepository synced
✅ Kustomizations reconciling
✅ No failing resources

## Need Help?

- Detailed guide: [BOOTSTRAP-GUIDE.md](./BOOTSTRAP-GUIDE.md)
- Troubleshooting: [BOOTSTRAP-GUIDE.md](./BOOTSTRAP-GUIDE.md#troubleshooting)
- Migration plan: [../docs/flux-operator-migration-plan.md](../docs/flux-operator-migration-plan.md)

---

**Next:** Configure webhook, deploy workloads, set up monitoring
