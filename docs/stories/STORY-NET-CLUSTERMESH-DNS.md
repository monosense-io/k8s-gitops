# XX — STORY-NET-CLUSTERMESH-DNS — Public DNS for Cilium ClusterMesh API Servers

Sequence: 34/38 | Prev: STORY-SEC-NP-BASELINE.md | Next: STORY-BOOT-AUTOMATION-ALIGN.md

Status: Draft
Owner: Platform Engineering
Date: 2025-10-22
Links: docs/architecture.md §20 (Phase 1–4 DNS requirements); kubernetes/clusters/*/cluster-settings.yaml; kubernetes/infrastructure/cilium/helmrelease-*.yaml

## Story
Create and validate DNS records for the ClusterMesh API servers so clusters can discover each other via FQDNs. Ensure the LB IPs are deterministic via Cilium LB IPAM and recorded in `cluster-settings`. Update validation steps in the ClusterMesh story accordingly.

## Why / Outcome
- Deterministic cross‑cluster discovery; decouples from raw IPs; simplifies rotation.

## Scope
- Records: `infra-cilium-apiserver.${SECRET_DOMAIN}` → infra LB IP; `apps-cilium-apiserver.${SECRET_DOMAIN}` → apps LB IP.
- Inputs from `cluster-settings`:
  - `CILIUM_GATEWAY_LB_IP` (gateway record is separate)
  - `CLUSTERMESH_IP` (LB IP for clustermesh‑apiserver if configured per cluster)

## Acceptance Criteria
1) DNS A record exists for each cluster’s clustermesh‑apiserver FQDN; resolves to the correct LB IP.
2) Cilium config on each cluster is set to use the peer FQDN and port 443.
3) `cilium clustermesh status` shows Connected ↔ Connected.
4) Pool hygiene: if clustermesh‑apiserver uses a LoadBalancer Service with static IPs, chosen IPs fall within the cluster’s LB IP pool.

## Dependencies / Inputs
- STORY-NET-CILIUM-IPAM (LB IP pool); STORY-NET-CILIUM-CLUSTERMESH (secret sync).
- External DNS/IaC process for zone updates (manual or automated), out of scope of Kubernetes manifests.

## Tasks / Subtasks — Implementation Plan (Story Only)
- [ ] Confirm LB IPs in `cluster-settings` (`CLUSTERMESH_IP` or the apiserver LB annotation values if used).
- [ ] Create DNS A records in the provider for both FQDNs pointing to the IPs above.
- [ ] Adjust Cilium values if needed to reference peer by FQDN instead of raw IP.
- [ ] Update ClusterMesh validation in STORY-NET-CILIUM-CLUSTERMESH to include FQDN resolution checks.

## Validation Steps
- `dig +short infra-cilium-apiserver.${SECRET_DOMAIN}` → matches infra LB IP
- `dig +short apps-cilium-apiserver.${SECRET_DOMAIN}` → matches apps LB IP
- `cilium clustermesh status --context infra|apps` → Connected
- If using static LB IPs: verify selected IPs are in the correct per‑cluster pool ranges.

## Definition of Done
- DNS records resolvable; ClusterMesh connected via FQDN; evidence captured.
