# PRD: Multi-Cluster Kubernetes GitOps Platform (Greenfield, Talos)

Status: Draft
Owner: Platform Engineering (Infra/DevOps)
Date: 2025-10-20
Version: v4

## 1. Executive Summary
We will stand up a greenfield, two‑cluster Kubernetes platform on Talos Linux, managed end‑to‑end with GitOps (Flux + Helm + Kustomize). One cluster ("infra") hosts shared platform services (storage, databases, observability, security). A second cluster ("apps") hosts application workloads with its own storage (Rook‑Ceph + OpenEBS LocalPV) and a leaf observability pack that ships data to infra. Bootstrap uses a phased Helmfile approach (Phase 0: CRDs, Phase 1: core); Flux then reconciles all day‑2 configuration with explicit dependencies, health checks, and wait/prune semantics. Secrets are managed exclusively via External Secrets with 1Password Connect. The design supports reproducible rebuilds, safe promotion, and clear separation of concerns.

## 2. Goals
- Deterministic cluster bootstrap with minimal manual steps and fast time‑to‑green.
- Clear, maintainable repository structure aligned to Flux best practices.
- Day‑2 operations (Cilium policies, issuers, storage, observability, workloads) fully managed by Flux.
- Security by default: no plaintext secrets in Git; least privilege; policy guardrails.
- Scalable to additional environments and optional multi‑tenancy.

## 3. Non‑Goals
- Managing app team SDLC beyond GitOps interfaces and shared services.
- In‑depth Talos OS lifecycle procedures (provided via task helpers/runbooks elsewhere).

## 4. Users & Use Cases
- Platform Engineers: bootstrap clusters, manage shared services, enforce policy, operate Flux.
- Application Developers: ship workloads via GitOps overlays; request namespaces/RBAC.
- SecOps: manage secrets, CA/issuers, policy; audit changes.
- SRE/Operations: observe/alert; perform restore/rollback; scale/recover clusters.

Primary use cases
- Fresh install of both clusters from zero to Flux‑managed steady state.
- Day‑2 config rollout: Cilium BGP/Gateway, cert-manager issuers, storage, observability.
- Workload onboarding with environment overlays and image automation.
- Backup/restore drill of databases and critical state.

## 5. Assumptions & Constraints
- Bare‑metal or on‑prem nodes; Talos Linux on all nodes.
- Private container registry access available; DNS/control delegated for cluster domains.
- Outbound egress allowed for charts/OCI and secret store.
- Two physical networks (or VLANs) available for cluster and storage (recommended).

## 6. Requirements
### 6.1 Functional
- Bootstrap (Taskfile is canonical)
  - Phase −1: `task bootstrap:talos` brings up first control plane, bootstraps etcd, applies remaining CPs, and exports kubeconfig.
  - Phase 0: `task :bootstrap:phase:0` applies prerequisites (namespaces, initial secrets).
  - Phase 1: `task :bootstrap:phase:1` installs CRDs only, extracted from charts (no controllers).
  - Phase 2: `task :bootstrap:phase:2` installs core controllers: cilium → coredns → cert‑manager (CRDs disabled) → external-secrets (CRDs disabled) → flux‑operator → flux‑instance.
  - Phase 3: `task :bootstrap:phase:3` validates readiness and Flux health; `task bootstrap:status` summarizes state.
  - Raw kubectl/helmfile commands are reference only (appendix in stories); Taskfiles are the only supported path.
  - Optional: role‑aware Talos layout `talos/<cluster>/{controlplane,worker}/`; workers join after API is up.
- GitOps Convergence
  - Flux Kustomizations with `dependsOn`, `wait`, `prune`, explicit `timeout`, and `healthChecks/healthCheckExprs`.
  - Repository sources (Git/Helm/OCI) scoped and discoverable; no remote bases.
- Secrets Management
  - External Secrets with 1Password Connect (only).
- Networking
  - Cilium core via Helmfile; Flux manages day‑2 features (BGP, Gateway, ClusterMesh secret, IPAM pools). Clusters share the same L2 (/24) and use BGP to a common router (10.25.11.1) for cross‑cluster PodCIDR reachability (single L3 hop).
- Storage
  - Infra cluster: Rook‑Ceph operator + cluster; Apps cluster: Dedicated Rook‑Ceph operator + cluster to avoid the 1 Gbps router bottleneck; OpenEBS LocalPV remains the default StorageClass on apps for node‑local NVMe.
- Observability
  - Infra: VictoriaMetrics global + VictoriaLogs; Apps: "leaf" pack only (vmagent for scrape/remote_write, kube‑state‑metrics, node‑exporter, Fluent Bit). No local TSDB/alerting/dashboards on apps. Install victoria‑metrics‑operator CRDs and prometheus‑operator CRDs on apps via Phase 0 so ServiceMonitor/PodMonitor/PrometheusRule/VM* resources are valid.
- CI/CD
  - Pre‑merge validations: kubeconform strict, kustomize build, flux build/diff.
  - Bootstrap smoke: run `task bootstrap:dry-run CLUSTER=infra` to catch helmfile/values drift (non‑blocking initially; can become gating).
- Policy
  - Admission policy baseline → restricted (audit then enforce), image provenance (cosign/notation) as stretch.

### 6.2 Non‑Functional
- Security: no plaintext secrets in Git; no cross‑namespace refs (tenants); network policies; TLS everywhere.
- Reliability:
  - Idempotent bootstrap tasks: re‑running any Phase yields no unintended changes.
  - Time‑to‑ready SLOs (per cluster, baseline): Talos ≤ 7m; CRDs ≤ 2m; Core ≤ 6m; total ≤ 20m.
  - Post‑change reconcile < 10 minutes; restore drill < 60 minutes.
- Performance: Flux reconcile intervals tuned; kustomize build < 60s per entry; controller CPU/memory within quotas.
- Scalability: ≥ 2 clusters, ≥ 50 Kustomizations, ≥ 30 HelmReleases; shardable controllers if needed.
- Operability: first‑class runbooks; alert coverage (Flux, cert‑manager, storage, cilium).
- Observability Readiness: CRDs for `monitoring.coreos.com` and `operator.victoriametrics.com` present before any dependent resources are applied.

### 6.3 Acceptance
- Handover Criteria: flux‑operator Ready; flux‑instance Ready; GitRepository connected; all initial Kustomizations Ready; `kustomize build` + `kubeconform` clean for cluster root.
- CI Dry‑Run in place running `task bootstrap:dry-run CLUSTER=infra` and writing a short summary; initially non‑blocking with a documented path to gating later.

## 7. Architecture Overview
See `docs/architecture.md` for full design. Highlights:
- Two clusters (infra, apps). Cilium for CNI; WireGuard transparent encryption; BGP control plane; Gateway API.
- Flux manages day‑2 resources; Helmfile performs deterministic bootstrap. Cilium ClusterMesh provides cross‑cluster service reachability with Global Services/MCS; until Cilium mutual‑auth spans ClusterMesh, app‑level TLS is required for sensitive cross‑cluster calls.
- Repository: `kubernetes/clusters/<cluster>` entries; `infrastructure/` (networking/security/storage); `workloads/` (platform & tenants); `bootstrap/` (helmfile, resources); `.taskfiles/` for Talos/bootstrap ops.

## 8. Environments
- Infra (id=1), Apps (id=2). Optional: apps‑dev, apps‑stg, apps‑prod overlays. All environments share repo; cluster‑specific `cluster-settings.yaml` provides variables.

## 9. Bootstrap Flow (Happy Path)
1) Install Talos on nodes; verify control plane reachable.
2) `task bootstrap:talos` → initializes cluster and writes kubeconfig.
3) Apply CRDs on both clusters (Phase 0). For apps cluster specifically:
   ```bash
   task bootstrap:apps-crds
   ```
   This installs victoria‑metrics‑operator CRDs and prometheus‑operator CRDs required by ServiceMonitor/PodMonitor/PrometheusRule/VM* resources.
4) `task bootstrap:infra` and `task bootstrap:apps` → apply prerequisites, Helmfile CRDs (if not already run), and core infrastructure.
4) Flux takes over; `flux get kustomizations -A` turns green as repo reconciles.

## 10. Security & Compliance
- Secrets: External Secrets (1Password Connect) with minimal bootstrap token for bootstrap; no SOPS.
- RBAC: no cluster‑admin for workloads; tenant namespaces with least privilege.
- Admission: baseline → restricted policies; image signature verification (phase 2+).
- Audit: Flux alerts to chat; audit logs centralized.

Network policy baseline (summary)
- Default‑deny per namespace; allow DNS and kube‑apiserver egress; FQDN allowlists for internet egress; gateway‑only ingress for exposed apps; CiliumAuthPolicy + SPIRE for in‑cluster mTLS on sensitive paths; app‑level TLS for cross‑cluster sensitive paths.

## 11. Operations & Supportability
- Runbooks: bootstrap, re‑apply, pause/resume Flux, rollback, Talos node ops, storage maintenance.
- Backups: CNPG scheduled backups with validation; Ceph object/pool backup.
- DR: documented RTO/RPO; quarterly drill.

Cross‑cluster routing expectations
- With native routing and BGP to 10.25.11.1, cross‑cluster pod traffic uses a single L3 hop via the router. This is acceptable on the same /24 and simplifies operations. Dedicated Ceph on apps avoids pushing storage I/O over that hop.

## 12. Risks & Mitigations
- CRD/app ordering issues → two‑phase bootstrap + postRenderer CRD filter; health checks.
- Secret store outage → alerts on External Secrets sync and 1Password Connect availability.
- Network disruption from BGP/Gateway → stage behind Kustomization toggles; can suspend Kustomization. LB IP pools are disjoint per cluster; add admission to prevent cross‑label usage. BGP serviceSelector tightened to advertise only intended Services per cluster.
- Controller saturation → shard controllers; tune intervals; label selectors.

## 13. Success Metrics & KPIs
- Reconciliation health ≥ 99%; CI pass rate ≥ 95% on main; median reconcile < 5m.
- MTTR rollback < 15m; successful restore drills ≥ 1/quarter.
- Policy violations trend to zero after enforcement.

## 14. Milestones & Timeline (Sprints)
- Sprint 0: Foundations (flags, CI, 1Password Connect bootstrap)
- Sprint 1: Repo skeleton + bootstrap files/tasks
- Sprint 2: Secrets (External Secrets only)
- Sprint 3: Platform controllers (ES, cert‑manager, CNPG if used)
- Sprint 4: Networking day‑2 via Flux
- Sprint 5: Storage
- Sprint 6: Observability
- Sprint 7: CI/Policy & image automation
- Sprint 8: Workloads migration (anchor app)
- Sprint 9: Tenancy & RBAC (optional)
- Sprint 10: DR & hardening

## 15. Open Questions
- Secret backend default: 1Password Connect (SOPS not used)
- Tenant model scope in phase 1?
- Image provenance enforcement timeline?

## 16. Dependencies
- DNS control and public certs; registry access; chat endpoint for alerts; secret store availability.

## 17. Appendix: Glossary
- Flux, Helmfile, Kustomize, OCI, Talos, CNPG, BGP, Gateway API, External Secrets.
