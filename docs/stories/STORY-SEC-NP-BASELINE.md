# XX — STORY-SEC-NP-BASELINE — Default‑Deny + DNS/API + FQDN Baseline

Sequence: 33/38 | Prev: STORY-SEC-SPIRE-CILIUM-AUTH.md | Next: STORY-NET-CLUSTERMESH-DNS.md
Sprint: 5 | Lane: Security
Global Sequence: 29/41

Status: Draft
Owner: Platform Engineering
Date: 2025-10-22
Links: docs/architecture.md §21; kubernetes/components/networkpolicy/{deny-all,allow-dns,allow-internal}/; kubernetes/infrastructure/networking/cilium/gateway

## Story
Enforce a platform‑wide network policy baseline: default‑deny ingress/egress, allow DNS and kube‑apiserver egress, define optional FQDN allowlists for internet egress, and provide identity‑based policy exemplars for sensitive paths. Apply to platform and tenant namespaces with clear onboarding steps.

## Why / Outcome
- Reduce attack surface and unintended traffic by default.
- Provide consistent, auditable policy building blocks for all teams.

## Scope
- Namespaces: platform (observability, cnpg‑system, dragonfly‑system, harbor, gitlab‑system, etc.) and tenant namespaces.
- Policies: Kubernetes `NetworkPolicy` and Cilium `CiliumNetworkPolicy`/`CiliumAuthPolicy` exemplars.

## Acceptance Criteria
1) Default‑deny enforced in targeted namespaces: ingress and egress denied unless explicitly allowed.
2) DNS allow in all targeted namespaces using `allow-dns` component (KNP or CNP variant for Cilium).
3) Kube‑apiserver egress allow in all targeted namespaces.
4) Optional FQDN allowlists applied where needed (e.g., pulling artifacts), with `toFQDNs` examples.
5) Sample namespace validation shows: DNS works, kube‑api works, disallowed egress blocked.

## Dependencies / Inputs
- STORY-NET-CILIUM-CORE-GITOPS; Cilium policy enforcement mode = default.
- Domain list for FQDN allowlists (per team or platform components).

## Tasks / Subtasks — Implementation Plan (Story Only)
- [ ] Create `kubernetes/infrastructure/security/networkpolicy/` Kustomization to aggregate reusable components from `kubernetes/components/networkpolicy/*`.
- [ ] Apply `deny-all`, `allow-dns`, and an `allow-kube-api` policy to platform namespaces.
- [ ] Provide a template Kustomization for tenant namespaces (to be included by tenant onboarding story).
- [ ] Add example `CiliumAuthPolicy` usage note referencing STORY-SEC-SPIRE-CILIUM-AUTH (no change here).
- [ ] Flux wiring: include network policy Kustomization in cluster `infrastructure.yaml` with wait/health checks as applicable.

## Validation Steps
- For a sample namespace `<ns>`:
  - `kubectl -n <ns> run curl --image=curlimages/curl -- sleep 3600`
  - `kubectl -n <ns> exec curl -- nslookup kubernetes.default` → OK
  - `kubectl -n <ns> exec curl -- curl -sfk https://kubernetes.default.svc` → OK (kube‑api egress)
  - `kubectl -n <ns> exec curl -- curl -s https://example.com` → Blocked unless FQDN allowlist applied

## Definition of Done
- ACs met in at least two platform namespaces and one sample tenant namespace; evidence recorded.
