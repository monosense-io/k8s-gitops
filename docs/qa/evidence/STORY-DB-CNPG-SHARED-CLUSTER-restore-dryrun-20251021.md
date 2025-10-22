# Evidence — Restore Dry‑Run (Planned)

Story: docs/stories/STORY-DB-CNPG-SHARED-CLUSTER.md
When: Pending first execution after merge
Cluster: infra
Namespace: cnpg-system

Artifacts to attach after job runs:
- CronJob logs from `cnpg-backup-restore-dryrun`
- Output of `barman-cloud-backup-list` and `barman-cloud-check-wal-archive`
- Screenshot or copy of `kubectl get cronjob/job/pod -n cnpg-system` showing success

Instructions (operator):
- Apply shared-cluster kustomization or `kubectl -n cnpg-system create job --from=cronjob/cnpg-backup-restore-dryrun cnpg-restore-dryrun-now`
- After completion, capture logs:
  `kubectl -n cnpg-system logs job/cnpg-restore-dryrun-now -c restore-dryrun > docs/qa/evidence/STORY-DB-CNPG-SHARED-CLUSTER-restore-dryrun-20251021.log`
- Commit the log file alongside this evidence stub.
