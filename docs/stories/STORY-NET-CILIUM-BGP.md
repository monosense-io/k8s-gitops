# 11 — STORY-NET-CILIUM-BGP — Cilium BGP Policy via GitOps

Sequence: 11/26 | Prev: STORY-NET-CILIUM-GATEWAY.md | Next: STORY-NET-CILIUM-CLUSTERMESH.md

Status: Draft
Owner: Platform Engineering
Date: 2025-10-21
Links: docs/architecture.md §9; kubernetes/infrastructure/networking/cilium/bgp; kubernetes/infrastructure/networking/cilium/ks.yaml

## Story
Publish Kubernetes Service VIPs and PodCIDRs to the upstream router using Cilium BGP policies, managed declaratively via Flux.

## Why / Outcome
- Northbound routing for LoadBalancer/NodePort and Pod networks without kube-proxy.
- Declarative routing, versioned and reviewed in Git.

## Scope
- Clusters: infra, apps
- Resources: `kubernetes/infrastructure/networking/cilium/bgp/*` (manifests) reconciled by `cilium-bgp-policy` Kustomization.

## Acceptance Criteria
1) Cilium 1.18.2 with `bgpControlPlane.enabled: true` on infra/apps; Flux reports Kustomizations Ready.
2) Router (ASN `${CILIUM_BGP_PEER_ASN}`) sees Established eBGP sessions from cluster nodes (local ASN `${CILIUM_BGP_LOCAL_ASN}`) with hold-time 9s and ECMP active.
3) LB Service IPs from Cilium LB IPAM are advertised and reachable from upstream; PodCIDR advertisement toggled per design (off by default).
4) No sustained BGP flaps; `cilium bgp peers` shows Established; exported prefixes match LB pool subnets.

## Dependencies / Inputs
- STORY-NET-CILIUM-CORE-GITOPS (Cilium Ready).
- Cluster settings include `CILIUM_BGP_LOCAL_ASN`, `CILIUM_BGP_PEER_ASN`, `CILIUM_BGP_PEER_ADDRESS` (router address). Values come from `cluster-settings` ConfigMap per cluster; do not hardcode.

## Tasks / Subtasks — Implementation Plan (Story Only)
- [ ] Confirm Helm values: `kube-system/HelmRelease cilium` has `values.bgpControlPlane.enabled: true` (both clusters).
- [ ] Replace legacy peering policy with 1.18 BGP Control Plane CRs (design only here; manifests added in later story):
  - Files to author (later):
    - `kubernetes/infrastructure/networking/cilium/bgp/cplane/bgp-peer-config.yaml` (`CiliumBGPPeerConfig`):
      - KeepAlive 3s, HoldTime 9s, graceful restart on, families `ipv4-unicast`, `multipath: true`.
    - `kubernetes/infrastructure/networking/cilium/bgp/cplane/bgp-cluster-config.yaml` (`CiliumBGPClusterConfig`):
      - `nodeSelector: {}` (or restrict to control-plane if required).
      - `localASN: ${CILIUM_BGP_LOCAL_ASN}`; neighbor `address: ${CILIUM_BGP_PEER_ADDRESS}` / `peerASN: ${CILIUM_BGP_PEER_ASN}`; reference peer-config.
    - `kubernetes/infrastructure/networking/cilium/bgp/cplane/bgp-advertisements.yaml` (`CiliumBGPAdvertisement`):
      - `advertise.loadBalancerIPs: true`; `advertise.podCIDRs: false` (default).
- [ ] Flux wiring (verify only): `kubernetes/infrastructure/networking/cilium/bgp/ks.yaml` references the `cplane/` folder; `postBuild.substitute` injects cluster-settings.
- [ ] Smoke test (when implemented later): Create `kubernetes/components/testing/lb-echo.yaml` (Service `type=LoadBalancer`), verify LB IP in pool and reachability from upstream.

## Validation Steps
- flux -n flux-system --context=<ctx> reconcile ks cilium-bgp-policy --with-source
- kubectl --context=<ctx> -n kube-system get cm,ds,deploy | grep cilium
- On router: show bgp summary; show routes for PodCIDRs and LB IP pools

## Definition of Done
- ACs met on infra and apps; validation outputs recorded in Dev Notes.

---

## Design — Migrate to Cilium 1.18 BGP Control Plane (Story‑Only)

Decision
- Adopt Cilium’s BGP Control Plane CRDs (1.18.2) instead of the legacy `CiliumBGPPeeringPolicy` for clearer modeling of sessions, advertisements, and status. No live manifests are changed in this story; this documents the design and plan.

Rationale
- New CP provides first‑class objects for neighbors, address families, timers, multipath ECMP, and advertisement selection (LB IPs, optional PodCIDRs). Improves day‑2 operations and observability.

Scope (This Story)
- Document CR structure, values source, and cutover plan.
- Provide example (illustrative) CR outlines that reference existing `cluster-settings` keys.
- Do NOT modify cluster config or apply manifests.

Values Source (single source of truth)
- `cluster-settings` ConfigMap per cluster provides:
  - `CILIUM_BGP_LOCAL_ASN` (node side)
  - `CILIUM_BGP_PEER_ASN` (router side)
  - `CILIUM_BGP_PEER_ADDRESS` (router address)
  - `CILIUM_GATEWAY_LB_IP` (for Gateway where relevant)

CR Outline (Illustrative — not applied)
```yaml
# 1) BGP Neighbor Session (per cluster)
apiVersion: cilium.io/v2alpha1
kind: CiliumBGPNeighborConfig   # illustrative name; actual CRD may differ in minor fields
metadata:
  name: bgp-session
spec:
  nodeSelector: {}               # all nodes (or limit to control-plane if desired)
  localASN: ${CILIUM_BGP_LOCAL_ASN}
  neighbors:
    - address: ${CILIUM_BGP_PEER_ADDRESS}
      peerASN: ${CILIUM_BGP_PEER_ASN}
      timers:
        holdTimeSeconds: 9
        keepAliveTimeSeconds: 3
      capabilities:
        gracefulRestart: true
        ebgpMultihop: true
      families: ["ipv4-unicast"]
      multipath: true            # ECMP alignment

# 2) Advertisement Policy: advertise LB IPs (default)
apiVersion: cilium.io/v2alpha1
kind: CiliumBGPAdvertisement
metadata:
  name: advertise-lb
spec:
  advertise:
    loadBalancerIPs: true        # from CiliumLoadBalancerIPPool
    podCIDRs: false              # optional (off by default in this plan)
```

Phased Cutover Plan (for later implementation story)
1) Enable path (already present): confirm `bgpControlPlane.enabled: true` in HelmRelease (1.18.2).
2) Staging dry run: apply new CP CRs to staging cluster only; verify sessions Established and LB IP routes advertised.
3) Cutover: remove legacy `CiliumBGPPeeringPolicy` on staging once CP sessions stable; validate reachability and ECMP.
4) Production rollout: repeat on infra/apps with maintenance window; monitor for flaps.
5) Optional: enable `podCIDRs` advertisements if direct pod routing is required; otherwise remain LB‑only.

Risks & Rollback
- Do not run legacy peering and new CP simultaneously (risk of duplicate advertisements).
- Rollback: re‑apply legacy `CiliumBGPPeeringPolicy` and remove CP CRs.

Acceptance Criteria — Design Additions (for this story)
- Documented CR outlines referencing `cluster-settings` keys.
- Written cutover/rollback plan with validation commands.
- Explicit decision recorded: advertise LB IPs by default; PodCIDRs optional.

Validation (when implemented later)
- Router: `show bgp summary` (Established), routes for LB pools; ECMP active.
- Cluster: `cilium bgp peers`, `cilium bgp advertisements`; curl to a sample LB IP succeeds from upstream network.

---

## Notes
- Use Cilium 1.18.2 BGP Control Plane for sessions/advertisements; legacy peering policy is deprecated for new designs.
- All values (ASNs, router address) come from `cluster-settings`; no hardcoded values in manifests.
- Validate with router “bgp summary/routes” and `cilium bgp peers/advertisements` once implemented in a later story.

## Optional Steps
- Deploy a second upstream router (if available) and configure ECMP with multipath for redundancy.
- Announce only a summarized LB prefix upstream while keeping granular pools internally (advanced).
