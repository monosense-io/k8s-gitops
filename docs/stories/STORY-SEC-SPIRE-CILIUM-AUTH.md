# 29 — STORY-SEC-SPIRE-CILIUM-AUTH — SPIRE + Cilium mTLS Authentication Baseline

Sequence: 29/41 | Prev: STORY-NET-CLUSTERMESH-DNS.md | Next: STORY-STO-APPS-OPENEBS-BASE.md
Sprint: 6 | Lane: Security
Global Sequence: 29/41

Status: Draft
Owner: Platform Engineering
Date: 2025-10-22
Links: docs/architecture.md §20, §21; kubernetes/infrastructure/networking/cilium/core/helmrelease.yaml; kubernetes/components/networkpolicy/deny-all/ciliumnetworkpolicy.yaml

## Story
Establish workload identity and mutual authentication across clusters using SPIRE as the identity provider and Cilium’s native authentication for mTLS enforcement. Manage SPIRE server+agents and Cilium auth settings via GitOps, then enforce identity-based policies with `CiliumAuthPolicy` in selected namespaces.

## Why / Outcome
- Zero‑trust baseline with SPIFFE identities and mTLS enforced by Cilium.
- Policy decisions become identity‑centric (service accounts), not IP-based.

## Scope
- Clusters: infra, apps
- Resources (to be created):
  - `kubernetes/infrastructure/security/spire/{namespace,server,agent,rbac,config}.yaml`
  - Update `kubernetes/infrastructure/networking/cilium/core/helmrelease.yaml` to enable `authentication.mutual.spire` with safe rollout gates.
  - Sample `CiliumAuthPolicy` and supporting `CiliumNetworkPolicy` exemplars under `kubernetes/components/networkpolicy/` (story-only references).

## Acceptance Criteria
1) SPIRE installed and Ready on both clusters:
   - Namespace `spire` exists; SPIRE server StatefulSet and DaemonSet agents report Ready.
2) Cilium HelmRelease values include:
   - `authentication.enabled: true`
   - `authentication.mutual.spire.enabled: true`
   - `authentication.mutual.spire.install.enabled: true` (or external if preferred)
   - Change is rolled out via Flux and Cilium pods remain healthy.
3) At least one namespace protected with identity‑based mTLS:
   - `CiliumAuthPolicy` requires SPIFFE mTLS for inbound traffic to a target namespace; non‑authenticated traffic is denied.
4) Hubble shows authenticated identity flows; sample requests without SVID fail as expected.
5) Rollback plan documented; disabling `authentication.enabled` reverts to pre‑auth behavior.

## Dependencies / Inputs
- STORY-NET-CILIUM-CORE-GITOPS (Cilium under GitOps).
- `cluster-settings` for `SECRET_DOMAIN` (SPIFFE trust domain default `spiffe://<domain>` or project domain, TBA).
- Storage for SPIRE server (PVC); TLS material internal to SPIRE (no external CA required).

## Tasks / Subtasks — Implementation Plan (Story Only)
- [ ] Author SPIRE manifests under `kubernetes/infrastructure/security/spire/`:
  - `namespace.yaml`, `server.yaml` (StatefulSet + Service), `agent.yaml` (DaemonSet), `rbac.yaml`, `configmaps/*.yaml`.
- [ ] Update Cilium GitOps HelmRelease (`networking/cilium/core/helmrelease.yaml`):
  - Add `authentication.enabled: true` and `authentication.mutual.spire.*` blocks with install enabled.
  - Keep change guarded with a feature flag value (e.g., `${CILIUM_AUTHN_ENABLED}`) if staged rollout is needed.
- [ ] Create an example `CiliumAuthPolicy` (`kubernetes/components/networkpolicy/require-spiffe-to-<ns>.yaml`) that requires SPIFFE auth to a chosen namespace.
- [ ] Document trust domain and SPIRE selectors for common service account patterns; add SVID rotation defaults.
- [ ] Flux wiring: include `security/spire/` Kustomization in both cluster `infrastructure.yaml` with health checks on server and agent.

## Validation Steps
- kubectl --context=<ctx> -n spire get sts,ds,po
- kubectl --context=<ctx> -n kube-system get ds/cilium deploy/cilium-operator
- Confirm Cilium values: `helmrelease cilium -o yaml | rg -n 'authentication:|spire:'`
- Apply example `CiliumAuthPolicy`; send traffic without SVID → denied; with SVID → allowed.
- Hubble: verify identity labels on flows and mTLS state.

## Definition of Done
- ACs met on both clusters; example policy and evidence captured in Dev Notes.
