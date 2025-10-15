# EPIC-7: Database Platform
**Goal:** Deploy CloudNativePG and Dragonfly
**Status:** ✅ 80% Complete (configs complete, deployment pending)

## Story 7.1: Deploy CloudNativePG Operator ✅
**Priority:** P0 | **Points:** 3 | **Days:** 1 | **Status:** ✅ CONFIG COMPLETE

**Acceptance Criteria:**
- [x] CloudNativePG operator manifests created
- [ ] Operator deployed on infra cluster
- [ ] Operator healthy
- [ ] CRDs installed

**Tasks:**
- Files already created, verify:
  - ✅ `kubernetes/workloads/platform/databases/cloudnative-pg/operator/kustomization.yaml`

- **Deploy via Flux** (automatic)

- **Verify:**
  ```bash
  kubectl --context infra get pods -n cnpg-system
  kubectl --context infra get crd | grep postgresql
  ```

**Files Created:**
- ✅ `kubernetes/workloads/platform/databases/cloudnative-pg/operator/kustomization.yaml`

---

## Story 7.2: Deploy Shared PostgreSQL Cluster ✅
**Priority:** P0 | **Points:** 5 | **Days:** 2 | **Status:** ✅ CONFIG COMPLETE

**Acceptance Criteria:**
- [x] PostgreSQL cluster manifest created
- [x] 3-replica configuration
- [x] Storage configured (OpenEBS local-nvme)
- [x] Backups configured to MinIO
- [x] Global service annotation for ClusterMesh
- [ ] Cluster deployed on infra
- [ ] Cluster healthy and ready
- [ ] Can connect to database
- [ ] Failover tested
- [ ] Accessible from apps cluster via ClusterMesh

**Tasks:**
- Files already created, verify:
  - ✅ `kubernetes/workloads/platform/databases/cloudnative-pg/cluster/cluster.yaml`
  - ✅ `kubernetes/workloads/platform/databases/cloudnative-pg/cluster/externalsecret.yaml`

- **Deploy via Flux** (automatic)

- **Wait for cluster ready:**
  ```bash
  kubectl --context infra get cluster -n databases
  kubectl --context infra get pods -n databases
  ```

- **Verify global service (ClusterMesh):**
  ```bash
  kubectl --context infra get service -n databases -o yaml | grep global
  # Should see: service.cilium.io/global: "true"
  ```

- **Test connection from apps cluster:**
  ```bash
  kubectl --context apps run psql-test --image=postgres:15 -it --rm -- \
    psql -h <cluster-name>-rw.databases.svc.clusterset.local -U postgres
  ```

- **Test failover:**
  ```bash
  # Delete primary pod
  kubectl --context infra delete pod <primary-pod> -n databases
  # Verify automatic failover and new primary election
  kubectl --context infra get cluster -n databases
  ```

**Files Created:**
- ✅ `kubernetes/workloads/platform/databases/cloudnative-pg/cluster/cluster.yaml`
- ✅ `kubernetes/workloads/platform/databases/cloudnative-pg/cluster/externalsecret.yaml`

**CloudNativePG Configuration:**
- Instances: 3 (HA)
- Storage class: `openebs-local-nvme`
- Data size: `200Gi`
- WAL size: `100Gi`
- Backup: MinIO S3 (configured via variables)
- Global service: Enabled for cross-cluster access

---

## Story 7.3: Create Application Databases
**Priority:** P1 | **Points:** 2 | **Days:** 1 | **Status:** 🔲 PENDING

**Acceptance Criteria:**
- [ ] Databases created: gitlab, harbor, keycloak, grafana, mattermost
- [ ] ExternalSecrets created for each database
- [ ] Connection tested from apps cluster
- [ ] Apps can access databases via ClusterMesh

**Tasks:**
- Create database users and databases:
  ```bash
  kubectl --context infra exec -n databases <cluster-pod> -- \
    psql -U postgres -c "CREATE DATABASE gitlab;"
  kubectl --context infra exec -n databases <cluster-pod> -- \
    psql -U postgres -c "CREATE USER gitlab WITH PASSWORD '<password>';"
  kubectl --context infra exec -n databases <cluster-pod> -- \
    psql -U postgres -c "GRANT ALL ON DATABASE gitlab TO gitlab;"
  # Repeat for harbor, keycloak, grafana, mattermost
  ```

- Create ExternalSecrets for credentials:
  - Store passwords in 1Password
  - Create ExternalSecret manifests
  - Deploy to apps cluster

- **Test connections:**
  ```bash
  # From apps cluster
  kubectl --context apps run test-db --image=postgres:15 -it --rm -- \
    psql -h <cluster>-rw.databases.svc.clusterset.local -U gitlab -d gitlab
  ```

**Files to Create:**
- 🔲 `kubernetes/workloads/platform/databases/cloudnative-pg/databases.yaml` (database creation jobs)
- 🔲 `kubernetes/workloads/tenants/gitlab/externalsecret-db.yaml`
- 🔲 Similar ExternalSecrets for other apps

---

## Story 7.4: Deploy Dragonfly (Redis-compatible) ✅
**Priority:** P1 | **Points:** 3 | **Days:** 1 | **Status:** ✅ CONFIG COMPLETE

**NEW STORY** - Dragonfly added for high-performance caching

**Acceptance Criteria:**
- [x] Dragonfly manifests created
- [x] Storage configured
- [x] Global service annotation for ClusterMesh
- [ ] Deployed on infra cluster
- [ ] Accessible from apps cluster
- [ ] Test Redis commands work

**Tasks:**
- Files already created, verify:
  - ✅ `kubernetes/workloads/platform/databases/dragonfly/kustomization.yaml`
  - ✅ `kubernetes/workloads/platform/databases/dragonfly/helmrelease.yaml`

- **Deploy via Flux** (automatic)

- **Verify:**
  ```bash
  kubectl --context infra get pods -n databases -l app=dragonfly
  kubectl --context infra get service -n databases dragonfly
  ```

- **Test from apps cluster:**
  ```bash
  kubectl --context apps run redis-test --image=redis:7 -it --rm -- \
    redis-cli -h dragonfly.databases.svc.clusterset.local PING
  ```

**Files Created:**
- ✅ `kubernetes/workloads/platform/databases/dragonfly/kustomization.yaml`
- ✅ `kubernetes/workloads/platform/databases/dragonfly/helmrelease.yaml`

**Dragonfly Configuration:**
- Storage: Uses `DRAGONFLY_STORAGE_CLASS` (openebs-local-nvme)
- Data size: `50Gi`
- Auth: Configured via ExternalSecret
- Global service: Enabled for apps cluster access
- Performance: Drop-in Redis replacement, 25x faster

---
