# 33 — STORY-CICD-GITHUB-ARC — Actions Runner Controller (ARC) + Runner Scale Sets

Sequence: 33/41 | Prev: STORY-STO-APPS-ROOK-CEPH-CLUSTER.md | Next: STORY-CICD-GITLAB-APPS.md
Sprint: 6 | Lane: CI/CD
Global Sequence: 33/41

Status: Draft
Owner: Platform Engineering
Date: 2025-10-22
Links: docs/architecture.md §19 (Workloads & Versions: Actions Runner); kubernetes/workloads/platform/cicd/actions-runner-controller; kubernetes/components/networkpolicy/monitoring

## Story
Deploy the GitHub Actions Runner Controller (ARC) with Runner Scale Sets on the apps cluster to execute GitHub Actions workflows inside Kubernetes with autoscaling and isolation. Manage via Flux, configure OIDC or PAT‑based auth via External Secrets, and enforce baseline security policies.

## Why / Outcome
- First‑class CI on Kubernetes for GitHub repositories; scalable and auditable.

## Scope
- Cluster: apps
- Resources (to be created):
  - `kubernetes/workloads/platform/cicd/actions-runner-controller/{namespace,ocirepository,helmrelease}.yaml`
  - `kubernetes/workloads/platform/cicd/actions-runner-controller/runners/{runnerscaleset.yaml}`
  - ExternalSecrets for controller creds (GitHub App or PAT): `gitHubAppId`, `installationId`, `privateKey` or `GITHUB_TOKEN`.
  - NetworkPolicies: allow controller webhooks and metrics scraping; default‑deny baseline inherited.

## Acceptance Criteria
1) ARC controller pods Ready in `actions-runner-system`; CRDs Established.
2) A `RunnerScaleSet` registers with GitHub and scales pods for queued jobs.
3) Sample workflow in a test repo completes successfully on the Kubernetes runner.
4) Metrics scraped (ServiceMonitor) and basic alerts present.
5) Security: runner pods run without privileged defaults (unless explicitly required by job) and are confined to the `gitHub` runner namespace; NP enforced.

## Dependencies / Inputs
- External Secrets store configured; GitHub App or PAT secret path present.
- STORY-SEC-NP-BASELINE for default‑deny; observability stack present.

## Tasks / Subtasks — Implementation Plan (Story Only)
- [ ] Author ARC HelmRelease + OCIRepository manifests under `workloads/platform/cicd/actions-runner-controller/`.
- [ ] Add RunnerScaleSet for a test repository; define labels and ephemeral volumes; set autoscaling bounds.
- [ ] Create ExternalSecrets mapping to controller credentials; document OIDC vs PAT options.
- [ ] Add Prometheus ServiceMonitor for controller metrics (if chart exposes) and dashboards (optional).
- [ ] NetworkPolicy: allow API to GitHub endpoints (FQDN allowlist) and observability scraping.

## Validation Steps
- kubectl --context=apps -n actions-runner-system get deploy,po
- Verify CRDs: `kubectl api-resources | rg actions.summerwind.dev|actions.github.com`
- Push a test workflow to the configured repo; confirm runner picks up and completes the job.
- Query metrics endpoint; validate ServiceMonitor discovery.

## Definition of Done
- ACs met; evidence recorded in Dev Notes with workflow run URL and logs.
