# EPIC-6: Observability Stack
**Goal:** Deploy Victoria Metrics, Victoria Logs, Grafana, Fluent-bit
**Status:** ✅ 70% Complete (most configs done, deployment pending)

## Story 6.1: Deploy Victoria Metrics Stack on Infra Cluster ✅
**Priority:** P0 | **Points:** 5 | **Days:** 2 | **Status:** ✅ CONFIG COMPLETE

**Acceptance Criteria:**
- [x] Victoria Metrics stack base HelmRelease created
- [x] VM stack workload config created
- [x] Includes: VMCluster, VMAgent, VMAlert, Grafana
- [x] Persistent storage configured (Rook Ceph)
- [ ] Deployed on infra cluster
- [ ] VMAgent scraping infra cluster metrics
- [ ] Grafana accessible with Victoria Metrics datasource
- [ ] Metrics visible in Grafana

**Tasks:**
- Files already created, verify:
  - ✅ `kubernetes/bases/victoria-metrics-stack/helmrelease.yaml`
  - ✅ `kubernetes/workloads/platform/observability/victoria-metrics/kustomization.yaml`

- **Deploy via Flux** (automatic via workloads reconciliation):
  ```bash
  flux reconcile kustomization cluster-infra-workloads
  ```

- **Verify:**
  ```bash
  kubectl --context infra get pods -n observability
  kubectl --context infra get vmcluster -n observability
  kubectl --context infra get vmagent -n observability
  ```

- **Access Grafana:**
  ```bash
  kubectl --context infra port-forward -n observability svc/victoria-metrics-stack-grafana 3000:80
  # Open http://localhost:3000
  # Admin password in 1Password
  ```

- **Verify metrics:**
  - Check Grafana datasources (Victoria Metrics should be configured)
  - Import Kubernetes dashboard
  - Verify metrics displayed

**Files Created:**
- ✅ `kubernetes/bases/victoria-metrics-stack/helmrelease.yaml`
- ✅ `kubernetes/workloads/platform/observability/victoria-metrics/kustomization.yaml`

**Components Included:**
- VMCluster (vmstorage, vmselect, vminsert)
- VMAgent (metrics scraping)
- VMAlert (alerting)
- Grafana (visualization)
- Persistent storage: Uses `OBSERVABILITY_BLOCK_SC` (rook-ceph-block)

---

## Story 6.2: Deploy Victoria Logs on Infra Cluster ✅
**Priority:** P0 | **Points:** 3 | **Days:** 1 | **Status:** ✅ CONFIG COMPLETE

**NEW STORY** - Victoria Logs added for modern log aggregation

**Acceptance Criteria:**
- [x] Victoria Logs base HelmRelease created
- [x] Victoria Logs workload config created
- [ ] Deployed on infra cluster
- [ ] Logs storage configured
- [ ] VMAuth configured for multi-tenancy
- [ ] Grafana datasource configured

**Tasks:**
- Files already created, verify:
  - ✅ `kubernetes/bases/victoria-logs/helmrelease.yaml`
  - ✅ `kubernetes/workloads/platform/observability/victoria-logs/kustomization.yaml`

- **Deploy via Flux** (automatic)

- **Verify:**
  ```bash
  kubectl --context infra get pods -n observability -l app=victoria-logs
  kubectl --context infra get svc -n observability victoria-logs
  ```

- **Test log ingestion:**
  ```bash
  curl -X POST http://<victoria-logs-ip>:9428/insert \
    -H "VL-Msg: Test log message" \
    -H "VL-Stream-Fields: app=test,env=dev"
  ```

**Files Created:**
- ✅ `kubernetes/bases/victoria-logs/helmrelease.yaml`
- ✅ `kubernetes/workloads/platform/observability/victoria-logs/kustomization.yaml`

**Victoria Logs Configuration:**
- Retention: From `OBSERVABILITY_LOGS_RETENTION` variable (14d)
- Storage: Uses Rook Ceph block storage
- Multi-tenancy: Enabled via VMAuth
- Endpoint: `http://victorialogs-vmauth.observability.svc:9428`

---

## Story 6.3: Deploy Fluent-bit (Both Clusters) ✅
**Priority:** P1 | **Points:** 3 | **Days:** 1 | **Status:** ✅ CONFIG COMPLETE

**Acceptance Criteria:**
- [x] Fluent-bit base HelmRelease created
- [x] Fluent-bit workload config created
- [x] Configured to forward to Victoria Logs
- [x] Multi-tenant configuration (infra/apps tenant headers)
- [ ] Deployed to infra cluster
- [ ] Deployed to apps cluster (automatic with tenant variable)
- [ ] Logs forwarded to Victoria Logs
- [ ] Logs visible in Grafana

**Tasks:**
- Files already created, verify:
  - ✅ `kubernetes/bases/fluent-bit/helmrelease.yaml`
  - ✅ `kubernetes/workloads/platform/observability/fluent-bit/kustomization.yaml`

- **Deploy via Flux** (automatic to both clusters)

- **Verify on both clusters:**
  ```bash
  kubectl --context infra get pods -n observability -l app=fluent-bit
  kubectl --context apps get pods -n observability -l app=fluent-bit
  ```

- **Check logs are forwarded:**
  ```bash
  kubectl --context infra logs -n observability -l app=fluent-bit
  ```

- **Verify in Grafana:**
  - Add Victoria Logs datasource
  - Create Logs dashboard
  - Query: `{cluster="infra"}` and `{cluster="apps"}`

**Files Created:**
- ✅ `kubernetes/bases/fluent-bit/helmrelease.yaml`
- ✅ `kubernetes/workloads/platform/observability/fluent-bit/kustomization.yaml`

**Fluent-bit Configuration:**
- Output: HTTP to Victoria Logs
- Endpoint: Uses `OBSERVABILITY_LOG_ENDPOINT_HOST` variable
- Tenant header: Uses `OBSERVABILITY_LOG_TENANT` variable (infra/apps)
- Format: JSON with Kubernetes metadata

**Multi-tenant Setup:**
- Infra cluster: `OBSERVABILITY_LOG_TENANT: "infra"`
- Apps cluster: `OBSERVABILITY_LOG_TENANT: "apps"`
- Logs segregated by tenant in Victoria Logs

**Note:** Stories 6.4 and 6.5 merged - single config deploys to both clusters!

---
