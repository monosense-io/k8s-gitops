# EPIC-10: Backup & DR
**Goal:** Deploy VolSync and Velero
**Status:** ❌ 0% Complete (not implemented - **CRITICAL GAP**)

**IMPORTANT:** ADR-004 specifies Velero Day 1 implementation. This epic should be **HIGH PRIORITY**.

## Story 10.1: Deploy VolSync on Infra Cluster
**Priority:** P0 | **Points:** 3 | **Days:** 1 | **Status:** ❌ NOT IMPLEMENTED

**Acceptance Criteria:**
- [ ] VolSync operator base HelmRelease created
- [ ] VolSync infrastructure config created
- [ ] MinIO bucket configured for backups
- [ ] Deployed on infra cluster
- [ ] Test ReplicationSource created
- [ ] Backup runs successfully

**Tasks:**
- Create `kubernetes/bases/volsync/helmrelease.yaml`
- Create `kubernetes/infrastructure/backup/volsync/kustomization.yaml`
- Create ExternalSecret for MinIO credentials
- Create test ReplicationSource:
  ```yaml
  apiVersion: volsync.backube/v1alpha1
  kind: ReplicationSource
  spec:
    sourcePVC: test-pvc
    trigger:
      schedule: "0 */6 * * *"  # Every 6 hours (ADR-006)
    restic:
      repository: volsync-restic-config
      retain:
        hourly: 6
        daily: 7
        weekly: 4
        monthly: 6
  ```
- Verify backup created in MinIO

**Files to Create:**
- 🔲 `kubernetes/bases/volsync/helmrelease.yaml`
- 🔲 `kubernetes/infrastructure/backup/volsync/kustomization.yaml`
- 🔲 `kubernetes/infrastructure/backup/volsync/externalsecret-minio.yaml`

**VolSync Configuration:**
- RPO: 6 hours (per ADR-006)
- Retention: 6H/7D/4W/6M
- Backend: MinIO S3 on Synology
- Method: Restic with Ceph CSI snapshots

---

## Story 10.2: Deploy VolSync on Apps Cluster
**Priority:** P1 | **Points:** 2 | **Days:** 0.5 | **Status:** ❌ NOT IMPLEMENTED

**Acceptance Criteria:**
- [ ] VolSync deployed on apps cluster (automatic via shared base)
- [ ] Test replication working

**Tasks:**
- VolSync deploys automatically to apps cluster (shared infrastructure)
- Create test ReplicationSource on apps cluster
- Verify backup to MinIO

**Note:** With shared-base pattern, this is mostly automatic!

---

## Story 10.3: Deploy Velero on Infra Cluster
**Priority:** P0 | **Points:** 3 | **Days:** 1 | **Status:** ❌ NOT IMPLEMENTED

**Acceptance Criteria:**
- [ ] Velero base HelmRelease created
- [ ] Velero infrastructure config created
- [ ] MinIO configured as backup destination
- [ ] Deployed on infra cluster
- [ ] Schedule created for weekly backups
- [ ] Test backup created successfully

**Tasks:**
- Create `kubernetes/bases/velero/helmrelease.yaml`
- Create `kubernetes/infrastructure/backup/velero/kustomization.yaml`
- Create `kubernetes/infrastructure/backup/velero/schedule.yaml`
- Create ExternalSecret for MinIO credentials
- Deploy via Flux

- **Trigger test backup:**
  ```bash
  velero backup create test-backup --wait --context infra
  velero backup describe test-backup --context infra
  ```

- **Create backup schedule:**
  ```yaml
  apiVersion: velero.io/v1
  kind: Schedule
  metadata:
    name: daily-backup
  spec:
    schedule: "0 2 * * 0"  # Sundays at 2 AM
    template:
      includedNamespaces:
        - '*'
      storageLocation: default
      volumeSnapshotLocations:
        - default
  ```

**Files to Create:**
- 🔲 `kubernetes/bases/velero/helmrelease.yaml`
- 🔲 `kubernetes/infrastructure/backup/velero/kustomization.yaml`
- 🔲 `kubernetes/infrastructure/backup/velero/schedule.yaml`
- 🔲 `kubernetes/infrastructure/backup/velero/externalsecret-minio.yaml`

**Velero Configuration:**
- Schedule: Weekly (Sundays 2 AM)
- Retention: 30 days
- Backend: MinIO S3 on Synology
- CSI snapshots: Enabled for Ceph PVCs

---

## Story 10.4: Deploy Velero on Apps Cluster
**Priority:** P1 | **Points:** 2 | **Days:** 0.5 | **Status:** ❌ NOT IMPLEMENTED

**Acceptance Criteria:**
- [ ] Velero deployed on apps cluster (automatic)
- [ ] Backups working

**Tasks:**
- Velero deploys automatically (shared infrastructure)
- Test backup on apps cluster:
  ```bash
  velero backup create test-apps-backup --wait --context apps
  ```

**Note:** With shared-base pattern, this is automatic!

---
