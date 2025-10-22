# 07 — STORY-DNS-COREDNS-BASE — CoreDNS via GitOps

Sequence: 07/26 | Prev: STORY-SEC-CERT-MANAGER-ISSUERS.md | Next: STORY-GITOPS-SELF-MGMT-FLUX.md

Status: Draft
Owner: Platform Engineering
Date: 2025-10-21
Links: docs/architecture.md §9; docs/_freeze/2025-10-21/architecture.v4.md §9; kubernetes/infrastructure/networking/coredns; kubernetes/bases/coredns

## Story
Manage CoreDNS via Flux with per‑cluster replica and ClusterIP settings, enable metrics and health/ready endpoints, and adopt safe HA + security defaults. Include guidance for optional NodeLocal DNSCache and autoscaling.

## Why / Outcome
- Deterministic DNS deployment aligned to cluster settings; observability coverage.

## Scope
- Resources: `kubernetes/infrastructure/networking/coredns/kustomization.yaml` (uses `bases/coredns`).

## Acceptance Criteria
1) CoreDNS Deployment `coredns` Available with replicas `${COREDNS_REPLICAS}`; PodDisruptionBudget enabled (minAvailable ≥ 1); anti‑affinity or topology spread in effect across nodes.
2) Service `kube-dns` present in `kube-system` with static ClusterIP `${COREDNS_CLUSTER_IP}`; DNS lookups from pods succeed for service, pod, and external names.
3) Metrics on `:9153` are scraped (ServiceMonitor enabled) and common `coredns_*` time series are visible in VictoriaMetrics.
4) Health/Ready endpoints respond (`health` on :8080, `ready` on :8181) for each CoreDNS pod.
5) Security: pods run as non‑root with read‑only root FS and no added capabilities; NetworkPolicy/Cilium policy allows DNS to CoreDNS from workloads while blocking unintended sources.
6) Version alignment: chart/tag matches architecture target (currently 1.38.0); any drift is documented with an upgrade plan.

## Dependencies / Inputs
- STORY-NET-CILIUM-CORE-GITOPS.

## Tasks / Subtasks
- [ ] Reconcile CoreDNS; verify `${COREDNS_REPLICAS}` and `${COREDNS_CLUSTER_IP}` from `cluster-settings`.
- [ ] Align version: update `kubernetes/bases/coredns/helmrelease.yaml` OCI `ref.tag` to `1.38.0` to match docs, or document exception and rationale.
- [ ] HA defaults: add `topologySpreadConstraints` or `podAntiAffinity` in chart values; keep PDB enabled with `minAvailable: 1`.
- [ ] Service name: confirm Service is `kube-dns` (chart default) rather than `coredns`; keep static ClusterIP.
- [ ] Observability: keep `prometheus.service` and `servicemonitor` enabled; verify scrape labels/selector.
- [ ] Health/Ready: ensure `health` and `ready` plugins enabled (chart default); document endpoints.
- [ ] Security: confirm container `runAsNonRoot`, `readOnlyRootFilesystem: true`, `allowPrivilegeEscalation: false`, and `capabilities.drop: [ALL]` in rendered manifests.
- [ ] Policy: ensure a DNS allow policy is present (e.g., `components/networkpolicy/allow-dns` or CiliumNetworkPolicy variant) referenced by workloads.
- [ ] Optional — Autoscaling: evaluate Cluster Proportional Autoscaler (CPA) for CoreDNS; if adopting, add HelmRelease or Kustomization and tune per node count.
- [ ] Optional — NodeLocal DNSCache: evaluate enabling per cluster to improve latency and stub resolver stability; document trade‑offs (e.g., autopath interactions) and create a follow‑up story if accepted.

## Validation Steps
- kubectl --context=<ctx> -n kube-system get deploy coredns; kubectl --context=<ctx> -n kube-system get pdb
- kubectl --context=<ctx> -n kube-system get svc kube-dns -o yaml | rg 'clusterIP:|name: kube-dns'
- DNS smoke: from a test pod, resolve internal and external names (`nslookup kubernetes.default`, `nslookup example.com`).
- Metrics: `kubectl --context=<ctx> -n kube-system port-forward deploy/coredns 9153:9153` and curl `/metrics`; verify `coredns_*` in VictoriaMetrics.
- Health/Ready: `kubectl --context=<ctx> -n kube-system port-forward deploy/coredns 8080:8080 8181:8181`; curl `:8080/health` and `:8181/ready` return OK.
- Security: inspect rendered CoreDNS pod spec for non‑root, read‑only FS, and dropped caps.
- Policy: verify DNS allow policy present and effective (allowed namespaces resolve; disallowed are blocked if policy is enforced).

## Definition of Done
- ACs met; outputs attached to Dev Notes.
