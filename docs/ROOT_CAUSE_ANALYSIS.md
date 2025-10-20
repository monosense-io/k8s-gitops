# Root Cause Analysis: Cilium Bootstrap Failure

## Executive Summary

**Critical Issue Found**: Cilium is being managed by **TWO conflicting controllers**:
1. ✓ **Bootstrap helmfile** (`bootstrap/helmfile.d/01-core.yaml`) - Deploys cilium via helmfile
2. ✗ **Flux Kustomization** (`kubernetes/infrastructure/networking/cilium/ks.yaml`) - Tries to re-deploy cilium via Flux HelmRelease

This dual management causes **cilium deployment to fail permanently**, cascading failures across the entire cluster.

**Status**: INFRA CLUSTER - cilium HelmRelease stuck in UpgradeFailed state
**Status**: APPS CLUSTER - Same issue

---

## Root Cause: Dual Cilium Management

### Current (Broken) Architecture

```
bootstrap/helmfile.d/01-core.yaml
  ├─ Deploy Cilium v1.18.2 via helmfile
  │  └─ Post-sync hook: rollout status daemonset/cilium
  │
  └─ Deploy flux-instance
     └─ Post-sync hook: Apply kubernetes/clusters/{cluster}/flux-system/gotk-sync.yaml

kubernetes/clusters/{cluster}/infrastructure.yaml
  └─ Apply Kustomization: kubernetes/infrastructure/networking/cilium/ks.yaml
     └─ Manage Cilium via Flux HelmRelease (CONFLICT!)
        └─ Tries to upgrade already-deployed Cilium
           └─ Timeout: "context deadline exceeded"
           └─ cilium pods remain NOT READY
```

### Reference Pattern (Correct)

```
bootstrap/helmfile.d/01-core.yaml
  ├─ Deploy Cilium v1.18.2 via helmfile
  │  └─ Post-sync hook: rollout status daemonset/cilium
  │
  └─ Cilium deployment COMPLETE - no further Flux management

kubernetes/clusters/{cluster}/infrastructure.yaml
  ├─ Apply Kustomization: kubernetes/infrastructure/networking/cilium/ks.yaml
  │  └─ Day-2 features ONLY (BGP policies, ClusterMesh, Gateway API, IPAM)
  │     └─ These depend on Cilium already being running from bootstrap
  │
  └─ NO HelmRelease for Cilium core
```

---

## Evidence of Dual Management

### 1. Bootstrap Helmfile Deploys Cilium

**File**: `bootstrap/helmfile.d/01-core.yaml.gotmpl:37-62`
```yaml
releases:
  # 1. Cilium CNI + Service Mesh - MUST BE FIRST
  - name: cilium
    namespace: kube-system
    chart: cilium/cilium
    version: 1.18.2
    values:
      - ../clusters/{{ .Environment.Name }}/cilium-values.yaml
    set:
      - name: k8sServiceHost
        value: {{ .Values.k8sServiceHost }}
    hooks:
      - events: ['postsync']
        showlogs: true
        command: kubectl
        args:
          - rollout
          - status
          - daemonset/cilium
          - -n
          - kube-system
          - --timeout=300s
```

✓ **This is CORRECT** - cilium deployed via helmfile bootstrap

### 2. Flux Also Manages Cilium (THE PROBLEM)

**File**: `kubernetes/infrastructure/networking/cilium/ks.yaml:1-39`
```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: cilium
  namespace: flux-system
spec:
  path: ./kubernetes/infrastructure/networking/cilium
  targetNamespace: kube-system
  healthChecks:
    - apiVersion: apps/v1
      kind: DaemonSet
      name: cilium
      namespace: kube-system
    - apiVersion: apps/v1
      kind: Deployment
      name: cilium-operator
      namespace: kube-system
```

**File**: `kubernetes/infrastructure/networking/cilium/kustomization.yaml:1-8`
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../../../bases/cilium        # ← This references the HelmRelease!
  - prometheusrule.yaml
  - ipam/ks.yaml
```

**File**: `kubernetes/bases/cilium/helmrelease.yaml`
```yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: cilium
spec:
  chart:
    spec:
      chart: cilium
      version: 1.18.2
      ...
```

✗ **This is the PROBLEM** - Flux tries to manage cilium that's already managed by helmfile

### 3. Proof: HelmRelease Status

**Output**: `kubectl get helmrelease -n kube-system cilium`
```
Status: UpgradeFailed
Reason: Helm upgrade failed with chart cilium@1.18.2: context deadline exceeded
```

The HelmRelease is trying to **upgrade** cilium, meaning it sees the deployment already exists and tries to modify it. But since the pods are stuck in pending state (due to networking not ready), the upgrade times out.

---

## Cascade Failure Chain

```
Cilium HelmRelease UpgradeFailed (stuck in 10m timeout)
  ↓
Cilium DaemonSet Pods NOT READY (0/3 ready)
  ↓
Cilium health check fails
  ↓
Kustomization "cilium" status: False
  └─ "health check failed after 14.426603ms: failed early due to stalled resources"
  ↓
ALL components that depend on cilium fail:
  ├─ cert-manager (depends on cilium)
  ├─ external-secrets (depends on cilium)
  ├─ cilium-bgp-policy (depends on cilium)
  ├─ cilium-clustermesh-secret (depends on cilium)
  ├─ cilium-gatewayclass (depends on cilium)
  ├─ openebs (depends on cilium)
  ├─ rook-ceph-* (depends on cilium)
  └─ ALL other infrastructure and workloads
```

**Result**: Complete cluster infrastructure failure cascading from single cilium management conflict.

---

## The Fix: Separate Cilium Core from Day-2 Features

### Step 1: Remove Cilium Core from Flux Management

**Remove cilium HelmRelease** from `kubernetes/bases/cilium/`

The `kubernetes/bases/cilium/` should NOT contain a HelmRelease. It should only contain:
- Configuration snippets for cilium
- Day-2 feature definitions
- Dependency declarations

**Option A: Delete the directory entirely**
```bash
rm -rf kubernetes/bases/cilium/
```

OR

**Option B: Keep only non-HelmRelease content** (if any exists)
```bash
# After reviewing what's in there, remove only the helmrelease.yaml
```

### Step 2: Update Cilium Kustomization to Reference Day-2 Features Only

**File**: `kubernetes/infrastructure/networking/cilium/kustomization.yaml` (AFTER FIX)
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

# DON'T include the helmrelease from bases/cilium
# Instead, include ONLY day-2 configuration resources
resources:
  - prometheusrule.yaml
  - ipam/ks.yaml

# Eventually add:
  # - bgp/ks.yaml
  # - clustermesh/ks.yaml
  # - gateway/ks.yaml
```

### Step 3: Update cilium Kustomization Dependencies

**File**: `kubernetes/infrastructure/networking/cilium/ks.yaml` (AFTER FIX)
```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: cilium
  namespace: flux-system
spec:
  path: ./kubernetes/infrastructure/networking/cilium
  targetNamespace: kube-system
  # IMPORTANT: Remove healthChecks for Cilium pods
  # (they're managed by bootstrap, not Flux)
  # healthChecks:
  #   - apiVersion: apps/v1
  #     kind: DaemonSet
  #     name: cilium
  #     namespace: kube-system
  #   - apiVersion: apps/v1
  #     kind: Deployment
  #     name: cilium-operator
  #     namespace: kube-system
```

### Step 4: Verify Bootstrap Helmfile is Correct

**File**: `bootstrap/helmfile.d/01-core.yaml.gotmpl` - ALREADY CORRECT ✓
- Cilium deployed with proper dependencies
- Post-sync hook ensures cilium is ready before flux-instance starts
- Flux-instance then takes over managing day-2 features

---

## Implementation Plan

### Phase 1: Fix Cilium Management Architecture

1. **Backup current state**
   ```bash
   git checkout -b fix/cilium-dual-management
   ```

2. **Remove Cilium HelmRelease from Flux**
   ```bash
   # Identify what to remove
   cat kubernetes/bases/cilium/helmrelease.yaml

   # Option: Delete entire directory
   rm -rf kubernetes/bases/cilium/

   # OR Option: Keep the directory but remove helmrelease.yaml
   rm kubernetes/bases/cilium/helmrelease.yaml
   ```

3. **Update Cilium Kustomization**
   ```yaml
   # kubernetes/infrastructure/networking/cilium/kustomization.yaml
   # Remove: - ../../../bases/cilium
   # Keep: - prometheusrule.yaml, ipam/ks.yaml, etc.
   ```

4. **Clean up Cilium Kustomization status checks**
   ```yaml
   # kubernetes/infrastructure/networking/cilium/ks.yaml
   # Remove healthChecks for DaemonSet/cilium and Deployment/cilium-operator
   ```

5. **Test on infra cluster**
   ```bash
   # Force Flux reconciliation
   flux reconcile kustomization cilium -n flux-system --with-source

   # Verify cilium pods remain ready (deployed by bootstrap)
   kubectl get daemonset -n kube-system cilium

   # Verify day-2 features work (from Flux)
   kubectl get ciliumbgppeering -A
   kubectl get ciliumloadbalancerippools -A
   ```

### Phase 2: Fix Apps Cluster

1. **Apply same changes to apps cluster configuration**
   ```bash
   # Apps cluster uses same kubernetes/infrastructure structure
   # So fixes apply automatically after git push
   ```

2. **Bootstrap apps cluster if needed**
   ```bash
   task bootstrap:apps
   ```

### Phase 3: Validation

1. **Verify Cilium health**
   ```bash
   kubectl get daemonset,deployment -n kube-system -l app.kubernetes.io/name=cilium
   kubectl get pods -n kube-system -l k8s-app=cilium
   kubectl exec -n kube-system cilium-xxx -- cilium status
   ```

2. **Verify Flux dependencies resolve**
   ```bash
   kubectl get kustomizations -n flux-system
   # All should show Ready: True or correct dependency status
   ```

3. **Verify infrastructure deployment**
   ```bash
   flux get kustomizations -A
   flux get helmreleases -A
   ```

---

## Root Cause Summary

| Aspect | Current (Wrong) | Reference (Right) |
|--------|-----------------|------------------|
| Cilium Deployment | Bootstrap helmfile | ✓ Bootstrap helmfile |
| Cilium Flux Management | HelmRelease in kubernetes/bases/cilium | ✗ NONE (no HelmRelease) |
| Who manages core cilium | TWO controllers (conflict) | ONE: Bootstrap only |
| Who manages day-2 features | Flux (correct) | Flux (correct) |
| Cilium pods status | 0/3 ready (failed upgrade) | 3/3 ready (bootstrap only) |
| Cluster health | Failed cascades from cilium | All healthy when cilium ready |

---

## Why This Pattern Exists

**Bootstrap helmfile is superior to Flux for core CNI because**:
1. CNI must be ready BEFORE Flux controllers can schedule pods
2. Flux requires functional networking to deploy its controllers
3. Chicken-and-egg problem: Flux can't deploy cilium, but cilium is needed for Flux to run
4. Bootstrap helmfile is a one-time initialization step on bare cluster
5. After bootstrap, Flux takes over day-2 features which DEPEND on Cilium working

**This is documented in the CLAUDE.md file**:
> "Note: cilium is deployed via bootstrap helmfile (not via Flux), day-2 features deployed here"

---

## Conclusion

The issue is **clear and fixable**: Remove cilium HelmRelease from Flux management, keep bootstrap helmfile deployment only, and let Flux manage day-2 features that depend on working Cilium.

This aligns the current implementation with the reference patterns from buroa and onedrop.
