# 34 — STORY-CICD-GITLAB-APPS — GitLab + Runners (DIND) on Apps Cluster

Sequence: 34/41 | Prev: STORY-CICD-GITHUB-ARC.md | Next: STORY-APP-HARBOR.md
Sprint: 7 | Lane: Applications
Global Sequence: 34/41

Status: Draft
Owner: Platform Engineering
Date: 2025-10-21
Links: docs/architecture.md §“GitLab Configuration”; kubernetes/workloads/tenants/gitlab; kubernetes/infrastructure/networking/cilium/gateway; kubernetes/workloads/platform/databases/cloudnative-pg/poolers

## Story
Deploy GitLab (Helm chart) in the apps cluster with external state (PostgreSQL via CNPG pooler, Redis via Dragonfly), S3-compatible object storage, HTTPS via Gateway API, and GitLab Runner with Kubernetes executor that supports Docker-in-Docker (DIND) for container builds.

## Why / Outcome
- First-class, self-managed GitLab with CI that builds/pushes images from the cluster.
- Separation of stateless vs. stateful components per our architecture (DB in infra cluster, object storage external, Redis service).
- Runners provide isolated, ephemeral build pods with optional privileged DIND support.

## Scope
- Namespaces: `gitlab-system` (GitLab), `gitlab-runner` (Runner — isolated)
- GitLab via HelmRelease; external Postgres/Redis/ObjectStorage; HTTPS through Gateway API (Cilium).
- GitLab Runner via HelmRelease, Kubernetes executor. Privileged jobs (DIND) run only in `gitlab-runner` with PSA guardrails; prefer non‑privileged alternatives (BuildKit/Kaniko) for most projects.

## Acceptance Criteria
1) GitLab endpoints are reachable over HTTPS at `${GITLAB_HOST}`; admin bootstrap succeeds (root cred via ExternalSecret).
2) External DB: Rails, Sidekiq, and migrations connect to CNPG through `${GITLAB_DB_SECRET_PATH}` with the `gitlab_app` role; health checks pass. 
3) External Redis (Dragonfly or Redis): GitLab uses `${GITLAB_REDIS_SECRET_PATH}`; background jobs and cache work.
4) Object storage: Artifacts/LFS/Uploads/Packages/Registry are configured to use S3-compatible storage via `${GITLAB_S3_SECRET_PATH}`; uploads and downloads succeed.
5) GitLab Runner registers automatically using `${GITLAB_RUNNER_REG_TOKEN}` secret, schedules jobs via the Kubernetes executor, and can run DIND jobs with privileged containers.
6) Sample pipeline builds and pushes an image using DIND to the target registry (Harbor or GitLab Registry per config).
7) Monitoring: ServiceMonitors from the charts are discovered by Prometheus; basic dashboards show web, sidekiq, and runner health.

## Dependencies / Inputs
- CNPG shared cluster and `gitlab-pooler` (rw) exist in `cnpg-system`; secret `${GITLAB_DB_SECRET_PATH}` present. 
- Dragonfly or Redis service reachable; secret `${GITLAB_REDIS_SECRET_PATH}` present.
- S3 object storage reachable (MinIO RGW, AWS S3, etc.); secret `${GITLAB_S3_SECRET_PATH}` present.
- cert-manager issuers available; Gateway API enabled with Cilium; `${GITLAB_HOST}`, `${GITLAB_REGISTRY_HOST}` set in `cluster-settings`.
- ExternalSecrets store configured; `${GITLAB_ROOT_SECRET_PATH}` and `${GITLAB_RUNNER_REG_TOKEN}` defined.

## Tasks / Subtasks — Implementation Plan (Story Only)
- [ ] Prepare namespaces (Security Isolation)
  - `kubernetes/workloads/tenants/gitlab/namespace.yaml` (ensure `gitlab-system` exists; no privileged workloads here)
  - Add `kubernetes/workloads/tenants/gitlab-runner/namespace.yaml` (ns: `gitlab-runner`) with PSA labels:
    - `pod-security.kubernetes.io/enforce: privileged`
    - `pod-security.kubernetes.io/audit: privileged`
    - `pod-security.kubernetes.io/warn: privileged`

- [ ] ExternalSecrets
  - `kubernetes/workloads/tenants/gitlab/externalsecrets.yaml` — map these keys to K8s secrets:
    - DB (Secret `gitlab-db-credentials`): host, port, dbname, user, password, sslmode; source `${GITLAB_DB_SECRET_PATH}`
    - Redis (Secret `gitlab-redis-credentials`): host, port, password (if set); source `${GITLAB_REDIS_SECRET_PATH}`
    - S3 (Secret `gitlab-s3-credentials`): endpoint, region, access_key, secret_key, bucket, insecure (true|false); source `${GITLAB_S3_SECRET_PATH}`
    - Root admin (Secret `gitlab-root`): password (or initial token); source `${GITLAB_ROOT_SECRET_PATH}`
    - Runner registration (Secret `gitlab-runner-registration`): token; source `${GITLAB_RUNNER_REG_TOKEN}`

- [ ] Gateway API exposure
  - Add `kubernetes/infrastructure/networking/cilium/gateway/gitlab-httproutes.yaml` — `HTTPRoute` for `${GITLAB_HOST}` (web) and optional `${GITLAB_REGISTRY_HOST}` (registry) with TLS from cert-manager (issuer per cluster policy). Attach to the existing `Gateway` in the same folder.

- [ ] GitLab HelmRelease (production posture; external state)
  - `kubernetes/workloads/tenants/gitlab/helmrelease.yaml` (chart: `gitlab/gitlab`):
    - Disable in-chart Postgres and Redis: `postgresql.install: false`, `redis.install: false`.
    - Configure external Postgres via `global.psql.*` pointing at the CNPG pooler host (e.g., `gitlab-pooler-rw.cnpg-system.svc.cluster.local`) and secret `gitlab-db-credentials`.
    - Configure external Redis via `global.redis.*` and secret `gitlab-redis-credentials`.
    - Configure object storage by disabling in-chart MinIO and setting `global.minio.enabled=false`, then configure `global.registry` and `global.appConfig.object_store` to use `gitlab-s3-credentials`.
    - Ingress/Routes: disable chart Ingress and rely on Gateway API HTTPRoutes, or keep Service exposure only (no in-chart ingress).
    - Optionally disable built-in GitLab Container Registry if Harbor is the authoritative registry.

- [ ] GitLab Runner (Kubernetes executor + DIND support)
  - Configure runner via `gitlab-runner` block in the same HelmRelease (preferred) or add a sibling HelmRelease under the same tenant folder; set `.namespace: gitlab-runner`.
  - Set `gitlabUrl: https://${GITLAB_HOST}` and inject `runnerRegistrationToken` from `gitlab-runner-registration` secret.
  - Security posture: dedicated ServiceAccount with minimal permissions; scope RBAC to namespace where possible.
  - Enable privileged mode only for tags that truly require DIND: in TOML `[runners.kubernetes] privileged = true` and restrict via tags; pin pods via nodeSelector/tolerations if isolated nodes available.
  - Set pod template defaults: nodeSelector/tolerations, ServiceAccount, runtimeClassName if needed. Optional: S3 cache using existing credentials.

## Validation Steps

AC1 — HTTPS reachability and bootstrap
- Reconcile: `flux -n flux-system --context=apps reconcile ks apps-workloads --with-source`
- Endpoints: `kubectl --context=apps -n gitlab-system get svc` (webservice/registry present)
- TLS: `curl -Ik https://${GITLAB_HOST}` returns 200/302 with correct issuer; registry host optional check if enabled.

AC2 — External DB connectivity (CNPG pooler)
- Pods healthy: `kubectl --context=apps -n gitlab-system get pods | rg "webservice|sidekiq"`
- Toolbox exec: `kubectl --context=apps -n gitlab-system exec -ti deploy/gitlab-toolbox -- bash -lc "psql 'host=<pooler-rw> dbname=gitlab user=gitlab_app sslmode=require' -c 'select 1'"`
- Migrations complete in logs; `rails db:prepare` not failing.

AC3 — External Redis
- Sidekiq processing: confirm queues active in Admin → Monitoring or check sidekiq logs for successful connection
- Optional: run `redis-cli -h <redis-host> -a <password> ping` from a debug pod if available

AC4 — Object storage
- Upload an artifact (e.g., pipeline job artifact) and verify object appears via S3 client: `aws --endpoint-url $S3_ENDPOINT s3 ls s3://$BUCKET/path` (using `gitlab-s3-credentials`)
- Verify SSE: `aws --endpoint-url $S3_ENDPOINT s3api head-object --bucket $BUCKET --key <object> | jq -r .ServerSideEncryption` shows `AES256` (or KMS if required)
- Download succeeds via UI/API

AC5 — Runner registration and scheduling
- Runner pod Ready: `kubectl --context=apps -n gitlab-system get pods | rg runner`
- GitLab Admin → Runners shows online runner; registration token consumed

AC6 — DIND pipeline proof
- Run sample `.gitlab-ci.yml` job building an image with docker:27 + docker:27-dind; verify push to Harbor/GitLab Registry

AC7 — Monitoring
- ServiceMonitors discovered; time series for GitLab (web/sidekiq) and runner > 0

Evidence to capture (Dev Notes)
- curl -Ik output, toolbox psql result, S3 listing, runner online screenshot/CLI, sample pipeline URL, VM query for `up{job~"gitlab.*|gitlab-runner"}`

Cleanup (optional)
- Disable sample pipeline project or remove test image tags from registry

- [ ] Network Policies (tighten later)
  - Allow egress from GitLab to CNPG pooler, Redis/Dragonfly, S3 endpoint, SMTP (if used).
  - Allow egress from Runner jobs to registries and the GitLab API; egress to the Docker registry mirror if configured (Spegel).

- [ ] Example CI for DIND (documentation asset only)
  - Add `.gitlab-ci.yml` snippet (in docs) that uses `docker:27` and `docker:27-dind` with `DOCKER_HOST=tcp://docker:2375` and privileged true, to validate image build/push path.

## Validation Steps
- Flux: `flux -n flux-system --context=apps reconcile ks apps-workloads --with-source`
- Pods: `kubectl --context=apps -n gitlab-system get pods` (webservice, sidekiq, gitaly, toolbox healthy)
- DB: From toolbox pod, `gitlab-rake db:doctor` succeeds; migrations complete.
- Redis/Dragonfly: login, create project, start pipeline; Sidekiq processes jobs.
- Object storage: push artifacts and LFS; verify in S3 backend.
- Gateway: `curl -Ik https://${GITLAB_HOST}` returns 200/302 with valid certificate.
- Runner: `kubectl -n gitlab-runner get pods`; runner shows online in GitLab → Admin → Runners.
- DIND job: run the sample pipeline building and pushing to Harbor or GitLab Registry; ensure image appears and can be pulled.

## Definition of Done
- All ACs met; evidence (commands, screenshots) recorded in Dev Notes; file list updated.

---

## Integration — Keycloak SSO (OIDC)

Goal
- Enable Keycloak as an OpenID Connect (OIDC) provider for GitLab sign‑in, with just‑in‑time (JIT) user provisioning, optional auto‑linking for existing users, and profile sync (name/email). GitLab continues to use external Postgres/Redis/S3 as defined above.

Acceptance Criteria (SSO)
1) “Sign in with Keycloak” appears on the GitLab sign‑in page; clicking completes an OIDC flow and signs in successfully.
2) JIT provisioning works when `allowSingleSignOn: ['openid_connect']` is enabled; created users have correct name/email.
3) Existing users can be auto‑linked when `autoLinkUser: ['openid_connect']` is enabled and emails match.
4) TLS to Keycloak is trusted by GitLab components (custom CA mounted if Keycloak uses private PKI).
5) Logout/login round‑trip works; no user creation occurs when `blockAutoCreatedUsers: true` is set (if chosen).

Design
- Protocol: OpenID Connect via GitLab OmniAuth provider `openid_connect` with discovery.
- Scopes: `openid`, `profile`, `email`.
- Issuer: `https://<keycloak-host>/realms/<realm>`; Keycloak must use HTTPS and RS256/RS512 token signing.
- Callback: `https://${GITLAB_HOST}/users/auth/openid_connect/callback`.
- Helm path: `global.appConfig.omniauth.*` and `global.appConfig.omniauth.providers[*]` in the GitLab chart.
- Optional: mount custom CA for Keycloak under `global.certificates.customCAs` (Secret or ConfigMap).

Tasks / Subtasks — Implementation Plan (Story Only)
1) Keycloak (admin)
   - Create a confidential client in the target realm:
     - Client ID: `gitlab` (or `${GITLAB_OIDC_CLIENT_ID}`)
     - Access type: Confidential; Standard Flow enabled.
     - Valid Redirect URIs: `https://${GITLAB_HOST}/users/auth/openid_connect/callback`
     - Web Origins: `https://${GITLAB_HOST}` (add registry host if using OAuth in registry UI).
     - Realm Settings → Tokens: set Default Signature Algorithm to RS256 (or RS512).
   - Create or note the client secret; store it in secrets manager.

2) ExternalSecrets (apps cluster)
   - File: `kubernetes/workloads/apps/gitlab/externalsecrets.yaml`
     - Add an item for the OIDC client credentials → K8s Secret `gitlab-oidc-credentials` with keys `client_id`, `client_secret` (sourced from your secret store path, e.g., `${GITLAB_OIDC_SECRET_PATH}`).
   - If Keycloak uses a private CA, create `Secret` or `ConfigMap` containing the CA and reference it via `global.certificates.customCAs`.

3) GitLab Helm values (apps cluster)
   - File: `kubernetes/workloads/apps/gitlab/helmrelease.yaml`
     - Under `global.appConfig.omniauth` set:
       - `enabled: true`
       - `allowSingleSignOn: ['openid_connect']` (or `false` if you want to disable JIT)
       - `autoLinkUser: ['openid_connect']` (optional; auto‑links existing users with matching emails)
       - `blockAutoCreatedUsers: false` (or `true` to require admin approval)
       - `syncProfileFromProvider: ['openid_connect']`
       - `syncProfileAttributes: ['name','email']`
     - Add provider entry:
       - name: `openid_connect`, label: `Keycloak`, args:
         - `scope: ['openid','profile','email']`
         - `issuer: https://<keycloak-host>/realms/<realm>`
         - `response_type: 'code'`, `discovery: true`, `uid_field: 'preferred_username'`
         - `client_options.identifier`: from Secret `gitlab-oidc-credentials:client_id`
         - `client_options.secret`: from Secret `gitlab-oidc-credentials:client_secret`
         - `client_options.redirect_uri`: `https://${GITLAB_HOST}/users/auth/openid_connect/callback`

4) Optional: Auto‑sign‑in
   - If you want to always redirect to Keycloak, set `autoSignInWithProvider: 'openid_connect'` (ensure at least one admin can still sign in if the IdP is unavailable).

Validation Steps (SSO)
- Admin → Settings → General → Sign‑in: verify provider enabled in UI.
- Browse to `https://${GITLAB_HOST}/users/sign_in` and click “Keycloak”; confirm login completes.
- Create a fresh user in Keycloak; verify JIT creates a GitLab account when allowed.
- Disable JIT and confirm sign‑in is blocked for unknown users, if required.
- Check profile name/email synced on sign‑in when `syncProfileFromProvider` is set.
- Inspect GitLab webservice pod logs on error; verify TLS trust chain if using custom CA (`global.certificates.customCAs`).

Notes
- Use OIDC (not OAuth2 Generic) for Keycloak; it provides discovery and better defaults.
- Ensure the GitLab chart uses the `global.appConfig.omniauth.providers` structure; do not edit Omnibus `gitlab.rb` directly on Kubernetes.

## Design Notes

- Deployment method: official GitLab Helm chart for GitLab; official `gitlab-runner` Helm chart for runners.
- External state: use CNPG (external PostgreSQL), Redis/Dragonfly, and external S3 object storage per GitLab production guidance (disable in-chart Postgres/Redis, MinIO).
- Runners: Kubernetes executor with privileged pods to enable DIND when needed; projects can choose safer alternatives (BuildKit, Kaniko) later.

### Sample DIND job snippet (for docs only)
```yaml
image: docker:27
services: ["docker:27-dind"]
variables:
  DOCKER_HOST: tcp://docker:2375
  DOCKER_TLS_CERTDIR: ""        # disable TLS for simplicity in test
  DOCKER_DRIVER: overlay2
  # Optional: REGISTRY auth vars via CI variables
build-and-push:
  stage: build
  tags: [k8s]
  script:
    - docker version
    - docker login -u "$CI_REGISTRY_USER" -p "$CI_REGISTRY_PASSWORD" "$CI_REGISTRY"
    - docker build -t "$CI_REGISTRY_IMAGE:ci-$CI_COMMIT_SHORT_SHA" .
    - docker push "$CI_REGISTRY_IMAGE:ci-$CI_COMMIT_SHORT_SHA"
```

### Helm values pointers
- Runner Helm values: `gitlabUrl`, `runnerRegistrationToken`, `rbac`, `runners.config` (privileged).
- GitLab Helm values: `global.psql.*`, `redis.install=false` + `global.redis.*`, `global.minio.enabled=false` + object storage sections.

## QA Results — Risk Profile (2025-10-21)

Reviewer: Quinn (Test Architect & Quality Advisor)

Summary
- Total Risks Identified: 13
- Critical: 3 | High: 5 | Medium: 4 | Low: 1
- Overall Story Risk Score: 54/100

Critical Risks (Must Address Within This Story)
- SEC-001 — Privileged DIND runner elevates cluster risk (Score 9).
  - Mitigation: Restrict runner to dedicated namespace with PSA labels; use least‑privilege SA/RBAC; set nodeSelector/tolerations to isolated nodes if available; document and prefer non‑privileged alternatives (BuildKit/Kaniko) for most projects; enable privileged only for repos that require it (tags/policies).
- DATA-002 — Object storage misconfiguration causes artifact/LFS/package data loss (Score 9).
  - Mitigation: Validate S3 creds/endpoint/bucket with CLI; enforce SSE (AES256/KMS) if policy requires; verify upload/download in Validation Steps; add retention policy notes.
- OPS-003 — GitLab not reachable due to missing/miswired HTTPRoute/TLS (Score 9).
  - Mitigation: Create gitlab-httproutes.yaml attached to existing Gateway; confirm cert issuance and 200/302 via curl; ensure correct Services and ports.

Risk Matrix
| ID | Category | Description | Prob | Impact | Score | Priority | Mitigation / Owner |
|---|---|---|---|---|---:|---|---|
| SEC-001 | Security | Privileged DIND runner increases attack surface | High(3) | High(3) | 9 | Critical | Isolate namespace, least‑privilege RBAC, restricted nodes; plan non‑privileged path. Owner: Platform |
| DATA-002 | Data | S3 config errors lead to artifact/LFS loss | High(3) | High(3) | 9 | Critical | CLI validation, SSE, retention checks; proof via upload/download. Owner: Dev |
| OPS-003 | Operational | HTTPRoute/cert misconfig blocks access | High(3) | High(3) | 9 | Critical | Add/verify HTTPRoute + issuer; curl check. Owner: Dev |
| TECH-004 | Technical | CNPG pooler DNS/secret mismatch breaks Rails/Sidekiq | Medium(2) | High(3) | 6 | High | Confirm service name/secret keys; toolbox psql check. Owner: Dev |
| TECH-005 | Technical | Redis config wrong; Sidekiq queues fail | Medium(2) | High(3) | 6 | High | Validate env/secret; sidekiq logs/health. Owner: Dev |
| OPS-006 | Operational | Runner registration token miswired; runner offline | Medium(2) | High(3) | 6 | High | Verify ExternalSecret; check Admin→Runners online. Owner: Dev |
| SEC-007 | Security | Secrets leakage in CI logs or values | Low(1) | High(3) | 3 | Low | Keep secrets in ExternalSecrets; mask CI vars; avoid echoing creds. Owner: Dev |
| PERF-008 | Performance | Under‑sized web/sidekiq → poor UX | Medium(2) | Medium(2) | 4 | Medium | Start with sane requests/limits; review after smoke. Owner: Platform |
| OPS-009 | Operational | ServiceMonitor selectors don’t match; no metrics | Medium(2) | Medium(2) | 4 | Medium | Confirm labels; check up{job~"gitlab.*|gitlab-runner"}. Owner: Dev |
| TECH-010 | Technical | Registry exposure misaligned when Harbor authoritative | Medium(2) | Medium(2) | 4 | Medium | Disable built‑in registry or route correctly; test push/pull. Owner: Dev |
| DATA-011 | Data | DB migrations fail/partial → inconsistent state | Low(1) | High(3) | 3 | Low | Review migration logs; re‑run prepare; rollback plan. Owner: Dev |
| OPS-012 | Operational | PSA not permitting privileged runner pods | Medium(2) | Medium(2) | 4 | Medium | Add PSA labels or move to allowed namespace; document. Owner: Platform |
| TECH-013 | Technical | Chart/values drift from cluster‑settings | Low(1) | Medium(2) | 2 | Low | Template from cluster settings; review at reconcile. Owner: Platform |

Risk‑Based Testing Focus
- P1 (Critical):
  - DIND runner isolation: verify namespace PSA, RBAC scope, and that privileged jobs only run where intended (tags/policies).
  - S3 survivability: upload artifact; list via CLI; download; confirm SSE/bucket policy where applicable.
  - HTTPRoute/TLS: verify curl -Ik to ${GITLAB_HOST} (and registry if enabled); confirm cert issuer.
- P2 (High/Medium):
  - CNPG pooler: toolbox psql ‘select 1’; migrations complete.
  - Redis: sidekiq queue activity/logs.
  - Monitoring: presence of gitlab and runner metrics; alerts baseline loaded.

Gate Decision
- Decision: CONCERNS — Proceed when SEC‑001, DATA‑002, and OPS‑003 mitigations are implemented and evidenced in Dev Notes (isolation+privileged policy, S3 upload/download with details, HTTPRoute/TLS curl output).

## QA Results — Test Design (2025-10-21)

Designer: Quinn (Test Architect)

Test Strategy Overview
- Focus on integration/E2E validation mapped to AC1–AC7, with P0 emphasis on reachability/TLS, object storage survivability, and secure runner operation.

Test Scenarios by Acceptance Criteria

AC1 — HTTPS reachability and bootstrap
- ID: GITLAB-APPS-INT-001 | Level: Integration | Priority: P0 | Mitigates: OPS-003
  - Given HTTPRoutes are defined and cert-manager issuers are available
  - When `curl -Ik https://${GITLAB_HOST}` is executed from outside the cluster
  - Then response is 200/302 and the certificate issuer matches the expected issuer

AC2 — External DB connectivity (CNPG pooler)
- ID: GITLAB-APPS-INT-002 | Level: Integration | Priority: P1 | Mitigates: TECH-004, DATA-011
  - Given the toolbox pod is running
  - When executing `psql 'host=<pooler-rw> dbname=gitlab user=gitlab_app sslmode=require' -c 'select 1'`
  - Then command exits 0 and migrations complete without errors in logs

AC3 — External Redis
- ID: GITLAB-APPS-INT-003 | Level: Integration | Priority: P1 | Mitigates: TECH-005
  - Given Sidekiq is deployed
  - When observing Sidekiq logs/metrics
  - Then Redis connection established and queues process jobs

AC4 — Object storage survivability
- ID: GITLAB-APPS-E2E-004 | Level: E2E | Priority: P0 | Mitigates: DATA-002
  - Given S3 credentials and bucket are configured
  - When uploading an artifact (or LFS/package) and listing via S3 CLI
  - Then the object is present and downloadable; verify SSE/bucket policy if required

AC5 — Runner registration and scheduling
- ID: GITLAB-APPS-INT-005 | Level: Integration | Priority: P1 | Mitigates: OPS-006
  - Given ExternalSecret rendered the registration token
  - When the runner comes up
  - Then it shows Online in Admin→Runners and schedules a trivial job

AC6 — DIND pipeline proof (privileged)
- ID: GITLAB-APPS-E2E-006 | Level: E2E | Priority: P0 | Mitigates: SEC-001
  - Given a project with the sample DIND job and runner with `privileged=true`
  - When the pipeline runs
  - Then the image is built and pushed to the configured registry; verify tag exists

AC7 — Monitoring
- ID: GITLAB-APPS-INT-007 | Level: Integration | Priority: P2 | Mitigates: OPS-009
  - Given ServiceMonitors are enabled
  - When scraping Prometheus/VictoriaMetrics
  - Then `up{job~"gitlab.*|gitlab-runner"}` time series exist and > 0

Negative / Edge Cases
- ID: GITLAB-APPS-NEG-001 | Level: Integration | Priority: P1 | Case: Wrong S3 creds/endpoint
  - Expect upload to fail with explicit error; fix by correcting ExternalSecret values
- ID: GITLAB-APPS-NEG-002 | Level: E2E | Priority: P1 | Case: Runner not privileged for DIND
  - Expect pipeline to fail at docker build/push due to permissions; document non‑privileged alternatives
- ID: GITLAB-APPS-NEG-003 | Level: Integration | Priority: P1 | Case: HTTPRoute missing/misbound
  - Expect curl to fail (404/503) or cert missing; fix route/issuer attachment

Recommended Execution Order
1) P0: INT-001 (HTTPS), E2E-004 (S3), E2E-006 (DIND)
2) P1: INT-002 (DB), INT-003 (Redis), INT-005 (Runner)
3) P2: INT-007 (Monitoring) and Negative cases

Evidence to Capture (Dev Notes)
- curl -Ik output (status, issuer)
- toolbox psql `select 1` result and migration log excerpt
- Sidekiq log line showing Redis connection and processed job
- S3 listing and download command output; SSE evidence if applicable
- Runner Online screenshot/CLI output; sample pipeline URL and image tag in registry
- VM query results for `up{job~"gitlab.*|gitlab-runner"}`
