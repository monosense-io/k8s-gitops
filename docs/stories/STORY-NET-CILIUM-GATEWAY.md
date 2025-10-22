# 10 — STORY-NET-CILIUM-GATEWAY — Gateway API with Cilium

Sequence: 10/26 | Prev: STORY-NET-CILIUM-IPAM.md | Next: STORY-NET-CILIUM-BGP.md

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
1) GatewayClass Ready; cluster `Gateway` Available with LB IP `${CILIUM_GATEWAY_LB_IP}`.
2) Pool alignment: `${CILIUM_GATEWAY_LB_IP}` belongs to the cluster’s Cilium LB IP pool range (infra: 10.25.11.100–119; apps: 10.25.11.120–139) and matches SRX policy.
3) Sample HTTPRoute returns 404 default on both clusters; TLS presents valid cert when configured.

## Dependencies / Inputs
- STORY-NET-CILIUM-CORE-GITOPS (Cilium Ready), STORY-SEC-CERT-MANAGER-ISSUERS (for TLS).
- `${CILIUM_GATEWAY_LB_IP}` in cluster settings.

## Tasks / Subtasks — Implementation Plan (Story Only)
- [ ] Define (later manifests) under `kubernetes/infrastructure/networking/cilium/gateway/`:
  - `gatewayclass.yaml` (name: `cilium`).
  - `gateway.yaml` (one per cluster) with `spec.addresses` set from `${CILIUM_GATEWAY_LB_IP}`; listener HTTP/HTTPS.
- [ ] Sample route (later): `kubernetes/components/testing/gateway-http-echo.yaml` (HTTPRoute → http-echo Service) for 404/200 checks.
- [ ] Flux wiring: ensure `cilium/gateway/ks.yaml` references these files and uses cluster-settings for LB IP.
- [ ] Pool alignment check: confirm `${CILIUM_GATEWAY_LB_IP}` is chosen from the correct pool for the cluster and adjust `cluster-settings` if needed (e.g., infra → 10.25.11.110).

## Validation Steps
- flux -n flux-system --context=<ctx> reconcile ks cilium-gatewayclass --with-source
- kubectl --context=<ctx> get gatewayclass; get gateway -A; get httproute -A
- curl http://<LB-IP> (expect 404 default)
- Verify pool alignment:
  - `kubectl --context=<ctx> -n flux-system get cm cluster-settings -o jsonpath='{.data.CILIUM_GATEWAY_LB_IP}'` → within the cluster’s pool range
  - `kubectl --context=<ctx> -n kube-system get svc cilium-gateway -o wide` → EXTERNAL-IP equals `${CILIUM_GATEWAY_LB_IP}` and in-range

## Definition of Done
- ACs met on both clusters; evidence captured in Dev Notes.

---

## Design — Cilium Gateway API (Story‑Only)

- Enablement: Gateway API controller enabled via Cilium 1.18.2 Helm values; Gateway API CRDs present.
- Topology: One `GatewayClass` (e.g., `cilium`), one cluster `Gateway` per environment with a static LB IP from Cilium LB IPAM (`${CILIUM_GATEWAY_LB_IP}`).
- TLS: Terminate at Gateway using cert‑manager‑managed secrets; `HTTPRoute` hostnames and TLS define SNI.
- Performance: Keep kube‑proxy replacement strict for eBPF; use NodePort only if required by environment.
- Validation: 404 default on base Gateway; `status.addresses` equals the expected LB IP.

## Optional Steps
- Configure rate‑limits and timeouts via HTTPRoute policies when rolling out production routes.
- Add SNI‑based multi‑tenant Gateway definitions per environment (infra/apps) with shared or dedicated LB IPs.
