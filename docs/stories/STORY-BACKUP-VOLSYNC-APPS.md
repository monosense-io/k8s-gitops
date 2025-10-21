# 23 — STORY-BACKUP-VOLSYNC-APPS — VolSync + Snapshot Controller on apps (MinIO target)

Sequence: 23/23 | Prev: STORY-NET-SPEGEL-REGISTRY-MIRROR.md

Status: Draft
Owner: Platform Engineering
Date: 2025-10-21
Links: kubernetes/workloads/platform/backup/volsync-system; kubernetes/components/volsync; kubernetes/clusters/apps/volsync.yaml

## Story
Deploy VolSync and the external snapshot-controller on the apps cluster to enable PVC backups and point-in-time restores, using MinIO at 10.25.11.3 as the S3-compatible backend (instead of Cloudflare R2). Use VolSync restic Direct mode by default to avoid CSI snapshot class dependencies; enable Snapshot copyMethod where CSI snapshots are available.

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
3) A sample ReplicationSource/ReplicationDestination pair (Direct mode) succeeds end-to-end against MinIO (backup, then restore to a PVC).
4) PrometheusRule for VolSync present; metrics scrape OK.

## Dependencies / Inputs
- External Secrets configured with 1Password (ClusterSecretStore `onepassword`).
- 1Password item `volsync-minio` providing: `RESTIC_PASSWORD`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`.
- MinIO reachable at `http://10.25.11.3:9000` with a `volsync` bucket.

## Tasks / Subtasks
- [ ] Reconcile `kubernetes/clusters/apps/volsync.yaml`.
- [ ] Create 1Password `volsync-minio` item as above and bucket in MinIO.
- [ ] Create a sample app namespace and apply `kubernetes/components/volsync` with vars (APP, VOLSYNC_BUCKET, etc.).
- [ ] Validate backup/restore lifecycle and record artifact outputs.

## Validation Steps
- flux -n volsync-system --context=apps get kustomizations,hr
- kubectl --context=apps -n volsync-system get deploy
- Create sample: `kustomize build kubernetes/components/volsync | envsubst | kubectl --context=apps -n <ns> apply -f -`
- Verify data appears in MinIO and PVC restore binds.

## Definition of Done
- ACs met; Dev Notes include MinIO endpoint config, bucket path, and sample object listings.

