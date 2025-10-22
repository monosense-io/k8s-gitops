# 03 — STORY-NET-CILIUM-IPAM — LB IP Pools via GitOps

Sequence: 03/41 | Prev: STORY-NET-CILIUM-CORE-GITOPS.md | Next: STORY-NET-CILIUM-GATEWAY.md
Sprint: 1 | Lane: Networking
Global Sequence: 3/41

Status: Refined
Owner: Platform Engineering
Date: 2025-10-22 (Refined after architectural analysis)
Links: docs/architecture.md §9; kubernetes/infrastructure/networking/cilium/ipam; kubernetes/infrastructure/networking/cilium/ks.yaml; bootstrap/clusters/{cluster}/cilium-values.yaml

## Story
Define cluster-isolated LoadBalancer IP pools for infra and apps clusters using Cilium IPAM with proper pool segmentation and cross-cluster protection.

## Why / Outcome
- **Deterministic LB allocation** from dedicated pools per cluster; eliminates IP conflicts.
- **Pool isolation** prevents cross-cluster IP allocation when shared infrastructure manifests deploy to both clusters.
- **Greenfield correctness** ensures bootstrap configs, IPAM pools, and cluster-settings are aligned from day 1.

## Scope
- Resources: `kubernetes/infrastructure/networking/cilium/ipam/*`
- Bootstrap configs: `bootstrap/clusters/{cluster}/cilium-values.yaml`
- Cluster settings: `kubernetes/clusters/{cluster}/cluster-settings.yaml`

## Acceptance Criteria
1) **IPAM Pools Deployed with Cluster Isolation:**
   - Flux reconciles `cilium-ipam` Kustomization successfully on both clusters.
   - `infra-pool` shows `disabled: false` on infra cluster, `disabled: true` on apps cluster.
   - `apps-pool` shows `disabled: true` on infra cluster, `disabled: false` on apps cluster.

2) **Services Allocate from Correct Pools:**
   - Infra ClusterMesh API server gets `10.25.11.100` (first IP in infra pool).
   - Apps ClusterMesh API server gets `10.25.11.120` (first IP in apps pool).
   - Infra Gateway gets `10.25.11.110` (explicit assignment in infra pool).
   - Apps Gateway gets `10.25.11.121` (explicit assignment in apps pool).

3) **Pool Alignment Verified:**
   - ALL infra cluster LB IPs fall within `10.25.11.100-119` (20 IPs).
   - ALL apps cluster LB IPs fall within `10.25.11.120-139` (20 IPs).
   - `Gateway.status.addresses` matches `${CILIUM_GATEWAY_LB_IP}` from cluster-settings.
   - No IP conflicts between clusters; each pool serves only its intended cluster.

4) **Cross-Cluster Reachability:**
   - Apps cluster can reach infra ClusterMesh API at `10.25.11.100` via BGP.
   - Infra cluster can reach apps ClusterMesh API at `10.25.11.120` via BGP.
   - BGP peer (10.25.11.1) shows routes for both pool ranges.

## Dependencies / Inputs
- STORY-NET-CILIUM-CORE-GITOPS (Cilium core installed via bootstrap).
- BGP peering established (or L2 announcements configured).
- Cluster-settings ConfigMaps present in flux-system namespace.

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

## Tasks / Subtasks — Implementation Plan

### **Phase 1: Fix Bootstrap Configuration** (CRITICAL)

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

### **Phase 2: Add Pool Isolation to IPAM Manifests**

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

### **Phase 3: Update Cluster-Settings**

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

### **Phase 4: Validation & Smoke Testing**

- [ ] **Pre-deployment validation:**
  ```bash
  # Verify Flux variable substitution works
  flux build kustomization cilium-ipam --path ./kubernetes/infrastructure/networking/cilium/ipam

  # Check YAML syntax
  kubectl --dry-run=client -f kubernetes/infrastructure/networking/cilium/ipam/

  # Verify pool ranges don't overlap
  yq '.spec.blocks[].start, .spec.blocks[].stop' kubernetes/infrastructure/networking/cilium/ipam/*.yaml
  ```

- [ ] **Post-deployment pool verification:**
  ```bash
  # Infra cluster: Check pools deployed correctly
  kubectl --context=infra get ciliumloadbalancerippool -A -o yaml | grep -A5 "name: infra-pool"
  kubectl --context=infra get ciliumloadbalancerippool -A -o yaml | grep -A5 "name: apps-pool"
  # Expected: infra-pool enabled, apps-pool disabled

  # Apps cluster: Check pools deployed correctly
  kubectl --context=apps get ciliumloadbalancerippool -A -o yaml | grep -A5 "name: infra-pool"
  kubectl --context=apps get ciliumloadbalancerippool -A -o yaml | grep -A5 "name: apps-pool"
  # Expected: infra-pool disabled, apps-pool enabled
  ```

- [ ] **Service IP allocation verification:**
  ```bash
  # Infra ClusterMesh IP
  kubectl --context=infra get svc -n kube-system clustermesh-apiserver \
    -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
  # Expected: 10.25.11.100

  # Apps ClusterMesh IP
  kubectl --context=apps get svc -n kube-system clustermesh-apiserver \
    -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
  # Expected: 10.25.11.120

  # Infra Gateway IP
  kubectl --context=infra get gateway -n kube-system \
    -o jsonpath='{.items[0].status.addresses[0].value}'
  # Expected: 10.25.11.110

  # Apps Gateway IP
  kubectl --context=apps get gateway -n kube-system \
    -o jsonpath='{.items[0].status.addresses[0].value}'
  # Expected: 10.25.11.121
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
- All acceptance criteria met (4/4).
- Bootstrap configs corrected for both clusters (subnet + IPs).
- IPAM pools deployed with cluster isolation (disabled flags).
- Cluster-settings updated with correct IP allocations.
- Validation steps pass on both clusters.
- Gateway services have correct IPs from their respective pools.
- Cross-cluster ClusterMesh connectivity verified.
- Evidence documented in Dev Notes or QA evidence log.

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
