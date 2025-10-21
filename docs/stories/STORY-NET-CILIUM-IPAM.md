# 09 — STORY-NET-CILIUM-IPAM — LB IP Pools via GitOps

Sequence: 09/21 | Prev: STORY-GITOPS-SELF-MGMT-FLUX.md | Next: STORY-NET-CILIUM-GATEWAY.md

Status: Draft
Owner: Platform Engineering
Date: 2025-10-21
Links: docs/architecture.md §9; kubernetes/infrastructure/networking/cilium/ipam; kubernetes/infrastructure/networking/cilium/ks.yaml

## Story
Define LoadBalancer IP pools for infra and apps clusters using Cilium IPAM resources, managed by Flux.

## Why / Outcome
- Deterministic LB allocation from dedicated pools; avoids conflicts.

## Scope
- Resources: `kubernetes/infrastructure/networking/cilium/ipam/*`.

## Acceptance Criteria
1) Kustomization applies successfully; `CiliumLoadBalancerIPPool` resources present.
2) LB Services receive IPs from the configured pool ranges.

## Dependencies / Inputs
- STORY-NET-CILIUM-CORE-GITOPS; cluster settings include IP ranges for each pool.

## Tasks / Subtasks
- [ ] Validate pools per cluster match network plan.
- [ ] Create sample LB service and confirm allocation from pool.

## Validation Steps
- flux -n flux-system --context=<ctx> reconcile ks cilium --with-source
- kubectl --context=<ctx> get ciloadbalancerippools -A

## Definition of Done
- ACs met; proof in Dev Notes.
