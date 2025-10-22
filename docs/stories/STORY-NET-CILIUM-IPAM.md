# 09 — STORY-NET-CILIUM-IPAM — LB IP Pools via GitOps

Sequence: 09/26 | Prev: STORY-GITOPS-SELF-MGMT-FLUX.md | Next: STORY-NET-CILIUM-GATEWAY.md

Status: Draft
Owner: Platform Engineering
Date: 2025-10-21
Links: docs/architecture.md §9; kubernetes/infrastructure/networking/cilium/ipam; kubernetes/infrastructure/networking/cilium/ks.yaml

## Story
Define LoadBalancer IP pools for infra and apps clusters using Cilium IPAM resources, managed by Flux.

## Why / Outcome
- Deterministic LB allocation from dedicated pools; avoids conflicts.

## Scope
- Resources: `kubernetes/infrastructure/networking/cilium/ipam/*`.

## Acceptance Criteria
1) Flux applies `CiliumLoadBalancerIPPool` resources; pools present per cluster.
2) LB Services receive IPs from intended pools; gateway `Gateway.status.addresses` matches `${CILIUM_GATEWAY_LB_IP}`.
3) Pool alignment: `${CILIUM_GATEWAY_LB_IP}` is inside the correct pool range for the cluster (infra: 10.25.11.100–119; apps: 10.25.11.120–139).

## Dependencies / Inputs
- STORY-NET-CILIUM-CORE-GITOPS; cluster settings include IP ranges for each pool.

## Tasks / Subtasks — Implementation Plan (Story Only)
- [ ] Define pools (later manifests): `kubernetes/infrastructure/networking/cilium/ipam/pools.yaml`
  - `CiliumLoadBalancerIPPool` with `spec.blocks` set to per‑cluster ranges from network plan (add keys to `cluster-settings` if missing).
  - Optional `serviceSelector` to dedicate a block for Gateway vs. internal LBs.
- [ ] Verify Flux wiring: `kubernetes/infrastructure/networking/cilium/ks.yaml` includes `ipam/` and substitutes cluster-settings.
- [ ] Smoke test (later): Create `kubernetes/components/testing/lb-echo.yaml` and confirm IP belongs to pool; verify reachability via BGP/L2.
- [ ] Cross-check `${CILIUM_GATEWAY_LB_IP}` against pool ranges and adjust `cluster-settings` if misaligned.

## Validation Steps
- flux -n flux-system --context=<ctx> reconcile ks cilium --with-source
- kubectl --context=<ctx> get ciloadbalancerippools -A
- kubectl --context=<ctx> -n flux-system get cm cluster-settings -o jsonpath='{.data.CILIUM_GATEWAY_LB_IP}' | awk '{print $1}'  # ensure value is in the cluster’s pool range

## Definition of Done
- ACs met; proof in Dev Notes.

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
