# EPIC-3: GitOps Foundation
**Goal:** Bootstrap FluxCD on both clusters
**Status:** ✅ 70% Complete (ready for bootstrap, not deployed)

## Story 3.1: Create FluxCD Repository Structure ✅
**Priority:** P0 | **Points:** 5 | **Days:** 1 | **Status:** ✅ COMPLETE

**Acceptance Criteria:**
- [x] FluxCD directory structure created using shared-base pattern
- [x] `kubernetes/bases/` created with shared HelmReleases
- [x] `kubernetes/infrastructure/` created with platform capabilities
- [x] `kubernetes/workloads/` created with application manifests
- [x] `clusters/infra/` and `clusters/apps/` created with Flux entry points
- [x] `infrastructure.yaml` and `workloads.yaml` created for each cluster
- [x] `postBuild.substitute` variables defined
- [x] Base configs reusable across clusters

**Directory Structure Created:**
```
kubernetes/
├── bases/                          # ✅ Shared HelmReleases
│   ├── cilium/
│   ├── cert-manager/
│   ├── coredns/
│   ├── external-secrets/
│   ├── fluent-bit/
│   ├── flux/
│   ├── openebs/
│   ├── rook-ceph-cluster/
│   ├── rook-ceph-operator/
│   ├── spegel/
│   ├── victoria-logs/
│   └── victoria-metrics-stack/
│
├── infrastructure/                  # ✅ Platform capabilities
│   ├── gitops/
│   │   └── flux/
│   ├── networking/
│   │   ├── cilium/
│   │   ├── coredns/
│   │   └── spegel/
│   ├── security/
│   │   ├── cert-manager/
│   │   ├── external-secrets/
│   │   └── rbac/
│   └── storage/
│       ├── openebs/
│       └── rook-ceph/
│
├── workloads/                       # ✅ Applications
│   ├── platform/
│   │   ├── databases/
│   │   │   ├── cloudnative-pg/
│   │   │   └── dragonfly/
│   │   ├── mesh-demo/
│   │   └── observability/
│   │       ├── fluent-bit/
│   │       ├── victoria-logs/
│   │       └── victoria-metrics/
│   └── tenants/
│       └── gitlab/
│
└── clusters/                        # ✅ Flux entry points
    ├── infra/
    │   ├── flux-system/
    │   │   ├── gotk-sync.yaml       # ✅ Created (points to main branch)
    │   │   └── kustomization.yaml
    │   ├── infrastructure.yaml       # ✅ Created (with 60+ variables)
    │   ├── workloads.yaml            # ✅ Created
    │   └── kustomization.yaml
    └── apps/
        ├── flux-system/
        │   ├── gotk-sync.yaml
        │   └── kustomization.yaml
        ├── infrastructure.yaml
        ├── workloads.yaml
        └── kustomization.yaml
```

**Tasks:**
- ✅ Structure created (verify with `tree kubernetes/`)
- ✅ Document structure in `kubernetes/STRUCTURE.md`
- ✅ Verify shared bases reference pattern
- ✅ Verify variable substitution in cluster files

**Key Differences from Original Epic:**
- **Old approach:** `kubernetes/infra/base/` and `kubernetes/apps/base/` (separate configs)
- **New approach:** `kubernetes/bases/` + `kubernetes/infrastructure/` (shared configs)
- **Why better:** DRY principle, single source of truth, standard Flux pattern

---

## Story 3.2: Bootstrap FluxCD on Infra Cluster
**Priority:** P0 | **Points:** 3 | **Days:** 1 | **Status:** 🔲 READY TO DEPLOY

**Acceptance Criteria:**
- [x] `clusters/infra/flux-system/gotk-sync.yaml` created
- [ ] FluxCD installed on infra cluster
- [ ] GitHub repository connected
- [ ] Flux sync verified
- [ ] All Flux controllers healthy
- [ ] Flux can reconcile manifests from `kubernetes/clusters/infra/`

**Tasks:**
- Install Flux CLI (if not installed):
  ```bash
  brew install fluxcd/tap/flux
  ```

- **Bootstrap Flux:**
  ```bash
  flux bootstrap github \
    --owner=monosense-io \
    --repository=k8s-gitops \
    --branch=main \
    --path=kubernetes/clusters/infra \
    --context=infra \
    --personal
  ```

- **Verify installation:**
  ```bash
  flux check --context infra
  kubectl --context infra get pods -n flux-system
  ```

- **Verify Flux reconciliation:**
  ```bash
  flux get kustomizations --context infra
  flux logs --follow --context infra
  ```

- **Verify infrastructure deployment:**
  ```bash
  kubectl --context infra get pods -n kube-system  # Should see Cilium, CoreDNS
  kubectl --context infra get helmreleases -A
  ```

**Files Created:**
- ✅ `kubernetes/clusters/infra/flux-system/gotk-sync.yaml` (pre-created)
- 🔲 `kubernetes/clusters/infra/flux-system/gotk-components.yaml` (created by flux bootstrap)
- 🔲 `kubernetes/clusters/infra/flux-system/kustomization.yaml` (created by flux bootstrap)

**Post-Bootstrap:**
- Flux controllers running in `flux-system` namespace
- GitRepository source created pointing to this repo
- Kustomizations created for infrastructure and workloads
- All infrastructure components deploy automatically

---

## Story 3.3: Bootstrap FluxCD on Apps Cluster
**Priority:** P0 | **Points:** 3 | **Days:** 1 | **Status:** 🔲 READY TO DEPLOY

**Acceptance Criteria:**
- [x] `clusters/apps/flux-system/gotk-sync.yaml` created
- [ ] FluxCD installed on apps cluster
- [ ] GitHub repository connected
- [ ] Flux sync verified
- [ ] All Flux controllers healthy

**Tasks:**
- **Bootstrap Flux on apps cluster:**
  ```bash
  flux bootstrap github \
    --owner=monosense-io \
    --repository=k8s-gitops \
    --branch=main \
    --path=kubernetes/clusters/apps \
    --context=apps \
    --personal
  ```

- **Verify:**
  ```bash
  flux check --context apps
  kubectl --context apps get pods -n flux-system
  flux get kustomizations --context apps
  ```

- **Verify apps cluster deployment:**
  ```bash
  kubectl --context apps get pods -n kube-system  # Should see Cilium
  kubectl --context apps get helmreleases -A
  ```

**Files Created:**
- ✅ `kubernetes/clusters/apps/flux-system/gotk-sync.yaml` (pre-created)
- 🔲 `kubernetes/clusters/apps/flux-system/gotk-components.yaml` (created by bootstrap)

---
