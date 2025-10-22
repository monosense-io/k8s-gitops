# XX — STORY-APP-HARBOR — Harbor (Anchor App) on Infra

Sequence: 35/38 | Prev: STORY-OBS-FLUENT-BIT-IMPLEMENT.md | Next: STORY-CICD-GITHUB-ARC.md

Status: Draft
Owner: Platform Engineering
Date: 2025-10-22
Links: docs/architecture.md §19; kubernetes/workloads/platform/registry/harbor; kubernetes/infrastructure/networking/cilium/gateway; kubernetes/workloads/platform/databases/cloudnative-pg/poolers

## Story
Deploy Harbor on the infra cluster as the platform container registry. Use external Postgres (CNPG pooler), external Redis‑compatible cache (Dragonfly), and object storage (S3 or Ceph RGW). Expose via Gateway API with TLS from cert‑manager.

## Why / Outcome
- Serves as the anchor application to demonstrate GitOps deployment, externalized state, rollback, and observability.

## Scope
- Cluster: infra
- Resources (to be created):
  - `kubernetes/workloads/platform/registry/harbor/{namespace,externalsecrets,helmrelease}.yaml`
  - `kubernetes/infrastructure/networking/cilium/gateway/harbor-httproute.yaml`
  - ExternalSecrets mapping DB, cache, and S3 creds from `cluster-settings` paths.

## Acceptance Criteria
1) Harbor pods Ready; UI reachable over HTTPS at `${HARBOR_HOST}` through Gateway; TLS valid.
2) External DB: Harbor connects via CNPG pooler; migrations succeed.
3) External cache: Harbor uses Dragonfly; background jobs stable.
4) Object storage configured for artifacts; push/pull of a test image succeeds.
5) Observability: ServiceMonitor discovered; basic dashboards/alerts show Harbor health.
6) Rollback guide present and exercised (chart version revert) with evidence.

## Dependencies / Inputs
- CNPG shared cluster and `harbor-pooler` Service; Dragonfly global Service; S3/RGW bucket and creds.
- cert‑manager issuers; Cilium Gateway; External Secrets store paths: `${HARBOR_DB_SECRET_PATH}`, `${HARBOR_REDIS_SECRET_PATH}`, `${HARBOR_S3_SECRET_PATH}`.

## Tasks / Subtasks — Implementation Plan (Story Only)
- [ ] Create namespace `harbor` and ExternalSecrets for DB/Redis/S3.
- [ ] Author Harbor HelmRelease with in‑chart DB/Redis disabled; wire external endpoints and secrets.
- [ ] Add HTTPRoute for `${HARBOR_HOST}` with TLS; reference the cluster `Gateway` and wildcard (or dedicated) cert.
- [ ] Add ServiceMonitor and basic alert rules; annotate pods for scraping if needed.
- [ ] Produce rollback runbook; validate by downgrading the chart one patch version and restoring.

## Validation Steps
- UI: login, create a project, push/pull `hello-world` image.
- DB/cache: check logs for connection stability; run a GC job.
- Observability: verify metrics series present and alerts loaded.
- Rollback: perform version rollback and confirm health; capture evidence.

## Definition of Done
- ACs met; evidence captured; Harbor serves as anchor app for the platform.
