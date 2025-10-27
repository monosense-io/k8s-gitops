# 46 — STORY-VALIDATE-STORAGE-OBSERVABILITY — Deploy & Validate Storage and Observability Stack

Sequence: 46/50 | Prev: STORY-VALIDATE-NETWORKING.md | Next: STORY-VALIDATE-DATABASES-SECURITY.md
Sprint: 8 | Lane: Deployment & Validation
Global Sequence: 46/50

Status: Draft (v3.0 Refinement)
Owner: Platform Engineering
Date: 2025-10-26 (v3.0 Refinement)
Links: docs/architecture.md; docs/SCHEDULE-V2-GREENFIELD.md; Stories 16-28 (storage & observability manifests)

ID: STORY-VALIDATE-STORAGE-OBSERVABILITY

## Story

As a Platform Engineer, I want to deploy and validate all storage and observability manifests (stories 16-28) on both infra and apps clusters, so that I can verify OpenEBS, Rook-Ceph, VictoriaMetrics, VictoriaLogs, and Fluent-bit are operational before deploying databases and applications.

This story focuses on **storage and observability layer validation** as part of the phased deployment approach. Story 45 (VALIDATE-NETWORKING) completed networking validation. This story validates the storage and monitoring foundation.

## Why / Outcome

- **Deploy storage manifests** (stories 16-21) to both clusters
- **Deploy observability manifests** (stories 25-28) to infra and apps clusters
- **Validate storage provisioning** (OpenEBS, Rook-Ceph) with test workloads
- **Validate observability stack** (metrics, logs) collecting platform telemetry
- **Establish monitoring baselines** for platform health
- **Provide storage infrastructure** for stateful workloads in subsequent stories
- **Enable comprehensive monitoring** before deploying databases/applications

## Scope

### v3.0 Phased Validation Approach

**Prerequisites** (completed in Story 45):
- Networking stack operational (Cilium, DNS, certs, BGP, ClusterMesh)
- Flux reconciliation healthy
- Both clusters ready for storage and observability deployment

**This Story Deploys & Validates**:
- Storage manifests (stories 16-21)
- Observability manifests (stories 25-28)
- Integration testing between storage and monitoring

**Deferred to Story 47**:
- Database deployment (CNPG, DragonflyDB)
- Security components (NetworkPolicy, SPIRE)

### Storage Coverage (Stories 16-21)

**Infra Cluster Storage**:
16. STORY-STO-OPENEBS-BASE — OpenEBS hostpath storage (local NVMe)
17. STORY-STO-ROOK-CEPH-OPERATOR — Rook-Ceph operator
18. STORY-STO-ROOK-CEPH-CLUSTER — Rook-Ceph cluster, pools, storage classes

**Apps Cluster Storage**:
19. STORY-STO-APPS-OPENEBS-BASE — OpenEBS hostpath storage (apps)
20. STORY-STO-APPS-ROOK-CEPH-OPERATOR — Rook-Ceph operator (apps)
21. STORY-STO-APPS-ROOK-CEPH-CLUSTER — Rook-Ceph cluster (apps)

### Observability Coverage (Stories 25-28)

**Infra Cluster Observability (Global Stack)**:
25. STORY-OBS-VM-STACK — VictoriaMetrics stack (global metrics aggregation)
26. STORY-OBS-VICTORIA-LOGS — VictoriaLogs (global logs aggregation)
27. STORY-OBS-FLUENT-BIT — Fluent-bit log collectors (infra)

**Apps Cluster Observability (Leaf Collectors)**:
28. STORY-OBS-APPS-COLLECTORS — vmagent, kube-state-metrics, node-exporter, fluent-bit (apps → infra)

## Acceptance Criteria

### AC1 — OpenEBS Operational (Infra + Apps)

**Infra Cluster**:
- [ ] OpenEBS control plane pods Running: `openebs-localpv-provisioner`, `openebs-ndt-daemon`
- [ ] Storage class `openebs-hostpath` available
- [ ] NVMe devices mounted at `/var/mnt/openebs` on all nodes
- [ ] Test PVC created, bound, and mounted successfully
- [ ] PVC write/read test passes

**Apps Cluster**:
- [ ] OpenEBS control plane pods Running (apps)
- [ ] Storage class `openebs-hostpath` available (apps)
- [ ] NVMe devices available (apps)
- [ ] Test PVC validation (apps)

### AC2 — Rook-Ceph Operator Operational (Infra + Apps)

**Infra Cluster**:
- [ ] Rook-Ceph operator pod Running and healthy
- [ ] CephCluster CRD available
- [ ] Operator logs show no errors
- [ ] Metrics endpoint responding
- [ ] ServiceMonitor scraping operator metrics

**Apps Cluster**:
- [ ] Rook-Ceph operator Running (apps)
- [ ] Independent operator (not clustered with infra)

### AC3 — Rook-Ceph Cluster Operational (Infra + Apps)

**Infra Cluster**:
- [ ] Ceph cluster status: `HEALTH_OK`
- [ ] OSD pods Running on all storage nodes (3 OSDs expected)
- [ ] MON quorum established (3 MON replicas)
- [ ] MGR active with dashboard accessible
- [ ] Storage class `rook-ceph-block` available
- [ ] CephBlockPool created with replication=3
- [ ] Test RBD PVC created, bound, and mounted
- [ ] Ceph dashboard accessible (optional)
- [ ] Metrics scraped by VictoriaMetrics

**Apps Cluster**:
- [ ] Independent Ceph cluster HEALTH_OK (apps)
- [ ] OSDs, MONs, MGR Running (apps)
- [ ] Storage class available (apps)
- [ ] Test PVC validation (apps)

### AC4 — VictoriaMetrics Stack Operational (Infra)

**Core Components**:
- [ ] VMAgent pod Running (scraping targets)
- [ ] VMInsert pod Running (ingestion endpoint)
- [ ] VMSelect pod Running (query endpoint)
- [ ] VMStorage StatefulSet Running (3 replicas for HA)
- [ ] VMAuth reverse proxy Running (authentication/routing)

**Functionality**:
- [ ] VMAgent scraping all configured targets (Cilium, Rook, Flux, Kubernetes)
- [ ] Metrics ingesting successfully (no scrape errors)
- [ ] 30-day retention configured and enforced
- [ ] PrometheusRules loaded (alert definitions)
- [ ] VMAuth authentication working
- [ ] Query performance acceptable (<1s for standard queries)

**Grafana**:
- [ ] Grafana pod Running
- [ ] Grafana accessible via HTTPRoute or port-forward
- [ ] Admin credentials from ExternalSecret working
- [ ] VictoriaMetrics datasource configured
- [ ] Test query returns data: `up{cluster="infra"}`

### AC5 — VictoriaLogs Operational (Infra)

**Core Components**:
- [ ] VictoriaLogs cluster Running (insert, select, storage components)
- [ ] VMAuth reverse proxy routing logs traffic

**Functionality**:
- [ ] Logs ingesting from Fluent-bit (infra)
- [ ] 14-day retention configured
- [ ] LogQL queries returning results: `{cluster="infra"}`
- [ ] No ingestion errors in logs
- [ ] Log volume metrics visible in VictoriaMetrics

**Integration with Grafana**:
- [ ] VictoriaLogs datasource configured in Grafana
- [ ] Test LogQL query in Grafana Explore

### AC6 — Fluent-bit Operational (Infra)

**Deployment**:
- [ ] Fluent-bit DaemonSet Running on all infra nodes
- [ ] Fluent-bit pods healthy (no CrashLoopBackOff)

**Functionality**:
- [ ] Logs streaming to VictoriaLogs HTTP endpoint
- [ ] CRI parser working correctly (containerd log format)
- [ ] Kubernetes metadata enrichment (pod, namespace, node) present
- [ ] Parsing rules working (no parsing errors in metrics)
- [ ] Buffer not backing up (check fluent-bit metrics)
- [ ] Logs from all namespaces appearing in VictoriaLogs

### AC7 — Apps Collectors Operational (Apps → Infra)

**vmagent (Apps)**:
- [ ] vmagent pod Running in apps cluster
- [ ] Remote write to infra VictoriaMetrics working (port 8480)
- [ ] External label `cluster=apps` attached to all metrics
- [ ] Scraping local targets: kube-state-metrics, node-exporter, kubelet, cadvisor

**kube-state-metrics (Apps)**:
- [ ] kube-state-metrics pod Running (apps)
- [ ] Metrics endpoint responding
- [ ] ServiceMonitor configured for scraping

**node-exporter (Apps)**:
- [ ] node-exporter DaemonSet Running on all apps nodes
- [ ] Talos-compatible configuration (hostNetwork, hostPID, correct paths)
- [ ] Metrics endpoint responding

**fluent-bit (Apps)**:
- [ ] fluent-bit DaemonSet Running on all apps nodes
- [ ] Forwarding logs to infra VictoriaLogs (port 9428)
- [ ] External label `cluster=apps` attached
- [ ] CRI parser working

**Cross-Cluster Validation**:
- [ ] Apps metrics visible in infra Grafana with `cluster=apps` label
- [ ] Apps logs queryable in infra VictoriaLogs: `{cluster="apps"}`

### AC8 — Monitoring Coverage

**ServiceMonitors Deployed**:
- [ ] Cilium ServiceMonitor (from Story 1)
- [ ] Rook-Ceph ServiceMonitor (from Stories 17, 18, 20, 21)
- [ ] Flux ServiceMonitor (from Story 44)
- [ ] OpenEBS ServiceMonitor (if available)

**Metrics Validation**:
- [ ] All ServiceMonitors have targets in UP state (check VMAgent)
- [ ] No scrape errors in VMAgent logs
- [ ] Custom metrics scraped (Cilium hubble, Ceph cluster health)

**PrometheusRules**:
- [ ] PrometheusRules loaded in VMAlert
- [ ] Alert rules defined for Rook-Ceph, VictoriaMetrics, Flux
- [ ] Test alert firing (intentionally trigger condition, verify alert)

### AC9 — Storage Performance Baselines

**I/O Performance**:
- [ ] Rook-Ceph block storage IOPS baseline established (fio benchmark)
  - Random read IOPS (target: >5000 IOPS at 4K block size)
  - Random write IOPS (target: >3000 IOPS at 4K block size)
  - Latency p95 < 10ms
- [ ] OpenEBS hostpath performance baseline (target: NVMe native performance)

**Ceph Cluster Health**:
- [ ] Ceph cluster PG distribution balanced
- [ ] No slow OSDs (check `ceph osd perf`)
- [ ] Network latency acceptable (check `ceph osd ping`)

### AC10 — Integration Testing

**Storage Integration**:
- [ ] Deploy test StatefulSet with Ceph-backed PVC (infra)
- [ ] Write data, delete pod, verify data persists after pod recreation
- [ ] Create VolumeSnapshot, restore to new PVC, verify data integrity
- [ ] Test PVC expansion (if supported)

**Observability Integration**:
- [ ] Deploy test workload (infra)
- [ ] Verify metrics scraped by VMAgent (test pod metrics visible)
- [ ] Verify logs forwarded to VictoriaLogs (test pod logs visible)
- [ ] Query metrics in Grafana: `container_cpu_usage_seconds_total{pod="test-pod"}`
- [ ] Query logs in VictoriaLogs: `{pod="test-pod"}`

**Cross-Cluster Observability**:
- [ ] Deploy test workload in apps cluster
- [ ] Verify apps metrics visible in infra Grafana
- [ ] Verify apps logs queryable in infra VictoriaLogs
- [ ] Confirm `cluster=apps` label differentiates apps vs infra metrics/logs

### AC11 — Documentation & Evidence

**QA Evidence**:
- [ ] Ceph status captured: `ceph status`, `ceph osd tree`, `ceph df`
- [ ] Storage class validation: `kubectl get sc` (both clusters)
- [ ] VictoriaMetrics query results: sample PromQL queries with output
- [ ] VictoriaLogs query results: sample LogQL queries with output
- [ ] Grafana screenshots: dashboards for Ceph, VictoriaMetrics, Cilium
- [ ] Performance benchmark results: fio output, IOPS/latency measurements

**Dev Notes**:
- [ ] Issues encountered with resolutions
- [ ] Deviations from manifests (if any)
- [ ] Runtime configuration adjustments
- [ ] Known limitations

## Dependencies / Inputs

**Upstream Prerequisites**:
- **Story 45 Complete**: Networking stack operational (Cilium, DNS, BGP, certs)
- **Stories 16-28 Complete**: All storage and observability manifests committed to git
- **Hardware**: NVMe devices available on all nodes for OpenEBS and Ceph OSDs
- **Secrets**: 1Password Connect for Grafana admin credentials

**Tools Required**:
- `kubectl`, `flux`, `talosctl`
- `ceph` CLI (via rook-ceph-tools pod)
- `fio` for storage benchmarks
- `curl`, `jq` for API queries

**Cluster Access**:
- KUBECONFIG contexts: `infra`, `apps`
- Network connectivity to both clusters

## Tasks / Subtasks

### T0 — Pre-Deployment Validation (NO Cluster Changes)

**Manifest Quality Checks**:
- [ ] Verify storage and observability manifests (stories 16-28) committed to git
- [ ] Run `flux build kustomization` for storage components:
  ```bash
  flux build kustomization cluster-infra-storage --path kubernetes/infrastructure/storage
  flux build kustomization cluster-apps-storage --path kubernetes/infrastructure/storage
  ```
- [ ] Run `flux build kustomization` for observability components:
  ```bash
  flux build kustomization cluster-infra-observability --path kubernetes/workloads/platform/observability
  flux build kustomization cluster-apps-observability --path kubernetes/workloads/platform/observability
  ```
- [ ] Validate with `kubeconform`:
  ```bash
  kustomize build kubernetes/infrastructure/storage | kubeconform -summary -strict
  kustomize build kubernetes/workloads/platform/observability | kubeconform -summary -strict
  ```

**Infrastructure Readiness**:
- [ ] Verify NVMe devices available on all nodes (infra + apps):
  ```bash
  talosctl --context=infra get disks
  talosctl --context=apps get disks
  ```
- [ ] Verify `/var/mnt/openebs` mount point exists (or will be created)
- [ ] Verify Story 45 complete: Cilium operational, Flux reconciling

### T1 — Deploy Storage Stack (Infra Cluster)

**OpenEBS Deployment**:
- [ ] Trigger OpenEBS reconciliation:
  ```bash
  flux --context=infra reconcile kustomization infra-storage-openebs --with-source
  ```
- [ ] Monitor deployment:
  ```bash
  kubectl --context=infra -n openebs get pods -w
  ```
- [ ] Verify storage class:
  ```bash
  kubectl --context=infra get sc openebs-hostpath
  ```

**Rook-Ceph Operator Deployment**:
- [ ] Trigger Rook operator reconciliation:
  ```bash
  flux --context=infra reconcile kustomization infra-storage-rook-operator --with-source
  ```
- [ ] Monitor operator deployment:
  ```bash
  kubectl --context=infra -n rook-ceph get pods -l app=rook-ceph-operator -w
  ```
- [ ] Wait for operator Ready:
  ```bash
  kubectl --context=infra -n rook-ceph rollout status deploy/rook-ceph-operator
  ```

**Rook-Ceph Cluster Deployment**:
- [ ] Trigger Ceph cluster reconciliation:
  ```bash
  flux --context=infra reconcile kustomization infra-storage-rook-cluster --with-source
  ```
- [ ] Monitor Ceph cluster deployment (MONs → MGRs → OSDs):
  ```bash
  watch kubectl --context=infra -n rook-ceph get pods
  ```
- [ ] Wait for Ceph HEALTH_OK (may take 5-10 minutes):
  ```bash
  kubectl --context=infra -n rook-ceph exec deploy/rook-ceph-tools -- ceph status
  # Wait until HEALTH_OK
  ```

**Validation**:
- [ ] Capture Ceph status:
  ```bash
  kubectl --context=infra -n rook-ceph exec deploy/rook-ceph-tools -- ceph status
  kubectl --context=infra -n rook-ceph exec deploy/rook-ceph-tools -- ceph osd tree
  kubectl --context=infra -n rook-ceph exec deploy/rook-ceph-tools -- ceph df
  ```
- [ ] Capture storage classes:
  ```bash
  kubectl --context=infra get sc
  ```
- [ ] Document in Dev Notes

### T2 — Deploy Storage Stack (Apps Cluster)

**Repeat T1 for Apps Cluster**:
- [ ] Deploy OpenEBS (apps)
- [ ] Deploy Rook-Ceph operator (apps)
- [ ] Deploy Rook-Ceph cluster (apps)
- [ ] Verify independent Ceph cluster (not clustered with infra)
- [ ] Capture validation outputs

### T3 — Storage Functional Testing (Infra)

**OpenEBS PVC Test**:
- [ ] Create test PVC:
  ```bash
  kubectl --context=infra apply -f - <<EOF
  apiVersion: v1
  kind: PersistentVolumeClaim
  metadata:
    name: test-openebs-pvc
    namespace: default
  spec:
    storageClassName: openebs-hostpath
    accessModes: [ReadWriteOnce]
    resources:
      requests:
        storage: 1Gi
  EOF
  ```
- [ ] Verify PVC bound:
  ```bash
  kubectl --context=infra get pvc test-openebs-pvc
  # Status: Bound
  ```
- [ ] Create test pod to mount PVC:
  ```bash
  kubectl --context=infra apply -f - <<EOF
  apiVersion: v1
  kind: Pod
  metadata:
    name: test-openebs-pod
    namespace: default
  spec:
    containers:
      - name: test
        image: busybox
        command: ["sh", "-c", "echo 'test data' > /data/test.txt && sleep 3600"]
        volumeMounts:
          - name: data
            mountPath: /data
    volumes:
      - name: data
        persistentVolumeClaim:
          claimName: test-openebs-pvc
  EOF
  ```
- [ ] Verify data written:
  ```bash
  kubectl --context=infra exec test-openebs-pod -- cat /data/test.txt
  # Should return: test data
  ```
- [ ] Delete pod, recreate, verify data persists:
  ```bash
  kubectl --context=infra delete pod test-openebs-pod
  kubectl --context=infra apply -f <pod-yaml>
  kubectl --context=infra exec test-openebs-pod -- cat /data/test.txt
  # Should still return: test data
  ```

**Rook-Ceph PVC Test**:
- [ ] Create test PVC:
  ```bash
  kubectl --context=infra apply -f - <<EOF
  apiVersion: v1
  kind: PersistentVolumeClaim
  metadata:
    name: test-ceph-pvc
    namespace: default
  spec:
    storageClassName: rook-ceph-block
    accessModes: [ReadWriteOnce]
    resources:
      requests:
        storage: 1Gi
  EOF
  ```
- [ ] Verify PVC bound
- [ ] Create test pod to mount Ceph PVC
- [ ] Write/read data test
- [ ] Delete pod, recreate, verify persistence

**VolumeSnapshot Test** (Ceph):
- [ ] Create VolumeSnapshot:
  ```bash
  kubectl --context=infra apply -f - <<EOF
  apiVersion: snapshot.storage.k8s.io/v1
  kind: VolumeSnapshot
  metadata:
    name: test-ceph-snapshot
    namespace: default
  spec:
    volumeSnapshotClassName: csi-rbdplugin-snapclass
    source:
      persistentVolumeClaimName: test-ceph-pvc
  EOF
  ```
- [ ] Verify snapshot created:
  ```bash
  kubectl --context=infra get volumesnapshot test-ceph-snapshot
  # ReadyToUse: true
  ```
- [ ] Restore snapshot to new PVC:
  ```bash
  kubectl --context=infra apply -f - <<EOF
  apiVersion: v1
  kind: PersistentVolumeClaim
  metadata:
    name: test-ceph-restored-pvc
    namespace: default
  spec:
    storageClassName: rook-ceph-block
    dataSource:
      name: test-ceph-snapshot
      kind: VolumeSnapshot
      apiGroup: snapshot.storage.k8s.io
    accessModes: [ReadWriteOnce]
    resources:
      requests:
        storage: 1Gi
  EOF
  ```
- [ ] Mount restored PVC and verify data matches original

**Validation**:
- [ ] Capture PVC status (both OpenEBS and Ceph)
- [ ] Capture VolumeSnapshot status
- [ ] Document test results in Dev Notes

### T4 — Storage Functional Testing (Apps)

**Repeat T3 for Apps Cluster**:
- [ ] OpenEBS PVC test (apps)
- [ ] Rook-Ceph PVC test (apps)
- [ ] VolumeSnapshot test (apps)

### T5 — Storage Performance Testing (Infra)

**Ceph Block Storage Benchmarks**:
- [ ] Create benchmark PVC (larger size for accurate testing):
  ```bash
  kubectl --context=infra apply -f - <<EOF
  apiVersion: v1
  kind: PersistentVolumeClaim
  metadata:
    name: fio-test-pvc
    namespace: default
  spec:
    storageClassName: rook-ceph-block
    accessModes: [ReadWriteOnce]
    resources:
      requests:
        storage: 10Gi
  EOF
  ```
- [ ] Run fio benchmark pod:
  ```bash
  kubectl --context=infra apply -f - <<EOF
  apiVersion: v1
  kind: Pod
  metadata:
    name: fio-benchmark
    namespace: default
  spec:
    containers:
      - name: fio
        image: nixery.dev/fio
        command: ["sleep", "3600"]
        volumeMounts:
          - name: data
            mountPath: /data
    volumes:
      - name: data
        persistentVolumeClaim:
          claimName: fio-test-pvc
  EOF
  ```
- [ ] Random read IOPS test:
  ```bash
  kubectl --context=infra exec fio-benchmark -- fio \
    --name=randread \
    --ioengine=libaio \
    --rw=randread \
    --bs=4k \
    --numjobs=1 \
    --size=1G \
    --runtime=60 \
    --directory=/data \
    --output-format=json
  # Target: >5000 IOPS
  ```
- [ ] Random write IOPS test:
  ```bash
  kubectl --context=infra exec fio-benchmark -- fio \
    --name=randwrite \
    --ioengine=libaio \
    --rw=randwrite \
    --bs=4k \
    --numjobs=1 \
    --size=1G \
    --runtime=60 \
    --directory=/data \
    --output-format=json
  # Target: >3000 IOPS
  ```
- [ ] Latency test:
  ```bash
  kubectl --context=infra exec fio-benchmark -- fio \
    --name=latency \
    --ioengine=libaio \
    --rw=randread \
    --bs=4k \
    --numjobs=1 \
    --size=1G \
    --runtime=60 \
    --directory=/data \
    --output-format=json
  # Target: p95 latency < 10ms
  ```

**OpenEBS Performance Test**:
- [ ] Repeat fio benchmarks with OpenEBS PVC
- [ ] Compare against Ceph performance
- [ ] Document results

**Validation**:
- [ ] Capture fio benchmark results (JSON output)
- [ ] Document IOPS, latency baselines
- [ ] Compare against targets

### T6 — Deploy Observability Stack (Infra)

**VictoriaMetrics Stack Deployment**:
- [ ] Trigger VM stack reconciliation:
  ```bash
  flux --context=infra reconcile kustomization infra-observability-vm-stack --with-source
  ```
- [ ] Monitor deployment:
  ```bash
  kubectl --context=infra -n observability get pods -w
  ```
- [ ] Wait for all components Ready:
  ```bash
  kubectl --context=infra -n observability get pods
  # vmagent, vminsert, vmselect, vmstorage, vmauth, grafana all Running
  ```

**VictoriaLogs Deployment**:
- [ ] Trigger VictoriaLogs reconciliation:
  ```bash
  flux --context=infra reconcile kustomization infra-observability-vlogs --with-source
  ```
- [ ] Monitor deployment:
  ```bash
  kubectl --context=infra -n observability get pods -l app=victorialogs -w
  ```

**Fluent-bit Deployment (Infra)**:
- [ ] Trigger fluent-bit reconciliation:
  ```bash
  flux --context=infra reconcile kustomization infra-observability-fluent-bit --with-source
  ```
- [ ] Monitor DaemonSet deployment:
  ```bash
  kubectl --context=infra -n observability get ds fluent-bit -w
  ```
- [ ] Verify fluent-bit pods on all nodes:
  ```bash
  kubectl --context=infra -n observability get pods -l app.kubernetes.io/name=fluent-bit
  # Should show 1 pod per node
  ```

**Validation**:
- [ ] Capture pod status:
  ```bash
  kubectl --context=infra -n observability get pods
  ```
- [ ] Check for errors in logs:
  ```bash
  kubectl --context=infra -n observability logs -l app=vmagent --tail=50
  kubectl --context=infra -n observability logs -l app=victorialogs --tail=50
  kubectl --context=infra -n observability logs -l app.kubernetes.io/name=fluent-bit --tail=50
  ```

### T7 — Deploy Apps Collectors (Apps Cluster)

**Apps Observability Deployment**:
- [ ] Trigger apps collectors reconciliation:
  ```bash
  flux --context=apps reconcile kustomization apps-observability-collectors --with-source
  ```
- [ ] Monitor deployment:
  ```bash
  kubectl --context=apps -n observability get pods -w
  ```
- [ ] Wait for all collectors Running:
  ```bash
  kubectl --context=apps -n observability get pods
  # vmagent, kube-state-metrics, node-exporter (DaemonSet), fluent-bit (DaemonSet)
  ```

**Validation**:
- [ ] Verify vmagent remote write configuration:
  ```bash
  kubectl --context=apps -n observability logs -l app=vmagent | grep "remote_write"
  # Should show connection to infra VictoriaMetrics
  ```
- [ ] Verify fluent-bit forwarding:
  ```bash
  kubectl --context=apps -n observability logs -l app.kubernetes.io/name=fluent-bit | grep "http"
  # Should show HTTP POST to infra VictoriaLogs
  ```

### T8 — Metrics Validation (Infra)

**Access Grafana**:
- [ ] Get Grafana admin password:
  ```bash
  kubectl --context=infra -n observability get secret grafana-admin -o jsonpath='{.data.password}' | base64 -d
  ```
- [ ] Port-forward Grafana:
  ```bash
  kubectl --context=infra port-forward -n observability svc/grafana 3000:80
  ```
- [ ] Login to Grafana: http://localhost:3000 (admin / <password>)

**Verify VictoriaMetrics Datasource**:
- [ ] Navigate to Configuration > Data Sources
- [ ] Verify VictoriaMetrics datasource configured
- [ ] Test datasource connection (should succeed)

**Query Metrics**:
- [ ] Navigate to Explore
- [ ] Run test queries:
  ```promql
  up{cluster="infra"}
  # Should return metrics from infra cluster

  node_cpu_seconds_total{cluster="infra"}
  # Should return CPU metrics from infra nodes

  cilium_policy_count{cluster="infra"}
  # Should return Cilium metrics (from Story 45)

  ceph_cluster_total_bytes{cluster="infra"}
  # Should return Ceph metrics (from this story)
  ```
- [ ] Verify all queries return data

**Check VMAgent Targets**:
- [ ] Port-forward VMAgent:
  ```bash
  kubectl --context=infra port-forward -n observability svc/vmagent 8429:8429
  ```
- [ ] Access targets page: http://localhost:8429/targets
- [ ] Verify all targets UP (Cilium, Rook, Flux, Kubernetes)
- [ ] Check for scrape errors (should be zero)

**Validation**:
- [ ] Capture screenshots of Grafana datasource test, Explore queries, VMAgent targets
- [ ] Document query results
- [ ] Note any missing ServiceMonitors

### T9 — Logs Validation (Infra)

**Query VictoriaLogs**:
- [ ] Port-forward VictoriaLogs:
  ```bash
  kubectl --context=infra port-forward -n observability svc/victorialogs 9428:9428
  ```
- [ ] Run LogQL queries:
  ```bash
  # All logs from infra cluster
  curl 'http://localhost:9428/select/logsql/query' -d 'query={cluster="infra"}'

  # Logs from flux-system namespace
  curl 'http://localhost:9428/select/logsql/query' -d 'query={cluster="infra",namespace="flux-system"}'

  # Error logs
  curl 'http://localhost:9428/select/logsql/query' -d 'query={cluster="infra"} |= "error"'
  ```
- [ ] Verify logs returned for all queries

**Verify Fluent-bit Forwarding**:
- [ ] Check fluent-bit metrics:
  ```bash
  kubectl --context=infra -n observability port-forward ds/fluent-bit 2020:2020
  curl http://localhost:2020/api/v1/metrics
  ```
- [ ] Check for:
  - Output success counter (should be increasing)
  - Buffer usage (should be low)
  - No dropped logs

**Grafana Logs Integration**:
- [ ] In Grafana, add VictoriaLogs datasource (if not already added)
- [ ] Navigate to Explore
- [ ] Select VictoriaLogs datasource
- [ ] Run test LogQL query: `{cluster="infra",namespace="rook-ceph"}`
- [ ] Verify logs displayed

**Validation**:
- [ ] Capture LogQL query results
- [ ] Capture fluent-bit metrics output
- [ ] Screenshot Grafana logs query

### T10 — Cross-Cluster Observability Validation (Apps → Infra)

**Metrics Validation**:
- [ ] In infra Grafana, query apps cluster metrics:
  ```promql
  up{cluster="apps"}
  # Should return metrics from apps cluster

  node_memory_MemAvailable_bytes{cluster="apps"}
  # Should return memory metrics from apps nodes

  kube_pod_status_phase{cluster="apps"}
  # Should return kube-state-metrics data from apps
  ```
- [ ] Verify all queries return apps cluster data

**Logs Validation**:
- [ ] Query apps cluster logs in infra VictoriaLogs:
  ```bash
  curl 'http://localhost:9428/select/logsql/query' -d 'query={cluster="apps"}'

  curl 'http://localhost:9428/select/logsql/query' -d 'query={cluster="apps",namespace="kube-system"}'
  ```
- [ ] Verify apps logs returned

**Validation**:
- [ ] Capture cross-cluster query results
- [ ] Verify `cluster=apps` label differentiates apps from infra data

### T11 — Monitoring Coverage Audit

**ServiceMonitors Inventory**:
- [ ] List all ServiceMonitors:
  ```bash
  kubectl --context=infra get servicemonitor -A -o wide
  ```
- [ ] Expected ServiceMonitors (from previous stories):
  - Cilium (namespace: kube-system)
  - Rook-Ceph operator (namespace: rook-ceph)
  - Rook-Ceph cluster (namespace: rook-ceph)
  - Flux controllers (namespace: flux-system)
  - VictoriaMetrics components (namespace: observability)
  - OpenEBS (if available)

**Coverage Validation**:
- [ ] Cross-check ServiceMonitors with VMAgent targets
- [ ] Identify any missing ServiceMonitors
- [ ] Document coverage gaps

**PrometheusRules Audit**:
- [ ] List all PrometheusRules:
  ```bash
  kubectl --context=infra get prometheusrule -A
  ```
- [ ] Verify alert rules loaded in VMAlert:
  ```bash
  kubectl --context=infra port-forward -n observability svc/vmalert 8880:8880
  curl http://localhost:8880/api/v1/rules
  ```

**Test Alert Firing**:
- [ ] Intentionally trigger an alert (e.g., scale down a deployment to 0 replicas)
- [ ] Wait for alert to fire (check VMAlert)
- [ ] Verify alert visible in Grafana Alerting
- [ ] Restore deployment

**Validation**:
- [ ] Document ServiceMonitors and PrometheusRules
- [ ] Capture VMAlert rules output
- [ ] Screenshot alert firing in Grafana

### T12 — Storage & Observability Integration Testing

**Test Workload with Storage & Monitoring**:
- [ ] Deploy test StatefulSet with Ceph-backed PVC:
  ```bash
  kubectl --context=infra apply -f - <<EOF
  apiVersion: v1
  kind: Service
  metadata:
    name: test-statefulset
    namespace: default
    labels:
      app: test-statefulset
  spec:
    ports:
      - port: 80
        name: web
    clusterIP: None
    selector:
      app: test-statefulset
  ---
  apiVersion: apps/v1
  kind: StatefulSet
  metadata:
    name: test-statefulset
    namespace: default
  spec:
    serviceName: test-statefulset
    replicas: 2
    selector:
      matchLabels:
        app: test-statefulset
    template:
      metadata:
        labels:
          app: test-statefulset
      spec:
        containers:
          - name: nginx
            image: nginx:alpine
            ports:
              - containerPort: 80
                name: web
            volumeMounts:
              - name: data
                mountPath: /usr/share/nginx/html
    volumeClaimTemplates:
      - metadata:
          name: data
        spec:
          storageClassName: rook-ceph-block
          accessModes: [ReadWriteOnce]
          resources:
            requests:
              storage: 1Gi
  EOF
  ```
- [ ] Wait for StatefulSet Ready:
  ```bash
  kubectl --context=infra rollout status statefulset/test-statefulset
  ```

**Verify Metrics Collected**:
- [ ] Query metrics for test pods:
  ```promql
  container_cpu_usage_seconds_total{pod=~"test-statefulset-.*"}
  container_memory_working_set_bytes{pod=~"test-statefulset-.*"}
  ```
- [ ] Verify metrics returned

**Verify Logs Collected**:
- [ ] Query logs for test pods:
  ```bash
  curl 'http://localhost:9428/select/logsql/query' -d 'query={pod=~"test-statefulset-.*"}'
  ```
- [ ] Verify logs returned

**Test Storage Persistence**:
- [ ] Write data to PVC:
  ```bash
  kubectl --context=infra exec test-statefulset-0 -- sh -c "echo 'persistent data' > /usr/share/nginx/html/index.html"
  ```
- [ ] Delete pod:
  ```bash
  kubectl --context=infra delete pod test-statefulset-0
  ```
- [ ] Wait for pod recreation (StatefulSet controller)
- [ ] Verify data persists:
  ```bash
  kubectl --context=infra exec test-statefulset-0 -- cat /usr/share/nginx/html/index.html
  # Should return: persistent data
  ```

**Validation**:
- [ ] Capture metrics query results for test pods
- [ ] Capture logs query results for test pods
- [ ] Document storage persistence test results

### T13 — Performance & Retention Validation

**Metrics Retention**:
- [ ] Query old metrics (test 30-day retention):
  ```promql
  up{cluster="infra"}[30d]
  ```
- [ ] Verify data available for full 30-day window

**Logs Retention**:
- [ ] Query old logs (test 14-day retention):
  ```bash
  curl 'http://localhost:9428/select/logsql/query' -d 'query={cluster="infra"} | time >= 14d'
  ```
- [ ] Verify logs available for 14-day window

**Query Performance**:
- [ ] Run standard query and measure response time:
  ```bash
  time curl 'http://localhost:8481/select/0/prometheus/api/v1/query?query=up{cluster="infra"}'
  # Target: < 1s
  ```
- [ ] Run complex query (aggregation) and measure:
  ```bash
  time curl 'http://localhost:8481/select/0/prometheus/api/v1/query?query=avg(rate(node_cpu_seconds_total{cluster="infra"}[5m]))'
  # Target: < 2s
  ```

**Storage Usage Validation**:
- [ ] Check Ceph pool usage:
  ```bash
  kubectl --context=infra -n rook-ceph exec deploy/rook-ceph-tools -- ceph df
  ```
- [ ] Check VictoriaMetrics disk usage:
  ```bash
  kubectl --context=infra -n observability exec <vmstorage-pod> -- df -h /storage
  ```
- [ ] Verify usage within expected limits

**Validation**:
- [ ] Document retention test results
- [ ] Document query performance measurements
- [ ] Document storage usage

### T14 — Documentation & Evidence Collection

**QA Evidence Artifacts**:
- [ ] Storage validation:
  - `docs/qa/evidence/VALIDATE-STO-ceph-status-infra.txt`
  - `docs/qa/evidence/VALIDATE-STO-ceph-status-apps.txt`
  - `docs/qa/evidence/VALIDATE-STO-pvc-tests.txt`
  - `docs/qa/evidence/VALIDATE-STO-performance-benchmarks.txt`

- [ ] Observability validation:
  - `docs/qa/evidence/VALIDATE-OBS-metrics-queries.txt`
  - `docs/qa/evidence/VALIDATE-OBS-logs-queries.txt`
  - `docs/qa/evidence/VALIDATE-OBS-cross-cluster.txt`

- [ ] Screenshots:
  - Grafana datasource test
  - Grafana Explore queries (metrics + logs)
  - VMAgent targets page
  - Ceph dashboard (if accessible)
  - Grafana dashboards for Ceph, VictoriaMetrics

**Dev Notes Documentation**:
- [ ] Issues encountered with resolutions
- [ ] Deviations from manifests (if any)
- [ ] Runtime configuration adjustments
- [ ] Known limitations
- [ ] Recommendations for database deployment (Story 47)

**Architecture/PRD Updates**:
- [ ] Update architecture.md with Ceph topology and pool configuration
- [ ] Document storage and observability performance baselines in PRD
- [ ] Note resource sizing adjustments (if any)

## Validation Steps

### Pre-Deployment Validation (NO Cluster)
```bash
# Validate manifests can build
flux build kustomization cluster-infra-storage --path kubernetes/infrastructure/storage
flux build kustomization cluster-infra-observability --path kubernetes/workloads/platform/observability

# Schema validation
kustomize build kubernetes/infrastructure/storage | kubeconform -summary -strict
kustomize build kubernetes/workloads/platform/observability | kubeconform -summary -strict
```

### Runtime Validation Commands (Summary)

**Storage Validation**:
```bash
# Ceph status
kubectl --context=infra -n rook-ceph exec deploy/rook-ceph-tools -- ceph status
kubectl --context=infra -n rook-ceph exec deploy/rook-ceph-tools -- ceph osd tree

# Storage classes
kubectl --context=infra get sc
kubectl --context=apps get sc

# PVC tests
kubectl --context=infra get pvc
kubectl --context=apps get pvc
```

**Observability Validation**:
```bash
# Metrics query
kubectl --context=infra port-forward -n observability svc/vmselect 8481:8481
curl 'http://localhost:8481/select/0/prometheus/api/v1/query?query=up{cluster="infra"}'

# Logs query
kubectl --context=infra port-forward -n observability svc/victorialogs 9428:9428
curl 'http://localhost:9428/select/logsql/query' -d 'query={cluster="infra"}'

# Grafana access
kubectl --context=infra port-forward -n observability svc/grafana 3000:80
# Open http://localhost:3000
```

## Rollback Procedures

**Storage Rollback** (HIGH RISK - data loss possible):
```bash
# Suspend Ceph cluster (preserve data)
flux --context=infra suspend kustomization infra-storage-rook-cluster

# Delete Ceph cluster (DESTRUCTIVE)
kubectl --context=infra -n rook-ceph delete cephcluster rook-ceph

# Re-deploy with fixes
flux --context=infra resume kustomization infra-storage-rook-cluster --with-source
```

**Observability Rollback**:
```bash
# Suspend observability stack
flux --context=infra suspend kustomization infra-observability-vm-stack
flux --context=infra suspend kustomization infra-observability-vlogs

# Delete components
kubectl --context=infra -n observability delete all -l app=vmagent

# Re-deploy with fixes
flux --context=infra resume kustomization infra-observability-vm-stack --with-source
```

## Risks / Mitigations

**Storage Risks**:

**R1 — Ceph Cluster Formation Failure** (Prob=Medium, Impact=High):
- Risk: Ceph MONs/OSDs fail to form quorum or detect devices
- Mitigation: Pre-validate NVMe devices available; check Talos device paths; review operator logs
- Recovery: Delete CephCluster CR, fix device configuration, re-apply

**R2 — Storage Performance Below Baseline** (Prob=Low, Impact=Medium):
- Risk: Ceph IOPS/latency worse than expected
- Mitigation: Run fio benchmarks early; check network latency between nodes; verify SSD performance
- Recovery: Tune Ceph configuration (pg_num, OSD tuning); add more OSDs

**R3 — PVC Provisioning Failures** (Prob=Low, Impact=High):
- Risk: CSI driver fails to provision PVCs
- Mitigation: Verify Ceph cluster HEALTH_OK before testing; check CSI driver logs
- Recovery: Delete failed PVC; check Ceph pool status; restart CSI pods if needed

**Observability Risks**:

**R4 — Metrics Ingestion Failure** (Prob=Medium, Impact=Medium):
- Risk: VMAgent cannot scrape targets or forward to VMInsert
- Mitigation: Validate ServiceMonitors configured correctly; check network connectivity
- Recovery: Review VMAgent logs; verify service endpoints; check for scrape errors

**R5 — Logs Not Forwarding** (Prob=Medium, Impact=Medium):
- Risk: Fluent-bit cannot reach VictoriaLogs
- Mitigation: Verify VictoriaLogs HTTP endpoint reachable; check fluent-bit configuration
- Recovery: Review fluent-bit logs; test HTTP connectivity manually; check NetworkPolicy

**R6 — Cross-Cluster Observability Failure** (Prob=Low, Impact=Medium):
- Risk: Apps cluster metrics/logs not visible in infra
- Mitigation: Verify remote write URL correct; check ClusterMesh if used for connectivity
- Recovery: Review vmagent remote write logs; verify VMInsert endpoint; check firewall rules

## Definition of Done

**All Acceptance Criteria Met**:
- [ ] AC1: OpenEBS operational (infra + apps)
- [ ] AC2: Rook-Ceph operator operational (infra + apps)
- [ ] AC3: Rook-Ceph cluster operational (infra + apps)
- [ ] AC4: VictoriaMetrics stack operational (infra)
- [ ] AC5: VictoriaLogs operational (infra)
- [ ] AC6: Fluent-bit operational (infra)
- [ ] AC7: Apps collectors operational (apps → infra)
- [ ] AC8: Monitoring coverage validated
- [ ] AC9: Storage performance baselines established
- [ ] AC10: Integration testing passed
- [ ] AC11: Documentation & evidence complete

**QA Gate**:
- [ ] QA evidence artifacts collected and reviewed
- [ ] Risk assessment updated with deployment findings
- [ ] Test design execution complete (all P0 tests passing)
- [ ] QA gate decision: PASS (or waivers documented)

**PO Acceptance**:
- [ ] Storage functional for both OpenEBS and Rook-Ceph
- [ ] Ceph clusters HEALTH_OK on both infra and apps
- [ ] Observability stack collecting metrics and logs from all components
- [ ] Cross-cluster observability working (apps → infra)
- [ ] Performance baselines acceptable
- [ ] Ready for database deployment (Story 47)

**Handoff to Story 47**:
- [ ] Storage classes available for database PVCs
- [ ] Monitoring configured for database metrics collection
- [ ] Storage performance validated and acceptable

## Architect Handoff

**Architecture (docs/architecture.md)**:
- Validate storage architecture matches deployed Ceph topology
- Document Ceph pool configuration (replication, pg_num)
- Update observability architecture with retention and performance metrics
- Document cross-cluster observability flow (apps → infra)

**PRD (docs/prd.md)**:
- Confirm storage NFRs met (IOPS, latency, availability)
- Document observability SLOs (query performance, retention, ingestion rate)
- Note resource sizing for VictoriaMetrics and Ceph
- Document storage capacity planning

**Runbooks**:
- Create `docs/runbooks/ceph-operations.md` for Ceph management
- Create `docs/runbooks/observability-operations.md` for metrics/logs troubleshooting
- Document storage performance tuning procedures

## Change Log

| Date       | Version | Description                              | Author  |
|------------|---------|------------------------------------------|---------|
| 2025-10-26 | 0.1     | Initial validation story creation (draft)| Winston |
| 2025-10-26 | 1.0     | **v3.0 Refinement**: Storage & observability deployment/validation story. Added 14 tasks (T0-T14) covering storage (OpenEBS, Rook-Ceph) and observability (VM Stack, VLogs, collectors). Created 11 acceptance criteria with detailed validation. Added storage performance benchmarks, cross-cluster observability validation, QA artifacts. | Winston |

## Dev Agent Record

### Agent Model Used
<to be filled by dev>

### Debug Log References
<to be filled by dev>

### Completion Notes List
<to be filled by dev>

### File List
<to be filled by dev>

## QA Results — Risk Profile

**Reviewer**: Quinn (Test Architect & Quality Advisor)

**Summary**:
- Total Risks Identified: 6
- Critical: 0 | High: 2 | Medium: 4 | Low: 0
- Overall Story Risk Score: 52/100 (Medium)

**Top Risks**:
1. **R1 — Ceph Cluster Formation Failure** (High): MONs/OSDs fail to form quorum
2. **R3 — PVC Provisioning Failures** (High): CSI driver cannot provision volumes
3. **R4 — Metrics Ingestion Failure** (Medium): VMAgent cannot scrape targets
4. **R5 — Logs Not Forwarding** (Medium): Fluent-bit connectivity issues

**Mitigations**:
- All risks have documented mitigation and recovery procedures
- Pre-validation of hardware and configuration before deployment
- Phased deployment allows early failure detection

**Risk-Based Testing Focus**:
- Priority 1: Ceph cluster health, PVC provisioning, metrics ingestion
- Priority 2: Cross-cluster observability, logs forwarding
- Priority 3: Performance benchmarks, retention validation

**Artifacts**:
- Full assessment: `docs/qa/assessments/STORY-VALIDATE-STORAGE-OBSERVABILITY-risk-20251026.md` (to be created)

## QA Results — Test Design

**Designer**: Quinn (Test Architect)

**Test Strategy Overview**:
- **Emphasis**: Storage functionality and observability data quality
- **Approach**: Component deployment → functional testing → performance validation → integration
- **Coverage**: All 11 acceptance criteria mapped to test cases
- **Priority Distribution**: P0 (Ceph health, metrics ingestion), P1 (PVC tests, logs), P2 (performance, dashboards)

**Test Environments**:
- **Infra Cluster**: 3 control plane nodes with NVMe devices
- **Apps Cluster**: 3 control plane nodes with NVMe devices

**Test Phases**:

**Phase 1: Pre-Deployment Validation** (T0):
- Manifest build validation
- Hardware readiness (NVMe devices)
- Story 45 completion check

**Phase 2: Storage Deployment** (T1-T2):
- OpenEBS deployment (infra + apps)
- Rook-Ceph operator deployment (infra + apps)
- Rook-Ceph cluster deployment (infra + apps)

**Phase 3: Storage Functional Testing** (T3-T4):
- OpenEBS PVC provisioning and persistence
- Rook-Ceph PVC provisioning and persistence
- VolumeSnapshot creation and restoration

**Phase 4: Storage Performance Testing** (T5):
- Ceph IOPS benchmarks (random read/write)
- Latency measurements
- OpenEBS performance baseline

**Phase 5: Observability Deployment** (T6-T7):
- VictoriaMetrics stack (infra)
- VictoriaLogs (infra)
- Fluent-bit (infra)
- Apps collectors (apps → infra)

**Phase 6: Observability Validation** (T8-T10):
- Metrics queries (PromQL)
- Logs queries (LogQL)
- Cross-cluster observability
- Monitoring coverage audit

**Phase 7: Integration Testing** (T11-T12):
- ServiceMonitors/PrometheusRules validation
- Storage + observability integration
- Alert testing

**Phase 8: Performance & Evidence** (T13-T14):
- Retention validation
- Query performance
- Evidence collection

**Test Cases** (High-Level Summary):

**P0 Tests (Critical Path)** (~15 tests):
- Ceph cluster HEALTH_OK
- OpenEBS storage class available
- PVC provisioning successful
- VictoriaMetrics ingesting metrics
- VMAgent targets UP
- Fluent-bit forwarding logs

**P1 Tests (Core Functionality)** (~20 tests):
- VolumeSnapshot creation/restoration
- Cross-cluster metrics visible
- Cross-cluster logs visible
- Grafana datasource configured
- ServiceMonitors scraping
- PrometheusRules loaded

**P2 Tests (Performance & Integration)** (~10 tests):
- Storage performance baselines (IOPS, latency)
- Query performance (<1s)
- Retention validation (30d metrics, 14d logs)
- Alert firing test
- Integration test (StatefulSet with storage + monitoring)

**Total Test Cases**: ~45 tests

**Traceability** (Acceptance Criteria → Test Coverage):
- AC1 (OpenEBS) → T1-T4 tests
- AC2 (Rook operator) → T1-T2 tests
- AC3 (Rook cluster) → T1-T5 tests
- AC4 (VM Stack) → T6, T8 tests
- AC5 (VictoriaLogs) → T6, T9 tests
- AC6 (Fluent-bit) → T6, T9 tests
- AC7 (Apps collectors) → T7, T10 tests
- AC8 (Monitoring coverage) → T11 tests
- AC9 (Performance) → T5, T13 tests
- AC10 (Integration) → T12 tests
- AC11 (Documentation) → T14 tasks

**Go/No-Go Criteria**:
- **GO**: All P0 tests pass, Ceph HEALTH_OK, metrics/logs ingesting, P1 tests >90% pass
- **NO-GO**: Ceph cluster unhealthy, PVC provisioning broken, metrics not ingesting, critical risks not mitigated

**Artifacts**:
- Full test design: `docs/qa/assessments/STORY-VALIDATE-STORAGE-OBSERVABILITY-test-design-20251026.md` (to be created)
- Test execution results: `docs/qa/evidence/VALIDATE-STO-*.txt`, `docs/qa/evidence/VALIDATE-OBS-*.txt`

## *** End of Story ***
