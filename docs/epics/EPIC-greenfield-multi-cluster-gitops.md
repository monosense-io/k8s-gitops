# EPIC: Greenfield Multi‑Cluster GitOps on Talos

Status: Proposed → In Progress
Owner: Platform Engineering
Date: 2025-10-21

## 1. Summary
Stand up from scratch a two‑cluster Kubernetes platform on Talos, bootstrap with Helmfile, and operate via Flux. Deliver a production‑grade repo, deterministic bootstrap, secure secrets, and phased workload enablement.

## 2. Business Value
- Faster, safer infra changes through GitOps, reducing toil and change failure.
- Reproducible rebuilds; consistent environments (infra/apps) supporting growth.
- Security posture by default (secrets, policy, audit), lowering compliance risk.

## 3. Scope
In Scope
- Repo structure, bootstrap files, Taskfiles, Flux Kustomizations, platform controllers, networking day‑2, storage, observability, CI/policy, and anchor workload migration.
Out of Scope
- Application feature work beyond platform enablement; vendor selection for non‑core tools.

## 4. Deliverables
- docs/architecture.md, docs/prd.md.
- bootstrap/helmfile.d/{00-crds.yaml,01-apps.yaml} + bootstrap/resources.yaml + templates/values.yaml.gotmpl.
- .taskfiles/bootstrap/Taskfile.yaml, .taskfiles/talos/Taskfile.yaml.
- Normalized kubernetes/ tree (clusters, infrastructure, workloads) with health checks.
- CI workflows: kubeconform, kustomize build, flux build/diff.
- Alerts: Flux Provider + Alerts to chat.

## 5. Success Criteria (Definition of Done)
- Fresh install completes: task bootstrap:talos then task bootstrap:apps → Flux healthy on both clusters.
- 0 missing dependsOn; all Kustomizations have wait, prune, timeouts, and health checks.
- Secrets are managed via External Secrets (1Password Connect); no plaintext in Git.
- CI passing on main; flux alerts emitting.
- One anchor platform app (e.g., Harbor) deployed via GitOps with rollback verified.

## 6. Risks & Mitigations
- CRD ordering → two‑phase bootstrap + CRD filter postRenderer.
- Secret store outage → alerting on External Secrets sync; ensure 1Password Connect is HA.
- Network changes risky → toggleable Kustomizations; staged rollout; clear rollback.
- Controller scale → shard or tune reconcile intervals.

## 7. Plan (Sprints)

Sprint 0 — Foundations
- Decide bootstrap ownership; lock Flux flags (no remote bases, no cross‑ns refs); scaffold CI; prepare 1Password Connect bootstrap.
- DoD: Docs + CI skeleton green; 1Password Connect bootstrap plan approved.

Sprint 1 — Repo & Bootstrap Skeleton
- Create clusters entries, infrastructure/workloads dirs; add bootstrap helmfiles and Taskfiles; ensure .spec.values reuse between Helmfile and HelmRelease.
- DoD: helmfile template and kustomize build clean for both clusters.

Sprint 2 — Secrets (External Secrets Only)
- Seed bootstrap/resources.yaml; configure External Secrets + 1Password Connect for bootstrap/runtime.
- DoD: bootstrap runs end‑to‑end; External Secrets sync verified.

Sprint 3 — Platform Controllers
- External Secrets, cert‑manager CRDs + issuers, CNPG (if used). Add health checks and ordering.
- DoD: controllers/configs healthy; issuer Ready checks pass.

Sprint 4 — Networking Day‑2
- Flux manage Cilium BGP, GatewayClass/Gateways, ClusterMesh secret; health checks for Cilium DS/Deployment.
- DoD: peers Established; GatewayClass Ready; mesh secret synced.

Sprint 5 — Storage
- Infra Rook‑Ceph operator + cluster; Apps dedicated Rook‑Ceph operator + cluster; PVC tests; monitoring rules.
- DoD: PVCs bound on both clusters; Ceph health green; alerts wiring.

Sprint 6 — Observability
- Infra: VictoriaMetrics Global + VictoriaLogs. Apps: vmagent + kube‑state‑metrics + node‑exporter + Fluent Bit (remote write/logs to infra). CRDs Phase 0 installed on apps.
- DoD: dashboards live; alert routes working; Flux alerts visible.

Sprint 7 — CI/Policy & Automation
- kubeconform/kustomize/flux build in CI; admission policy audit → enforce; image automation on selected apps.
- DoD: CI required; failing policies block merges in dev; automation landed to staging.

Sprint 8 — Workloads Migration (Anchor)
- Normalize bases/overlays; migrate Harbor (or chosen anchor) end‑to‑end; rollback tested.
- DoD: app deployed, rollback exercised, runbook merged.

Sprint 9 — Tenancy & RBAC (Optional)
- Team namespaces + RBAC + per‑team Kustomizations; isolation validated.
- DoD: tenant can deploy; no cross‑ns refs; audit logs show isolation.

Sprint 10 — DR & Hardening
- Backup/restore drills; PodSecurity enforce; image provenance; finalize runbooks.
- DoD: successful restore; hardening checklist closed.

## 8. Stories (Initial Backlog)
- STORY‑BOOT‑CRDS: Phase 0 CRDs on infra + apps (victoria‑metrics‑operator CRDs + prometheus‑operator CRDs).
- STORY‑BOOT‑CORE: Phase 1 core (Cilium/CoreDNS/ExternalSecrets/cert‑manager [crds:false]/Flux).
- STORY‑NET‑BGP‑CLUSTERMESH: BGP peering + LB IP pools + ClusterMesh ExternalSecret + DNS.
- STORY‑STO‑APPS‑ROOK: Apps cluster Rook‑Ceph (operator + cluster) + StorageClasses; align versions with infra.
- STORY‑OBS‑APPS‑LEAF: vmagent + kube‑state‑metrics + node‑exporter + Fluent Bit on apps (remote write/logs to infra); CRDs present.
- STORY‑SEC‑NP‑BASELINE: Default‑deny + DNS/API egress + FQDN allowlists + CiliumAuthPolicy exemplars.
- STORY‑CI‑PIPELINE: kubeconform + kustomize + flux build; remove SOPS checks.
- STORY‑APP‑ANCHOR: Anchor app (Harbor) via HelmRelease + health checks; rollback runbook.

## 9. Dependencies
- DNS and certificates; registry; secret store credentials; chat endpoint for alerting.

## 10. Acceptance & Validation
- CI matrix builds clusters/infra and clusters/apps entries.
- flux get kustomizations -A healthy; alert test messages received.
