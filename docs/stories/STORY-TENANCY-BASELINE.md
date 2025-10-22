# XX — STORY-TENANCY-BASELINE — Team Namespace + RBAC + Quotas Template

Sequence: 37/38 | Prev: STORY-SEC-NP-BASELINE.md | Next: STORY-NET-CILIUM-BGP-CP-IMPLEMENT.md

Status: Draft
Owner: Platform Engineering
Date: 2025-10-22
Links: docs/architecture.md §13; kubernetes/components/{namespace,networkpolicy,monitoring}; kubernetes/workloads/tenants

## Story
Provide a reusable tenant baseline (namespace, RBAC, LimitRange, ResourceQuota, default network policies, optional ServiceAccounts) and a documented onboarding flow. Ensure no cross‑namespace references and align with policy baseline.

## Why / Outcome
- Predictable, secure starting point for teams; faster onboarding and consistent guardrails.

## Scope
- Create `kubernetes/workloads/tenants/_template/` with Kustomization and components for a new team namespace.
- Include: namespace, Role/RoleBinding(s), ServiceAccount(s), LimitRange, ResourceQuota, deny‑all + allow‑dns + kube‑api policies, and optional FQDN egress.

## Acceptance Criteria
1) Applying the template with `TEAM=demo` creates `demo` namespace with baseline resources.
2) Default‑deny enforced; DNS and kube‑api egress work; optional FQDN egress works when configured.
3) Resource quotas/limits enforced; example pod adheres to LimitRange.
4) No cross‑namespace references in tenant Kustomization.

## Dependencies / Inputs
- STORY-SEC-NP-BASELINE; cluster observability available for metrics/alerts.

## Tasks / Subtasks — Implementation Plan (Story Only)
- [ ] Scaffold `workloads/tenants/_template/` with parameterized Kustomization and references to components.
- [ ] Provide a small script or documented Kustomize var substitution process for creating a new team directory.
- [ ] Add example `demo` tenant Kustomization to validate the template (can be pruned after validation).
- [ ] Document onboarding steps in `docs/runbooks/`.

## Validation Steps
- Create `demo` tenant from template and apply via Flux.
- Verify policies and quotas; run sample workloads and confirm expected behavior.

## Definition of Done
- ACs met; onboarding runbook published; template ready for general use.
