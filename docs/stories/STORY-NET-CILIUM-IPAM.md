# 02 — STORY-NET-CILIUM-IPAM — Create Cilium IPAM LoadBalancer Pool Manifests

Sequence: 02/50 | Prev: STORY-NET-CILIUM-CORE-GITOPS.md | Next: STORY-NET-CILIUM-GATEWAY.md
Sprint: 1 | Lane: Networking
Global Sequence: 02/50

Status: Draft (v3.0 Refinement)
Owner: Platform Engineering
Date: 2025-10-26 (v3.0 Refinement)
Links: docs/architecture.md §9; kubernetes/infrastructure/networking/cilium/ipam/

## Story
As a platform engineer, I want to **create Cilium IPAM LoadBalancer pool manifests** for infra and apps clusters with proper pool segmentation and cluster isolation, so that LoadBalancer services receive deterministic IP addresses from cluster-specific pools when deployed in Story 45.

This story creates the declarative CiliumLoadBalancerIPPool manifests. Actual deployment and IP allocation validation happen in Story 45 (VALIDATE-NETWORKING).

## Why / Outcome
- Create IPAM pool manifests with cluster-specific IP ranges
- Configure pool isolation to prevent cross-cluster IP conflicts
- Enable deterministic LoadBalancer IP allocation from dedicated pools
- Align pool definitions with bootstrap configurations and cluster-settings

## Scope

**This Story (Manifest Creation):**
- Create CiliumLoadBalancerIPPool manifests in `kubernetes/infrastructure/networking/cilium/ipam/`
- Create Kustomization for IPAM pools
- Update bootstrap configs if needed: `bootstrap/clusters/{cluster}/cilium-values.yaml`
- Validate pool definitions align with cluster-settings
- Local validation (flux build, kubeconform)

**Deferred to Story 45 (Deployment & Validation):**
- Deploying IPAM pools to clusters
- Verifying pool isolation (disabled flag per cluster)
- Testing LoadBalancer IP allocation
- Cross-cluster reachability validation

## Acceptance Criteria

**Manifest Creation (This Story):**

1) **IPAM Pool Manifests Created:**
   - `kubernetes/infrastructure/networking/cilium/ipam/lb-ippool-infra.yaml` exists
     - Pool name: `infra-pool`
     - CIDR: `10.25.11.100-10.25.11.119` (20 IPs)
     - Disabled condition: `${CLUSTER} != "infra"` (enabled only on infra cluster)
   - `kubernetes/infrastructure/networking/cilium/ipam/lb-ippool-apps.yaml` exists
     - Pool name: `apps-pool`
     - CIDR: `10.25.11.120-10.25.11.139` (20 IPs)
     - Disabled condition: `${CLUSTER} != "apps"` (enabled only on apps cluster)

2) **Kustomization Created:**
   - `kubernetes/infrastructure/networking/cilium/ipam/ks.yaml` exists
   - References both pool manifests
   - Includes dependency on cilium-core
   - `kubernetes/infrastructure/networking/cilium/ipam/kustomization.yaml` glue file exists

3) **Cluster Settings Alignment:**
   - Cluster-settings include IP pool variables (if needed)
   - Bootstrap cilium-values.yaml reference correct IPs:
     - Infra ClusterMesh API: `10.25.11.100` (first IP in infra pool)
     - Apps ClusterMesh API: `10.25.11.120` (first IP in apps pool)
     - Infra Gateway: `10.25.11.110` (within infra pool)
     - Apps Gateway: `10.25.11.121` (within apps pool)

4) **Local Validation Passes:**
   - `flux build kustomization cluster-infra-infrastructure --path ./kubernetes/infrastructure` succeeds
   - `flux build kustomization cluster-apps-infrastructure --path ./kubernetes/infrastructure` succeeds
   - Output shows correct pool substitution for each cluster (infra-pool enabled on infra, apps-pool enabled on apps)
   - `kubeconform --strict` validates IPAM pool manifests

5) **Pool Segmentation Correct:**
   - No IP overlap between pools (100-119 vs 120-139)
   - Each pool contains 20 IPs
   - Pools are within shared L2 subnet `10.25.11.0/24`
   - Pool ranges documented in architecture.md

**Deferred to Story 45 (Deployment & Validation):**
- ❌ IPAM pools deployed to clusters
- ❌ Pool isolation verified (disabled flag working)
- ❌ Services allocating IPs from correct pools
- ❌ Cross-cluster reachability via BGP

## Dependencies / Inputs

**Prerequisites (v3.0):**
- Story 01 (STORY-NET-CILIUM-CORE-GITOPS) complete (Cilium core manifests created)
- Cluster-settings ConfigMaps created (from Story 01 or earlier)
- Access to `docs/architecture.md` for IP allocation plan
- Tools: kubectl (for dry-run), flux CLI, kubeconform

**NOT Required (v3.0):**
- ❌ Cluster access (validation is local-only)
- ❌ BGP peering configured (deployment in Story 45)
- ❌ Running clusters (Story 45 handles deployment)

## Architecture Decision — IP Allocation Plan

**Network Topology:** Shared L2 subnet `10.25.11.0/24`, both clusters peer with BGP router at `10.25.11.1`.

```
10.25.11.0/24 - LoadBalancer Subnet (Shared L2, BGP Advertised)
├── .1          → BGP Router/Peer (ASN 64501)
├── .2-.99      → Static Infrastructure (MinIO .3, etc.)
├── .100-.119   → Infra Cluster LB Pool (20 IPs)
│   ├── .100    → infra-clustermesh-apiserver
│   ├── .110    → infra-gateway (NEW IP, moved from .120)
│   └── .111-.119 → Available for future infra LBs
└── .120-.139   → Apps Cluster LB Pool (20 IPs)
    ├── .120    → apps-clustermesh-apiserver (NEW IP, moved from .101)
    ├── .121    → apps-gateway (existing IP, no change)
    └── .122-.139 → Available for future app LBs
```

**Rationale:**
- Clean pool segmentation (no overlap, no gaps).
- ClusterMesh IPs at start of each pool for easy identification.
- Gateways follow ClusterMesh in sequence.
- ~17 IPs reserved per cluster for future LoadBalancer services.

## Tasks / Subtasks

**T1 — Fix Bootstrap Configuration** (if needed)

- [ ] **Fix apps cluster subnet mismatch** (`bootstrap/clusters/apps/cilium-values.yaml`):
  ```yaml
  # Line 143-144: ClusterMesh API Server
  annotations:
    io.cilium/lb-ipam-ips: "10.25.11.120"  # WAS: 10.25.12.100

  # Line 177-178: Gateway API Envoy
  annotations:
    io.cilium/lb-ipam-ips: "10.25.11.121"  # WAS: 10.25.12.120
  ```
  **Issue:** Apps bootstrap used wrong subnet (10.25.12.x). Architecture requires shared L2 (10.25.11.0/24).

- [ ] **Fix infra gateway IP conflict** (`bootstrap/clusters/infra/cilium-values.yaml`):
  ```yaml
  # Line 177: Gateway API Envoy
  annotations:
    io.cilium/lb-ipam-ips: "10.25.11.110"  # WAS: 10.25.11.120
  ```
  **Issue:** .120 is start of apps pool; infra gateway must be in infra pool (100-119).

**T2 — Create IPAM Pool Manifests with Cluster Isolation**

- [ ] **Update infra pool with disabled flag** (`kubernetes/infrastructure/networking/cilium/ipam/lb-ippool-infra.yaml`):
  ```yaml
  apiVersion: cilium.io/v2alpha1
  kind: CiliumLoadBalancerIPPool
  metadata:
    name: infra-pool
    namespace: kube-system
  spec:
    disabled: ${INFRA_POOL_DISABLED:-false}  # NEW: cluster-controlled
    blocks:
      - start: "10.25.11.100"
        stop: "10.25.11.119"
    serviceSelector: {}  # Default pool when enabled
  ```
  **Issue:** Current `serviceSelector: {}` matches ALL services on BOTH clusters (shared manifest). Need cluster-specific control.

- [ ] **Update apps pool with disabled flag** (`kubernetes/infrastructure/networking/cilium/ipam/lb-ippool-apps.yaml`):
  ```yaml
  apiVersion: cilium.io/v2alpha1
  kind: CiliumLoadBalancerIPPool
  metadata:
    name: apps-pool
    namespace: kube-system
  spec:
    disabled: ${APPS_POOL_DISABLED:-false}  # NEW: cluster-controlled
    blocks:
      - start: "10.25.11.120"
        stop: "10.25.11.139"
    serviceSelector: {}  # Default pool when enabled
  ```
  **Fix:** Remove manual label requirement; use disabled flag for cluster isolation.

**T3 — Update Cluster-Settings with Pool Variables**

- [ ] **Update infra cluster-settings** (`kubernetes/clusters/infra/cluster-settings.yaml`):
  ```yaml
  # Existing Cilium Configuration (update)
  CLUSTERMESH_IP: "10.25.11.100"  # ✅ Already correct
  CILIUM_GATEWAY_LB_IP: "10.25.11.110"  # 🔄 Change from .120

  # NEW: IPAM Pool Control
  INFRA_POOL_DISABLED: "false"
  APPS_POOL_DISABLED: "true"

  # NEW: Pool Range Documentation (informational)
  CILIUM_LB_POOL_START: "10.25.11.100"
  CILIUM_LB_POOL_END: "10.25.11.119"
  ```

- [ ] **Update apps cluster-settings** (`kubernetes/clusters/apps/cluster-settings.yaml`):
  ```yaml
  # Existing Cilium Configuration (update)
  CLUSTERMESH_IP: "10.25.11.120"  # 🔄 Change from .101
  CILIUM_GATEWAY_LB_IP: "10.25.11.121"  # ✅ Already correct

  # NEW: IPAM Pool Control
  INFRA_POOL_DISABLED: "true"
  APPS_POOL_DISABLED: "false"

  # NEW: Pool Range Documentation (informational)
  CILIUM_LB_POOL_START: "10.25.11.120"
  CILIUM_LB_POOL_END: "10.25.11.139"
  ```

**T4 — Create Kustomization for IPAM Pools**
- [ ] Create `kubernetes/infrastructure/networking/cilium/ipam/ks.yaml`:
  - Reference both pool manifests
  - Add dependency on cilium-core
  - Configure health checks (if applicable)
- [ ] Create `kubernetes/infrastructure/networking/cilium/ipam/kustomization.yaml` glue file
- [ ] Update infrastructure kustomization to include IPAM pools

**T5 — Local Validation** (NO Cluster Access)
- [ ] Validate pool manifests:
  ```bash
  # Verify Flux variable substitution works
  flux build kustomization cluster-infra-infrastructure --path ./kubernetes/infrastructure
  flux build kustomization cluster-apps-infrastructure --path ./kubernetes/infrastructure

  # Check YAML syntax
  kubectl --dry-run=client -f kubernetes/infrastructure/networking/cilium/ipam/

  # Verify pool ranges don't overlap
  yq '.spec.blocks[].start, .spec.blocks[].stop' kubernetes/infrastructure/networking/cilium/ipam/*.yaml
  # Expected: 10.25.11.100, 10.25.11.119, 10.25.11.120, 10.25.11.139

  # Verify cluster isolation (disabled flags)
  flux build kustomization cluster-infra-infrastructure --path ./kubernetes/infrastructure | \
    yq 'select(.kind == "CiliumLoadBalancerIPPool")' | grep -A2 disabled
  # Expected: infra-pool disabled=false, apps-pool disabled=true (on infra)
  ```

**T6 — Documentation**
- [ ] Document IP allocation plan in Dev Notes
- [ ] Update architecture.md with pool ranges (if not already documented)
- [ ] Note bootstrap configuration fixes applied

**Runtime Validation (MOVED TO STORY 45):**
```bash
# These commands execute in Story 45, NOT this story:
# - Pool deployment verification
# - Service IP allocation testing
# - Cross-cluster reachability testing
```

- [ ] **BGP reachability test:**
  ```bash
  # From apps cluster, test connectivity to infra ClusterMesh API
  kubectl --context=apps run test-curl --rm -it --image=curlimages/curl -- \
    curl -k https://10.25.11.100:2379/healthz

  # From infra cluster, test connectivity to apps ClusterMesh API
  kubectl --context=infra run test-curl --rm -it --image=curlimages/curl -- \
    curl -k https://10.25.11.120:2379/healthz
  ```

- [ ] **Smoke test with temporary LoadBalancer service** (optional):
  ```bash
  # Create test service on infra cluster
  kubectl --context=infra create -f - <<EOF
  apiVersion: v1
  kind: Service
  metadata:
    name: test-lb-ipam
    namespace: default
  spec:
    type: LoadBalancer
    selector:
      app: nonexistent
    ports:
    - port: 80
  EOF

  # Check allocated IP is in infra pool range (100-119)
  kubectl --context=infra get svc test-lb-ipam -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

  # Cleanup
  kubectl --context=infra delete svc test-lb-ipam
  ```

## Validation Steps

**Flux Reconciliation:**
```bash
flux -n flux-system --context=infra reconcile ks cilium-ipam --with-source
flux -n flux-system --context=apps reconcile ks cilium-ipam --with-source
```

**Pool Status Check:**
```bash
kubectl --context=infra get ciliumloadbalancerippool -A -o wide
kubectl --context=apps get ciliumloadbalancerippool -A -o wide
```

**IP Allocation Verification:**
```bash
# List all LoadBalancer services and their IPs
kubectl --context=infra get svc -A -o wide | grep LoadBalancer
kubectl --context=apps get svc -A -o wide | grep LoadBalancer

# Verify Gateway IPs match cluster-settings
kubectl --context=infra -n flux-system get cm cluster-settings \
  -o jsonpath='{.data.CILIUM_GATEWAY_LB_IP}'
kubectl --context=apps -n flux-system get cm cluster-settings \
  -o jsonpath='{.data.CILIUM_GATEWAY_LB_IP}'
```

**BGP Advertisement Check:**
```bash
# From BGP router or monitoring tool
show ip bgp summary
show ip route bgp
# Expected: Routes for 10.25.11.100-119 from infra nodes, 10.25.11.120-139 from apps nodes
```

## Definition of Done

**Manifest Creation Complete:**
- [ ] IPAM pool manifests created for both infra and apps clusters
- [ ] Pool manifests include cluster isolation (disabled flag with ${CLUSTER} substitution)
- [ ] Bootstrap configurations fixed (if needed) with correct IP allocations
- [ ] Cluster-settings updated with pool control variables
- [ ] Kustomization created for IPAM pools
- [ ] Local validation passes (flux build, kubeconform, YAML syntax)
- [ ] Pool ranges validated (no overlap, within subnet)
- [ ] IP allocation plan documented
- [ ] Manifests committed to git
- [ ] Story 45 (VALIDATE-NETWORKING) can proceed with deployment

**NOT Part of DoD (Moved to Story 45):**
- ❌ IPAM pools deployed to clusters
- ❌ Pool isolation verified (disabled flags working)
- ❌ Services allocating IPs from correct pools
- ❌ Cross-cluster reachability via BGP
- ❌ Gateway IP allocation verified

---

## Design — Cilium LB IPAM (Story‑Only)

- Pools: Define `CiliumLoadBalancerIPPool` objects with CIDR blocks for LB Services. Allocate from dedicated ranges per cluster/environment.
- Advertisement: Reachability is provided by BGP Control Plane (preferred) or L2 announcer; choose per environment.
- Selection: Optionally segment pools with `serviceSelector` (e.g., Gateway vs. internal LB).
- Alternatives: Node‑based LB mode exists but is out‑of‑scope for this design.
---

## Notes
- Keep Pod IPAM as bootstrapped; LB IPAM is orthogonal.
- Reserve growth headroom in ranges; document ownership.
- Validate with a temporary LB Service; confirm IP is from the pool and reachable upstream.

## Optional Steps
- Add `CiliumL2AnnouncementPolicy` if using L2 announcements instead of BGP.
- Introduce `serviceSelector` to dedicate specific subranges for Gateway vs. other LBs.

---

## Change Log
| Date       | Version | Description                          | Author  |
|------------|---------|--------------------------------------|---------|
| 2025-10-22 | 1.0     | Initial refined version              | Platform Engineering |
| 2025-10-26 | 2.0     | **v3.0 Refinement**: Updated header, story, scope, AC, dependencies, tasks, DoD for manifests-first approach. Separated manifest creation from deployment (moved to Story 45). | Winston |
