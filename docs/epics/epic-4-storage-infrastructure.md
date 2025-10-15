# EPIC-4: Storage Infrastructure
**Goal:** Deploy Rook Ceph and OpenEBS
**Status:** ✅ 85% Complete (configs complete, deployment pending)

## Story 4.1: Deploy Rook Ceph Operator ✅
**Priority:** P0 | **Points:** 3 | **Days:** 1 | **Status:** ✅ CONFIG COMPLETE

**Acceptance Criteria:**
- [x] Rook Ceph operator base HelmRelease created
- [x] Rook Ceph operator infrastructure config created
- [ ] Operator deployed on infra cluster
- [ ] Operator healthy and running
- [ ] CRDs installed

**Tasks:**
- Files already created, verify:
  - ✅ `kubernetes/bases/rook-ceph-operator/helmrelease.yaml`
  - ✅ `kubernetes/infrastructure/storage/rook-ceph/operator/kustomization.yaml`

- **Deploy via Flux** (automatic after infrastructure reconciliation):
  ```bash
  flux reconcile kustomization cluster-infra-infrastructure
  ```

- **Verify:**
  ```bash
  kubectl --context infra get pods -n rook-ceph
  kubectl --context infra get crd | grep ceph
  ```

**Files Created:**
- ✅ `kubernetes/bases/rook-ceph-operator/helmrelease.yaml`
- ✅ `kubernetes/infrastructure/storage/rook-ceph/operator/kustomization.yaml`

---

## Story 4.2: Deploy Rook Ceph Cluster ✅
**Priority:** P0 | **Points:** 5 | **Days:** 2 | **Status:** ✅ CONFIG COMPLETE

**Acceptance Criteria:**
- [x] Ceph cluster manifest created
- [x] RBD StorageClass configured
- [ ] Ceph cluster deployed (3 nodes)
- [ ] 3x1TB NVMe disks configured as OSDs
- [ ] Ceph health: HEALTH_OK
- [ ] RBD StorageClass `rook-ceph-block` created
- [ ] Test PVC can be created and bound

**Tasks:**
- Files already created, verify:
  - ✅ `kubernetes/bases/rook-ceph-cluster/cephcluster.yaml`
  - ✅ `kubernetes/bases/rook-ceph-cluster/storageclass-rbd.yaml`
  - ✅ `kubernetes/infrastructure/storage/rook-ceph/cluster/kustomization.yaml`

- **Deploy via Flux** (automatic after operator is ready)

- **Wait for Ceph health (5-10 minutes):**
  ```bash
  kubectl --context infra get cephcluster -n rook-ceph
  kubectl --context infra exec -n rook-ceph deploy/rook-ceph-tools -- ceph status
  ```

- **Verify StorageClass:**
  ```bash
  kubectl --context infra get storageclass rook-ceph-block
  ```

- **Test PVC:**
  ```bash
  kubectl --context infra create -f - <<EOF
  apiVersion: v1
  kind: PersistentVolumeClaim
  metadata:
    name: test-pvc
  spec:
    accessModes: [ReadWriteOnce]
    resources:
      requests:
        storage: 1Gi
    storageClassName: rook-ceph-block
  EOF

  kubectl --context infra get pvc test-pvc  # Should show Bound
  kubectl --context infra delete pvc test-pvc
  ```

**Files Created:**
- ✅ `kubernetes/bases/rook-ceph-cluster/cephcluster.yaml`
- ✅ `kubernetes/bases/rook-ceph-cluster/storageclass-rbd.yaml`
- ✅ `kubernetes/infrastructure/storage/rook-ceph/cluster/kustomization.yaml`

**Ceph Configuration:**
- Device filter: `^nvme[0-9]+n1$` (1TB NVMe drives)
- OSD device class: `ssd`
- MON count: 3
- Replica size: 3
- Image tag: `v18.2.2`

---

## Story 4.3: Deploy OpenEBS (Both Clusters) ✅
**Priority:** P1 | **Points:** 3 | **Days:** 1 | **Status:** ✅ CONFIG COMPLETE

**Acceptance Criteria:**
- [x] OpenEBS base HelmRelease created
- [x] OpenEBS infrastructure config created
- [x] LocalPV hostpath StorageClass configured
- [ ] Deployed to infra cluster
- [ ] Deployed to apps cluster (automatic - shared base)
- [ ] Test PVC works on both clusters

**Tasks:**
- Files already created, verify:
  - ✅ `kubernetes/bases/openebs/helmrelease.yaml`
  - ✅ `kubernetes/infrastructure/storage/openebs/kustomization.yaml`
  - ✅ `kubernetes/infrastructure/storage/openebs/storageclass.yaml`

- **Deploy via Flux** (automatic to both clusters):
  ```bash
  flux reconcile kustomization cluster-infra-infrastructure
  flux reconcile kustomization cluster-apps-infrastructure
  ```

- **Verify on both clusters:**
  ```bash
  kubectl --context infra get pods -n openebs
  kubectl --context apps get pods -n openebs
  kubectl --context infra get storageclass openebs-local-nvme
  kubectl --context apps get storageclass openebs-local-nvme
  ```

- **Test PVC on infra:**
  ```bash
  kubectl --context infra create -f - <<EOF
  apiVersion: v1
  kind: PersistentVolumeClaim
  metadata:
    name: test-openebs
  spec:
    accessModes: [ReadWriteOnce]
    resources:
      requests:
        storage: 1Gi
    storageClassName: openebs-local-nvme
  EOF

  kubectl --context infra get pvc test-openebs
  kubectl --context infra delete pvc test-openebs
  ```

**Files Created:**
- ✅ `kubernetes/bases/openebs/helmrelease.yaml`
- ✅ `kubernetes/infrastructure/storage/openebs/kustomization.yaml`
- ✅ `kubernetes/infrastructure/storage/openebs/storageclass.yaml`

**Note:** Story 4.4 (Deploy OpenEBS on Apps) is automatic with shared-base pattern!

**OpenEBS Configuration:**
- Base path: `/var/openebs/local`
- StorageClass: `openebs-local-nvme`
- Node selector: 512GB NVMe drives
- Suitable for: Cache, ephemeral volumes, non-replicated workloads

---

## Story 4.5: Configure Cross-Cluster Storage Access
**Priority:** P1 | **Points:** 3 | **Days:** 1 | **Status:** ⚠️ PARTIALLY DESIGNED

**Acceptance Criteria:**
- [ ] Apps cluster can access Ceph from infra cluster via ClusterMesh
- [ ] Global services configured for Ceph
- [ ] CSI driver deployed on apps cluster
- [ ] Test PVC created on apps cluster using infra Ceph
- [ ] Cross-cluster storage verified

**Tasks:**
- **Option 1: ClusterMesh Global Service** (recommended):
  - Annotate Ceph services on infra cluster:
    ```bash
    kubectl --context infra annotate service -n rook-ceph rook-ceph-mon-a service.cilium.io/global="true"
    kubectl --context infra annotate service -n rook-ceph rook-ceph-mon-b service.cilium.io/global="true"
    kubectl --context infra annotate service -n rook-ceph rook-ceph-mon-c service.cilium.io/global="true"
    ```
  - Apps cluster can now access via ClusterMesh DNS
  - Deploy Ceph CSI driver on apps cluster with mon endpoints pointing to global services

- **Option 2: Remote StorageClass** (simpler):
  - Create StorageClass on apps cluster
  - Reference infra cluster Ceph via ClusterMesh service DNS
  - Test PVC creation

- **Verify cross-cluster access:**
  ```bash
  # On apps cluster, create PVC using infra Ceph
  kubectl --context apps create -f test-remote-pvc.yaml
  kubectl --context apps get pvc
  ```

**Files to Create:**
- 🔲 `kubernetes/workloads/tenants/gitlab/remote-storageclass.yaml` (if needed)
- 🔲 Documentation on cross-cluster storage pattern

**Note:** Current implementation may use OpenEBS on apps instead of remote Ceph for simplicity.

---
