# 35 — STORY-APP-HARBOR — Harbor (Anchor App) on Infra

Sequence: 35/41 | Prev: STORY-CICD-GITLAB-APPS.md | Next: STORY-TENANCY-BASELINE.md
Sprint: 7 | Lane: Applications
Global Sequence: 35/41

Status: Draft
Owner: Platform Engineering
Date: 2025-10-22
Links: docs/architecture.md §19; kubernetes/workloads/platform/registry/harbor; kubernetes/infrastructure/networking/cilium/gateway; kubernetes/workloads/platform/databases/cloudnative-pg/poolers

## Story
Deploy Harbor on the infra cluster as the platform container registry. Use external PostgreSQL (CNPG pooler), external Redis‑compatible cache (Dragonfly), and object storage backed by our local MinIO (S3 API). Expose via Gateway API with TLS from cert‑manager. The registry’s blob and chart content MUST reside in the local MinIO bucket, not in PVCs. citeturn0search0

## Why / Outcome
- Serves as the anchor application to demonstrate GitOps deployment, externalized state, rollback, and observability.

## Scope
- Cluster: infra
- Helm repo already present: `kubernetes/infrastructure/repositories/helm/harbor.yaml`.
- Resources (to be created):
  - `kubernetes/workloads/platform/registry/harbor/{namespace,externalsecrets,helmrelease}.yaml`
  - `kubernetes/infrastructure/networking/cilium/gateway/harbor-httproute.yaml`
  - ExternalSecrets mapping DB, cache, and S3 creds from `cluster-settings` paths.
  - NetworkPolicy for Harbor namespace (egress: CNPG pooler, Dragonfly, MinIO, Trivy update endpoints; ingress via Gateway only).

## Acceptance Criteria
1) Harbor pods Ready; UI reachable over HTTPS at `${HARBOR_HOST}` through Gateway; TLS valid (cert‑manager issuer).
2) External DB: Harbor uses CNPG pooler (rw) via `${HARBOR_DB_SECRET_PATH}`; schema migrations succeed; liveness/readiness probes green. citeturn0search0
3) External cache: Harbor uses Dragonfly (addr: `dragonfly.dragonfly-system.svc.cluster.local:6379`) via `${HARBOR_REDIS_SECRET_PATH}`; jobservice and core show healthy Redis connections. citeturn0search0
4) Object storage: `persistence.imageChartStorage.type: s3` configured to MinIO at `http://10.25.11.3:9000`; bucket `harbor` exists; chart values set `s3.regionendpoint`, `s3.bucket`, `s3.accesskey/secretkey` provided via ExternalSecret/valuesFrom; `persistence.imageChartStorage.disableredirect: true` and `registry.relativeurls: true` are set (MinIO backend). Push/pull a test image succeeds. citeturn0search0
5) Exposure: Chart `expose.type` is not used for Ingress/LB; we set `expose.type: clusterIP` and publish with a Gateway API HTTPRoute bound to the cluster Gateway. citeturn0search0
6) Observability: ServiceMonitor discovered; dashboard panels show Harbor Core/Registry metrics.
7) Security posture: Harbor namespace has default‑deny; egress allowlists for CNPG/Dragonfly/MinIO; route only via Gateway.
8) Rollback guide present and exercised (chart version revert) with evidence.

## Dependencies / Inputs
- CNPG shared cluster and `harbor-pooler` Service; Dragonfly global Service.
- MinIO bucket `harbor` created with access/secret; reachable at `http://10.25.11.3:9000` (no TLS for internal use).
- cert‑manager issuers; Cilium Gateway; HelmRepository `harbor` (present).
- External Secrets store paths in `cluster-settings` (to be added if missing):
  - `${HARBOR_DB_SECRET_PATH}` → renders `harbor-db-credentials` (user/password/db/host/port/sslmode)
  - `${HARBOR_REDIS_SECRET_PATH}` → renders `harbor-redis-credentials` (addr, password if set)
  - `${HARBOR_S3_SECRET_PATH}` → renders `harbor-s3` (accesskey, secretkey, bucket, regionendpoint)

## Tasks / Subtasks — Implementation Plan (Story Only)
Data plane & namespace
- [ ] Create `kubernetes/workloads/platform/registry/harbor/namespace.yaml` (ns: `harbor`), apply baseline policies (deny‑all + allow‑dns + allow‑kube‑api), and ServiceAccount if needed.

External Secrets
- [ ] Add ExternalSecret `harbor-db-credentials` from `${HARBOR_DB_SECRET_PATH}` with keys: `host`, `port`, `dbname`, `username`, `password`, `sslmode` (default `disable`).
- [ ] Add ExternalSecret `harbor-redis-credentials` from `${HARBOR_REDIS_SECRET_PATH}` with keys: `addr`, `password` (optional).
- [ ] Add ExternalSecret `harbor-s3` from `${HARBOR_S3_SECRET_PATH}` with keys: `accesskey`, `secretkey`, `bucket`, `regionendpoint` (e.g., `http://10.25.11.3:9000`).

HelmRelease (values with valuesFrom)
- [ ] Author `helmrelease.yaml` (chart `harbor/harbor`) with:
  - `externalURL: https://${HARBOR_HOST}`.
  - `expose.type: clusterIP` (we’ll publish with Gateway API). citeturn0search0
  - `database.type: external` and `database.external.{host,port,username,sslmode}` from `harbor-db-credentials`; use HelmRelease `valuesFrom` to avoid plaintext. citeturn0search0
  - `redis.type: external` and `redis.external.{addr}` (+ `existingSecret` if using chart support), sourced from `harbor-redis-credentials`. citeturn0search0turn0search5
  - `persistence.imageChartStorage.type: s3` with:
    - `s3.regionendpoint`, `s3.bucket` from `harbor-s3`.
    - `s3.accesskey`, `s3.secretkey` via HelmRelease `valuesFrom` → secret `harbor-s3` (no plaintext in Git).
    - `persistence.imageChartStorage.disableredirect: true` (required for MinIO). citeturn0search0
  - `registry.relativeurls: true` (proxy/gateway‑fronted). citeturn0search0
  - Disable ChartMuseum (use OCI artifacts) unless explicitly required: `chartmuseum.enabled: false`.
  - Keep `trivy.enabled: true` with internet egress for DB updates; set cache PVC or RAM as defaults.
  - Set resource requests/limits and replicas (2 for stateless components; 1 for trivy/notary by default).

Gateway API (HTTPRoute)
- [ ] Create `kubernetes/infrastructure/networking/cilium/gateway/harbor-httproute.yaml`:
  - Hostname `${HARBOR_HOST}`; TLS terminated at cluster `Gateway` using wildcard or dedicated cert.
  - BackendRef → Service `harbor` port 80 (chart’s aggregated service when `expose.type: clusterIP`).
  - Optional: Add separate `HTTPRoute` for notary if enabled (`:4443` via gateway TLS passthrough or re‑terminate).

NetworkPolicy
- [ ] Apply `deny-all` and allow rules in `harbor` namespace:
  - Egress allow to CNPG pooler (namespace `cnpg-system`), Dragonfly (namespace `dragonfly-system`), and MinIO (`10.25.11.3:9000`).
  - Egress FQDN allowlist for Trivy DB updates (GitHub/Aqua endpoints), and CRL/OCSP as needed.
  - Ingress only via Gateway (no direct pod access).

Observability
- [ ] Add ServiceMonitor(s) for core/registry and basic PrometheusRules; verify metrics in VictoriaMetrics.

Operability
- [ ] Produce rollback runbook (chart version pin + revert procedure) and validate by downgrading one patch.

Optional (future)
- [ ] OIDC (Keycloak) configuration for Harbor UI (auth mode `oidc`): client config via ExternalSecret; map groups/projects.
- [ ] Replication policies to external registries (out‑of‑scope here).

## Validation Steps
- Helm/Flux
  - `flux -n flux-system --context=infra reconcile ks infra-infrastructure --with-source`
  - `kubectl --context=infra -n harbor get pods,svc`
- Storage (MinIO)
  - Confirm chart values: `helmrelease harbor -o yaml | rg -n 'imageChartStorage|s3|disableredirect'`
  - Push/pull: `docker login ${HARBOR_HOST}`; `docker push ${HARBOR_HOST}/test/probe:1.0`; `docker pull ...`
- DB/Redis
  - Core and jobservice logs show successful PostgreSQL/Redis connections.
- Exposure
  - `kubectl --context=infra -n kube-system get gateway cilium-gateway -o yaml | rg addresses`
  - `kubectl --context=infra -n harbor get svc harbor` (ClusterIP) and `curl -k https://${HARBOR_HOST}` → UI loads.
- Observability
  - ServiceMonitor targets up; core/registry metrics visible.
- Security
  - NetworkPolicy: only allowed egress observed; gateway‑only ingress works.
- Rollback
  - Change chart version (−1 patch); reconcile; confirm healthy; record evidence.

## Definition of Done
- ACs met; evidence captured; Harbor serves as anchor app for the platform.

---

## Research Notes — Architect Review (condensed)

- Expose & Gateway: The chart supports multiple expose types, including gateway‑api/HTTPRoute in 1.0.0+, but we’ll standardize on `expose.type: clusterIP` and publish through our cluster Gateway with a dedicated HTTPRoute. This keeps routing policy centralized. citeturn0search0

- External DB/Redis: Chart provides `database.type: external` and `database.external.*` plus `redis.type: external` (with optional `existingSecret`). We’ll consume credentials via ExternalSecret + HelmRelease `valuesFrom` so secrets never live in Git. citeturn0search0turn0search5

- Object storage (MinIO): Use `persistence.imageChartStorage.type: s3` with `s3.regionendpoint` pointing to MinIO and `persistence.imageChartStorage.disableredirect: true` to avoid redirect behavior MinIO doesn’t support. Set `registry.relativeurls: true` when Harbor is fronted by a reverse proxy/Gateway. citeturn0search0

- ChartMuseum: Prefer OCI artifacts (disable ChartMuseum) to simplify storage and auth. (Harbor supports OCI by default.)

- Trivy: Keep online DB updates; add FQDN allowlist for egress in NetworkPolicy.

- Review of existing manifests: HelmRepository exists at `kubernetes/infrastructure/repositories/helm/harbor.yaml`. No HelmRelease/namespace yet. An older README under `kubernetes/workloads/platform/registry/harbor/` references PVC storage; this story moves storage to MinIO per platform requirement.
