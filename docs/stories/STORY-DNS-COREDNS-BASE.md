# 07 — STORY-DNS-COREDNS-BASE — CoreDNS via GitOps

Sequence: 07/22 | Prev: STORY-SEC-CERT-MANAGER-ISSUERS.md | Next: STORY-GITOPS-SELF-MGMT-FLUX.md

Status: Draft
Owner: Platform Engineering
Date: 2025-10-21
Links: docs/architecture.md §9; kubernetes/infrastructure/networking/coredns; kubernetes/bases/coredns

## Story
Manage CoreDNS via Flux with per‑cluster replica and ClusterIP settings, and enable metrics for observability.

## Why / Outcome
- Deterministic DNS deployment aligned to cluster settings; observability coverage.

## Scope
- Resources: `kubernetes/infrastructure/networking/coredns/kustomization.yaml` (uses `bases/coredns`).

## Acceptance Criteria
1) CoreDNS Deployment Available with replicas `${COREDNS_REPLICAS}` and service IP `${COREDNS_CLUSTER_IP}` on each cluster.
2) PrometheusRule in place; metrics exposed.

## Dependencies / Inputs
- STORY-NET-CILIUM-CORE-GITOPS.

## Tasks / Subtasks
- [ ] Reconcile CoreDNS; verify settings substituted from `cluster-settings`.

## Validation Steps
- kubectl --context=<ctx> -n kube-system get deploy coredns
- kubectl --context=<ctx> -n kube-system get svc coredns -o yaml | grep clusterIP

## Definition of Done
- ACs met; outputs attached to Dev Notes.
