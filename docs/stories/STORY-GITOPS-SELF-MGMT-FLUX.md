# 08 — STORY-GITOPS-SELF-MGMT-FLUX — Flux Self‑Management via Operator/Instance

Sequence: 08/22 | Prev: STORY-DNS-COREDNS-BASE.md | Next: STORY-NET-CILIUM-IPAM.md

Status: Draft
Owner: Platform Engineering
Date: 2025-10-21
Links: docs/architecture.md §5; kubernetes/infrastructure/gitops/flux-operator; kubernetes/infrastructure/gitops/flux-instance

## Story
Transition Flux controllers to self‑management using `flux-operator` and a `flux-instance` HelmRelease reconciled by Flux itself.

## Why / Outcome
- Git as canonical source; operator manages controller lifecycles/versions.

## Scope
- Resources: `kubernetes/infrastructure/gitops/flux-operator/*`, `kubernetes/infrastructure/gitops/flux-instance/*`.

## Acceptance Criteria
1) flux-operator and flux-instance HelmReleases Ready.
2) Controllers managed by operator; upgrades performed by changing Git versions only.
3) Bootstrap “flux install” becomes a one‑time step; subsequent restarts recover from Git.

## Dependencies / Inputs
- STORY-BOOT-CORE (Flux installed initially), repository URL and path set in `flux-instance` values.

## Tasks / Subtasks
- [ ] Reconcile `kubernetes/infrastructure/gitops/*` Kustomizations.
- [ ] Validate that controllers reconcile from operator after restarting Flux pods.

## Validation Steps
- flux -n flux-system --context=<ctx> reconcile ks flux-operator --with-source
- flux -n flux-system --context=<ctx> reconcile ks flux-instance --with-source
- kubectl --context=<ctx> -n flux-system get pods

## Definition of Done
- ACs met on infra and apps; evidence recorded.
