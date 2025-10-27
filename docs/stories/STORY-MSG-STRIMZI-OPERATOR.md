# 37 — STORY-MSG-STRIMZI-OPERATOR — Create Strimzi Kafka Operator Manifests (apps)

Sequence: 37/50 | Prev: STORY-BACKUP-VOLSYNC-APPS.md | Next: STORY-MSG-KAFKA-CLUSTER-APPS.md
Sprint: 6 | Lane: Messaging
Global Sequence: 37/50

**Status**: v3.0 (Manifests-First)
Owner: Platform Engineering
Date: 2025-10-26
Links: docs/architecture.md §19 (Workloads & Versions); kubernetes/workloads/platform/messaging/strimzi-operator

## Story

Create complete Strimzi Kafka Operator manifests for the apps cluster to enable declarative management of Apache Kafka clusters, topics, users, and connectors via Kubernetes CRDs. Deploy operator version 0.48.0 with KRaft mode support, providing a robust GitOps-managed messaging platform for application workloads. All manifests will be validated locally before committing to git; runtime deployment and validation will occur in Story 45.

## Scope

**This Story (37 - Manifest Creation)**:
- Create Strimzi operator HelmRelease (version 0.48.0) for apps cluster
- Create operator namespace (`strimzi-operator-system`) with Pod Security Standards
- Create messaging namespace for Kafka workloads
- Create ServiceMonitor and PrometheusRule for operator monitoring
- Create Helm repository for Strimzi charts
- Create Flux Kustomization entrypoint with dependency chain
- Document operator architecture, CRD usage, and operational procedures
- Validate all manifests with local tools (flux build, kustomize build, yamllint)
- **NO cluster deployment or testing** (all deployment happens in Story 45)

**Story 45 (Deployment & Validation)**:
- Apply manifests to apps cluster
- Verify operator deployment and CRD installation
- Verify RBAC permissions for cross-namespace management
- Deploy test Kafka cluster (KRaft mode, ephemeral storage) for smoke test
- Validate operator reconciliation and resource cleanup
- Verify metrics scrape and PrometheusRule alerts

## Acceptance Criteria

**AC1**: `kubernetes/workloads/platform/messaging/strimzi-operator/` contains HelmRelease, namespace manifests, ServiceMonitor, and PrometheusRule.

**AC2**: `kubernetes/workloads/platform/messaging/strimzi-operator/helmrelease.yaml` deploys Strimzi operator v0.48.0 via Helm chart with:
- Namespace watch configuration (`messaging` namespace)
- Resource limits (CPU: 200m/1000m, Memory: 256Mi/512Mi)
- NetworkPolicy generation enabled
- Log level: INFO
- Liveness and readiness probes configured

**AC3**: `kubernetes/workloads/platform/messaging/strimzi-operator/namespace.yaml` creates `strimzi-operator-system` namespace with Pod Security Standards (baseline enforcement).

**AC4**: `kubernetes/workloads/platform/messaging/namespace.yaml` creates `messaging` namespace for Kafka clusters with Pod Security Standards (baseline enforcement).

**AC5**: `kubernetes/workloads/platform/messaging/strimzi-operator/servicemonitor.yaml` defines Prometheus scraping for operator metrics.

**AC6**: `kubernetes/workloads/platform/messaging/strimzi-operator/prometheusrule.yaml` defines alerts for:
- Operator pod unavailability
- Reconciliation failures
- CRD validation errors
- Resource creation delays

**AC7**: `kubernetes/infrastructure/repositories/helm/strimzi.yaml` adds Strimzi Helm repository (`https://strimzi.io/charts/`).

**AC8**: `kubernetes/clusters/apps/messaging.yaml` creates Flux Kustomization with dependency on infrastructure Kustomizations and health checks for operator deployment.

**AC9**: All manifests pass local validation:
- `flux build kustomization cluster-apps-messaging-strimzi-operator --path ./kubernetes/workloads/platform/messaging/strimzi-operator` succeeds
- `kustomize build kubernetes/workloads/platform/messaging/strimzi-operator/` renders without errors
- `yamllint kubernetes/workloads/platform/messaging/strimzi-operator/` passes
- No secrets or credentials hardcoded in git

**AC10**: Documentation includes:
- Strimzi operator architecture (Cluster Operator, Topic Operator, User Operator)
- CRD reference (Kafka, KafkaTopic, KafkaUser, KafkaConnect, etc.)
- KRaft mode configuration (no ZooKeeper)
- Operational runbook (view logs, restart operator, upgrade, troubleshooting)
- Test Kafka cluster manifest for smoke testing

**AC11**: All manifests committed to git with commit message describing changes.

## Dependencies

**Local Tools Required**:
- `flux` CLI (v2.4.0+) - Build and validate Flux Kustomizations
- `kustomize` (v5.0+) - Build and validate Kustomize overlays
- `yamllint` (v1.35+) - YAML syntax validation
- `yq` (v4.44+) - YAML manipulation and validation
- `git` - Commit manifests to repository
- `helm` (optional) - Template validation for HelmReleases

**External Dependencies** (for Story 45):
- Apps cluster bootstrapped with Flux operational
- Storage classes available (`rook-ceph-block`, `openebs-local-nvme`)
- Victoria Metrics operator for ServiceMonitor

## Tasks / Subtasks

### T1: Prerequisites and Strategy

**T1.1**: Review Strimzi architecture and Kafka deployment patterns
- Study Strimzi operator components (Cluster Operator, Topic Operator, User Operator)
- Review KRaft mode vs ZooKeeper mode
- Understand CRD lifecycle (Kafka → StatefulSet, KafkaTopic → Kafka topics)

**T1.2**: Review cluster-settings for messaging configuration
- File: `kubernetes/clusters/apps/cluster-settings.yaml`
- Identify substitution variables for operator configuration

**T1.3**: Create directory structure
```bash
mkdir -p kubernetes/workloads/platform/messaging/{strimzi-operator,namespace}
```

### T2: Operator Namespace and RBAC

**T2.1**: Create `kubernetes/workloads/platform/messaging/strimzi-operator/namespace.yaml`
```yaml
---
apiVersion: v1
kind: Namespace
metadata:
  name: strimzi-operator-system
  labels:
    app.kubernetes.io/name: strimzi-operator
    app.kubernetes.io/component: operator
    app.kubernetes.io/managed-by: flux
    pod-security.kubernetes.io/enforce: baseline
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

**T2.2**: Create `kubernetes/workloads/platform/messaging/namespace.yaml`
```yaml
---
apiVersion: v1
kind: Namespace
metadata:
  name: messaging
  labels:
    app.kubernetes.io/name: messaging
    app.kubernetes.io/component: kafka
    app.kubernetes.io/managed-by: flux
    pod-security.kubernetes.io/enforce: baseline
    pod-security.kubernetes.io/audit: baseline
    pod-security.kubernetes.io/warn: baseline
```

### T3: Strimzi Operator HelmRelease

**T3.1**: Create `kubernetes/workloads/platform/messaging/strimzi-operator/helmrelease.yaml`
```yaml
---
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: strimzi-kafka-operator
  namespace: strimzi-operator-system
spec:
  interval: 30m
  timeout: 15m
  chart:
    spec:
      chart: strimzi-kafka-operator
      version: 0.48.0
      sourceRef:
        kind: HelmRepository
        name: strimzi
        namespace: flux-system
      interval: 30m
  install:
    crds: CreateReplace
    remediation:
      retries: 3
  upgrade:
    crds: CreateReplace
    cleanupOnFail: true
    remediation:
      retries: 3
      strategy: rollback
  values:
    # Operator configuration
    watchAnyNamespace: false
    watchNamespaces:
      - messaging

    # Image configuration
    image:
      registry: quay.io
      repository: strimzi/operator
      tag: 0.48.0

    # Log level
    logLevel: INFO

    # Resource limits
    resources:
      limits:
        cpu: 1000m
        memory: 512Mi
      requests:
        cpu: 200m
        memory: 256Mi

    # Probes
    livenessProbe:
      initialDelaySeconds: 10
      periodSeconds: 30
      timeoutSeconds: 5
      failureThreshold: 3

    readinessProbe:
      initialDelaySeconds: 10
      periodSeconds: 30
      timeoutSeconds: 5
      failureThreshold: 3

    # Security context
    securityContext:
      runAsNonRoot: true
      runAsUser: 1001
      fsGroup: 1001
      seccompProfile:
        type: RuntimeDefault

    # Generate NetworkPolicy for operator
    generateNetworkPolicy: true

    # Feature gates (enable KRaft support)
    featureGates: +UseKRaft,+KafkaNodePools

    # Operator labels
    labels:
      app.kubernetes.io/name: strimzi-operator
      app.kubernetes.io/component: cluster-operator

    # Tolerations for control plane nodes (optional)
    tolerations: []

    # Affinity for distribution (optional)
    affinity: {}

    # Kafka default configuration (used for new Kafka clusters)
    kafkaDefaultConfig:
      # Default Kafka version
      version: 3.9.0
      # Default log retention
      log.retention.hours: 168  # 7 days
      # Default replication factor
      default.replication.factor: 3
      min.insync.replicas: 2
      # Enable auto-create topics (can be overridden per cluster)
      auto.create.topics.enable: false

    # Topic Operator configuration (embedded in Cluster Operator)
    topicOperator:
      reconciliationIntervalSeconds: 90
      # Zookeeper session timeout (not used in KRaft mode)
      # zookeeperSessionTimeoutSeconds: 18

    # User Operator configuration (embedded in Cluster Operator)
    userOperator:
      reconciliationIntervalSeconds: 120

    # Metrics configuration
    metrics:
      enabled: true

    # Create PodMonitor for operator metrics
    createGlobalResources: true
```

### T4: ServiceMonitor for Metrics

**T4.1**: Create `kubernetes/workloads/platform/messaging/strimzi-operator/servicemonitor.yaml`
```yaml
---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: strimzi-cluster-operator
  namespace: strimzi-operator-system
  labels:
    app.kubernetes.io/name: strimzi-operator
    app.kubernetes.io/component: cluster-operator
    prometheus: platform
spec:
  selector:
    matchLabels:
      name: strimzi-cluster-operator
  endpoints:
    - port: http
      interval: 30s
      path: /metrics
      scheme: http
  namespaceSelector:
    matchNames:
      - strimzi-operator-system
```

### T5: PrometheusRule for Alerts

**T5.1**: Create `kubernetes/workloads/platform/messaging/strimzi-operator/prometheusrule.yaml`
```yaml
---
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: strimzi-operator
  namespace: strimzi-operator-system
  labels:
    prometheus: platform
    role: alert-rules
spec:
  groups:
    - name: strimzi-operator.rules
      interval: 1m
      rules:
        # Operator availability
        - alert: StrimziOperatorDown
          expr: |
            up{job="strimzi-cluster-operator"} == 0
          for: 5m
          labels:
            severity: critical
            category: messaging
          annotations:
            summary: "Strimzi Kafka operator is down"
            description: "Strimzi operator has been unavailable for 5 minutes. Kafka cluster reconciliation is halted."
            runbook: "Check operator pod: kubectl -n strimzi-operator-system get pods -l name=strimzi-cluster-operator"

        # Operator pod not ready
        - alert: StrimziOperatorPodNotReady
          expr: |
            kube_pod_status_ready{namespace="strimzi-operator-system",pod=~"strimzi-cluster-operator-.*",condition="true"} == 0
          for: 5m
          labels:
            severity: high
            category: messaging
          annotations:
            summary: "Strimzi operator pod not ready"
            description: "Strimzi operator pod {{ $labels.pod }} has been not ready for 5 minutes."
            runbook: "Check pod status: kubectl -n strimzi-operator-system describe pod {{ $labels.pod }}"

        # Reconciliation failures
        - alert: StrimziReconciliationFailures
          expr: |
            rate(strimzi_reconciliations_failed_total[5m]) > 0
          for: 10m
          labels:
            severity: high
            category: messaging
          annotations:
            summary: "Strimzi reconciliation failures detected"
            description: "Strimzi operator is experiencing reconciliation failures for {{ $labels.kind }}/{{ $labels.name }} in namespace {{ $labels.namespace }}."
            runbook: "Check operator logs: kubectl -n strimzi-operator-system logs -l name=strimzi-cluster-operator --tail=100"

        # High reconciliation duration
        - alert: StrimziReconciliationSlow
          expr: |
            histogram_quantile(0.99, rate(strimzi_reconciliations_duration_seconds_bucket[5m])) > 300
          for: 15m
          labels:
            severity: warning
            category: messaging
          annotations:
            summary: "Strimzi reconciliation taking longer than expected"
            description: "P99 reconciliation duration for {{ $labels.kind }} is over 5 minutes."
            runbook: "Investigate resource constraints or Kafka cluster issues"

        # Operator resource usage
        - alert: StrimziOperatorHighMemory
          expr: |
            container_memory_usage_bytes{namespace="strimzi-operator-system",pod=~"strimzi-cluster-operator-.*"} / container_spec_memory_limit_bytes{namespace="strimzi-operator-system",pod=~"strimzi-cluster-operator-.*"} > 0.9
          for: 15m
          labels:
            severity: warning
            category: messaging
          annotations:
            summary: "Strimzi operator memory usage high"
            description: "Strimzi operator memory usage is above 90% of limit."
            runbook: "Consider increasing memory limits in HelmRelease"

        # CRD validation errors (if metric available)
        - alert: StrimziCRDValidationErrors
          expr: |
            increase(strimzi_reconciliations_validation_errors_total[10m]) > 0
          for: 5m
          labels:
            severity: high
            category: messaging
          annotations:
            summary: "Strimzi CRD validation errors"
            description: "Strimzi operator detected CRD validation errors for {{ $labels.kind }} in namespace {{ $labels.namespace }}."
            runbook: "Check CR definition: kubectl -n {{ $labels.namespace }} get {{ $labels.kind }} -o yaml"

        # Resource creation delays
        - alert: StrimziResourceCreationDelayed
          expr: |
            strimzi_resources{kind="Kafka"} > 0 and strimzi_resources_ready{kind="Kafka"} / strimzi_resources{kind="Kafka"} < 0.8
          for: 15m
          labels:
            severity: warning
            category: messaging
          annotations:
            summary: "Strimzi Kafka resource creation delayed"
            description: "Less than 80% of Kafka clusters are in Ready state for 15 minutes."
            runbook: "Check Kafka cluster status: kubectl -n messaging get kafka"

        # Operator restart loops
        - alert: StrimziOperatorRestartLoop
          expr: |
            rate(kube_pod_container_status_restarts_total{namespace="strimzi-operator-system",pod=~"strimzi-cluster-operator-.*"}[15m]) > 0.1
          for: 5m
          labels:
            severity: high
            category: messaging
          annotations:
            summary: "Strimzi operator in restart loop"
            description: "Strimzi operator pod {{ $labels.pod }} is restarting frequently."
            runbook: "Check pod logs: kubectl -n strimzi-operator-system logs {{ $labels.pod }} --previous"
```

### T6: Helm Repository

**T6.1**: Create `kubernetes/infrastructure/repositories/helm/strimzi.yaml`
```yaml
---
apiVersion: source.toolkit.fluxcd.io/v1
kind: HelmRepository
metadata:
  name: strimzi
  namespace: flux-system
spec:
  interval: 1h
  url: https://strimzi.io/charts/
  timeout: 5m
```

**T6.2**: Update `kubernetes/infrastructure/repositories/helm/kustomization.yaml` to include Strimzi repo
```yaml
---
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: flux-system
resources:
  # ... existing repos ...
  - strimzi.yaml
```

### T7: Kustomization Files

**T7.1**: Create `kubernetes/workloads/platform/messaging/strimzi-operator/kustomization.yaml`
```yaml
---
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: strimzi-operator-system
resources:
  - namespace.yaml
  - helmrelease.yaml
  - servicemonitor.yaml
  - prometheusrule.yaml

labels:
  - pairs:
      app.kubernetes.io/name: strimzi-operator
      app.kubernetes.io/component: cluster-operator
      app.kubernetes.io/managed-by: flux
```

**T7.2**: Create `kubernetes/workloads/platform/messaging/kustomization.yaml`
```yaml
---
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - namespace.yaml
  - strimzi-operator/kustomization.yaml
```

### T8: Cluster Kustomization Entrypoint

**T8.1**: Create `kubernetes/clusters/apps/messaging.yaml` (Flux Kustomization entrypoint)
```yaml
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: cluster-apps-messaging-strimzi-operator
  namespace: flux-system
spec:
  interval: 10m
  path: ./kubernetes/workloads/platform/messaging/strimzi-operator
  prune: true
  sourceRef:
    kind: GitRepository
    name: flux-system
  wait: true
  timeout: 10m
  dependsOn:
    - name: cluster-apps-infrastructure-repositories
    - name: cluster-apps-observability-victoria-metrics
  postBuild:
    substitute:
      KAFKA_VERSION: "3.9.0"
      STRIMZI_VERSION: "0.48.0"
    substituteFrom:
      - kind: ConfigMap
        name: cluster-settings
  healthChecks:
    - apiVersion: apps/v1
      kind: Deployment
      name: strimzi-cluster-operator
      namespace: strimzi-operator-system
```

### T9: Documentation

**T9.1**: Create `docs/runbooks/strimzi-operator.md`
```markdown
# Strimzi Kafka Operator Runbook

## Overview

Strimzi provides a Kubernetes-native way to run Apache Kafka on Kubernetes. The Strimzi operator manages Kafka clusters, topics, users, and connectors using custom resource definitions (CRDs).

## Architecture

### Operator Components

**Cluster Operator**:
- Manages Kafka, KafkaConnect, KafkaMirrorMaker2, KafkaBridge CRs
- Creates and manages StatefulSets, Services, ConfigMaps for Kafka brokers
- Handles rolling updates and configuration changes
- Monitors Kafka cluster health

**Topic Operator** (embedded or standalone):
- Manages KafkaTopic CRs
- Synchronizes Kubernetes CRs with Kafka topics
- Handles topic creation, configuration changes, deletion

**User Operator** (embedded or standalone):
- Manages KafkaUser CRs
- Creates and manages Kafka users and ACLs
- Generates and manages user credentials (SCRAM-SHA, TLS)

### KRaft Mode vs ZooKeeper Mode

**KRaft Mode** (Kafka Raft - preferred):
- No ZooKeeper dependency (ZooKeeper is deprecated)
- Simplified architecture (fewer components)
- Better performance (lower latency, higher throughput)
- Uses `KafkaNodePool` CR for node management
- Requires Kafka 3.3+ (using 3.9.0)

**ZooKeeper Mode** (legacy):
- Requires separate ZooKeeper ensemble
- More complex architecture
- Will be removed in Kafka 4.0

## Custom Resource Definitions (CRDs)

### Kafka CR

Defines a Kafka cluster with brokers and optional ZooKeeper ensemble (or KRaft controllers).

**Example (KRaft mode)**:
```yaml
apiVersion: kafka.strimzi.io/v1beta2
kind: Kafka
metadata:
  name: my-cluster
  namespace: messaging
  annotations:
    strimzi.io/kraft: "enabled"
    strimzi.io/node-pools: "enabled"
spec:
  kafka:
    version: 3.9.0
    # replicas moved to KafkaNodePool
    listeners:
      - name: plain
        port: 9092
        type: internal
        tls: false
      - name: tls
        port: 9093
        type: internal
        tls: true
    config:
      offsets.topic.replication.factor: 3
      transaction.state.log.replication.factor: 3
      transaction.state.log.min.isr: 2
      default.replication.factor: 3
      min.insync.replicas: 2
      inter.broker.protocol.version: "3.9"
    # storage moved to KafkaNodePool
  # No zookeeper section - using KRaft!
  entityOperator:
    topicOperator: {}
    userOperator: {}
```

**KafkaNodePool CR** (KRaft mode):
```yaml
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaNodePool
metadata:
  name: broker-pool
  namespace: messaging
  labels:
    strimzi.io/cluster: my-cluster
spec:
  replicas: 3
  roles:
    - controller  # KRaft controller
    - broker      # Kafka broker
  storage:
    type: persistent-claim
    size: 100Gi
    class: rook-ceph-block
    deleteClaim: false
  resources:
    requests:
      cpu: 1000m
      memory: 2Gi
    limits:
      cpu: 2000m
      memory: 4Gi
```

### KafkaTopic CR

Defines a Kafka topic with partitions, replication, and configuration.

```yaml
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaTopic
metadata:
  name: my-topic
  namespace: messaging
  labels:
    strimzi.io/cluster: my-cluster
spec:
  partitions: 12
  replicas: 3
  config:
    retention.ms: 604800000  # 7 days
    segment.bytes: 1073741824  # 1GB
    compression.type: lz4
    min.insync.replicas: 2
```

### KafkaUser CR

Defines a Kafka user with authentication and authorization.

```yaml
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaUser
metadata:
  name: my-app
  namespace: messaging
  labels:
    strimzi.io/cluster: my-cluster
spec:
  authentication:
    type: scram-sha-512
  authorization:
    type: simple
    acls:
      # Producer ACLs
      - resource:
          type: topic
          name: my-topic
          patternType: literal
        operations:
          - Write
          - Create
          - Describe
      # Consumer ACLs
      - resource:
          type: topic
          name: my-topic
          patternType: literal
        operations:
          - Read
          - Describe
      - resource:
          type: group
          name: my-app-group
          patternType: literal
        operations:
          - Read
```

## Operations

### View Operator Logs

```bash
# Cluster Operator logs
kubectl -n strimzi-operator-system logs -l name=strimzi-cluster-operator -f

# Topic Operator logs (embedded in Entity Operator)
kubectl -n messaging logs <kafka-cluster>-entity-operator -c topic-operator -f

# User Operator logs (embedded in Entity Operator)
kubectl -n messaging logs <kafka-cluster>-entity-operator -c user-operator -f
```

### Restart Operator

```bash
# Restart Cluster Operator
kubectl -n strimzi-operator-system rollout restart deployment strimzi-cluster-operator

# Restart Entity Operator (Topic + User Operators)
kubectl -n messaging rollout restart deployment <kafka-cluster>-entity-operator
```

### Check Operator Status

```bash
# Operator deployment
kubectl -n strimzi-operator-system get deploy strimzi-cluster-operator

# Operator pod
kubectl -n strimzi-operator-system get pods -l name=strimzi-cluster-operator

# Operator version
kubectl -n strimzi-operator-system get deploy strimzi-cluster-operator -o jsonpath='{.spec.template.spec.containers[0].image}'
```

### Check CRDs

```bash
# List all Strimzi CRDs
kubectl get crds | grep strimzi

# Check specific CRD version
kubectl get crd kafkas.kafka.strimzi.io -o jsonpath='{.spec.versions[*].name}'

# View CRD schema
kubectl explain kafka.spec
kubectl explain kafkatopic.spec
kubectl explain kafkauser.spec
```

### Upgrade Operator

1. **Update HelmRelease version**:
   ```bash
   # Edit HelmRelease
   vim kubernetes/workloads/platform/messaging/strimzi-operator/helmrelease.yaml

   # Change version: 0.48.0 → 0.49.0
   spec:
     chart:
       spec:
         version: 0.49.0
   ```

2. **Commit and push**:
   ```bash
   git add kubernetes/workloads/platform/messaging/strimzi-operator/helmrelease.yaml
   git commit -m "chore(messaging): upgrade Strimzi operator to v0.49.0"
   git push origin main
   ```

3. **Reconcile Flux**:
   ```bash
   flux reconcile kustomization cluster-apps-messaging-strimzi-operator --with-source
   ```

4. **Verify upgrade**:
   ```bash
   kubectl -n strimzi-operator-system get deploy strimzi-cluster-operator -o jsonpath='{.spec.template.spec.containers[0].image}'
   kubectl -n strimzi-operator-system get pods -l name=strimzi-cluster-operator
   ```

5. **Check operator logs**:
   ```bash
   kubectl -n strimzi-operator-system logs -l name=strimzi-cluster-operator --tail=100
   ```

## Monitoring

### Metrics

**Operator Metrics**:
- `strimzi_reconciliations_total` - Total reconciliations
- `strimzi_reconciliations_failed_total` - Failed reconciliations
- `strimzi_reconciliations_duration_seconds` - Reconciliation duration
- `strimzi_resources` - Total Kafka resources managed
- `strimzi_resources_ready` - Kafka resources in Ready state

**Query Examples**:
```promql
# Reconciliation rate
rate(strimzi_reconciliations_total[5m])

# Failure rate
rate(strimzi_reconciliations_failed_total[5m])

# P99 reconciliation duration
histogram_quantile(0.99, rate(strimzi_reconciliations_duration_seconds_bucket[5m]))

# Resource readiness
strimzi_resources_ready / strimzi_resources
```

### Alerts

See `kubernetes/workloads/platform/messaging/strimzi-operator/prometheusrule.yaml` for full alert definitions:

- **StrimziOperatorDown**: Operator unavailable for 5 minutes (Critical)
- **StrimziOperatorPodNotReady**: Operator pod not ready for 5 minutes (High)
- **StrimziReconciliationFailures**: Reconciliation failures for 10 minutes (High)
- **StrimziReconciliationSlow**: P99 duration > 5 minutes (Warning)
- **StrimziOperatorHighMemory**: Memory usage > 90% (Warning)
- **StrimziCRDValidationErrors**: CRD validation errors (High)
- **StrimziResourceCreationDelayed**: < 80% resources ready for 15 minutes (Warning)
- **StrimziOperatorRestartLoop**: Frequent restarts (High)

## Troubleshooting

### Operator Pod Crash Loop

**Symptoms**: Operator pod repeatedly crashing

**Diagnosis**:
```bash
# Check pod status
kubectl -n strimzi-operator-system get pods

# View logs from previous container
kubectl -n strimzi-operator-system logs -l name=strimzi-cluster-operator --previous

# Check events
kubectl -n strimzi-operator-system get events --sort-by='.lastTimestamp'
```

**Common Causes**:
- Insufficient memory (OOMKilled)
- RBAC permission errors
- Invalid configuration (check HelmRelease values)
- CRD version mismatch

### Reconciliation Failures

**Symptoms**: Kafka CR not reaching Ready state

**Diagnosis**:
```bash
# Check Kafka CR status
kubectl -n messaging get kafka <cluster-name> -o yaml

# Check operator logs for specific cluster
kubectl -n strimzi-operator-system logs -l name=strimzi-cluster-operator | grep <cluster-name>

# Check events for Kafka cluster
kubectl -n messaging get events --field-selector involvedObject.name=<cluster-name>
```

**Common Causes**:
- Storage class not found
- Insufficient cluster resources (CPU, memory, storage)
- Invalid Kafka configuration
- Network policy blocking communication

### Topic Not Created

**Symptoms**: KafkaTopic CR exists but topic not created in Kafka

**Diagnosis**:
```bash
# Check KafkaTopic CR status
kubectl -n messaging get kafkatopic <topic-name> -o yaml

# Check Topic Operator logs
kubectl -n messaging logs <kafka-cluster>-entity-operator -c topic-operator

# Verify topic in Kafka (exec into broker pod)
kubectl -n messaging exec -it <kafka-cluster>-broker-0 -c kafka -- bin/kafka-topics.sh --bootstrap-server localhost:9092 --list
```

**Common Causes**:
- Topic Operator not running
- Topic name violates Kafka naming constraints
- Replication factor > number of brokers
- Topic Operator cannot connect to Kafka

### User Credentials Not Generated

**Symptoms**: KafkaUser CR exists but Secret not created

**Diagnosis**:
```bash
# Check KafkaUser CR status
kubectl -n messaging get kafkauser <user-name> -o yaml

# Check User Operator logs
kubectl -n messaging logs <kafka-cluster>-entity-operator -c user-operator

# Check for Secret
kubectl -n messaging get secret <user-name>
```

**Common Causes**:
- User Operator not running
- Invalid authentication type
- User Operator cannot connect to Kafka
- RBAC permission errors (User Operator needs Secret create permissions)

### CRD Version Mismatch

**Symptoms**: Operator logs show unknown fields or validation errors

**Diagnosis**:
```bash
# Check CRD version
kubectl get crd kafkas.kafka.strimzi.io -o jsonpath='{.spec.versions[*].name}'

# Check operator version
kubectl -n strimzi-operator-system get deploy strimzi-cluster-operator -o jsonpath='{.spec.template.spec.containers[0].image}'

# Check for deprecated API versions in existing CRs
kubectl get kafka -A -o yaml | grep "apiVersion:"
```

**Resolution**:
- Upgrade operator to match CRD version
- Or downgrade CRDs to match operator version (not recommended)
- Run API migration tool if available

### Operator Not Watching Namespace

**Symptoms**: Kafka CRs in namespace not reconciled

**Diagnosis**:
```bash
# Check operator watch configuration
kubectl -n strimzi-operator-system get deploy strimzi-cluster-operator -o yaml | grep -A5 "STRIMZI_NAMESPACE"

# Check if namespace is labeled correctly
kubectl get ns messaging -o yaml
```

**Resolution**:
- Add namespace to `watchNamespaces` in HelmRelease
- Or enable `watchAnyNamespace: true` for cluster-wide watch
- Restart operator after configuration change

## Reference

### Component Versions
- **Strimzi Operator**: 0.48.0
- **Kafka**: 3.9.0 (default)
- **Java**: 21 (default in Kafka 3.9.0)

### Resource Requirements

**Cluster Operator**:
- CPU: 200m request, 1000m limit
- Memory: 256Mi request, 512Mi limit

**Topic Operator** (per Kafka cluster):
- CPU: 100m request, 500m limit
- Memory: 128Mi request, 256Mi limit

**User Operator** (per Kafka cluster):
- CPU: 100m request, 500m limit
- Memory: 128Mi request, 256Mi limit

### Storage Requirements
- **CRD storage**: Minimal (etcd)
- **Operator logs**: Ephemeral (container filesystem)
- **Kafka storage**: Defined per KafkaNodePool (e.g., 100Gi per broker)

### Network Requirements
- Operator → Kubernetes API (443)
- Operator → Kafka brokers (9092/9093)
- Topic/User Operator → Kafka brokers (9092/9093)

### Security
- **Pod Security Standards**: Baseline enforcement
- **RBAC**: ClusterRole for cross-namespace management
- **Network Policies**: Generated by operator (if enabled)
- **Container Security**: Non-root user (uid 1001), seccomp profile

### Limitations
- **Single operator per cluster**: One Strimzi operator manages all Kafka clusters
- **Namespace watch**: Operator watches specific namespaces (not cluster-wide by default)
- **CRD versioning**: Operator and CRDs must be compatible versions
- **KRaft migration**: Migrating from ZooKeeper to KRaft requires careful planning
```

**T9.2**: Create test Kafka manifest for smoke testing
Create `docs/examples/test-kafka-kraft.yaml`:
```yaml
---
# Test Kafka cluster using KRaft mode (no ZooKeeper)
# Minimal configuration for smoke testing operator functionality
# DO NOT USE IN PRODUCTION - ephemeral storage will lose data on pod restart

apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaNodePool
metadata:
  name: test-pool
  namespace: messaging
  labels:
    strimzi.io/cluster: test-kafka
spec:
  # Single replica for testing
  replicas: 1

  # Combined controller+broker role (simplified for testing)
  roles:
    - controller
    - broker

  # Ephemeral storage (data lost on pod restart)
  storage:
    type: ephemeral

  # Minimal resources for testing
  resources:
    requests:
      cpu: 250m
      memory: 512Mi
    limits:
      cpu: 500m
      memory: 1Gi

---
apiVersion: kafka.strimzi.io/v1beta2
kind: Kafka
metadata:
  name: test-kafka
  namespace: messaging
  annotations:
    strimzi.io/kraft: "enabled"
    strimzi.io/node-pools: "enabled"
spec:
  kafka:
    # Kafka version
    version: 3.9.0

    # Replicas managed by KafkaNodePool
    # replicas: N/A

    # Listeners (plain and TLS)
    listeners:
      - name: plain
        port: 9092
        type: internal
        tls: false
      - name: tls
        port: 9093
        type: internal
        tls: true

    # Kafka configuration (single replica mode)
    config:
      # Replication factors (single replica)
      offsets.topic.replication.factor: 1
      transaction.state.log.replication.factor: 1
      transaction.state.log.min.isr: 1
      default.replication.factor: 1
      min.insync.replicas: 1

      # Protocol version
      inter.broker.protocol.version: "3.9"

      # Disable auto-create topics
      auto.create.topics.enable: false

      # Log retention (1 hour for testing)
      log.retention.hours: 1
      log.retention.bytes: 1073741824  # 1GB

    # Storage managed by KafkaNodePool
    # storage: N/A

  # No ZooKeeper section - using KRaft!
  # zookeeper: N/A

  # Entity Operator (Topic + User Operators)
  entityOperator:
    topicOperator:
      reconciliationIntervalSeconds: 90
      resources:
        requests:
          cpu: 100m
          memory: 128Mi
        limits:
          cpu: 500m
          memory: 256Mi
    userOperator:
      reconciliationIntervalSeconds: 120
      resources:
        requests:
          cpu: 100m
          memory: 128Mi
        limits:
          cpu: 500m
          memory: 256Mi

---
# Optional: Test topic
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaTopic
metadata:
  name: test-topic
  namespace: messaging
  labels:
    strimzi.io/cluster: test-kafka
spec:
  partitions: 3
  replicas: 1  # Single replica for testing
  config:
    retention.ms: 3600000  # 1 hour
    segment.bytes: 104857600  # 100MB
    compression.type: lz4

---
# Optional: Test user
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaUser
metadata:
  name: test-user
  namespace: messaging
  labels:
    strimzi.io/cluster: test-kafka
spec:
  authentication:
    type: scram-sha-512
  authorization:
    type: simple
    acls:
      # Allow all operations on test-topic
      - resource:
          type: topic
          name: test-topic
          patternType: literal
        operations:
          - Read
          - Write
          - Create
          - Describe
      # Allow consumer group
      - resource:
          type: group
          name: test-group
          patternType: literal
        operations:
          - Read
```

**T9.3**: Add architecture documentation
Update `docs/architecture.md` with Strimzi operator section (if not already present):
```markdown
### Messaging Platform (Strimzi Kafka)

**Operator**: Strimzi Kafka Operator v0.48.0
**Cluster**: apps
**Namespace**: `strimzi-operator-system` (operator), `messaging` (Kafka clusters)

Strimzi provides Kubernetes-native Apache Kafka management:
- **Cluster Operator**: Manages Kafka clusters via Kafka CR
- **Topic Operator**: Manages Kafka topics via KafkaTopic CR
- **User Operator**: Manages Kafka users via KafkaUser CR
- **KRaft Mode**: ZooKeeper-less Kafka using Kafka Raft consensus
- **GitOps**: Declarative Kafka infrastructure managed by Flux
```

### T10: Validation and Commit

**T10.1**: Validate operator manifests
```bash
# Validate Kustomization build
kustomize build kubernetes/workloads/platform/messaging/strimzi-operator

# Validate Flux Kustomization
flux build kustomization cluster-apps-messaging-strimzi-operator \
  --path ./kubernetes/workloads/platform/messaging/strimzi-operator

# YAML lint
yamllint kubernetes/workloads/platform/messaging/strimzi-operator/
```

**T10.2**: Validate PrometheusRule syntax
```bash
# Check PrometheusRule structure
yq eval '.spec.groups[].rules[]' kubernetes/workloads/platform/messaging/strimzi-operator/prometheusrule.yaml

# Validate alert expressions (requires promtool)
promtool check rules kubernetes/workloads/platform/messaging/strimzi-operator/prometheusrule.yaml
```

**T10.3**: Validate Helm repository
```bash
# Check repository URL
yq eval '.spec.url' kubernetes/infrastructure/repositories/helm/strimzi.yaml

# Test repository reachability (optional)
curl -I https://strimzi.io/charts/
```

**T10.4**: Verify no secrets in git
```bash
# Search for potential secrets
grep -r "password\|secret\|key" kubernetes/workloads/platform/messaging/strimzi-operator/ \
  | grep -v "ClusterRole\|ClusterRoleBinding\|secretStoreRef\|name:"
```

**T10.5**: Commit manifests to git
```bash
git add kubernetes/workloads/platform/messaging/
git add kubernetes/infrastructure/repositories/helm/strimzi.yaml
git add kubernetes/infrastructure/repositories/helm/kustomization.yaml
git add kubernetes/clusters/apps/messaging.yaml
git add docs/runbooks/strimzi-operator.md
git add docs/examples/test-kafka-kraft.yaml
git add docs/architecture.md

git commit -m "feat(messaging): create Strimzi Kafka operator manifests for apps cluster

- Add Strimzi operator v0.48.0 HelmRelease with KRaft support
- Add ServiceMonitor for operator metrics
- Add PrometheusRule with 8 operator alerts
- Add strimzi-operator-system and messaging namespaces
- Add Strimzi Helm repository
- Add Flux Kustomization with health checks
- Add comprehensive operator runbook with CRD reference
- Add test Kafka cluster manifest (KRaft mode, ephemeral storage)
- Document operator architecture, operations, and troubleshooting

Related: Story 37 (STORY-MSG-STRIMZI-OPERATOR)
"
```

## Runtime Validation (Story 45)

Runtime validation will be performed in Story 45 and includes:

### Operator Deployment Validation
- Reconcile `cluster-apps-messaging-strimzi-operator` Kustomization
- Verify operator Deployment: `strimzi-cluster-operator` (1/1 Ready)
- Verify operator pod running without errors
- Verify operator logs show healthy reconciliation loop

### CRD Installation Validation
- List all Strimzi CRDs: `kubectl get crds | grep strimzi`
- Verify expected CRDs present:
  - `kafkas.kafka.strimzi.io`
  - `kafkatopics.kafka.strimzi.io`
  - `kafkausers.kafka.strimzi.io`
  - `kafkaconnects.kafka.strimzi.io`
  - `kafkamirrormaker2s.kafka.strimzi.io`
  - `kafkabridges.kafka.strimzi.io`
  - `kafkarebalances.kafka.strimzi.io`
  - `kafkanodepools.kafka.strimzi.io`
- Verify CRDs in Established condition

### RBAC Validation
- Verify ClusterRole created: `kubectl get clusterrole | grep strimzi`
- Verify ClusterRoleBinding: `kubectl get clusterrolebinding | grep strimzi`
- Verify ServiceAccount has correct permissions
- Test operator can list Kafka CRs in messaging namespace

### Smoke Test (KRaft Mode)
- Apply test Kafka cluster: `kubectl apply -f docs/examples/test-kafka-kraft.yaml`
- Wait for Kafka CR to reach Ready condition (3-5 minutes)
- Verify resources created:
  - KafkaNodePool: `test-pool` (1/1 replicas)
  - StatefulSet: `test-kafka-test-pool` (1/1 pods)
  - Deployment: `test-kafka-entity-operator` (1/1 pods)
  - Services: `test-kafka-kafka-bootstrap`, `test-kafka-kafka-brokers`
  - No ZooKeeper resources (KRaft mode)
- Verify test topic created: `kubectl -n messaging get kafkatopic test-topic`
- Verify test user created: `kubectl -n messaging get kafkauser test-user`
- Verify user Secret generated: `kubectl -n messaging get secret test-user`
- Delete test resources: `kubectl delete -f docs/examples/test-kafka-kraft.yaml`
- Verify operator cleans up all child resources (StatefulSets, Services, ConfigMaps, Pods)

### Metrics Validation
- Verify ServiceMonitor created and scraping
- Query Victoria Metrics: `up{job="strimzi-cluster-operator"} == 1`
- Verify Strimzi metrics present: `strimzi_reconciliations_total`, `strimzi_resources`
- Port-forward to metrics endpoint: `curl http://localhost:8080/metrics | grep strimzi`

### Alert Validation
- Verify PrometheusRule loaded in Victoria Metrics
- Verify alerts can fire (optional: simulate operator down)

## Definition of Done

- [x] **AC1-AC11 met**: All manifests created, validated, and committed to git
- [x] **Local validation passed**: `flux build`, `kustomize build`, `yamllint` all succeed
- [x] **No secrets in git**: Grep search confirms no hardcoded credentials
- [x] **Documentation complete**: Runbook with CRD reference, operations, troubleshooting, test manifest
- [x] **Manifests committed**: Git commit with descriptive message
- [ ] **Runtime validation**: Deferred to Story 45 (deployment, CRD verification, smoke test)

## Design Notes

### Strimzi Operator Architecture

**Operator Pattern**:
Strimzi follows the Kubernetes Operator pattern:
1. **Watch**: Operator watches for changes to Kafka CRs
2. **Diff**: Compare desired state (CR spec) with actual state (cluster resources)
3. **Reconcile**: Create/update/delete resources to match desired state
4. **Status**: Update CR status with current cluster state

**Operator Components**:
- **Cluster Operator**: Main controller managing Kafka clusters
- **Topic Operator**: Manages Kafka topics (can be embedded or standalone)
- **User Operator**: Manages Kafka users (can be embedded or standalone)

**Deployment Modes**:
- **Embedded Entity Operator**: Topic + User Operators run in Entity Operator pod (default)
- **Standalone Operators**: Topic/User Operators run as separate deployments (advanced)

### KRaft Mode vs ZooKeeper Mode

**KRaft Mode** (Kafka Raft - used in this story):
- **No ZooKeeper**: Kafka manages metadata internally using Raft consensus
- **Simplified Architecture**: Fewer components to manage
- **Better Performance**: Lower latency, higher throughput
- **Node Pools**: Uses `KafkaNodePool` CR to define broker/controller roles
- **Combined Mode**: Nodes can be both controllers and brokers (used in test manifest)
- **Separated Mode**: Dedicated controller nodes + dedicated broker nodes (production)

**ZooKeeper Mode** (legacy):
- **ZooKeeper Ensemble**: Separate ZooKeeper cluster manages Kafka metadata
- **Complex Architecture**: More components to manage and monitor
- **Deprecated**: Will be removed in Kafka 4.0
- **Not Recommended**: Only use for legacy compatibility

**Migration Path**:
- New deployments: Use KRaft mode from the start
- Existing ZooKeeper clusters: Migrate to KRaft (complex process, requires careful planning)

### Custom Resource Definitions (CRDs)

**Kafka CR** (`kafka.strimzi.io/v1beta2`):
- Defines Kafka cluster configuration
- Specifies listeners (plain, TLS, external)
- Configures Kafka broker settings
- Optionally defines ZooKeeper ensemble (legacy mode)
- Optionally embeds Entity Operator

**KafkaNodePool CR** (`kafka.strimzi.io/v1beta2`):
- Defines node pools for KRaft clusters
- Specifies roles (controller, broker, or both)
- Configures storage per pool
- Allows heterogeneous broker configurations

**KafkaTopic CR** (`kafka.strimzi.io/v1beta2`):
- Defines Kafka topic with partitions and replication
- Configures topic-level settings (retention, compression)
- Synced bidirectionally with Kafka (Topic Operator)

**KafkaUser CR** (`kafka.strimzi.io/v1beta2`):
- Defines Kafka user with authentication (SCRAM-SHA, TLS)
- Configures ACLs for authorization
- Generates Secrets with credentials

**KafkaConnect CR** (`kafka.strimzi.io/v1beta2`):
- Defines Kafka Connect cluster
- Manages connectors for data integration
- Supports custom connector plugins

**Other CRs**:
- `KafkaMirrorMaker2`: Multi-cluster replication
- `KafkaBridge`: HTTP REST API for Kafka
- `KafkaRebalance`: Cruise Control integration for partition rebalancing

### Namespace Strategy

**Operator Namespace** (`strimzi-operator-system`):
- Dedicated namespace for operator deployment
- Isolated from Kafka workloads
- Pod Security Standards: Baseline enforcement

**Kafka Workload Namespace** (`messaging`):
- All Kafka clusters, topics, users deployed here
- Operator watches this namespace via `watchNamespaces`
- Pod Security Standards: Baseline enforcement

**Multi-Namespace Support**:
- Operator can watch multiple namespaces: `watchNamespaces: [messaging, app-ns-1, app-ns-2]`
- Or watch all namespaces: `watchAnyNamespace: true`
- Trade-off: Security (scoped) vs Flexibility (cluster-wide)

### Resource Management

**Operator Resources**:
- CPU: 200m request, 1000m limit
- Memory: 256Mi request, 512Mi limit
- Sufficient for managing 10+ Kafka clusters

**Kafka Broker Resources** (per broker):
- CPU: 1-2 cores (request), 2-4 cores (limit)
- Memory: 2-4Gi (request), 4-8Gi (limit)
- Depends on throughput requirements

**Storage**:
- **Ephemeral**: For testing only (data lost on pod restart)
- **Persistent**: Production clusters (PVC per broker)
- **Storage Class**: `rook-ceph-block` (network storage) or `openebs-local-nvme` (local NVMe)

### Security Model

**Pod Security Standards**:
- Operator namespace: Baseline enforcement, restricted audit/warn
- Messaging namespace: Baseline enforcement (Kafka requires some privileges)

**RBAC**:
- Operator requires ClusterRole for cross-namespace management
- ServiceAccount with minimal required permissions
- Topic/User Operators need additional permissions for Secrets and ConfigMaps

**Network Policies**:
- Operator generates NetworkPolicies when `generateNetworkPolicy: true`
- Policies allow Kafka broker communication and client access
- Deny-all by default (Cilium NetworkPolicy)

**Authentication**:
- SCRAM-SHA-512 (username/password stored in Secrets)
- TLS mutual authentication (client certificates)
- OAuth2 (Keycloak integration)

**Authorization**:
- Simple ACLs (managed by User Operator)
- OAuth2 authorization (Keycloak integration)
- OPA (Open Policy Agent) integration

### Monitoring Strategy

**Operator Metrics**:
- Reconciliation metrics (total, failed, duration)
- Resource metrics (managed resources, ready resources)
- Operator health metrics (memory, CPU)

**Kafka Metrics** (not covered in this story):
- JMX metrics exported via Prometheus exporter
- Broker metrics (throughput, lag, partition count)
- Topic metrics (size, message rate)
- Consumer group metrics (lag, offset)

**ServiceMonitor**:
- Scrapes operator metrics every 30s
- Victoria Metrics discovers and scrapes automatically

**PrometheusRule**:
- 8 operator alerts (availability, reconciliation, performance, errors)
- Alert severity: Critical (operator down) → Warning (slow reconciliation)

### Flux Dependency Chain

```
cluster-apps-infrastructure-repositories (Helm repos)
├── cluster-apps-observability-victoria-metrics (ServiceMonitor)
│   └── cluster-apps-messaging-strimzi-operator
└── cluster-apps-messaging-strimzi-operator
```

**Rationale**:
- Helm repositories must exist before HelmRelease can fetch charts
- Victoria Metrics must exist before ServiceMonitor can scrape metrics
- Operator has health check on Deployment (Flux waits for Ready)

### Upgrade Strategy

**Operator Upgrade**:
1. Update HelmRelease version in git
2. Commit and push changes
3. Flux reconciles HelmRelease automatically
4. Helm upgrades operator Deployment (rolling update)
5. New operator version reconciles existing Kafka clusters

**CRD Upgrade**:
- CRDs upgraded automatically by Helm (`crds: CreateReplace`)
- Backward compatible within minor versions
- Major version upgrades may require CR migration

**Kafka Cluster Upgrade**:
- Managed by operator (not covered in this story)
- Rolling update of brokers
- Zero-downtime upgrade (if replication factor ≥ 3)

### Feature Gates

**Enabled Feature Gates**:
- `+UseKRaft`: Enable KRaft mode support (ZooKeeper-less Kafka)
- `+KafkaNodePools`: Enable KafkaNodePool CRD for heterogeneous brokers

**Other Feature Gates** (not enabled):
- `+UseStrimziPodSets`: Use StrimziPodSet instead of StatefulSet (experimental)
- `+ControlPlaneListener`: Separate control plane listener (advanced)

### Limitations and Future Work

**Current Limitations**:
1. **Single operator instance**: One operator per cluster (no HA for operator itself)
2. **Namespace scoped watch**: Operator watches specific namespaces (not cluster-wide by default)
3. **Manual scaling**: No auto-scaling based on load (requires manual replica adjustment)
4. **No multi-cluster replication**: KafkaMirrorMaker2 setup deferred to future story

**Future Enhancements**:
1. **Kafka Connect**: Deploy Kafka Connect for data integration (STORY-MSG-KAFKA-CONNECT)
2. **Schema Registry**: Deploy Confluent Schema Registry (STORY-MSG-SCHEMA-REGISTRY)
3. **Multi-cluster replication**: KafkaMirrorMaker2 for cross-cluster replication
4. **Cruise Control**: Auto-balancing and capacity management
5. **Grafana dashboards**: Pre-built dashboards for Kafka monitoring
6. **Backup and DR**: Integration with VolSync for Kafka data backup

### Testing Strategy

**Unit Tests** (Manifest Validation):
- `flux build kustomization` - Flux Kustomization syntax
- `kustomize build` - Kustomize resource composition
- `yamllint` - YAML syntax
- `promtool check rules` - PrometheusRule validation

**Integration Tests** (Story 45):
- Deploy operator to apps cluster
- Verify Deployment ready
- Verify CRDs installed
- Verify ServiceMonitor scraping

**Smoke Test** (Story 45):
- Deploy test Kafka cluster (KRaft mode, 1 replica, ephemeral storage)
- Verify operator reconciles CR and creates resources
- Verify no ZooKeeper pods (KRaft mode)
- Verify test topic and user created
- Delete test cluster and verify cleanup

**Negative Tests** (Story 45 - optional):
- Invalid Kafka configuration → reconciliation fails with clear error
- Insufficient cluster resources → pending pods with descriptive events
- Storage class not found → PVC creation fails with clear error

### Operational Runbooks

**View Operator Logs**:
```bash
kubectl -n strimzi-operator-system logs -l name=strimzi-cluster-operator -f
```

**Restart Operator**:
```bash
kubectl -n strimzi-operator-system rollout restart deployment strimzi-cluster-operator
```

**Check Operator Version**:
```bash
kubectl -n strimzi-operator-system get deploy strimzi-cluster-operator \
  -o jsonpath='{.spec.template.spec.containers[0].image}'
```

**List Managed Kafka Clusters**:
```bash
kubectl -n messaging get kafka
```

**Check Kafka Cluster Status**:
```bash
kubectl -n messaging get kafka <cluster-name> -o jsonpath='{.status.conditions}'
```

**Upgrade Operator**:
1. Edit HelmRelease version
2. Commit and push
3. Reconcile Flux: `flux reconcile kustomization cluster-apps-messaging-strimzi-operator --with-source`

## Change Log

| Date       | Version | Description                                                                 | Author |
|------------|---------|-----------------------------------------------------------------------------|--------|
| 2025-10-26 | 3.0     | v3.0 manifests-first refinement: separate manifest creation from deployment | Claude |
| 2025-10-23 | 0.1     | Initial draft with KRaft mode support                                       | Sarah  |
