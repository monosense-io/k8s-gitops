# 24 — STORY-DB-DRAGONFLY-OPERATOR-CLUSTER — DragonflyDB Operator & Shared Cluster

Sequence: 24/41 | Prev: STORY-DB-CNPG-SHARED-CLUSTER.md | Next: STORY-SEC-NP-BASELINE.md
Sprint: 5 | Lane: Database
Global Sequence: 24/41

Status: Approved
Owner: Platform Engineering
Date: 2025-10-21
Links:
- docs/architecture.md §B.9
- kubernetes/infrastructure/repositories/oci/dragonfly-operator.yaml
- kubernetes/bases/dragonfly-operator/operator/kustomization.yaml
- kubernetes/bases/dragonfly-operator/operator/helmrelease.yaml
- kubernetes/workloads/platform/databases/dragonfly/kustomization.yaml
- kubernetes/workloads/platform/databases/dragonfly/dragonfly.yaml
- kubernetes/workloads/platform/databases/dragonfly/externalsecret.yaml
- kubernetes/workloads/platform/databases/dragonfly/service.yaml
- kubernetes/workloads/platform/databases/dragonfly/prometheusrule.yaml
 - kubernetes/workloads/platform/databases/dragonfly/dragonfly-pdb.yaml   (to be created in this story)
 - kubernetes/workloads/platform/databases/dragonfly/networkpolicy.yaml  (to be created in this story)
 - docs/examples/dragonfly-gitlab.yaml (per‑tenant CR stub; to be created in this story)

## Story
Deploy and harden DragonflyDB using the official operator on the infra cluster, expose it to the apps cluster via Cilium ClusterMesh, and make it consumable by GitLab and other workloads. Implement HA, security, observability, and network policies; document tenancy guidance (shared vs per‑tenant instances).

## Why / Outcome
- Reliable, Redis‑compatible cache with low latency and simple ops, centrally provided for platform workloads (GitLab, Harbor, others) with clear isolation options.

## Scope
- Operator (Flux HelmRelease + OCIRepository)
- Dragonfly CR in `dragonfly-system` namespace with PVCs, Service, ServiceMonitor, and PrometheusRule
- Cross‑cluster exposure via Cilium global Service
- NetworkPolicies for client allow‑lists and metrics scraping

## Acceptance Criteria
1) Operator Ready (replicas ≥2, PDB present); CRDs Established.
2) Dragonfly CR Ready with 3 pods (1 primary, 2 replicas); PVCs Bound; metrics exposed at `/metrics` and scraped by VictoriaMetrics; data‑plane PDB present (minAvailable: 2).
3) Global Service reachable from apps cluster; GitLab HelmRelease resolves `dragonfly.dragonfly-system.svc.cluster.local:6379` and passes connectivity checks.
4) NetworkPolicy restricts access to approved namespaces (e.g., `gitlab-system`, `harbor`, selected apps); monitoring egress allowed; policy enforcement validated (allowed→OK, denied→blocked).
5) PrometheusRule includes availability, memory reserve, disk saturation, command rate, and replication health alerts.
6) Tenancy guidance documented; example per‑tenant CR stub provided (optional) without flipping existing consumers.

## Dependencies / Inputs
- Cilium ClusterMesh enabled on infra and apps clusters; `service.cilium.io/global: "true"` allowed.
- StorageClass `${DRAGONFLY_STORAGE_CLASS}` available; `${DRAGONFLY_DATA_SIZE}` sized appropriately.
- External Secrets store configured; `${DRAGONFLY_AUTH_SECRET_PATH}` populated.
- GitLab chart configured to use external Redis (already set in repo).

## Tasks / Subtasks — Operator & Cluster
- [ ] Validate operator HelmRelease (`kubernetes/bases/dragonfly-operator/operator/helmrelease.yaml`) and OCI source (`kubernetes/infrastructure/repositories/oci/dragonfly-operator.yaml`); keep `crds: CreateReplace`, `replicaCount: 2`, PDB on.
- [ ] Review and bump Dragonfly image tag in CR (`kubernetes/workloads/platform/databases/dragonfly/dragonfly.yaml`) to latest tested compatible with operator 1.3.x; enable master‑only snapshots and safe replication flags if available in chosen version.
- [ ] Add `topologySpreadConstraints` or pod anti‑affinity to Dragonfly pods to distribute 3 pods across nodes.
- [ ] Add a data‑plane PDB (minAvailable: 2) — create `kubernetes/workloads/platform/databases/dragonfly/dragonfly-pdb.yaml` and include in kustomization.
- [ ] Enforce NetworkPolicy in `dragonfly-system` to only allow:
  - from namespaces: `gitlab-system`, `harbor`, selected app namespaces
  - from `observability` namespace for metrics scrapes
  - DNS egress as needed
- [ ] Create `kubernetes/workloads/platform/databases/dragonfly/networkpolicy.yaml` implementing the above allow‑list and default‑deny.
- [ ] Confirm and retain the `dragonfly-global` Service with `service.cilium.io/global: "true"` and `shared: "true"` annotations as the stable cross‑cluster endpoint; document client DNS.
- [ ] Extend `PrometheusRule` with memory reserve (≥80%), disk saturation, replication health, and role‑change notifications.
- [ ] Optional: Provide `dragonfly-gitlab` CR example with its own PVC and resources, but do not switch GitLab yet (design only in this story).
- [ ] Documentation updates: architecture §B.9, Workloads & Versions table, and runbook notes.

### Tasks / Subtasks — Hardening (Should‑Fix)
- [ ] Harden Dragonfly pod securityContext in `kubernetes/workloads/platform/databases/dragonfly/dragonfly.yaml` (set `runAsNonRoot: true`, `readOnlyRootFilesystem: true`, `allowPrivilegeEscalation: false`, and drop all capabilities) — if supported by the operator CR.
- [ ] Confirm operator PDB remains enabled (minAvailable ≥1) via HelmRelease values; add an explicit operator PDB manifest only if the chart does not emit one.
- [ ] Ensure liveness/readiness probes are configured or tuned appropriately for `/healthz` on port 8080 to reduce failover time.
- [ ] Add per‑tenant example CR `docs/examples/dragonfly-gitlab.yaml` referenced by this story (no consumer switch in this story).

## Validation Steps
- flux -n flux-system --context=infra reconcile ks infra-infrastructure --with-source
- kubectl --context=infra -n dragonfly-operator-system get deploy,po
- kubectl --context=infra -n dragonfly-operator-system get pdb
- kubectl --context=infra -n dragonfly-system get dragonflies.dragonflydb.io,pods,svc,pvc
- kubectl --context=infra -n dragonfly-system get pdb
- kubectl --context=infra -n dragonfly-system get dragonflies.dragonflydb.io dragonfly -o yaml | rg -n 'topologySpreadConstraints|antiAffinity'
- kubectl --context=infra -n dragonfly-system get prometheusrule servicemonitor
- kubectl --context=infra -n dragonfly-system get networkpolicy
- Policy enforcement: from allowed namespaces (gitlab-system, harbor), `redis-cli -h dragonfly.dragonfly-system.svc.cluster.local PING` succeeds; from a disallowed namespace, TCP connect to 6379 is blocked.
- SecurityContext check: `kubectl --context=infra -n dragonfly-system get dragonflies.dragonflydb.io dragonfly -o yaml | rg -n 'runAsNonRoot|readOnlyRootFilesystem|allowPrivilegeEscalation'`
- Probes check: `kubectl --context=infra -n dragonfly-system get dragonflies.dragonflydb.io dragonfly -o yaml | rg -n 'livenessProbe|readinessProbe'`
- From apps: `nc -vz dragonfly.dragonfly-system.svc.cluster.local 6379` (or app pod test) and confirm GitLab cache/Sidekiq connectivity.
- VictoriaMetrics: confirm `dragonfly_*` series present; alerts evaluate.

## Definition of Done
- All ACs satisfied; evidence (commands, screenshots, alert samples) attached in Dev Notes.

---

## Research — Best Practices (Operator + Dragonfly)

- Operator delivery via Helm (OCI) with CRDs managed by the chart. Keep `CreateReplace` on install/upgrade and remediation with retries; run ≥2 replicas with a PDB to avoid webhook and reconcile gaps during node maintenance.
- Dragonfly CR: 3 pods minimum for HA (1 primary, 2 replicas). Persist data to fast storage; set `--dir=/data`, expose metrics, and enable authentication via a Secret. Use PVCs sized with headroom (30–50%).
- Replication & persistence: Prefer master‑only snapshots (if supported in chosen version) to offload replica IO; validate replication behavior on primary restart to avoid divergence.
- Security: Run as non‑root, drop capabilities, restrict ingress via NetworkPolicy. Use External Secrets for credentials.
- Cross‑cluster access: Rely on Cilium global Services for DNS and routing; keep a stable `ClusterIP` Service annotated as global/shared.
- Observability: Enable ServiceMonitor; add alert rules for availability, memory and disk pressure, replication lag, and command rate bursts. Label time series with instance/role for dashboards.

## Gap Analysis — Repo vs Best Practices

- Operator already aligned: OCIRepository + HelmRelease with HA, PDB, anti‑affinity, ServiceMonitor enabled.
- Dragonfly CR present with 3 replicas, PVCs, auth, metrics, and a global Service; missing items: pod anti‑affinity/topology spread on data plane, explicit PDB for data pods, and NetworkPolicy. Image is `v1.17.0`; plan upgrade to a tested newer tag.
- Observability rules exist; extend to include memory reserve and disk saturation alerts.

## Notes for Future Stories (Out of Scope Here)

- Per‑tenant Dragonfly CRs (e.g., dedicated `dragonfly-gitlab`) with tailored resources and ACLs.
- Automated backups/export of snapshot/AOF files to object storage with restore drills.
