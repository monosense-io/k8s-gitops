# 10 — STORY-NET-CILIUM-GATEWAY — Gateway API with Cilium

Sequence: 10/21 | Prev: STORY-NET-CILIUM-IPAM.md | Next: STORY-NET-CILIUM-BGP.md

Status: Draft
Owner: Platform Engineering
Date: 2025-10-21
Links: docs/architecture.md §9; kubernetes/infrastructure/networking/cilium/gateway; kubernetes/infrastructure/networking/cilium/ks.yaml

## Story
Expose L7 HTTP(S) traffic using Gateway API implemented by Cilium, managed by Flux, with a default GatewayClass and a cluster Gateway per environment.

## Why / Outcome
- Standards‑based traffic management (Gateway API) with Cilium dataplane.
- Git‑managed routing, TLS termination delegated to cert‑manager issuers.

## Scope
- Clusters: infra, apps
- Resources: `kubernetes/infrastructure/networking/cilium/gateway/*` reconciled by `cilium-gatewayclass` Kustomization.

## Acceptance Criteria
1) GatewayClass Ready; cluster `Gateway` Available with LB IP from `${CILIUM_GATEWAY_LB_IP}`.
2) Sample HTTPRoute returns 404 default on both clusters.
3) If certs configured, HTTPS route presents valid cert from cert‑manager issuer.

## Dependencies / Inputs
- STORY-NET-CILIUM-CORE-GITOPS (Cilium Ready), STORY-SEC-CERT-MANAGER-ISSUERS (for TLS).
- `${CILIUM_GATEWAY_LB_IP}` in cluster settings.

## Tasks / Subtasks
- [ ] Confirm `kubernetes/infrastructure/networking/cilium/gateway/ks.yaml` is reconciled.
- [ ] Add sample `httproute` smoke test under `kubernetes/components/` (optional).

## Validation Steps
- flux -n flux-system --context=<ctx> reconcile ks cilium-gatewayclass --with-source
- kubectl --context=<ctx> get gatewayclass; get gateway -A; get httproute -A
- curl http://<LB-IP> (expect 404 default)

## Definition of Done
- ACs met on both clusters; evidence captured in Dev Notes.
