# 11 — STORY-NET-CILIUM-BGP — Cilium BGP Policy via GitOps

Sequence: 11/13 | Prev: STORY-NET-CILIUM-GATEWAY.md | Next: STORY-NET-CILIUM-CLUSTERMESH.md

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
1) `cilium-bgp-policy` Kustomization Ready on infra/apps.
2) Router sees BGP session Established from each control-plane/node (per design), routes present for Service VIP ranges and PodCIDRs.
3) LB Service acquires IP and is reachable from router’s LAN.
4) Metrics/Logs: no continuous BGP flaps; Hubble/metrics do not show policy errors.

## Dependencies / Inputs
- STORY-NET-CILIUM-CORE-GITOPS (Cilium Ready).
- Cluster settings include `CILIUM_BGP_LOCAL_ASN`, `CILIUM_BGP_PEER_ASN`, `CILIUM_BGP_PEER_ADDRESS`.

## Tasks / Subtasks
- [ ] Ensure `kubernetes/infrastructure/networking/cilium/bgp/ks.yaml` is included (already wired).
- [ ] Verify policy templates and per‑cluster substitute values from `cluster-settings`.
- [ ] Attach simple LB Service smoke test (e.g., nginx) and confirm reachability.

## Validation Steps
- flux -n flux-system --context=<ctx> reconcile ks cilium-bgp-policy --with-source
- kubectl --context=<ctx> -n kube-system get cm,ds,deploy | grep cilium
- On router: show bgp summary; show routes for PodCIDRs and LB IP pools

## Definition of Done
- ACs met on infra and apps; validation outputs recorded in Dev Notes.
