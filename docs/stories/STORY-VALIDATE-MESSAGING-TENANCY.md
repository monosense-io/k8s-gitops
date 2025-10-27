# 49 — STORY-VALIDATE-MESSAGING-TENANCY — Deploy & Validate Messaging, Tenancy, and Final Components

Sequence: 49/50 | Prev: STORY-VALIDATE-APPS-CLUSTER.md | Next: STORY-BOOT-AUTOMATION-ALIGN.md
Sprint: 7 | Lane: Bootstrap & Platform
Global Sequence: 49/50

Status: Draft
Owner: Platform Engineering
Date: 2025-10-26
Links: docs/architecture.md; docs/SCHEDULE-V2-GREENFIELD.md

## Story

As a Platform Engineer, I want to deploy and validate the final platform components including messaging infrastructure (Kafka), backup systems (Volsync), and apps cluster observability collectors (stories 35-41), so that I can verify the complete platform is operational before the final reproducibility test and automation alignment.

## Why / Outcome

- Validates messaging infrastructure (Strimzi, Kafka, Schema Registry) for event-driven applications
- Confirms backup and restore systems (Volsync) are functional on apps cluster
- Establishes application observability collectors (Fluent Bit, vmagent) for apps cluster forwarding to infra
- Validates self-managing Flux GitOps infrastructure across both clusters
- Completes platform deployment before final reproducibility testing (Story 50)
- Provides comprehensive end-to-end integration testing across all platform layers

## Scope

Deploy and validate final platform components:

**Backup (Story 36)**:
- Volsync operator on apps cluster
- PVC backup/restore to S3 using Restic
- Scheduled backups and restore validation

**Messaging Infrastructure (Stories 37-39)**:
- Strimzi Kafka operator on apps cluster
- Kafka cluster (3-broker, persistent storage, TLS)
- Schema Registry for Avro/Protobuf schema management

**Apps Observability (Story 40)**:
- Fluent Bit collecting logs on apps cluster
- vmagent scraping apps cluster metrics
- Metrics/logs federation to infra cluster Victoria stack

**GitOps Self-Management (Story 41)**:
- Flux managing its own deployment via HelmRelease
- Multi-cluster Flux architecture (infra + apps)
- Image automation (if configured)

This story validates manifest stories 35-41:
35. STORY-TENANCY-BASELINE (skipped - no specific manifests, covered by namespace components)
36. STORY-BACKUP-VOLSYNC-APPS (Volsync on apps cluster)
37. STORY-MSG-STRIMZI-OPERATOR (Strimzi operator)
38. STORY-MSG-KAFKA-CLUSTER-APPS (Kafka cluster)
39. STORY-MSG-SCHEMA-REGISTRY (Schema Registry)
40. STORY-OBS-APPS-COLLECTORS (Fluent Bit, vmagent)
41. STORY-GITOPS-SELF-MGMT-FLUX (Flux self-management)

## Acceptance Criteria

### Prerequisites from Previous Stories
- Story 45: Networking validated (Cilium, Gateway API, BGP, ClusterMesh)
- Story 46: Storage and observability validated (Rook-Ceph, VictoriaMetrics, VictoriaLogs on infra)
- Story 47: Databases validated (CloudNative-PG, poolers, DragonflyDB)
- Story 48: CI/CD validated (GitLab, Harbor, GitHub ARC)

### AC1: Volsync Operator Deployment
**Objective**: Deploy Volsync operator on apps cluster for PVC backup/restore.

**Validation Steps**:
1. Volsync operator pod running in `volsync-system` namespace on apps cluster
2. Volsync CRDs installed: `ReplicationSource`, `ReplicationDestination`
3. Operator logs show no errors
4. Metrics endpoint accessible
5. S3 bucket configured and accessible for backups

**Success Criteria**:
- Operator pod in `Running` state
- All CRDs present: `kubectl get crd | grep volsync.backube`
- Operator logs clean (no errors in last 5 minutes)
- Prometheus metrics scraped successfully

**Evidence**: Operator pod status, CRD list, metrics endpoint response

---

### AC2: Volsync Backup Functionality
**Objective**: Validate PVC backup to S3 using Restic.

**Validation Steps**:
1. Create test PVC with known data (e.g., 1GB file with checksum)
2. Configure `ReplicationSource` with S3 destination
3. Trigger manual backup
4. Verify backup appears in S3 bucket
5. Check backup metadata (size, timestamp, retention policy)
6. Verify Volsync metrics show successful backup

**Success Criteria**:
- Backup completes successfully within 5 minutes
- S3 bucket contains backup snapshots
- File checksum matches original data
- Metrics show `volsync_replication_duration_seconds` < 300s
- No errors in ReplicationSource status

**Evidence**: ReplicationSource status, S3 bucket listing, backup metrics

---

### AC3: Volsync Restore Functionality
**Objective**: Validate restore from S3 backup to new PVC.

**Validation Steps**:
1. Create `ReplicationDestination` pointing to backup in S3
2. Trigger restore operation
3. Mount restored PVC to test pod
4. Verify data integrity (checksum matches original)
5. Compare file contents with original PVC
6. Test scheduled restore (if configured)

**Success Criteria**:
- Restore completes successfully within 10 minutes
- New PVC created with correct size
- Data integrity verified (checksums match)
- Restored PVC accessible and functional
- Metrics show `volsync_replication_duration_seconds` < 600s

**Evidence**: ReplicationDestination status, restored data verification, restore metrics

---

### AC4: Strimzi Kafka Operator Deployment
**Objective**: Deploy Strimzi operator on apps cluster.

**Validation Steps**:
1. Strimzi operator pod running in `kafka` namespace on apps cluster
2. Kafka CRDs installed: `Kafka`, `KafkaTopic`, `KafkaUser`
3. Operator logs show no errors
4. Operator watching Kafka resources
5. Metrics endpoint functional

**Success Criteria**:
- Operator pod in `Running` state
- All CRDs present: `kubectl get crd | grep kafka.strimzi.io`
- Operator logs clean (no errors in last 5 minutes)
- Operator reconciling Kafka resources
- Prometheus metrics scraped successfully

**Evidence**: Operator pod status, CRD list, operator logs, metrics

---

### AC5: Kafka Cluster Deployment
**Objective**: Deploy 3-broker Kafka cluster with persistent storage and TLS.

**Validation Steps**:
1. 3 Kafka broker pods running
2. ZooKeeper ensemble healthy (3 pods) OR KRaft mode configured
3. Kafka cluster status: `READY`
4. Persistent storage: 3 PVCs bound to Rook-Ceph storage class
5. TLS encryption enabled for client and inter-broker communication
6. Kafka metrics exported to Prometheus

**Success Criteria**:
- All Kafka broker pods in `Running` state
- ZooKeeper quorum healthy OR KRaft controller quorum healthy
- Kafka cluster status shows `Ready: True`
- PVCs bound and storage class `rook-ceph-block`
- TLS certificates present and valid
- Kafka metrics visible in Prometheus

**Evidence**: Kafka cluster status, pod status, PVC status, TLS certificate validation, metrics

---

### AC6: Kafka Basic Functionality
**Objective**: Validate Kafka cluster can produce and consume messages.

**Validation Steps**:
1. Create test topic: `test-topic` (replication factor 3, partitions 3)
2. Produce 1000 test messages to topic
3. Consume messages and verify count matches
4. Verify message ordering within partitions
5. Check Kafka broker logs for errors
6. Verify consumer group offsets

**Success Criteria**:
- Test topic created successfully
- All 1000 messages produced without errors
- All 1000 messages consumed successfully
- Message ordering preserved within partitions
- No errors in broker logs
- Consumer group offsets tracking correctly

**Evidence**: Topic status, producer output, consumer output, Kafka logs

---

### AC7: Kafka High Availability and Performance
**Objective**: Validate Kafka replication and performance baselines.

**Validation Steps**:
1. Verify replication factor 3 for test topic
2. Simulate broker failure (delete pod)
3. Verify messages still accessible (failover successful)
4. Run performance test: producer throughput
5. Run performance test: consumer throughput
6. Measure end-to-end latency (p50, p95, p99)

**Success Criteria**:
- Replication factor 3 confirmed for all partitions
- Data survives single broker failure
- Producer throughput: >10,000 messages/sec
- Consumer throughput: >15,000 messages/sec
- p95 latency: <50ms, p99 latency: <100ms
- Kafka cluster recovers automatically after broker restart

**Evidence**: Replication status, failover test results, performance benchmark results

---

### AC8: Schema Registry Deployment
**Objective**: Deploy Schema Registry connected to Kafka cluster.

**Validation Steps**:
1. Schema Registry pod running in `kafka` namespace
2. Connected to Kafka cluster for schema storage
3. REST API accessible on port 8081
4. Schema Registry metrics exported
5. Health check endpoint returning 200 OK

**Success Criteria**:
- Schema Registry pod in `Running` state
- Successfully connected to Kafka cluster
- REST API responding: `curl http://schema-registry:8081/subjects`
- Metrics endpoint functional
- Health check passing

**Evidence**: Pod status, REST API response, metrics, health check

---

### AC9: Schema Registry Functionality
**Objective**: Validate schema registration and evolution.

**Validation Steps**:
1. Register test Avro schema via REST API
2. Retrieve schema and verify structure
3. Register schema v2 with additional field (backward compatible)
4. Verify compatibility mode enforcement (BACKWARD)
5. Attempt incompatible schema change (should fail)
6. Test Protobuf schema registration

**Success Criteria**:
- Schema v1 registered successfully
- Schema retrieved matches registered schema
- Schema v2 accepted (backward compatible)
- Incompatible schema rejected
- Protobuf schema supported
- Schema versions tracked correctly

**Evidence**: Schema registration output, compatibility test results, schema version list

---

### AC10: Apps Cluster Observability Collectors
**Objective**: Deploy Fluent Bit and vmagent on apps cluster, forwarding to infra.

**Validation Steps**:
1. Fluent Bit DaemonSet running on all apps cluster nodes
2. vmagent StatefulSet running on apps cluster
3. Fluent Bit forwarding logs to infra VictoriaLogs
4. vmagent forwarding metrics to infra VictoriaMetrics
5. External label `cluster=apps` applied to all metrics
6. Apps cluster logs visible in Grafana (infra cluster)
7. Apps cluster metrics visible in Grafana (infra cluster)

**Success Criteria**:
- Fluent Bit pods running on all nodes (DaemonSet)
- vmagent pods running (StatefulSet)
- Logs appearing in infra VictoriaLogs with `cluster=apps` label
- Metrics appearing in infra VictoriaMetrics with `cluster=apps` label
- Grafana dashboards showing apps cluster data
- No errors in Fluent Bit or vmagent logs

**Evidence**: DaemonSet/StatefulSet status, log query results, metric query results, Grafana screenshots

---

### AC11: Flux Self-Management
**Objective**: Validate Flux managing its own deployment across both clusters.

**Validation Steps**:
1. Flux managing itself via HelmRelease `flux-instance` in `flux-system` namespace
2. Flux components: source-controller, kustomize-controller, helm-controller, notification-controller
3. Flux auto-updating from OCI repository (if configured)
4. Multi-cluster reconciliation: infra and apps clusters
5. Image automation: ImagePolicy and ImageUpdateAutomation (if configured)
6. Flux metrics and alerts operational

**Success Criteria**:
- HelmRelease `flux-instance` exists and status `Ready: True`
- All Flux components running on both clusters
- Flux reconciling from git repository (no drift)
- Multi-cluster kustomizations reconciling successfully
- Image automation functional (if configured)
- Flux metrics visible in Prometheus

**Evidence**: HelmRelease status, Flux component status, reconciliation logs, metrics

---

### AC12: End-to-End Integration Testing
**Objective**: Validate complete platform integration with event-driven application.

**Validation Steps**:
1. Deploy test event-driven application (producer + consumer)
2. Producer writes messages to Kafka with Schema Registry validation
3. Consumer reads messages from Kafka with Schema Registry validation
4. Verify message schema validation enforced
5. Test Volsync backup of application PVC
6. Restore application PVC and verify data integrity
7. Verify applications use CI/CD pipeline (GitLab → Harbor → K8s)
8. Verify applications connect to shared PostgreSQL via poolers
9. Trigger Flux reconciliation across all clusters

**Success Criteria**:
- Event-driven application deployed successfully
- Messages produced and consumed with schema validation
- Schema Registry rejecting invalid messages
- Volsync backup and restore successful
- CI/CD pipeline functional (GitLab build → Harbor push → K8s deploy)
- Database connectivity via poolers working
- Flux reconciliation successful across all clusters
- No errors in application logs

**Evidence**: Application logs, message flow verification, backup/restore results, CI/CD pipeline output, Flux reconciliation logs

---

### AC13: Monitoring and Performance Baselines
**Objective**: Establish monitoring and performance baselines for messaging and final components.

**Validation Steps**:
1. Kafka metrics visible in Grafana: broker throughput, replication lag, consumer lag
2. Schema Registry metrics visible: schema count, request rate, latency
3. Volsync metrics visible: backup duration, restore duration, success rate
4. Apps cluster observability metrics: log volume, metric cardinality
5. Flux metrics visible: reconciliation duration, success rate, drift detection
6. Alerts configured and firing for critical conditions
7. Performance baselines documented

**Success Criteria**:
- All component metrics visible in Grafana
- Dashboards created for Kafka, Schema Registry, Volsync, Flux
- Alerts configured with appropriate thresholds
- Performance baselines documented:
  - Kafka: >10K msg/sec, p95 latency <50ms
  - Schema Registry: response time <100ms
  - Volsync: backup duration <5min, restore <10min
  - Flux: reconciliation <2min
- No critical alerts firing

**Evidence**: Grafana dashboard screenshots, alert configurations, performance baseline documentation

## Tasks / Subtasks

### T0 — Pre-Deployment Validation (NO CLUSTER CHANGES)
**Objective**: Validate all manifests locally before deploying to clusters.

**Steps**:
1. Verify all manifests committed for stories 35-41
2. Run `flux build` for each component (Volsync, Strimzi, Kafka, Schema Registry, observability, Flux)
3. Validate with `kubeconform`
4. Verify S3 bucket configured for Volsync
5. Verify prerequisite stories completed (45-48)

**Success Criteria**:
- All manifests committed to git
- `flux build` succeeds for all components
- `kubeconform` validation passes
- S3 bucket configuration present
- Prerequisites validated

---

### T1 — Deploy Volsync Operator
**Objective**: Deploy Volsync operator on apps cluster.

**Steps**:
1. Reconcile Volsync kustomization
2. Monitor operator deployment
3. Verify CRDs installed
4. Check operator logs
5. Verify metrics endpoint

**Success Criteria** (AC1):
- Operator pod running in `volsync-system` namespace
- CRDs installed
- No errors in operator logs
- Metrics endpoint responding

---

### T2 — Volsync Backup Testing
**Objective**: Test PVC backup to S3 using Restic.

**Steps**:
1. Create test PVC with known data
2. Configure ReplicationSource
3. Trigger manual backup
4. Monitor backup progress
5. Verify backup in S3 (check metrics)

**Success Criteria** (AC2):
- Backup completes within 5 minutes
- No errors in ReplicationSource status
- Backup metrics visible in Prometheus

---

### T3 — Volsync Restore Testing
**Objective**: Test restore from S3 backup to new PVC.

**Steps**:
1. Create ReplicationDestination
2. Monitor restore progress
3. Mount restored PVC and verify data
4. Query restore metrics

**Success Criteria** (AC3):
- Restore completes within 10 minutes
- Restored PVC created and accessible
- Data checksums match original
- Restore metrics visible

---

### T4 — Deploy Strimzi Kafka Operator
**Objective**: Deploy Strimzi operator on apps cluster.

**Steps**:
1. Reconcile Strimzi kustomization
2. Monitor operator deployment
3. Verify CRDs installed
4. Check operator logs
5. Verify operator watching Kafka resources

**Success Criteria** (AC4):
- Operator pod running in `kafka` namespace
- All Kafka CRDs installed
- Operator logs clean (no errors)
- Metrics endpoint responding

---

### T5 — Deploy Kafka Cluster
**Objective**: Deploy 3-broker Kafka cluster with persistent storage and TLS.

**Steps**:
1. Reconcile Kafka cluster kustomization
2. Monitor Kafka cluster deployment (5-10 minutes)
3. Check Kafka cluster status
4. Verify persistent storage
5. Verify TLS certificates
6. Check Kafka broker logs

**Success Criteria** (AC5):
- 3 Kafka broker pods running
- ZooKeeper quorum healthy OR KRaft mode
- Kafka cluster status: `Ready: True`
- PVCs bound to `rook-ceph-block` storage class
- TLS certificates present

---

### T6 — Kafka Basic Functionality Testing
**Objective**: Validate Kafka cluster can produce and consume messages.

**Steps**:
1. Create test topic (replication factor 3, partitions 3)
2. Wait for topic creation
3. Produce test messages
4. Consume test messages
5. Verify consumer group offsets

**Success Criteria** (AC6):
- Test topic created successfully
- Messages produced without errors
- Messages consumed successfully
- Consumer group offsets tracking correctly

---

### T7 — Kafka High Availability and Performance Testing
**Objective**: Validate Kafka replication and performance baselines.

**Steps**:
1. Verify replication factor 3
2. Simulate broker failure
3. Run producer performance test (target: >10K msg/sec)
4. Run consumer performance test (target: >15K msg/sec)
5. Measure latency (p95 <50ms, p99 <100ms)

**Success Criteria** (AC7):
- Replication factor 3 confirmed
- Data survives broker failure
- Producer throughput >10,000 msg/sec
- Consumer throughput >15,000 msg/sec
- p95 latency <50ms

---

### T8 — Deploy Schema Registry
**Objective**: Deploy Schema Registry connected to Kafka cluster.

**Steps**:
1. Reconcile Schema Registry kustomization
2. Monitor Schema Registry deployment
3. Verify connection to Kafka
4. Test REST API
5. Check health endpoint

**Success Criteria** (AC8):
- Schema Registry pod running
- Successfully connected to Kafka
- REST API responding
- Health check passing

---

### T9 — Schema Registry Functionality Testing
**Objective**: Validate schema registration and evolution.

**Steps**:
1. Register test Avro schema v1
2. Retrieve schema and verify structure
3. Register schema v2 (backward compatible)
4. Test incompatible schema change (should fail)
5. Test Protobuf schema
6. Check compatibility mode

**Success Criteria** (AC9):
- Schema v1 registered successfully
- Schema v2 accepted (backward compatible)
- Incompatible schema rejected
- Protobuf schema supported
- Compatibility mode enforced

---

### T10 — Deploy Apps Cluster Observability Collectors
**Objective**: Deploy Fluent Bit and vmagent on apps cluster.

**Steps**:
1. Reconcile Fluent Bit kustomization
2. Monitor Fluent Bit DaemonSet
3. Reconcile vmagent kustomization
4. Monitor vmagent StatefulSet
5. Verify Fluent Bit forwarding logs
6. Verify vmagent remote write

**Success Criteria** (AC10):
- Fluent Bit pods running on all nodes
- vmagent pods running
- Logs forwarding to infra VictoriaLogs
- Metrics forwarding to infra VictoriaMetrics

---

### T11 — Validate Apps Cluster Observability
**Objective**: Verify apps cluster metrics and logs visible in infra Grafana.

**Steps**:
1. Query apps cluster metrics from infra VictoriaMetrics
2. Query apps cluster logs from infra VictoriaLogs
3. Verify Grafana dashboards
4. Verify apps cluster metrics cardinality

**Success Criteria** (AC10):
- Apps cluster metrics visible with `cluster=apps` label
- Apps cluster logs visible with `cluster=apps` label
- Grafana dashboards showing apps cluster data
- No errors in collector logs

---

### T12 — Validate Flux Self-Management
**Objective**: Verify Flux managing its own deployment across both clusters.

**Steps**:
1. Check Flux HelmRelease on both clusters
2. Verify Flux components running
3. Check Flux reconciliation status
4. Test Flux self-update (optional)
5. Verify image automation (if configured)
6. Check Flux metrics

**Success Criteria** (AC11):
- Flux managing itself via HelmRelease
- All Flux components running on both clusters
- Kustomizations reconciling successfully
- Flux metrics visible

---

### T13 — End-to-End Integration Testing
**Objective**: Validate complete platform integration with event-driven application.

**Steps**:
1. Deploy test event-driven application (producer + consumer)
2. Verify message flow with schema validation
3. Test Schema Registry validation enforcement
4. Test Volsync backup of application PVC
5. Test CI/CD pipeline (GitLab → Harbor → K8s)
6. Test database connectivity via poolers
7. Trigger Flux reconciliation across all clusters

**Success Criteria** (AC12):
- Event-driven application deployed
- Messages flow through Kafka with schema validation
- Schema Registry rejecting invalid messages
- Volsync backup successful
- CI/CD pipeline functional
- Database connectivity working
- Flux reconciliation successful

---

### T14 — Monitoring and Performance Validation
**Objective**: Establish monitoring and performance baselines.

**Steps**:
1. Verify Kafka metrics in Grafana
2. Verify Schema Registry metrics
3. Verify Volsync metrics
4. Verify apps cluster observability metrics
5. Verify Flux metrics
6. Configure alerts
7. Document performance baselines

**Success Criteria** (AC13):
- All component metrics visible in Grafana
- Dashboards created
- Alerts configured
- Performance baselines documented
- No critical alerts firing

---

### T15 — Documentation and Evidence Collection
**Objective**: Document deployment and collect evidence for validation.

**Steps**:
1. Capture deployment status (Volsync, Kafka, Schema Registry, observability, Flux)
2. Capture Grafana screenshots (dashboards for all components)
3. Export performance metrics
4. Document configuration
5. Create validation report

**Success Criteria**:
- All deployment status captured
- Grafana screenshots collected
- Performance metrics exported
- Configuration documented
- Validation report created


## Dev Notes

### Kafka Cluster Deployment
**Deployment Time**: 5-10 minutes for Kafka cluster (ZooKeeper + Kafka brokers)

**Critical Configuration**:
- Kafka brokers: 3 replicas for HA
- ZooKeeper ensemble: 3 replicas (or KRaft mode)
- Persistent storage: Rook-Ceph block storage
- TLS encryption: Enabled for client and inter-broker communication
- Replication factor: 3 for topics

**Common Issues**:
- **Slow startup**: Kafka pods can take 5-10 minutes to become ready
- **TLS certificate issues**: Verify cluster CA and clients CA certificates
- **Storage performance**: Ensure NVMe storage for low latency
- **ZooKeeper connectivity**: Check ZooKeeper ensemble health before deploying Kafka

### Volsync Backup/Restore
**Backup Strategy**: Restic-based backups to S3 with snapshot copy method

**Critical Configuration**:
- S3 bucket: Pre-configured in external secrets
- Retention policy: hourly (24), daily (7), weekly (4)
- Copy method: Snapshot (for point-in-time consistency)
- Backup schedule: Configurable (default: every 30 minutes)

**Common Issues**:
- **S3 credentials**: Verify external secret for Restic repository
- **Snapshot class**: Ensure VolumeSnapshotClass configured for Rook-Ceph
- **Backup duration**: Large PVCs may take longer than 5 minutes
- **Restore timing**: Wait for snapshot controller to provision PVC

### Schema Registry
**Compatibility Modes**: BACKWARD (default), FORWARD, FULL, NONE

**Critical Configuration**:
- Kafka connection: Uses Kafka cluster for schema storage
- REST API: Port 8081
- Supported formats: Avro, Protobuf, JSON Schema

**Common Issues**:
- **Kafka connectivity**: Verify Schema Registry can connect to Kafka bootstrap
- **Compatibility enforcement**: Test incompatible schemas to verify mode
- **Schema storage**: Schemas stored in internal Kafka topic `_schemas`

### Apps Cluster Observability
**Federation Model**: Apps cluster collectors forward to infra cluster aggregation

**Critical Configuration**:
- Fluent Bit: DaemonSet forwarding logs to infra VictoriaLogs
- vmagent: StatefulSet forwarding metrics to infra VictoriaMetrics
- External labels: `cluster=apps` for multi-cluster differentiation
- Remote write: Configured for infra cluster endpoints

**Common Issues**:
- **Network connectivity**: Verify apps cluster can reach infra cluster services
- **Label conflicts**: Ensure `cluster` label doesn't conflict with existing labels
- **Cardinality**: Monitor metric cardinality to avoid overwhelming infra cluster
- **Log volume**: Monitor log ingestion rate

### Flux Self-Management
**Architecture**: Flux manages itself via HelmRelease

**Critical Configuration**:
- HelmRelease: `flux-instance` in `flux-system` namespace
- OCI repository: Flux Helm chart from official registry
- Multi-cluster: Separate Flux instances on infra and apps clusters
- Image automation: Optional, requires ImagePolicy and ImageUpdateAutomation

**Common Issues**:
- **Circular dependency**: Flux must be bootstrapped before self-management
- **Version updates**: Test self-update on non-production cluster first
- **Reconciliation**: Flux may temporarily show drift during self-update
- **Image automation**: Requires write access to git repository

## Validation Steps

### Pre-Deployment Validation Checklist
- [ ] All manifests committed for stories 35-41
- [ ] `flux build` passes for all components
- [ ] `kubeconform` validation passes
- [ ] S3 bucket configured for Volsync
- [ ] Prerequisites validated (Stories 45-48 completed)

### Component Validation Checklist

**Volsync**:
- [ ] Operator pod running in `volsync-system` namespace
- [ ] CRDs installed: ReplicationSource, ReplicationDestination
- [ ] Test backup completes within 5 minutes
- [ ] Test restore completes within 10 minutes
- [ ] Data integrity verified (checksums match)

**Strimzi & Kafka**:
- [ ] Strimzi operator running in `kafka` namespace
- [ ] 3 Kafka broker pods running
- [ ] ZooKeeper ensemble healthy (3 pods) OR KRaft mode
- [ ] Kafka cluster status: `Ready: True`
- [ ] PVCs bound to `rook-ceph-block` storage
- [ ] TLS certificates present and valid

**Kafka Functionality**:
- [ ] Test topic created (replication factor 3, partitions 3)
- [ ] Messages produced successfully (1000+ messages)
- [ ] Messages consumed successfully
- [ ] Replication validated (data survives broker failure)
- [ ] Producer throughput >10,000 msg/sec
- [ ] Consumer throughput >15,000 msg/sec
- [ ] p95 latency <50ms

**Schema Registry**:
- [ ] Schema Registry pod running
- [ ] Connected to Kafka cluster
- [ ] REST API responding on port 8081
- [ ] Test schema registered (Avro)
- [ ] Schema evolution validated (backward compatible)
- [ ] Incompatible schema rejected
- [ ] Protobuf schema supported

**Apps Observability**:
- [ ] Fluent Bit pods running on all nodes (DaemonSet)
- [ ] vmagent pods running (StatefulSet)
- [ ] Logs forwarding to infra VictoriaLogs
- [ ] Metrics forwarding to infra VictoriaMetrics
- [ ] Apps cluster metrics visible with `cluster=apps` label
- [ ] Apps cluster logs visible with `cluster=apps` label
- [ ] Grafana dashboards showing apps cluster data

**Flux Self-Management**:
- [ ] HelmRelease `flux-instance` exists on both clusters
- [ ] All Flux components running (source, kustomize, helm, notification controllers)
- [ ] Flux reconciling from git repository (no drift)
- [ ] Multi-cluster kustomizations reconciling successfully
- [ ] Image automation functional (if configured)
- [ ] Flux metrics visible in Prometheus

**Integration Testing**:
- [ ] Event-driven application deployed
- [ ] Messages flow through Kafka with schema validation
- [ ] Schema Registry rejecting invalid messages
- [ ] Volsync backup of application PVC successful
- [ ] CI/CD pipeline functional (GitLab → Harbor → K8s)
- [ ] Database connectivity via poolers working
- [ ] Flux reconciliation successful across all clusters

### Performance Baseline Validation
- [ ] Kafka producer throughput: >10,000 msg/sec
- [ ] Kafka consumer throughput: >15,000 msg/sec
- [ ] Kafka p95 latency: <50ms
- [ ] Schema Registry p95 latency: <100ms
- [ ] Volsync backup duration: <5 minutes
- [ ] Volsync restore duration: <10 minutes
- [ ] Flux reconciliation duration: <2 minutes
- [ ] All metrics visible in Grafana
- [ ] Alerts configured and not firing

## Rollback Procedures

### Rollback Strategy
In case of critical issues during deployment, follow these rollback procedures in order:

### R1 — Rollback Flux Self-Management
**Scenario**: Flux self-management causing issues

**Steps**:
1. Suspend Flux HelmRelease:
   ```bash
   flux suspend helmrelease flux-instance -n flux-system
   ```

2. Revert git commit introducing self-management:
   ```bash
   git revert <commit-hash>
   git push origin main
   ```

3. Manually reconcile:
   ```bash
   flux reconcile kustomization flux-system --with-source
   ```

4. Resume HelmRelease after revert:
   ```bash
   flux resume helmrelease flux-instance -n flux-system
   ```

**Recovery Time**: 5-10 minutes

---

### R2 — Rollback Apps Observability Collectors
**Scenario**: Apps cluster observability causing issues (high cardinality, log volume)

**Steps**:
1. Suspend kustomizations:
   ```bash
   flux suspend kustomization fluent-bit-apps
   flux suspend kustomization vmagent-apps
   ```

2. Delete collectors:
   ```bash
   kubectl --context=apps -n observability delete daemonset fluent-bit
   kubectl --context=apps -n observability delete statefulset vmagent
   ```

3. Revert git commit:
   ```bash
   git revert <commit-hash>
   git push origin main
   ```

4. Verify infra cluster observability still functional

**Recovery Time**: 5 minutes

---

### R3 — Rollback Schema Registry
**Scenario**: Schema Registry causing issues or incompatible with Kafka

**Steps**:
1. Suspend kustomization:
   ```bash
   flux suspend kustomization schema-registry
   ```

2. Delete Schema Registry:
   ```bash
   kubectl --context=apps -n kafka delete deployment schema-registry
   kubectl --context=apps -n kafka delete service schema-registry
   ```

3. Revert git commit:
   ```bash
   git revert <commit-hash>
   git push origin main
   ```

4. Verify Kafka cluster still operational

**Recovery Time**: 5 minutes

---

### R4 — Rollback Kafka Cluster
**Scenario**: Kafka cluster causing critical issues

**Steps**:
1. Suspend kustomization:
   ```bash
   flux suspend kustomization kafka-cluster
   ```

2. Delete Kafka cluster (WARNING: Data loss):
   ```bash
   kubectl --context=apps -n kafka delete kafka kafka-cluster
   ```

3. Wait for pods to terminate (5-10 minutes)

4. Delete PVCs (if needed):
   ```bash
   kubectl --context=apps -n kafka delete pvc -l app.kubernetes.io/name=kafka
   kubectl --context=apps -n kafka delete pvc -l app.kubernetes.io/name=zookeeper
   ```

5. Revert git commit:
   ```bash
   git revert <commit-hash>
   git push origin main
   ```

**Recovery Time**: 15-20 minutes
**Data Loss**: YES (all Kafka messages and topics lost)

---

### R5 — Rollback Strimzi Operator
**Scenario**: Strimzi operator causing issues (incompatible version, CRD issues)

**Steps**:
1. Suspend kustomization:
   ```bash
   flux suspend kustomization strimzi-operator
   ```

2. Delete Kafka cluster first (if exists):
   ```bash
   kubectl --context=apps -n kafka delete kafka kafka-cluster
   ```

3. Delete Strimzi operator:
   ```bash
   kubectl --context=apps -n kafka delete deployment strimzi-cluster-operator
   ```

4. Revert git commit:
   ```bash
   git revert <commit-hash>
   git push origin main
   ```

5. Consider manual CRD cleanup if CRDs changed:
   ```bash
   kubectl --context=apps get crd | grep kafka.strimzi.io
   # Manually delete CRDs if needed (WARNING: Data loss)
   ```

**Recovery Time**: 10-15 minutes
**Data Loss**: YES (if CRDs deleted)

---

### R6 — Rollback Volsync
**Scenario**: Volsync causing issues (backup failures, S3 access issues)

**Steps**:
1. Suspend kustomization:
   ```bash
   flux suspend kustomization volsync-apps
   ```

2. Delete test ReplicationSource/Destination:
   ```bash
   kubectl --context=apps delete replicationsource test-volsync-backup
   kubectl --context=apps delete replicationdestination test-volsync-restore
   ```

3. Delete Volsync operator:
   ```bash
   kubectl --context=apps -n volsync-system delete deployment volsync
   ```

4. Revert git commit:
   ```bash
   git revert <commit-hash>
   git push origin main
   ```

**Recovery Time**: 5-10 minutes
**Data Loss**: NO (backups in S3 preserved)

---

### Emergency Rollback (Complete Story)
**Scenario**: Multiple critical failures, need to rollback entire story

**Steps**:
1. Suspend all kustomizations:
   ```bash
   flux suspend kustomization volsync-apps
   flux suspend kustomization strimzi-operator
   flux suspend kustomization kafka-cluster
   flux suspend kustomization schema-registry
   flux suspend kustomization fluent-bit-apps
   flux suspend kustomization vmagent-apps
   flux suspend helmrelease flux-instance -n flux-system
   ```

2. Delete all resources (in reverse order of dependencies):
   ```bash
   # Schema Registry
   kubectl --context=apps -n kafka delete deployment schema-registry

   # Kafka cluster
   kubectl --context=apps -n kafka delete kafka kafka-cluster

   # Strimzi operator
   kubectl --context=apps -n kafka delete deployment strimzi-cluster-operator

   # Apps observability
   kubectl --context=apps -n observability delete daemonset fluent-bit
   kubectl --context=apps -n observability delete statefulset vmagent

   # Volsync
   kubectl --context=apps -n volsync-system delete deployment volsync
   ```

3. Revert all commits:
   ```bash
   git revert <commit-range>
   git push origin main
   ```

4. Resume kustomizations after revert:
   ```bash
   flux resume kustomization --all
   flux resume helmrelease flux-instance -n flux-system
   ```

**Recovery Time**: 30-45 minutes
**Data Loss**: YES (Kafka messages, topics)

## Risks and Mitigations

### Risk 1: Kafka Cluster Deployment Failure
**Severity**: HIGH | **Likelihood**: MEDIUM | **Impact**: HIGH

**Description**: Kafka cluster fails to deploy due to resource constraints, storage issues, or ZooKeeper problems.

**Indicators**:
- Kafka pods stuck in `Pending` or `CrashLoopBackOff`
- ZooKeeper quorum not forming
- Insufficient storage for Kafka PVCs
- TLS certificate issues

**Mitigation**:
- Pre-validate storage availability (Rook-Ceph HEALTH_OK)
- Monitor pod events: `kubectl --context=apps -n kafka get events`
- Increase timeout for Kafka startup (5-10 minutes)
- Check ZooKeeper logs first before investigating Kafka
- Verify TLS certificates generated correctly
- Use rollback procedure R4 if deployment fails

**Prevention**:
- Validate storage performance in Story 46
- Test ZooKeeper deployment independently
- Pre-generate TLS certificates if issues persist
- Monitor resource utilization during deployment

---

### Risk 2: Schema Registry Incompatibility with Kafka
**Severity**: MEDIUM | **Likelihood**: LOW | **Impact**: MEDIUM

**Description**: Schema Registry version incompatible with Kafka version, causing connection failures.

**Indicators**:
- Schema Registry pod logs show connection errors to Kafka
- REST API not responding
- Schema registration failing

**Mitigation**:
- Verify Schema Registry version compatibility with Kafka 3.6.0
- Check Kafka bootstrap service accessible from Schema Registry pod
- Verify TLS certificates if TLS enabled
- Use rollback procedure R3 if incompatible

**Prevention**:
- Test Schema Registry version against Kafka version in pre-deployment validation
- Use official Strimzi-recommended Schema Registry images
- Document tested version combinations

---

### Risk 3: Volsync Backup Failures
**Severity**: HIGH | **Likelihood**: MEDIUM | **Impact**: HIGH

**Description**: Volsync backups fail due to S3 access issues, credential problems, or snapshot failures.

**Indicators**:
- ReplicationSource status shows errors
- Backups not appearing in S3 bucket
- Snapshot creation failing
- Restic repository errors

**Mitigation**:
- Verify S3 bucket accessible and credentials valid
- Check VolumeSnapshotClass configured for Rook-Ceph
- Verify snapshot controller running
- Monitor backup metrics: `volsync_replication_duration_seconds`
- Use rollback procedure R6 if persistent failures

**Prevention**:
- Pre-validate S3 bucket access in T0
- Test VolumeSnapshotClass functionality before Volsync
- Document S3 bucket configuration requirements
- Set up alerts for backup failures

---

### Risk 4: Apps Cluster Observability Overload
**Severity**: MEDIUM | **Likelihood**: MEDIUM | **Impact**: MEDIUM

**Description**: Apps cluster collectors overwhelm infra cluster with high log volume or metric cardinality.

**Indicators**:
- Infra VictoriaMetrics high memory usage
- Infra VictoriaLogs high disk usage
- Query latency increase in Grafana
- Remote write errors in vmagent logs

**Mitigation**:
- Monitor infra cluster resource utilization
- Adjust log/metric sampling if needed
- Increase retention settings if disk space low
- Use rollback procedure R2 if overload occurs

**Prevention**:
- Estimate log/metric volume before deployment
- Configure log filtering in Fluent Bit
- Set metric relabeling rules in vmagent
- Monitor cardinality: `curl infra-vm:8428/api/v1/status/tsdb`

---

### Risk 5: Flux Self-Management Circular Dependency
**Severity**: HIGH | **Likelihood**: LOW | **Impact**: HIGH

**Description**: Flux self-management misconfiguration causes Flux to become unable to reconcile itself.

**Indicators**:
- HelmRelease `flux-instance` stuck in failed state
- Flux components not updating
- Reconciliation errors in Flux logs
- Git source not accessible

**Mitigation**:
- Monitor Flux HelmRelease status closely after enabling self-management
- Keep manual bootstrap procedure available
- Test self-update on non-production cluster first
- Use rollback procedure R1 if issues occur

**Prevention**:
- Validate Flux HelmRelease manifest before committing
- Ensure Flux source-controller can access OCI repository
- Document manual Flux re-bootstrap procedure
- Set up alerts for Flux reconciliation failures

---

### Risk 6: Kafka Performance Below Baseline
**Severity**: MEDIUM | **Likelihood**: MEDIUM | **Impact**: MEDIUM

**Description**: Kafka performance does not meet baseline targets (throughput, latency).

**Indicators**:
- Producer throughput <10,000 msg/sec
- Consumer throughput <15,000 msg/sec
- p95 latency >50ms
- High disk I/O wait

**Mitigation**:
- Check storage performance (use fio benchmark)
- Verify Kafka broker resource limits not too restrictive
- Adjust Kafka configuration (batch size, linger.ms, compression)
- Monitor Kafka metrics: `kafka_server_brokertopicmetrics_messagesinpersec`

**Prevention**:
- Validate storage performance in Story 46
- Use NVMe storage for Kafka PVCs
- Tune Kafka configuration based on workload
- Document expected performance baselines

---

### Risk 7: Event-Driven Application Integration Failures
**Severity**: MEDIUM | **Likelihood**: MEDIUM | **Impact**: MEDIUM

**Description**: Test event-driven application fails to integrate with Kafka and Schema Registry.

**Indicators**:
- Application cannot connect to Kafka bootstrap
- Schema validation errors
- Message production/consumption failures
- Authentication errors (TLS)

**Mitigation**:
- Verify application Kafka client configuration
- Check TLS certificates accessible to application
- Verify Schema Registry URL accessible
- Test Kafka connectivity from application pod

**Prevention**:
- Document Kafka connection patterns for applications
- Provide example application manifests
- Test TLS configuration separately
- Create troubleshooting guide for common issues

---

### Risk 8: Multi-Cluster Flux Drift
**Severity**: MEDIUM | **Likelihood**: LOW | **Impact**: MEDIUM

**Description**: Infra and apps clusters drift apart in Flux configuration, causing reconciliation issues.

**Indicators**:
- Flux reconciliation failures on one cluster
- Configuration differences between clusters
- Git source not syncing on one cluster

**Mitigation**:
- Monitor Flux reconciliation status on both clusters
- Verify git source accessible from both clusters
- Check cluster-specific substitutions in cluster-settings
- Use rollback procedure R1 if drift causes issues

**Prevention**:
- Validate multi-cluster Flux configuration in T0
- Document cluster-specific configuration patterns
- Set up alerts for Flux drift detection
- Test configuration changes on both clusters

---

### Risk Summary
**Total Risks**: 8
- **HIGH Severity**: 3 (Kafka deployment, Volsync backup, Flux self-management)
- **MEDIUM Severity**: 5 (Schema Registry, observability overload, performance, integration, drift)

**Overall Story Risk Score**: 64/100 (MEDIUM-HIGH)

**Risk Mitigation Priority**:
1. Kafka cluster deployment (validate storage, ZooKeeper first)
2. Volsync backup functionality (validate S3 access, snapshot controller)
3. Flux self-management (test on non-prod first, keep bootstrap available)
4. Apps observability overload (monitor infra cluster resources)
5. Kafka performance (validate storage performance, tune configuration)

## Definition of Done

**Deployment Complete**:
- [ ] All acceptance criteria (AC1-AC13) validated
- [ ] All tasks (T0-T15) completed successfully
- [ ] All validation checklists signed off

**Functional Requirements Met**:
- [ ] Volsync operator deployed and functional on apps cluster
- [ ] Kafka cluster (3 brokers) deployed and operational
- [ ] Strimzi operator managing Kafka resources
- [ ] Schema Registry connected to Kafka and functional
- [ ] Apps cluster observability collectors forwarding to infra
- [ ] Flux self-managing deployment across both clusters

**Performance Baselines Established**:
- [ ] Kafka producer throughput: >10,000 msg/sec
- [ ] Kafka consumer throughput: >15,000 msg/sec
- [ ] Kafka p95 latency: <50ms
- [ ] Schema Registry p95 latency: <100ms
- [ ] Volsync backup duration: <5 minutes
- [ ] Volsync restore duration: <10 minutes
- [ ] Flux reconciliation duration: <2 minutes

**Integration Testing Passed**:
- [ ] Event-driven application deployed and functional
- [ ] Messages flowing through Kafka with schema validation
- [ ] Schema Registry enforcing schema compatibility
- [ ] Volsync backup and restore successful with data integrity
- [ ] CI/CD pipeline functional (GitLab → Harbor → K8s)
- [ ] Database connectivity via poolers validated
- [ ] Multi-cluster Flux reconciliation successful

**Monitoring and Observability**:
- [ ] All component metrics visible in Grafana
- [ ] Dashboards created for Kafka, Schema Registry, Volsync, Flux
- [ ] Alerts configured with appropriate thresholds
- [ ] Apps cluster metrics/logs visible in infra Grafana with `cluster=apps` label
- [ ] No critical alerts firing

**Documentation and Evidence**:
- [ ] Deployment status captured for all components
- [ ] Grafana dashboard screenshots collected
- [ ] Performance metrics exported and documented
- [ ] Configuration documented
- [ ] Validation report created
- [ ] Rollback procedures documented and understood
- [ ] Risks documented with mitigations

**Quality Assurance**:
- [ ] QA risk assessment completed
- [ ] QA test design reviewed and executed
- [ ] All high-severity risks mitigated
- [ ] Dev notes updated with lessons learned

**Ready for Story 50**:
- [ ] Complete platform deployment validated
- [ ] All platform layers functional (networking, storage, observability, databases, CI/CD, messaging)
- [ ] Ready for reproducibility testing and automation alignment

## Architect Handoff

**Architecture (docs/architecture.md)**:
- Validate messaging architecture matches deployment (Kafka, Schema Registry, event-driven patterns)
- Update observability federation architecture (apps cluster → infra cluster forwarding)
- Document Flux self-management architecture across multiple clusters
- Validate backup and restore architecture (Volsync with S3)

**PRD (docs/prd.md)**:
- Confirm messaging NFRs met:
  - Throughput: >10K msg/sec producer, >15K msg/sec consumer
  - Latency: p95 <50ms end-to-end
  - Availability: 3-broker cluster with replication factor 3
- Document backup SLOs:
  - RPO: 30 minutes (backup interval)
  - RTO: <10 minutes (restore duration)
- Note multi-cluster observability federation performance (log/metric volume, cardinality)
- Document Flux reconciliation performance (duration, success rate)

**Platform Readiness**:
- Confirm complete platform stack operational for Story 50 (reproducibility testing)
- Validate all Stories 1-49 manifests deployed and functional
- Document any deviations from original architecture or requirements

## Change Log
| Date       | Version | Description                                      | Author  |
|------------|---------|--------------------------------------------------|---------|
| 2025-10-26 | 0.1     | Initial validation story creation                | Winston |
| 2025-10-26 | 1.0     | v3.0 refinement with 13 ACs, 16 tasks, 8 risks  | Claude  |

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

Reviewer: Quinn (Test Architect & Quality Advisor)

Summary
- Total Risks Identified: TBD
- Critical: TBD | High: TBD | Medium: TBD | Low: TBD
- Overall Story Risk Score: TBD/100

<QA risk assessment to be completed>

## QA Results — Test Design

Designer: Quinn (Test Architect)

Test Strategy Overview
- Emphasis on event-driven architecture and data durability
- Priorities: P0 on Kafka cluster health and message delivery; P1 on Volsync backup/restore; P2 on observability federation

<QA test design to be completed>
