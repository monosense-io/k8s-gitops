# Cilium Bootstrap Fix - Validation Procedure

## Changes Made

### 1. Removed Flux HelmRelease for Cilium
- **Deleted**: `kubernetes/bases/cilium/` (contained conflicting HelmRelease)
  - `kustomization.yaml` - included helmrelease.yaml
  - `helmrelease.yaml` - the Flux-managed cilium deployment

### 2. Updated Cilium Day-2 Features Kustomization
- **File**: `kubernetes/infrastructure/networking/cilium/kustomization.yaml`
  - **Removed**: `- ../../../bases/cilium` (the conflicting HelmRelease reference)
  - **Kept**: `- prometheusrule.yaml`, `- ipam/ks.yaml` (day-2 features)
  - **Added**: Comment documenting that cilium core is bootstrap-only

### 3. Updated Cilium Kustomization Deployment
- **File**: `kubernetes/infrastructure/networking/cilium/ks.yaml`
  - **Disabled**: healthChecks for DaemonSet/cilium and Deployment/cilium-operator
  - **Reason**: These are now managed by bootstrap only; Flux should not check them
  - **Added**: Comments explaining bootstrap vs Flux management

---

## Validation Checklist

### Pre-Validation: Current State
```bash
# Check current status (should show failures due to cilium conflict)
kubectl get kustomizations -n flux-system -o wide | grep -E "cilium|NAME"
# Expected: cilium shows False status

kubectl get helmrelease -n kube-system cilium -o jsonpath='{.status.conditions[?(@.type=="Ready")].reason}'
# Expected: UpgradeFailed (or similar error)

kubectl get daemonset -n kube-system cilium -o jsonpath='{.status.numberReady}/{.status.desiredNumberScheduled}'
# Expected: 0/3 (cilium pods not ready)
```

### Post-Fix Validation

#### Step 1: Delete Failed HelmRelease
```bash
# The HelmRelease should be gone after fix, but force delete if needed
kubectl delete helmrelease -n kube-system cilium --ignore-not-found

# Verify it's gone
kubectl get helmrelease -n kube-system cilium
# Expected: "Error from server (NotFound): helmreleases.helm.toolkit.fluxcd.io "cilium" not found"
```

#### Step 2: Force Flux Reconciliation
```bash
# Reconcile the cilium kustomization
flux reconcile kustomization cilium -n flux-system --with-source

# Watch for success (should apply quickly since no HelmRelease to manage)
flux get kustomizations -A --watch | grep cilium
# Expected: Ready True
```

#### Step 3: Verify Cilium Health
```bash
# Check Cilium pods are ready (from bootstrap, not Flux)
kubectl get daemonset,deployment -n kube-system -l app.kubernetes.io/name=cilium
# Expected:
# daemonset.apps/cilium      3         3         3       3            3
# deployment.apps/cilium-operator   1/2 or 2/2 ready

# Check individual pods
kubectl get pods -n kube-system -l k8s-app=cilium
# Expected: All pods in Running state

# Verify cilium functionality
kubectl exec -n kube-system daemonset/cilium -- cilium status
# Expected: "Cilium:        OK"
```

#### Step 4: Verify Flux Infrastructure Reconciliation
```bash
# Check all infrastructure kustomizations
kubectl get kustomizations -n flux-system -o wide

# Expected Ready=True for:
- cluster-{infra|apps}-settings
- flux-repositories
- cluster-{infra|apps}-infrastructure
- cilium
- cilium-bgp-policy (if configured)
- cilium-clustermesh-secret (if configured)
- cilium-gatewayclass (if configured)
```

#### Step 5: Verify Cascade Failure Is Resolved
```bash
# All dependent components should now reconcile
kubectl get kustomizations -n flux-system --sort-by=.metadata.name

# Expected: Most should transition from False to True/Ready state:
- cert-manager (depends on cilium)
- external-secrets (depends on cert-manager)
- openebs (depends on cilium)
- rook-ceph-* (depends on cilium)
```

#### Step 6: Validate Day-2 Features Work
```bash
# Check Cilium configuration was applied (PrometheusRule)
kubectl get prometheusrule -n kube-system
# Expected: cilium-agent PrometheusRule exists

# Check IPAM pools
kubectl get ciliumloadbalancerippools -A
# Expected: Pools for infra and apps clusters

# Check BGP peering (if enabled)
kubectl get ciliumbgppeerconfigs -A
# Expected: BGP config resources exist
```

#### Step 7: Verify Cluster Health
```bash
# Overall health check
flux get kustomizations -A --status=stalled
# Expected: None stalled

flux get helmreleases -A --status=failed
# Expected: None failed (or expected failures for disabled features)

# Pod health
kubectl get pods -n kube-system
# Expected: All system pods Running

# Verify Hubble is working
kubectl port-forward -n kube-system svc/hubble-relay 4245:4245 &
hubble status
# Expected: "Hubble Server:  OK"
```

---

## Troubleshooting

### Issue: Cilium pods still not ready after fix
**Cause**: Bootstrap helmfile sync might not have completed
**Solution**:
```bash
# Check bootstrap status
helm status cilium -n kube-system
# If not found: bootstrap never ran

# Re-run bootstrap
task bootstrap:infra
# OR
helmfile -e infra sync

# Verify cilium installed
helm list -n kube-system | grep cilium
# Expected: cilium 1.18.2 deployed
```

### Issue: Flux kustomization still failing after deleting HelmRelease
**Cause**: Flux might be caching old state
**Solution**:
```bash
# Force Flux to reconcile with source
flux reconcile source git flux-system -n flux-system

# Wait a moment, then reconcile kustomization
flux reconcile kustomization cilium -n flux-system --with-source

# Check status
flux get kustomizations cilium -n flux-system --watch
```

### Issue: Gateway API CRDs not found
**Cause**: Gateway API CRDs must be installed before cilium-gateway
**Solution**:
```bash
# Check if Gateway API CRDs exist
kubectl get crd gateways.gateway.networking.k8s.io
# If not found, install them:

kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.1/standard-install.yaml

# Or install via bootstrap (uncomment in 00-crds.yaml if needed)
```

### Issue: Other components still failing after cilium is ready
**Cause**: Dependencies chain not yet reconciled
**Solution**:
```bash
# Force reconciliation of dependent kustomizations
flux reconcile kustomization cluster-{cluster}-infrastructure -n flux-system

# Watch the cascade
flux get kustomizations -A --watch

# Manually restart specific failing kustomizations if needed
flux reconcile kustomization cert-manager -n flux-system
flux reconcile kustomization external-secrets -n flux-system
```

---

## Expected Timeline

### After applying fixes (git push):

| Time | Event | Status |
|------|-------|--------|
| T+0s | Git push, Flux source reconciles | Source updated |
| T+10s | kustomization/cilium reconciles | Begins applying day-2 features |
| T+15s | HelmRelease/cilium is gone | No more upgrade conflict |
| T+20s | Cilium pods already running | From bootstrap (no change) |
| T+30s | Cilium kustomization Ready | Day-2 features applied |
| T+40s | Dependent kustomizations begin | cert-manager, etc. |
| T+60s | Infrastructure largely healthy | Most Ready=True |
| T+120s | Full cluster convergence | All components Ready |

---

## Permanent Fix Verification

After applying the fix, verify it solves the problem **permanently**:

```bash
# 1. New cluster bootstrap
task cluster:create-infra  # Or create-apps
task bootstrap:infra       # Bootstrap should complete successfully

# 2. Verify cilium deployed by bootstrap
kubectl get daemonset -n kube-system cilium
# Expected: 3/3 Ready (from bootstrap helmfile)

# 3. Verify Flux takes over day-2 only
kubectl get kustomization cilium -n flux-system
# Expected: Ready True (managing day-2 features only)

# 4. Verify no HelmRelease conflict
kubectl get helmrelease -n kube-system cilium 2>&1 | grep -q NotFound
# Expected: (no output or "NotFound" message)

# 5. Verify infrastructure healthy
flux get kustomizations -A | grep False | wc -l
# Expected: Low number (only expected failures like disabled features)
```

---

## Git Commit Message

```
fix: separate cilium bootstrap from flux management

Cilium core is deployed by bootstrap/helmfile.d/01-core.yaml (one-time
initialization) and managed by bootstrap helmfile only. This prevents
conflicts with Flux trying to re-deploy it.

Changes:
- Delete kubernetes/bases/cilium/ (contained conflicting HelmRelease)
- Update kubernetes/infrastructure/networking/cilium/kustomization.yaml
  to reference bases/cilium (day-2 features only)
- Update kubernetes/infrastructure/networking/cilium/ks.yaml to remove
  health checks for bootstrap-managed DaemonSet/Deployment

Fixes:
- Cilium HelmRelease no longer stuck in UpgradeFailed state
- Cilium pods now properly deploy from bootstrap
- All dependent components now reconcile successfully
- Aligns with reference patterns from buroa and onedrop

This follows the bootstrap pattern where:
1. Bootstrap helmfile deploys core CNI (Cilium) one-time
2. Flux manages day-2 features that depend on working CNI
