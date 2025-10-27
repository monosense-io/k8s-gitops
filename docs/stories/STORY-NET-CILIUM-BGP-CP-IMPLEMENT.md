# 10 — STORY-NET-CILIUM-BGP-CP-IMPLEMENT — Implement Cilium BGP Control Plane (v1.18)

Sequence: 10/50 | Prev: STORY-NET-CILIUM-BGP.md | Next: STORY-NET-SPEGEL-REGISTRY-MIRROR.md
Sprint: 4 | Lane: Networking
Global Sequence: 10/50

Status: Draft
Owner: Platform Engineering
Date: 2025-10-22
Links: docs/architecture.md §9; docs/stories/STORY-NET-CILIUM-BGP.md (design); kubernetes/infrastructure/networking/cilium/bgp

## Story
Replace the legacy `CiliumBGPPeeringPolicy` with Cilium’s BGP Control Plane CRs on infra and apps. Advertise LoadBalancer IPs from Cilium LB IPAM (default), keep PodCIDRs advertisement disabled initially, validate on the router, and remove legacy policy manifests.

## Why / Outcome
- First‑class modeling of neighbors and advertisements, clearer observability, and alignment with Cilium 1.18.

## Scope
- Clusters: infra, apps
- Resources (to be created under `kubernetes/infrastructure/networking/cilium/bgp/cplane/`):
  - `bgp-peer-config.yaml` (`CiliumBGPPeerConfig`)
  - `bgp-cluster-config.yaml` (`CiliumBGPClusterConfig`)
  - `bgp-advertisements.yaml` (`CiliumBGPAdvertisement` — LB IPs true; PodCIDRs false)
- Remove legacy `CiliumBGPPeeringPolicy` after CP is healthy.

## Acceptance Criteria
1) CP CRs applied; `cilium bgp peers` shows Established sessions on both clusters.
2) Router shows learned routes for LB pools; no sustained flaps (keepalive 3s; holdtime 9s; ECMP on).
3) Sample `Service type=LoadBalancer` gets IP from pool; reachable upstream.
4) Legacy `CiliumBGPPeeringPolicy` removed from repo and clusters.

## Dependencies / Inputs
- STORY-NET-CILIUM-BGP (design);
- `cluster-settings`: `CILIUM_BGP_LOCAL_ASN`, `CILIUM_BGP_PEER_ASN`, `CILIUM_BGP_PEER_ADDRESS`.

## Tasks / Subtasks — Implementation Plan
- [ ] Add CP CRs under `kubernetes/infrastructure/networking/cilium/bgp/cplane/` referencing `cluster-settings`.
- [ ] Update `kubernetes/infrastructure/networking/cilium/bgp/ks.yaml` to include `cplane/` and set health checks if supported.
- [ ] Stage rollout on a non‑prod cluster; validate sessions and advertisements.
- [ ] Remove legacy file `kubernetes/infrastructure/networking/cilium/bgp/peering-policy.yaml` and prune from cluster.
- [ ] Repeat on prod clusters; monitor for stability.

## Validation Steps
- Cluster: `cilium bgp peers`, `cilium bgp advertisements`.
- Router: `show bgp summary`; `show route` for LB pools.
- LB smoke: deploy `components/testing/lb-echo.yaml`; curl from upstream network.

## Definition of Done
- ACs met on both clusters; legacy policy removed; evidence captured in Dev Notes.
