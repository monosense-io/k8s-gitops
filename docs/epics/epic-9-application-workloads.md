# EPIC-9: Application Workloads
**Goal:** Deploy GitLab, Harbor, Mattermost
**Status:** ⚠️ 20% Complete (only GitLab configured)

## Story 9.1: Deploy GitLab ✅
**Priority:** P1 | **Points:** 5 | **Days:** 3 | **Status:** ✅ CONFIG COMPLETE

**Acceptance Criteria:**
- [x] GitLab manifests created
- [x] Connected to shared PostgreSQL on infra (via ClusterMesh)
- [x] Connected to Dragonfly (via ClusterMesh)
- [x] MinIO object storage configured
- [ ] GitLab deployed on apps cluster
- [ ] GitLab accessible via HTTPRoute
- [ ] SSO configured (pending EPIC-8)
- [ ] Can create repo and run pipeline

**Tasks:**
- Files already created, verify:
  - ✅ `kubernetes/workloads/tenants/gitlab/kustomization.yaml`
  - ✅ `kubernetes/workloads/tenants/gitlab/helmrelease.yaml`
  - ✅ `kubernetes/workloads/tenants/gitlab/externalsecret.yaml`

- **Deploy via Flux** (automatic when workloads reconcile on apps cluster)

- **Verify:**
  ```bash
  kubectl --context apps get pods -n gitlab
  kubectl --context apps get httproute -n gitlab
  ```

- **Access GitLab:**
  - URL: `https://gitlab.monosense.io`
  - Root password: From 1Password

- **Test:**
  - Create test project
  - Push code
  - Create .gitlab-ci.yml
  - Verify pipeline runs

**Files Created:**
- ✅ `kubernetes/workloads/tenants/gitlab/kustomization.yaml`
- ✅ `kubernetes/workloads/tenants/gitlab/helmrelease.yaml`
- ✅ `kubernetes/workloads/tenants/gitlab/externalsecret.yaml`

**GitLab Configuration:**
- PostgreSQL: `<cluster>-rw.databases.svc.clusterset.local` (cross-cluster)
- Redis: `dragonfly.databases.svc.clusterset.local` (cross-cluster)
- Object storage: MinIO at `http://10.25.11.3:9000`
- Storage: OpenEBS local-nvme for git repositories
- Runners: To be deployed after GitLab is operational

---

## Story 9.2: Deploy Harbor Registry
**Priority:** P1 | **Points:** 3 | **Days:** 2 | **Status:** ❌ NOT IMPLEMENTED

**Acceptance Criteria:**
- [ ] Harbor manifests created
- [ ] Connected to shared PostgreSQL
- [ ] Connected to Dragonfly (Redis)
- [ ] Object storage configured (MinIO or Ceph RGW)
- [ ] Deployed on apps cluster
- [ ] SSO configured
- [ ] Can push/pull images

**Tasks:**
- Create `kubernetes/workloads/tenants/harbor/helmrelease.yaml`
- Create `kubernetes/workloads/tenants/harbor/externalsecret.yaml` (DB, Redis, admin password)
- Create `kubernetes/workloads/tenants/harbor/httproute.yaml`
- Deploy via Flux
- Configure SSO with Keycloak (after EPIC-8)
- Test docker push/pull:
  ```bash
  docker login harbor.monosense.io
  docker tag test-image harbor.monosense.io/library/test-image
  docker push harbor.monosense.io/library/test-image
  ```

**Files to Create:**
- 🔲 `kubernetes/workloads/tenants/harbor/kustomization.yaml`
- 🔲 `kubernetes/workloads/tenants/harbor/helmrelease.yaml`
- 🔲 `kubernetes/workloads/tenants/harbor/externalsecret.yaml`
- 🔲 `kubernetes/workloads/tenants/harbor/httproute.yaml`

**Harbor Configuration:**
- Database: PostgreSQL (cross-cluster)
- Redis: Dragonfly (cross-cluster)
- Storage: MinIO or Ceph for images
- Replicas: 2 (HA)

---

## Story 9.3: Deploy Mattermost
**Priority:** P1 | **Points:** 3 | **Days:** 2 | **Status:** ❌ NOT IMPLEMENTED

**Acceptance Criteria:**
- [ ] Mattermost operator deployed
- [ ] Mattermost instance created
- [ ] Connected to shared PostgreSQL
- [ ] Deployed on apps cluster
- [ ] SSO configured
- [ ] Can send messages

**Tasks:**
- Create Mattermost operator and instance manifests
- Connect to PostgreSQL (cross-cluster)
- Create HTTPRoute for external access
- Configure SSO with Keycloak
- Deploy via Flux
- Test messaging functionality

**Files to Create:**
- 🔲 `kubernetes/workloads/tenants/mattermost/operator/kustomization.yaml`
- 🔲 `kubernetes/workloads/tenants/mattermost/instance/mattermost.yaml`
- 🔲 `kubernetes/workloads/tenants/mattermost/instance/externalsecret.yaml`
- 🔲 `kubernetes/workloads/tenants/mattermost/instance/httproute.yaml`

---
