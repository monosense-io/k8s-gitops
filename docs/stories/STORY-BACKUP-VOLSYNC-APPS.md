# 37 — STORY-BACKUP-VOLSYNC-APPS — VolSync + Snapshot Controller on apps (MinIO target)

Sequence: 37/41 | Prev: STORY-TENANCY-BASELINE.md | Next: STORY-BOOT-CRDS.md
Sprint: 7 | Lane: Backup
Global Sequence: 37/41

Status: Draft
Owner: Platform Engineering
Date: 2025-10-21
Links: kubernetes/workloads/platform/backup/volsync-system; kubernetes/components/volsync; kubernetes/clusters/apps/volsync.yaml

## Story
Deploy VolSync and the external snapshot-controller on the apps cluster to enable PVC backups and point-in-time restores, using MinIO at 10.25.11.3 as the S3-compatible backend (instead of Cloudflare R2). Align with buroa pattern: enable Snapshot copyMethod by default with a Ceph RBD VolumeSnapshotClass (csi-ceph-block) and use OpenEBS hostpath cache for movers.

## Why / Outcome
- App teams can declaratively back up and restore stateful PVCs on the apps cluster with minimal downtime.
- Object storage remains local (MinIO at 10.25.11.3), improving latency and control.

## Scope
- Cluster: apps
- Operators: snapshot-controller (piraeusdatastore), volsync (backube)
- Developer components: reusable `kubernetes/components/volsync` (ExternalSecret, ReplicationSource/Destination, PVC restore)

## Acceptance Criteria
1) `cluster-apps-volsync` Kustomization Ready; Deployments for `snapshot-controller` and `volsync` Available in `volsync-system`.
2) ExternalSecret template supports MinIO: creates per-app `*-restic-secret` with required env (AWS keys, endpoint, RESTIC vars).
3) A sample ReplicationSource/ReplicationDestination pair (Snapshot mode) succeeds end-to-end against MinIO (backup, then restore to a PVC) using volumeSnapshotClassName=csi-ceph-block and cacheStorageClassName=openebs-hostpath.
4) PrometheusRule for VolSync present; metrics scrape OK.

## Dependencies / Inputs
- External Secrets configured with 1Password (ClusterSecretStore `onepassword`).
- 1Password item `volsync-minio` providing: `RESTIC_PASSWORD`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`.
- MinIO reachable at `http://10.25.11.3:9000` with a `volsync` bucket.
- VolumeSnapshotClass `csi-ceph-block` present; OpenEBS StorageClass `openebs-hostpath` present.

## Tasks / Subtasks
- [ ] Prepare MinIO + 1Password (AC2)
  - [ ] Create/verify MinIO bucket `volsync` and scoped user `volsync-backup` with readwrite policy
  - [ ] Create 1Password item `volsync-minio` with keys: `RESTIC_PASSWORD`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`
  - [ ] Sanity-check access with AWS CLI against `http://10.25.11.3:9000`

- [ ] Reconcile VolSync stack (AC1)
  - [ ] Reconcile `kubernetes/clusters/apps/volsync.yaml`
  - [ ] Verify Deployments `snapshot-controller` and `volsync` Available=1 and replicas match

- [ ] Sample namespace + apply components (AC2, AC3)
  - [ ] Create namespace `${APP:=demo-ns}`
  - [ ] Apply `kubernetes/components/volsync` with variables (`APP`, `VOLSYNC_BUCKET`, `VOLSYNC_SNAPSHOTCLASS`)
  - [ ] Verify ExternalSecret renders `<app>-restic-secret` with required keys

- [ ] End-to-end backup → restore (AC3)
  - [ ] Create a test PVC `demo-pvc` and seed a file; record checksum
  - [ ] Create ReplicationSource/ReplicationDestination (Snapshot mode) using `csi-ceph-block` and cache `openebs-hostpath`
  - [ ] Confirm backup completes; restore to `demo-pvc-restore`; verify checksum matches

- [ ] Observability (AC4)
  - [ ] Confirm VolSync metrics are scraped and `up{job="volsync-metrics"}` is present
  - [ ] Ensure PrometheusRule is loaded; verify alert sanity for missing exporter

- [ ] Cleanup (housekeeping)
  - [ ] Remove demo namespace/resources or label and prune

### MinIO and 1Password Setup (required)
- [ ] Ensure MinIO has a `volsync` bucket and a dedicated user/access keys, then create the 1Password item consumed by External Secrets.
  - MinIO (using `mc`):
    1. Configure alias to your MinIO endpoint (replace ADMIN creds if needed):
       - `mc alias set local http://10.25.11.3:9000 <MINIO_ADMIN_ACCESS_KEY> <MINIO_ADMIN_SECRET_KEY>`
    2. Create bucket (idempotent):
       - `mc mb --ignore-existing local/volsync`
    3. Create a user for VolSync and attach readwrite policy:
       - `mc admin user add local volsync-backup <STRONG_PASSWORD>`
       - `mc admin policy attach local readwrite --user volsync-backup`
    4. (Optional) Create a service account for least-privilege key rotation:
       - `mc admin user svcacct add local volsync-backup`
  - Validate access with AWS CLI (using the created access/secret):
    - `AWS_ACCESS_KEY_ID=<KEY> AWS_SECRET_ACCESS_KEY=<SECRET> aws --endpoint-url http://10.25.11.3:9000 s3 ls s3://volsync`
  - 1Password item (using `op` CLI), store credentials for External Secrets:
    - `op item create --category=login --title "volsync-minio" \
       "RESTIC_PASSWORD=<random-strong-password>" \
       "AWS_ACCESS_KEY_ID=<KEY>" \
       "AWS_SECRET_ACCESS_KEY=<SECRET>"`
    - Confirm External Secret template matches key names above.

## Validation Steps
- Preflight
  - `kubectl --context=apps get volumesnapshotclass | rg csi-ceph-block` (must exist)
  - `kubectl --context=apps get sc | rg openebs-hostpath` (cache SC exists)

- Reconcile
  - `flux -n volsync-system --context=apps get kustomizations,hr`
  - `kubectl --context=apps -n volsync-system get deploy` (volsync, snapshot-controller Available=1)

- Apply components (concrete example)
  - `APP=demo-ns VOLSYNC_BUCKET=volsync VOLSYNC_SNAPSHOTCLASS=csi-ceph-block \\
     kustomize build kubernetes/components/volsync | envsubst | \\
     kubectl --context=apps -n $APP apply -f -`
  - Verify ExternalSecret rendered: `kubectl --context=apps -n $APP get secret $APP-restic-secret -o yaml | rg "RESTIC_PASSWORD|AWS_ACCESS_KEY_ID|AWS_SECRET_ACCESS_KEY|RESTIC_REPOSITORY"`

- E2E backup → restore evidence
  - Record checksum before/after on source and restored PVC
  - Capture Events showing successful RS/RD

- Metrics and alerts
  - Verify metrics: confirm `up{job="volsync-metrics"}` exists in VM, or port-forward the metrics endpoint and curl
  - Verify PrometheusRule present and fires if exporter absent

- MinIO verification
  - `mc ls local/volsync` and `aws --endpoint-url http://10.25.11.3:9000 s3 ls s3://volsync`

## Definition of Done
- ACs met; Dev Notes include MinIO endpoint config, bucket path, and sample object listings.

## Dev Notes

Variables used by components
- `APP` (default `demo-ns`): sample application namespace
- `VOLSYNC_BUCKET` (default `volsync`): MinIO bucket name
- `VOLSYNC_SNAPSHOTCLASS` (default `csi-ceph-block`): VolumeSnapshotClass used by VolSync

Relevant source tree
- `kubernetes/clusters/apps/volsync.yaml`
- `kubernetes/workloads/platform/backup/volsync-system/**`
- `kubernetes/components/volsync/**`
- `kubernetes/infrastructure/storage/rook-ceph/cluster/volumesnapshotclass.yaml`

Troubleshooting (quick pointers)
- Secrets: `kubectl -n $APP get secret $APP-restic-secret -o yaml`
- Events: `kubectl -n $APP get events --sort-by=.lastTimestamp`
- Controller logs: `kubectl -n volsync-system logs deploy/volsync`

Out of Scope
- Multi‑cluster replication and cross‑site DR
- S3 object‑lock/WORM settings

Cleanup Commands (example)
```
# Set context/namespace
APP=${APP:=demo-ns}

# Remove VolSync demo resources (ignore errors if already gone)
kubectl --context=apps -n "$APP" delete replicationsource,replicationdestination --all --ignore-not-found
kubectl --context=apps -n "$APP" delete pvc demo-pvc demo-pvc-restore --ignore-not-found
kubectl --context=apps -n "$APP" delete secret "$APP-restic-secret" --ignore-not-found

# Optionally remove the demo namespace
kubectl --context=apps delete ns "$APP" --ignore-not-found
```

### Testing
- Evidence to capture in Dev Notes: secret keys present, backup/restore timestamps and object counts, checksum before/after, metrics snapshot showing `up{job="volsync-metrics"}`

## Change Log
| Date       | Version | Description                                      | Author |
|------------|---------|--------------------------------------------------|--------|
| 2025-10-21 | 0.2     | PO course‑correction + QA risk/design integration | Sarah  |

## Dev Agent Record

### Agent Model Used
<to be filled by dev>

### Debug Log References
<to be filled by dev>

### Completion Notes List
<to be filled by dev>

### File List
<to be filled by dev>

## QA Results — Risk Profile (2025-10-21)

Reviewer: Quinn (Test Architect & Quality Advisor)

Summary
- Total Risks Identified: 14
- Critical: 3 | High: 5 | Medium: 5 | Low: 1
- Overall Story Risk Score: 57/100 (risk‑weighted; see register)

Critical Risks (Must Address Before Done)
- DATA-001 — Backup/restore not actually validated end‑to‑end (Score 9). Mitigation: Execute sample ReplicationSource/ReplicationDestination on a real PVC; record artifacts (timestamps, object counts) and a restore bind proof (PVC/PV). Add cleanup step.
- SEC-002 — Secret materialization mismatch (key names/values) causing silent failures (Score 9). Mitigation: Confirm ExternalSecret keys match `kubernetes/components/volsync/volsync/externalsecret.yaml` schema; include an envsubst example and a one‑shot `kubectl get secret -o yaml | rg` check.
- OPS-001 — Missing explicit metrics verification for VolSync scrape (Score 9). Mitigation: Add validation to confirm `up{job="volsync-metrics"}` or curl scrape endpoint via port‑forward; ensure PrometheusRule fires if exporter absent.

Risk Matrix
| ID | Category | Description | Prob | Impact | Score | Priority | Mitigation / Owner |
|---|---|---|---|---|---:|---|---|
| DATA-001 | Data | E2E backup/restore not exercised on real PVC | High(3) | High(3) | 9 | Critical | Add sample ns, seed data, run RS/RD, verify restore; record evidence. Owner: Dev |
| SEC-002 | Security | ExternalSecret key mismatch or missing item | High(3) | High(3) | 9 | Critical | Validate keys and secret materialization; add sanity check cmd. Owner: Dev |
| OPS-001 | Operational | No metrics verification for VolSync exporter | High(3) | High(3) | 9 | Critical | Add scrape check in Validation Steps + alert sanity. Owner: Dev |
| TECH-003 | Technical | VolumeSnapshotClass missing/wrong (csi-ceph-block) | Medium(2) | High(3) | 6 | High | Preflight: ensure VSC exists; fail fast with clear remediation. Owner: Dev |
| TECH-004 | Technical | Cache SC (openebs-hostpath) absent/misnamed | Medium(2) | High(3) | 6 | High | Preflight check SC; provide fallback SC variable. Owner: Dev |
| OPS-005 | Operational | Task ordering can cause false failures | Medium(2) | High(3) | 6 | High | Reorder: MinIO→1Password→reconcile→sample apply→E2E→metrics→cleanup. Owner: SM/Dev |
| SEC-006 | Security | Secrets embedded accidentally in manifests | Low(1) | High(3) | 3 | Low | Reiterate External Secrets only; add grep check to prevent leakage. Owner: Dev |
| PERF-007 | Performance | MinIO latency/throughput insufficient | Medium(2) | Medium(2) | 4 | Medium | Use small dataset; note perf as non‑goal; capture object counts/times. Owner: Dev |
| DATA-008 | Data | MinIO user not scoped to bucket | Medium(2) | Medium(2) | 4 | Medium | Apply least‑privilege policy to `volsync` bucket only. Owner: Platform |
| TECH-009 | Technical | Version drift between VolSync chart and CRDs | Low(1) | Medium(2) | 2 | Low | Keep chart/CRDs aligned; reconcile order via Flux ks. Owner: Platform |
| OPS-010 | Operational | Incomplete cleanup of demo artifacts | Medium(2) | Low(1) | 2 | Low | Add explicit cleanup subtask; label demo resources. Owner: Dev |
| SEC-011 | Security | Weak RESTIC_PASSWORD or key rotation missing | Medium(2) | Medium(2) | 4 | Medium | Document strong secret, rotation cadence via 1Password. Owner: Platform |
| TECH-012 | Technical | Incorrect envsubst vars during apply | Medium(2) | Medium(2) | 4 | Medium | Provide concrete example with defaults; echo vars pre‑apply. Owner: Dev |
| OPS-013 | Operational | Unclear failure diagnostics (events/logs) | Medium(2) | Medium(2) | 4 | Medium | Add “Troubleshooting” bullets (controllers/events paths). Owner: Dev |

Risk‑Based Testing Focus
- P1 (Critical):
  - Execute snapshot‑mode backup and restore on an example PVC; verify data integrity (file hash before/after).
  - Validate ExternalSecret renders `*-restic-secret` with required keys; run a dry restic repo listing if feasible.
  - Confirm metrics presence and alert behavior for VolSync exporter.
- P2 (High/Medium):
  - Preflight checks for `csi-ceph-block` and `openebs-hostpath`.
  - MinIO perf smoke (object count + size, elapsed time); not a perf goal, just baseline.
  - Cleanup verification (no stray demo resources).

Gate Decision
- Decision: CONCERNS — Proceed if Critical risks (DATA‑001, SEC‑002, OPS‑001) are addressed in this story’s tasks and validated in Dev Notes.

Notes & Required Story Updates
- Add concrete envsubst example and sample namespace name.
- Add explicit metrics scrape validation and E2E evidence capture to Validation Steps.
- Add cleanup subtask.

## QA Results — Test Design (2025-10-21)

Designer: Quinn (Test Architect)

Test Strategy Overview
- Levels: Integration and E2E dominate; unit is minimal (config/render).
- Priorities: P0 focuses on restore correctness, secret materialization, and metrics visibility.

Test Scenarios by Acceptance Criteria

AC1: VolSync stack Available in volsync-system
- ID: BACKUP-VOLSYNC-APPS-INT-001 | Level: Integration | Priority: P1
  - Given the apps cluster context
  - When the Kustomization `cluster-apps-volsync` is reconciled
  - Then Deployments `snapshot-controller` and `volsync` report Available=1 and replicas=desired

AC2: ExternalSecret template supports MinIO and renders per-app restic secret
- ID: BACKUP-VOLSYNC-APPS-INT-002 | Level: Integration | Priority: P0 | Mitigates: SEC-002
  - Given ClusterSecretStore onepassword and item `volsync-minio` exist with required keys
  - When ExternalSecret for APP=`demo-ns` is applied
  - Then Secret `<app>-restic-secret` exists with keys `RESTIC_PASSWORD`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, and `RESTIC_REPOSITORY` pointing to MinIO endpoint

AC3: Snapshot-mode ReplicationSource/ReplicationDestination backup→restore succeeds
- ID: BACKUP-VOLSYNC-APPS-E2E-001 | Level: E2E | Priority: P0 | Mitigates: DATA-001
  - Given a PVC `demo-pvc` in namespace `demo-ns` with a test file and checksum recorded
  - And ReplicationSource configured with VolumeSnapshotClass `csi-ceph-block` and cache `openebs-hostpath`
  - When backup is triggered and completes
  - And ReplicationDestination restores to `demo-pvc-restore`
  - Then the restored PVC binds and the test file checksum matches the source

- ID: BACKUP-VOLSYNC-APPS-INT-003 | Level: Integration | Priority: P1
  - Given VolSync CR events and controller logs
  - When backup and restore complete
  - Then Events show Successful runs; logs contain no errors (exclude transient retries)

AC4: PrometheusRule present; metrics scrape OK
- ID: BACKUP-VOLSYNC-APPS-INT-004 | Level: Integration | Priority: P0 | Mitigates: OPS-001
  - Given VictoriaMetrics operator is present and PodMonitor/ServiceMonitors are enabled for VolSync
  - When the stack is reconciled
  - Then metrics endpoint is scraped and `up{job="volsync-metrics"}` is present

Negative / Edge Scenarios
- ID: BACKUP-VOLSYNC-APPS-NEG-001 | Level: Integration | Priority: P1 | Mitigates: TECH-003
  - Given `csi-ceph-block` is missing or misnamed
  - When applying VolSync CRs
  - Then validation fails clearly; story documents remediation

- ID: BACKUP-VOLSYNC-APPS-NEG-002 | Level: Integration | Priority: P1 | Mitigates: TECH-004
  - Given `openebs-hostpath` cache SC is missing
  - When reconciliation occurs
  - Then an event/log highlights cache SC error; provide override variable path

Recommended Execution Order
1) P0: INT-002 (secrets), E2E-001 (backup/restore), INT-004 (metrics)
2) P1: INT-001 (deployments), INT-003 (events/logs)
3) Negative cases: NEG-001, NEG-002

Evidence to Capture (Dev Notes)
- Secret keys present (kubectl get secret -o yaml | rg)
- Backup/restore timestamps, object counts, checksum before/after
- Metrics query output (`up{job="volsync-metrics"}`) or curl via port-forward
