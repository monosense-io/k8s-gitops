# 38 — STORY-MSG-KAFKA-CLUSTER-APPS — Create Kafka Cluster Manifests (apps)

Sequence: 38/50 | Prev: STORY-MSG-STRIMZI-OPERATOR.md | Next: STORY-MSG-SCHEMA-REGISTRY.md
Sprint: 6 | Lane: Messaging
Global Sequence: 38/50

**Status**: v3.0 (Manifests-First)
Owner: Platform Engineering
Date: 2025-10-26
Links: docs/architecture.md §19 (Workloads & Versions); kubernetes/workloads/platform/messaging/kafka; STORY-MSG-STRIMZI-OPERATOR.md

## Story

Create complete production-grade Apache Kafka cluster manifests for the apps cluster using Strimzi operator with KRaft mode (no ZooKeeper), persistent storage, TLS encryption, SCRAM-SHA-512 authentication, and comprehensive monitoring. Deploy Kafka version 4.1.0 (latest stable) with 3 nodes in combined controller+broker mode to provide a reliable event streaming platform for application workloads. All manifests will be validated locally before committing to git; runtime deployment and validation will occur in Story 45.

**Version Note**: Originally planned for Kafka 3.9.0, but upgraded to 4.1.0 (Sep 2025) as Strimzi 0.48.0 removed support for Kafka 3.9.x. Kafka 4.1.0 is the latest stable version with production-ready KRaft mode and enhanced features.

## Scope

**This Story (38 - Manifest Creation)**:
- Create Kafka CR with KRaft mode (3-node combined controller+broker)
- Create KafkaNodePool CR for broker/controller pool definition
- Create metrics ConfigMap for JMX Prometheus exporter
- Create ServiceMonitors for Kafka brokers and exporters
- Create PrometheusRule for Kafka cluster monitoring
- Create example KafkaTopic and KafkaUser manifests for testing
- Create Flux Kustomization entrypoint with dependency chain
- Document Kafka cluster architecture, client configuration, and operations
- Validate all manifests with local tools (flux build, kustomize build, yamllint)
- **NO cluster deployment or testing** (all deployment happens in Story 45)

**Story 45 (Deployment & Validation)**:
- Apply manifests to apps cluster
- Verify Kafka cluster deployment (3 Kafka pods, Entity Operator pod)
- Verify PVCs bound to persistent storage
- Verify TLS encryption and SCRAM-SHA-512 authentication
- Execute produce/consume test with authenticated client
- Verify metrics scrape and PrometheusRule alerts
- Test KafkaTopic and KafkaUser lifecycle

## Acceptance Criteria

**AC1**: `kubernetes/workloads/platform/messaging/kafka/` contains Kafka CR, KafkaNodePool CR, metrics ConfigMap, ServiceMonitors, and PrometheusRule.

**AC2**: `kubernetes/workloads/platform/messaging/kafka/kafka.yaml` defines Kafka cluster with:
- Kafka version 4.1.0 (latest stable as of Sep 2025)
- KRaft mode enabled (default in Strimzi 0.48.0, no annotations needed)
- Listeners: plain (9092) and TLS (9093) with SCRAM-SHA-512 authentication
- Production-grade configuration (replication factor 3, min.insync.replicas 2)
- Entity Operator (Topic + User Operators) with resource limits
- Kafka Exporter for consumer group metrics

**AC3**: `kubernetes/workloads/platform/messaging/kafka/kafka-nodepool.yaml` defines KafkaNodePool with:
- 3 replicas in combined controller+broker mode
- Persistent storage: 100Gi per node on `${BLOCK_SC}` (rook-ceph-block)
- JBOD storage configuration (single volume)
- Resource requests (CPU: 1000m, Memory: 2Gi) and limits (CPU: 2000m, Memory: 4Gi)
- JVM options (-Xms: 1024m, -Xmx: 2048m)

**AC4**: `kubernetes/workloads/platform/messaging/kafka/metrics-configmap.yaml` defines JMX Prometheus exporter configuration for Kafka metrics.

**AC5**: `kubernetes/workloads/platform/messaging/kafka/servicemonitors.yaml` defines ServiceMonitors for:
- Kafka broker metrics (JMX exporter)
- Kafka Exporter metrics (consumer groups)
- Entity Operator metrics (Topic/User Operators)

**AC6**: `kubernetes/workloads/platform/messaging/kafka/prometheusrule.yaml` defines alerts for:
- Kafka broker down
- Under-replicated partitions
- Offline partitions
- ISR shrink rate high
- Disk usage high
- Consumer group lag high
- Leader election rate high
- Network handler idle low

**AC7**: `kubernetes/workloads/platform/messaging/kafka/examples/` contains example manifests for:
- KafkaTopic CR (test-topic with 3 partitions, 3 replicas)
- KafkaUser CR (test-user with SCRAM-SHA-512 auth and ACLs)

**AC8**: `kubernetes/clusters/apps/messaging-kafka.yaml` creates Flux Kustomization with dependency on Strimzi operator and health checks for Kafka CR.

**AC9**: All manifests pass local validation:
- `flux build kustomization cluster-apps-messaging-kafka --path ./kubernetes/workloads/platform/messaging/kafka` succeeds
- `kustomize build kubernetes/workloads/platform/messaging/kafka/` renders without errors
- `yamllint kubernetes/workloads/platform/messaging/kafka/` passes
- No secrets or credentials hardcoded in git

**AC10**: Documentation includes:
- Kafka cluster architecture (KRaft mode, storage, networking)
- Client configuration guide (bootstrap endpoints, TLS, SCRAM-SHA-512)
- Operations runbook (restart brokers, scale cluster, troubleshoot)
- KafkaTopic and KafkaUser creation patterns

**AC11**: All manifests committed to git with commit message describing changes.

## Dependencies

**Local Tools Required**:
- `flux` CLI (v2.4.0+) - Build and validate Flux Kustomizations
- `kustomize` (v5.0+) - Build and validate Kustomize overlays
- `yamllint` (v1.35+) - YAML syntax validation
- `yq` (v4.44+) - YAML manipulation and validation
- `git` - Commit manifests to repository

**External Dependencies** (for Story 45):
- Strimzi operator deployed on apps cluster (Story 37)
- Storage class available: `rook-ceph-block` or `openebs-local-nvme`
- Victoria Metrics operator for ServiceMonitors
- External Secrets operator (optional, for KafkaUser credential management)

## Tasks / Subtasks

### T1: Prerequisites and Strategy

**T1.1**: Review Kafka architecture and deployment patterns
- Study KRaft mode architecture (controllers, brokers, combined mode)
- Review Strimzi Kafka CR structure and KafkaNodePool CR
- Understand Kafka listeners (plain, TLS, SASL)
- Review production-grade configuration recommendations

**T1.2**: Review cluster-settings for Kafka configuration
- File: `kubernetes/clusters/apps/cluster-settings.yaml`
- Identify substitution variables for storage class, retention, resources

**T1.3**: Create directory structure
```bash
mkdir -p kubernetes/workloads/platform/messaging/kafka/{examples,}
```

### T2: Kafka Cluster Configuration

**T2.1**: Create `kubernetes/workloads/platform/messaging/kafka/kafka-nodepool.yaml`
```yaml
---
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaNodePool
metadata:
  name: kafka-pool
  namespace: messaging
  labels:
    strimzi.io/cluster: kafka-cluster
    app.kubernetes.io/name: kafka
    app.kubernetes.io/component: kafka-broker
    app.kubernetes.io/managed-by: flux
spec:
  # Number of Kafka nodes (controller+broker combined mode)
  replicas: 3

  # Roles: controller (KRaft metadata quorum) + broker (data plane)
  roles:
    - controller
    - broker

  # Storage configuration (JBOD with single persistent volume)
  storage:
    type: jbod
    volumes:
      - id: 0
        type: persistent-claim
        size: 100Gi
        class: ${BLOCK_SC}
        deleteClaim: false  # Retain PVCs on pool deletion

  # Resource allocation
  resources:
    requests:
      memory: 2Gi
      cpu: 1000m
    limits:
      memory: 4Gi
      cpu: 2000m

  # JVM heap configuration (50% of memory request)
  jvmOptions:
    -Xms: "1024m"
    -Xmx: "2048m"
    # GC tuning for low-latency
    -XX:+UseG1GC: null
    -XX:MaxGCPauseMillis: "20"
    -XX:InitiatingHeapOccupancyPercent: "35"
    -XX:G1HeapRegionSize: "16M"
    # JVM diagnostic options
    -XX:+HeapDumpOnOutOfMemoryError: null
    -XX:HeapDumpPath: "/tmp/heap_dump.hprof"

  # Pod template for additional configuration
  template:
    pod:
      # Affinity: distribute pods across nodes
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              podAffinityTerm:
                labelSelector:
                  matchExpressions:
                    - key: strimzi.io/cluster
                      operator: In
                      values:
                        - kafka-cluster
                    - key: strimzi.io/name
                      operator: In
                      values:
                        - kafka-pool
                topologyKey: kubernetes.io/hostname

      # Security context
      securityContext:
        runAsNonRoot: true
        fsGroup: 0

      # Tolerations (if needed for dedicated nodes)
      tolerations: []

      # Termination grace period (allow clean shutdown)
      terminationGracePeriodSeconds: 120
```

**T2.2**: Create `kubernetes/workloads/platform/messaging/kafka/kafka.yaml`
```yaml
---
apiVersion: kafka.strimzi.io/v1beta2
kind: Kafka
metadata:
  name: kafka-cluster
  namespace: messaging
  labels:
    app.kubernetes.io/name: kafka
    app.kubernetes.io/instance: kafka-cluster
    app.kubernetes.io/managed-by: flux
  annotations:
    # Enable KRaft mode (no ZooKeeper)
    strimzi.io/kraft: "enabled"
    # Enable KafkaNodePool management
    strimzi.io/node-pools: "enabled"
spec:
  kafka:
    # Kafka version
    version: 3.9.0

    # Replicas, storage, resources, jvmOptions moved to KafkaNodePool
    # replicas: N/A
    # storage: N/A
    # resources: N/A
    # jvmOptions: N/A

    # Listeners
    listeners:
      # Plain listener (SCRAM-SHA-512 authentication)
      - name: plain
        port: 9092
        type: internal
        tls: false
        authentication:
          type: scram-sha-512

      # TLS listener (SCRAM-SHA-512 authentication)
      - name: tls
        port: 9093
        type: internal
        tls: true
        authentication:
          type: scram-sha-512
        configuration:
          # TLS cipher suites
          preferredNodePortAddressType: InternalDNS

    # Kafka broker configuration
    config:
      # Replication settings (production-grade)
      offsets.topic.replication.factor: 3
      transaction.state.log.replication.factor: 3
      transaction.state.log.min.isr: 2
      default.replication.factor: 3
      min.insync.replicas: 2

      # Protocol version
      inter.broker.protocol.version: "3.9"
      log.message.format.version: "3.9"

      # Topic management
      auto.create.topics.enable: false  # Require KafkaTopic CRs
      delete.topic.enable: true

      # Log retention
      log.retention.hours: 168  # 7 days
      log.retention.bytes: -1  # No size limit (time-based only)
      log.segment.bytes: 1073741824  # 1GB
      log.retention.check.interval.ms: 300000  # 5 minutes

      # Compression
      compression.type: producer  # Honor producer compression setting
      log.cleanup.policy: delete

      # Performance tuning
      num.network.threads: 3
      num.io.threads: 8
      num.replica.fetchers: 4
      num.recovery.threads.per.data.dir: 1

      # Socket buffer sizes
      socket.send.buffer.bytes: 102400  # 100KB
      socket.receive.buffer.bytes: 102400  # 100KB
      socket.request.max.bytes: 104857600  # 100MB

      # Replication
      replica.lag.time.max.ms: 30000  # 30s
      replica.socket.timeout.ms: 30000  # 30s
      replica.socket.receive.buffer.bytes: 65536  # 64KB

      # Leader election
      controlled.shutdown.enable: true
      controlled.shutdown.max.retries: 3
      unclean.leader.election.enable: false  # Prevent data loss

      # Group coordinator
      group.initial.rebalance.delay.ms: 3000  # 3s
      group.min.session.timeout.ms: 6000  # 6s
      group.max.session.timeout.ms: 1800000  # 30min

      # Log flush
      log.flush.interval.messages: 10000
      log.flush.interval.ms: 1000

    # Metrics configuration (JMX Prometheus exporter)
    metricsConfig:
      type: jmxPrometheusExporter
      valueFrom:
        configMapKeyRef:
          name: kafka-metrics
          key: kafka-metrics-config.yml

    # Logging configuration
    logging:
      type: inline
      loggers:
        kafka.root.logger.level: "INFO"
        kafka.controller: "INFO"
        kafka.server.KafkaRequestHandler: "WARN"
        kafka.network.RequestChannel$: "WARN"
        kafka.server.ReplicaManager: "INFO"
        kafka.log.LogCleaner: "INFO"

  # No ZooKeeper section - using KRaft!
  # zookeeper: N/A

  # Entity Operator (Topic + User Operators)
  entityOperator:
    topicOperator:
      reconciliationIntervalSeconds: 90
      resources:
        requests:
          memory: 256Mi
          cpu: 100m
        limits:
          memory: 512Mi
          cpu: 500m
      logging:
        type: inline
        loggers:
          rootLogger.level: INFO

    userOperator:
      reconciliationIntervalSeconds: 120
      resources:
        requests:
          memory: 256Mi
          cpu: 100m
        limits:
          memory: 512Mi
          cpu: 500m
      logging:
        type: inline
        loggers:
          rootLogger.level: INFO

  # Kafka Exporter (consumer group lag metrics)
  kafkaExporter:
    topicRegex: ".*"
    groupRegex: ".*"
    resources:
      requests:
        cpu: 100m
        memory: 128Mi
      limits:
        cpu: 500m
        memory: 256Mi
    logging:
      type: inline
      loggers:
        rootLogger.level: INFO
```

### T3: Metrics Configuration

**T3.1**: Create `kubernetes/workloads/platform/messaging/kafka/metrics-configmap.yaml`
```yaml
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: kafka-metrics
  namespace: messaging
  labels:
    app.kubernetes.io/name: kafka
    app.kubernetes.io/component: metrics
    app.kubernetes.io/managed-by: flux
data:
  kafka-metrics-config.yml: |
    lowercaseOutputName: true
    lowercaseOutputLabelNames: true
    rules:
      # Broker metrics
      - pattern: kafka.server<type=(.+), name=(.+), clientId=(.+), topic=(.+), partition=(.*)><>Value
        name: kafka_server_$1_$2
        type: GAUGE
        labels:
          clientId: "$3"
          topic: "$4"
          partition: "$5"

      - pattern: kafka.server<type=(.+), name=(.+), clientId=(.+), brokerHost=(.+), brokerPort=(.+)><>Value
        name: kafka_server_$1_$2
        type: GAUGE
        labels:
          clientId: "$3"
          broker: "$4:$5"

      # Replica manager metrics
      - pattern: kafka.server<type=ReplicaManager, name=(.+)><>(Value|OneMinuteRate)
        name: kafka_server_replicamanager_$1
        type: GAUGE

      # Controller metrics
      - pattern: kafka.controller<type=KafkaController, name=(.+)><>Value
        name: kafka_controller_kafkacontroller_$1
        type: GAUGE

      # Network metrics
      - pattern: kafka.network<type=RequestMetrics, name=RequestsPerSec, request=(.+), version=(.+)><>OneMinuteRate
        name: kafka_network_requestmetrics_requestspersec
        type: GAUGE
        labels:
          request: "$1"
          version: "$2"

      - pattern: kafka.network<type=RequestMetrics, name=TotalTimeMs, request=(.+)><>(Mean|Max)
        name: kafka_network_requestmetrics_totaltimems_$2
        type: GAUGE
        labels:
          request: "$1"

      # Log metrics
      - pattern: kafka.log<type=Log, name=(.+), topic=(.+), partition=(.+)><>Value
        name: kafka_log_log_$1
        type: GAUGE
        labels:
          topic: "$2"
          partition: "$3"

      - pattern: kafka.log<type=LogFlushStats, name=LogFlushRateAndTimeMs><>(OneMinuteRate|Mean)
        name: kafka_log_logflushstats_$1
        type: GAUGE

      # Partition metrics
      - pattern: kafka.cluster<type=Partition, name=(.+), topic=(.+), partition=(.+)><>Value
        name: kafka_cluster_partition_$1
        type: GAUGE
        labels:
          topic: "$2"
          partition: "$3"

      # Request handler metrics
      - pattern: kafka.server<type=KafkaRequestHandlerPool, name=RequestHandlerAvgIdlePercent><>(OneMinuteRate|Mean)
        name: kafka_server_kafkarequesthandlerpool_requesthandleravgidlepercent
        type: GAUGE

      # Broker topic metrics
      - pattern: kafka.server<type=BrokerTopicMetrics, name=(.+)><>(OneMinuteRate|Mean)
        name: kafka_server_brokertopicmetrics_$1_$2
        type: GAUGE

      - pattern: kafka.server<type=BrokerTopicMetrics, name=(.+), topic=(.+)><>(OneMinuteRate|Mean)
        name: kafka_server_brokertopicmetrics_$1_$3
        type: GAUGE
        labels:
          topic: "$2"

      # JVM metrics
      - pattern: java.lang<type=Memory><HeapMemoryUsage>(\w+)
        name: jvm_memory_heap_$1
        type: GAUGE

      - pattern: java.lang<type=Memory><NonHeapMemoryUsage>(\w+)
        name: jvm_memory_nonheap_$1
        type: GAUGE

      - pattern: java.lang<type=GarbageCollector, name=(.+)><>CollectionCount
        name: jvm_gc_collection_count
        type: COUNTER
        labels:
          gc: "$1"

      - pattern: java.lang<type=GarbageCollector, name=(.+)><>CollectionTime
        name: jvm_gc_collection_time_ms
        type: COUNTER
        labels:
          gc: "$1"

      # Catch-all for other metrics
      - pattern: (.+)
        name: kafka_$1
        type: GAUGE
```

### T4: ServiceMonitors

**T4.1**: Create `kubernetes/workloads/platform/messaging/kafka/servicemonitors.yaml`
```yaml
---
# ServiceMonitor for Kafka broker JMX metrics
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: kafka-cluster-kafka
  namespace: messaging
  labels:
    app.kubernetes.io/name: kafka
    app.kubernetes.io/component: kafka-broker
    prometheus: platform
spec:
  selector:
    matchLabels:
      strimzi.io/cluster: kafka-cluster
      strimzi.io/kind: Kafka
      strimzi.io/name: kafka-cluster-kafka
  endpoints:
    - port: tcp-prometheus
      interval: 30s
      path: /metrics
      scheme: http
  namespaceSelector:
    matchNames:
      - messaging

---
# ServiceMonitor for Kafka Exporter (consumer group metrics)
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: kafka-cluster-exporter
  namespace: messaging
  labels:
    app.kubernetes.io/name: kafka
    app.kubernetes.io/component: kafka-exporter
    prometheus: platform
spec:
  selector:
    matchLabels:
      strimzi.io/cluster: kafka-cluster
      strimzi.io/kind: Kafka
      strimzi.io/name: kafka-cluster-kafka-exporter
  endpoints:
    - port: tcp-prometheus
      interval: 30s
      path: /metrics
      scheme: http
  namespaceSelector:
    matchNames:
      - messaging

---
# ServiceMonitor for Entity Operator (Topic + User Operators)
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: kafka-cluster-entity-operator
  namespace: messaging
  labels:
    app.kubernetes.io/name: kafka
    app.kubernetes.io/component: entity-operator
    prometheus: platform
spec:
  selector:
    matchLabels:
      strimzi.io/cluster: kafka-cluster
      strimzi.io/kind: Kafka
      strimzi.io/name: kafka-cluster-entity-operator
  endpoints:
    - port: healthcheck
      interval: 30s
      path: /metrics
      scheme: http
  namespaceSelector:
    matchNames:
      - messaging
```

### T5: PrometheusRule for Alerts

**T5.1**: Create `kubernetes/workloads/platform/messaging/kafka/prometheusrule.yaml`
```yaml
---
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: kafka-cluster
  namespace: messaging
  labels:
    prometheus: platform
    role: alert-rules
spec:
  groups:
    - name: kafka-cluster.rules
      interval: 1m
      rules:
        # Broker availability
        - alert: KafkaBrokerDown
          expr: |
            up{job="kafka-cluster-kafka"} == 0
          for: 5m
          labels:
            severity: critical
            category: messaging
          annotations:
            summary: "Kafka broker {{ $labels.pod }} is down"
            description: "Kafka broker {{ $labels.pod }} has been unavailable for 5 minutes."
            runbook: "Check broker pod: kubectl -n messaging describe pod {{ $labels.pod }}"

        # Under-replicated partitions
        - alert: KafkaUnderReplicatedPartitions
          expr: |
            kafka_server_replicamanager_underreplicatedpartitions > 0
          for: 15m
          labels:
            severity: high
            category: messaging
          annotations:
            summary: "Kafka has under-replicated partitions"
            description: "Broker {{ $labels.pod }} has {{ $value }} under-replicated partitions for 15 minutes."
            runbook: "Check replication status: kubectl -n messaging exec {{ $labels.pod }} -c kafka -- bin/kafka-topics.sh --bootstrap-server localhost:9092 --describe --under-replicated-partitions"

        # Offline partitions
        - alert: KafkaOfflinePartitions
          expr: |
            kafka_controller_kafkacontroller_offlinepartitionscount > 0
          for: 5m
          labels:
            severity: critical
            category: messaging
          annotations:
            summary: "Kafka has offline partitions"
            description: "Kafka cluster has {{ $value }} offline partitions for 5 minutes. Data is unavailable."
            runbook: "Check cluster status: kubectl -n messaging get kafka kafka-cluster -o yaml"

        # ISR shrink rate
        - alert: KafkaISRShrinkRateHigh
          expr: |
            rate(kafka_server_replicamanager_isrshrinkspersec[5m]) > 0
          for: 15m
          labels:
            severity: warning
            category: messaging
          annotations:
            summary: "Kafka ISR shrink rate is high"
            description: "Broker {{ $labels.pod }} ISR shrink rate is {{ $value }} for 15 minutes. Replicas are falling behind."
            runbook: "Check network latency and disk I/O on affected broker"

        # Disk usage
        - alert: KafkaDiskUsageHigh
          expr: |
            (kafka_log_log_size / 107374182400) > 0.8
          for: 30m
          labels:
            severity: warning
            category: messaging
          annotations:
            summary: "Kafka disk usage is high"
            description: "Kafka disk usage on {{ $labels.pod }} for topic {{ $labels.topic }} partition {{ $labels.partition }} is above 80%."
            runbook: "Consider increasing log retention or scaling storage"

        # Consumer group lag
        - alert: KafkaConsumerGroupLagHigh
          expr: |
            kafka_consumergroup_lag > 10000
          for: 15m
          labels:
            severity: warning
            category: messaging
          annotations:
            summary: "Kafka consumer group lag is high"
            description: "Consumer group {{ $labels.consumergroup }} for topic {{ $labels.topic }} has lag of {{ $value }} messages for 15 minutes."
            runbook: "Check consumer health and processing rate"

        # Leader election rate
        - alert: KafkaLeaderElectionRateHigh
          expr: |
            rate(kafka_controller_kafkacontroller_leaderelectionrateandtimems_total[5m]) > 0.5
          for: 15m
          labels:
            severity: high
            category: messaging
          annotations:
            summary: "Kafka leader election rate is high"
            description: "Kafka controller has high leader election rate: {{ $value }} elections/sec for 15 minutes. Cluster is unstable."
            runbook: "Check network connectivity and broker health"

        # Request handler idle low
        - alert: KafkaRequestHandlerIdleLow
          expr: |
            kafka_server_kafkarequesthandlerpool_requesthandleravgidlepercent < 0.2
          for: 30m
          labels:
            severity: warning
            category: messaging
          annotations:
            summary: "Kafka request handler idle percentage is low"
            description: "Broker {{ $labels.pod }} request handler idle is {{ $value }}% for 30 minutes. Broker may be overloaded."
            runbook: "Consider scaling up broker resources or adding more brokers"

        # Network handler idle low
        - alert: KafkaNetworkHandlerIdleLow
          expr: |
            kafka_network_requestmetrics_totaltimems_mean > 1000
          for: 30m
          labels:
            severity: warning
            category: messaging
          annotations:
            summary: "Kafka network request time is high"
            description: "Mean network request time for {{ $labels.request }} is {{ $value }}ms for 30 minutes."
            runbook: "Check network latency and broker resource utilization"

        # Cluster controller active
        - alert: KafkaNoActiveController
          expr: |
            sum(kafka_controller_kafkacontroller_activecontrollercount) == 0
          for: 5m
          labels:
            severity: critical
            category: messaging
          annotations:
            summary: "Kafka has no active controller"
            description: "Kafka cluster has no active controller for 5 minutes. Metadata operations are blocked."
            runbook: "Check controller logs: kubectl -n messaging logs -l strimzi.io/name=kafka-pool -c kafka | grep -i controller"

        # Broker JVM heap usage
        - alert: KafkaBrokerHeapUsageHigh
          expr: |
            (jvm_memory_heap_used / jvm_memory_heap_max) > 0.9
          for: 15m
          labels:
            severity: high
            category: messaging
          annotations:
            summary: "Kafka broker JVM heap usage is high"
            description: "Broker {{ $labels.pod }} JVM heap usage is {{ $value }}% for 15 minutes."
            runbook: "Consider increasing JVM heap size (-Xmx) in KafkaNodePool"

        # Broker GC time high
        - alert: KafkaBrokerGCTimeHigh
          expr: |
            rate(jvm_gc_collection_time_ms[5m]) > 100
          for: 15m
          labels:
            severity: warning
            category: messaging
          annotations:
            summary: "Kafka broker GC time is high"
            description: "Broker {{ $labels.pod }} GC time is {{ $value }}ms/sec for {{ $labels.gc }} collector."
            runbook: "Tune JVM GC settings or increase heap size"
```

### T6: Example Manifests

**T6.1**: Create `kubernetes/workloads/platform/messaging/kafka/examples/kafkatopic-example.yaml`
```yaml
---
# Example KafkaTopic for testing and reference
# DO NOT apply this to production - it's for testing only
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaTopic
metadata:
  name: test-topic
  namespace: messaging
  labels:
    strimzi.io/cluster: kafka-cluster
    app.kubernetes.io/name: kafka-topic
    app.kubernetes.io/instance: test-topic
spec:
  # Number of partitions (affects parallelism)
  partitions: 3

  # Replication factor (must be ≤ number of brokers)
  replicas: 3

  # Topic configuration
  config:
    # Retention: 1 hour for testing
    retention.ms: 3600000  # 1 hour
    retention.bytes: -1  # No size limit

    # Segment size: 100MB
    segment.bytes: 104857600  # 100MB

    # Compression
    compression.type: lz4

    # Min in-sync replicas (for producer acks=all)
    min.insync.replicas: 2

    # Cleanup policy
    cleanup.policy: delete

    # Message timestamp type
    message.timestamp.type: CreateTime

    # Max message size: 1MB
    max.message.bytes: 1048576
```

**T6.2**: Create `kubernetes/workloads/platform/messaging/kafka/examples/kafkauser-example.yaml`
```yaml
---
# Example KafkaUser for testing and reference
# DO NOT apply this to production - it's for testing only
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaUser
metadata:
  name: test-user
  namespace: messaging
  labels:
    strimzi.io/cluster: kafka-cluster
    app.kubernetes.io/name: kafka-user
    app.kubernetes.io/instance: test-user
spec:
  # Authentication: SCRAM-SHA-512 (username/password in Secret)
  authentication:
    type: scram-sha-512

  # Authorization: Simple ACLs
  authorization:
    type: simple
    acls:
      # Producer ACLs for test-topic
      - resource:
          type: topic
          name: test-topic
          patternType: literal
        operations:
          - Write
          - Create
          - Describe
        host: "*"

      # Consumer ACLs for test-topic
      - resource:
          type: topic
          name: test-topic
          patternType: literal
        operations:
          - Read
          - Describe
        host: "*"

      # Consumer group ACLs
      - resource:
          type: group
          name: test-group
          patternType: literal
        operations:
          - Read
        host: "*"

      # Cluster ACLs (for IdempotentWrite)
      - resource:
          type: cluster
        operations:
          - IdempotentWrite
        host: "*"
```

### T7: Kustomization Files

**T7.1**: Create `kubernetes/workloads/platform/messaging/kafka/kustomization.yaml`
```yaml
---
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: messaging
resources:
  - metrics-configmap.yaml
  - kafka-nodepool.yaml
  - kafka.yaml
  - servicemonitors.yaml
  - prometheusrule.yaml

# Note: examples/ directory is not included (for reference only)

labels:
  - pairs:
      app.kubernetes.io/name: kafka
      app.kubernetes.io/instance: kafka-cluster
      app.kubernetes.io/managed-by: flux
```

### T8: Cluster Kustomization Entrypoint

**T8.1**: Create `kubernetes/clusters/apps/messaging-kafka.yaml` (Flux Kustomization entrypoint)
```yaml
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: cluster-apps-messaging-kafka
  namespace: flux-system
spec:
  interval: 10m
  path: ./kubernetes/workloads/platform/messaging/kafka
  prune: true
  sourceRef:
    kind: GitRepository
    name: flux-system
  wait: true
  timeout: 15m
  dependsOn:
    - name: cluster-apps-messaging-strimzi-operator
    - name: cluster-apps-storage-rook-ceph-cluster
  postBuild:
    substitute:
      BLOCK_SC: "rook-ceph-block"
      KAFKA_VERSION: "3.9.0"
      KAFKA_RETENTION_HOURS: "168"
    substituteFrom:
      - kind: ConfigMap
        name: cluster-settings
  healthChecks:
    - apiVersion: kafka.strimzi.io/v1beta2
      kind: Kafka
      name: kafka-cluster
      namespace: messaging
```

### T9: Documentation

**T9.1**: Create `docs/runbooks/kafka-cluster.md`
```markdown
# Kafka Cluster Runbook

## Overview

This runbook covers operations for the production Kafka cluster running on the apps cluster using Strimzi operator in KRaft mode (no ZooKeeper).

## Architecture

### Cluster Configuration
- **Kafka Version**: 3.9.0
- **Mode**: KRaft (Kafka Raft - no ZooKeeper)
- **Nodes**: 3 nodes in combined controller+broker mode
- **Storage**: 100Gi per node on rook-ceph-block
- **Replication**: Default replication factor 3, min.insync.replicas 2
- **Authentication**: SCRAM-SHA-512
- **Encryption**: TLS on port 9093, plain on port 9092

### KRaft Mode

**What is KRaft?**
- **No ZooKeeper**: Kafka manages metadata internally using Raft consensus
- **Simplified**: Fewer components, easier operations
- **Performance**: Lower latency, higher throughput
- **Production-ready**: Supported since Kafka 3.3, recommended for new deployments

**Node Roles**:
- **Controller**: Manages Kafka metadata (cluster state, topic configuration, ACLs)
- **Broker**: Handles data plane (message storage, replication, client requests)
- **Combined**: Node acts as both controller and broker (our configuration)

## Client Configuration

### Bootstrap Endpoints

**Plain (SCRAM-SHA-512)**:
```
kafka-cluster-kafka-bootstrap.messaging.svc.cluster.local:9092
```

**TLS (SCRAM-SHA-512)**:
```
kafka-cluster-kafka-bootstrap.messaging.svc.cluster.local:9093
```

### Connection Properties

**Plain Listener**:
```properties
bootstrap.servers=kafka-cluster-kafka-bootstrap.messaging.svc.cluster.local:9092
security.protocol=SASL_PLAINTEXT
sasl.mechanism=SCRAM-SHA-512
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required \
  username="<username>" \
  password="<password>";
```

**TLS Listener**:
```properties
bootstrap.servers=kafka-cluster-kafka-bootstrap.messaging.svc.cluster.local:9093
security.protocol=SASL_SSL
sasl.mechanism=SCRAM-SHA-512
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required \
  username="<username>" \
  password="<password>";
# TLS trust store configuration
ssl.truststore.location=/path/to/ca.truststore.jks
ssl.truststore.password=changeit
```

### Obtaining Cluster CA Certificate

```bash
# Extract cluster CA certificate
kubectl -n messaging get secret kafka-cluster-cluster-ca-cert \
  -o jsonpath='{.data.ca\.crt}' | base64 -d > ca.crt

# Create Java truststore
keytool -import -trustcacerts -alias kafka-ca -file ca.crt \
  -keystore ca.truststore.jks -storepass changeit -noprompt
```

## Creating Topics

### Using KafkaTopic CR (Recommended)

```yaml
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaTopic
metadata:
  name: my-topic
  namespace: messaging
  labels:
    strimzi.io/cluster: kafka-cluster
spec:
  partitions: 12
  replicas: 3
  config:
    retention.ms: 604800000  # 7 days
    segment.bytes: 1073741824  # 1GB
    compression.type: lz4
    min.insync.replicas: 2
    cleanup.policy: delete
    message.timestamp.type: CreateTime
    max.message.bytes: 1048576  # 1MB
```

**Apply**:
```bash
kubectl apply -f my-topic.yaml
```

**Verify**:
```bash
# Check KafkaTopic CR status
kubectl -n messaging get kafkatopic my-topic

# Check in Kafka
kubectl -n messaging exec kafka-cluster-kafka-pool-0 -c kafka -- \
  bin/kafka-topics.sh --bootstrap-server localhost:9092 --describe --topic my-topic
```

### Topic Configuration Guidelines

**Partitions**:
- Start with `num_consumers * 2` for parallelism
- Max partitions per broker: ~4000 (Kafka recommendation)
- Cannot reduce partition count (only increase)

**Replication Factor**:
- **3** for critical topics (production)
- **2** for non-critical topics (acceptable for dev/staging)
- Must be ≤ number of brokers

**Retention**:
- **Time-based**: `retention.ms` (e.g., 604800000 = 7 days)
- **Size-based**: `retention.bytes` (e.g., 10737418240 = 10GB per partition)
- **Both**: Whichever limit is reached first

**min.insync.replicas**:
- **2** for production (with replication factor 3)
- Ensures data durability when producer uses `acks=all`

## Creating Users

### Using KafkaUser CR (Recommended)

```yaml
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaUser
metadata:
  name: my-app
  namespace: messaging
  labels:
    strimzi.io/cluster: kafka-cluster
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
        operations: [Write, Create, Describe]
        host: "*"

      # Consumer ACLs
      - resource:
          type: topic
          name: my-topic
          patternType: literal
        operations: [Read, Describe]
        host: "*"

      - resource:
          type: group
          name: my-app-group
          patternType: literal
        operations: [Read]
        host: "*"

      # Idempotent producer
      - resource:
          type: cluster
        operations: [IdempotentWrite]
        host: "*"
```

**Apply**:
```bash
kubectl apply -f my-user.yaml
```

**Obtain Credentials**:
```bash
# Username
kubectl -n messaging get kafkauser my-app -o jsonpath='{.status.username}'

# Password
kubectl -n messaging get secret my-app -o jsonpath='{.data.password}' | base64 -d
```

### ACL Patterns

**Producer** (write-only):
- `Write`, `Create`, `Describe` on topic
- `IdempotentWrite` on cluster (for exactly-once semantics)

**Consumer** (read-only):
- `Read`, `Describe` on topic
- `Read` on consumer group

**Admin** (full access):
- `All` on topic
- `All` on consumer group
- `Alter`, `Describe`, `ClusterAction` on cluster

## Operations

### View Broker Logs

```bash
# Specific broker
kubectl -n messaging logs kafka-cluster-kafka-pool-0 -c kafka -f

# All brokers (controller+broker logs)
kubectl -n messaging logs -l strimzi.io/name=kafka-pool -c kafka --tail=100
```

### Restart Brokers

**Rolling Restart** (graceful, no downtime):
```bash
kubectl -n messaging rollout restart statefulset kafka-cluster-kafka-pool
```

**Restart Single Broker**:
```bash
kubectl -n messaging delete pod kafka-cluster-kafka-pool-0
# Pod will be recreated automatically
```

### Check Cluster Status

```bash
# Kafka CR status
kubectl -n messaging get kafka kafka-cluster -o yaml

# Check conditions
kubectl -n messaging get kafka kafka-cluster -o jsonpath='{.status.conditions}'

# Cluster ID (KRaft)
kubectl -n messaging get kafka kafka-cluster -o jsonpath='{.status.clusterId}'

# Listener status
kubectl -n messaging get kafka kafka-cluster -o jsonpath='{.status.listeners}'
```

### Scale Cluster

**Add Brokers**:
```bash
# Edit KafkaNodePool
kubectl -n messaging edit kafkanodepool kafka-pool

# Change replicas: 3 → 5
spec:
  replicas: 5

# Strimzi will add 2 new brokers
# Existing data will NOT be rebalanced automatically
# Use Cruise Control for partition rebalancing
```

**Remove Brokers** (requires partition reassignment first):
```bash
# DO NOT reduce replicas directly without reassigning partitions
# Follow Kafka partition reassignment procedure first

# 1. Generate partition reassignment plan
# 2. Execute reassignment
# 3. Wait for completion
# 4. Then reduce replicas
```

### Troubleshooting

#### Broker Not Starting

**Symptoms**: Pod in CrashLoopBackOff or Error

**Diagnosis**:
```bash
# Check pod status
kubectl -n messaging get pod kafka-cluster-kafka-pool-0

# Check events
kubectl -n messaging describe pod kafka-cluster-kafka-pool-0

# Check logs
kubectl -n messaging logs kafka-cluster-kafka-pool-0 -c kafka --previous
```

**Common Causes**:
- Storage issues (PVC not bound)
- Resource limits too low (OOMKilled)
- Configuration errors (invalid broker config)
- KRaft cluster ID mismatch (corrupted metadata)

#### Under-Replicated Partitions

**Symptoms**: Alert `KafkaUnderReplicatedPartitions` firing

**Diagnosis**:
```bash
# List under-replicated partitions
kubectl -n messaging exec kafka-cluster-kafka-pool-0 -c kafka -- \
  bin/kafka-topics.sh --bootstrap-server localhost:9092 \
  --describe --under-replicated-partitions

# Check replication metrics
kubectl -n messaging exec kafka-cluster-kafka-pool-0 -c kafka -- \
  bin/kafka-broker-api-versions.sh --bootstrap-server localhost:9092
```

**Common Causes**:
- Broker down or restarting
- Network issues between brokers
- Disk I/O bottleneck
- Broker overloaded (CPU/memory)

#### Consumer Lag High

**Symptoms**: Alert `KafkaConsumerGroupLagHigh` firing

**Diagnosis**:
```bash
# Check consumer group lag
kubectl -n messaging exec kafka-cluster-kafka-pool-0 -c kafka -- \
  bin/kafka-consumer-groups.sh --bootstrap-server localhost:9092 \
  --describe --group my-consumer-group

# Check consumer group status
kubectl -n messaging exec kafka-cluster-kafka-pool-0 -c kafka -- \
  bin/kafka-consumer-groups.sh --bootstrap-server localhost:9092 \
  --describe --group my-consumer-group --state
```

**Common Causes**:
- Consumer processing too slow
- Consumer instances down
- Producer throughput > consumer throughput
- Partitions imbalanced (hotspots)

#### Disk Usage High

**Symptoms**: Alert `KafkaDiskUsageHigh` firing

**Diagnosis**:
```bash
# Check PVC usage
kubectl -n messaging exec kafka-cluster-kafka-pool-0 -c kafka -- df -h /var/lib/kafka/data-0

# Check topic sizes
kubectl -n messaging exec kafka-cluster-kafka-pool-0 -c kafka -- \
  du -sh /var/lib/kafka/data-0/kafka-log*
```

**Solutions**:
- Reduce retention time (`retention.ms`)
- Reduce retention size (`retention.bytes`)
- Delete old topics
- Scale storage (resize PVC)

## Monitoring

### Key Metrics

**Broker Health**:
- `kafka_server_replicamanager_underreplicatedpartitions` - Under-replicated partitions (should be 0)
- `kafka_controller_kafkacontroller_offlinepartitionscount` - Offline partitions (should be 0)
- `kafka_controller_kafkacontroller_activecontrollercount` - Active controller count (should be 1)

**Performance**:
- `kafka_server_brokertopicmetrics_messagesinpersec_oneminuterate` - Message ingestion rate
- `kafka_server_brokertopicmetrics_bytesinpersec_oneminuterate` - Byte ingestion rate
- `kafka_network_requestmetrics_totaltimems_mean` - Request latency

**Consumer Lag**:
- `kafka_consumergroup_lag` - Consumer group lag (messages behind)

**Resource Usage**:
- `jvm_memory_heap_used / jvm_memory_heap_max` - JVM heap usage
- `rate(jvm_gc_collection_time_ms[5m])` - GC time

### Query Examples

```promql
# Broker throughput (messages/sec)
rate(kafka_server_brokertopicmetrics_messagesinpersec_total[5m])

# Topic size
sum(kafka_log_log_size) by (topic)

# Consumer lag by group
kafka_consumergroup_lag{consumergroup="my-group"}

# Partition count per broker
count(kafka_cluster_partition_replicascount) by (pod)
```

## Backup and Disaster Recovery

### Metadata Backup (KRaft)

KRaft metadata is stored in PVCs. Back up PVCs to protect against cluster loss.

**Using VolSync** (recommended):
```yaml
apiVersion: volsync.backube/v1alpha1
kind: ReplicationSource
metadata:
  name: kafka-pool-backup
  namespace: messaging
spec:
  sourcePVC: data-0-kafka-cluster-kafka-pool-0
  trigger:
    schedule: "0 2 * * *"  # Daily at 2 AM
  restic:
    copyMethod: Snapshot
    repository: kafka-backup-secret
    # ... (see VolSync runbook for details)
```

### Data Recovery

**Scenario 1: Single Broker Failure**
- Delete failed pod
- Kubernetes recreates pod
- PVC retained, data intact
- Broker rejoins cluster automatically

**Scenario 2: Complete Cluster Loss**
- Restore PVCs from backup (all brokers)
- Redeploy Kafka cluster
- KRaft metadata restored from PVCs
- Cluster resumes from last checkpoint

**Scenario 3: Data Corruption**
- If replication factor ≥ 2, delete corrupted broker pod
- Kafka replicates data from healthy replicas
- If all replicas corrupted, restore from backup

## Performance Tuning

### Producer Configuration

**High Throughput**:
```properties
acks=1  # Wait for leader only
compression.type=lz4  # Fast compression
batch.size=32768  # 32KB batches
linger.ms=10  # Wait 10ms for batching
buffer.memory=67108864  # 64MB buffer
```

**Low Latency**:
```properties
acks=1
compression.type=none  # No compression overhead
batch.size=0  # Send immediately
linger.ms=0
```

**High Durability**:
```properties
acks=all  # Wait for all in-sync replicas
compression.type=lz4
enable.idempotence=true  # Exactly-once semantics
max.in.flight.requests.per.connection=5
retries=2147483647  # Infinite retries
```

### Consumer Configuration

**High Throughput**:
```properties
fetch.min.bytes=1048576  # 1MB min fetch
fetch.max.wait.ms=500  # Wait up to 500ms
max.poll.records=500  # Process 500 records per poll
```

**Low Latency**:
```properties
fetch.min.bytes=1  # Return immediately
fetch.max.wait.ms=100
max.poll.records=100
```

### Broker Tuning

**CPU-Bound** (high throughput):
- Increase `num.network.threads` (default: 3)
- Increase `num.io.threads` (default: 8)
- Increase `num.replica.fetchers` (default: 4)

**Disk-Bound** (slow storage):
- Decrease `num.io.threads` to reduce contention
- Increase `replica.lag.time.max.ms` to tolerate slower replication
- Use local NVMe storage (`openebs-local-nvme` instead of `rook-ceph-block`)

**Memory-Bound** (GC pressure):
- Increase JVM heap: `-Xms` and `-Xmx` in KafkaNodePool
- Tune GC: Use G1GC with aggressive `-XX:MaxGCPauseMillis`
- Increase pod memory limits

## Reference

### Component Versions
- **Kafka**: 3.9.0
- **Java**: 21 (default in Kafka 3.9.0)
- **Strimzi**: 0.48.0

### Resource Requirements

**Broker** (combined controller+broker):
- CPU: 1000m request, 2000m limit
- Memory: 2Gi request, 4Gi limit
- JVM Heap: 1024m min, 2048m max
- Storage: 100Gi per broker

**Entity Operator**:
- Topic Operator: 100m CPU, 256Mi memory
- User Operator: 100m CPU, 256Mi memory

**Kafka Exporter**:
- CPU: 100m request, 500m limit
- Memory: 128Mi request, 256Mi limit

### Network Ports

**Internal**:
- 9092: Plain listener (SCRAM-SHA-512)
- 9093: TLS listener (SCRAM-SHA-512)
- 9404: JMX Prometheus exporter

**Controller** (KRaft only):
- 9090: Controller listener (internal, not exposed)

### Storage

**PVC Naming**:
- `data-0-kafka-cluster-kafka-pool-0` (broker 0)
- `data-0-kafka-cluster-kafka-pool-1` (broker 1)
- `data-0-kafka-cluster-kafka-pool-2` (broker 2)

**Storage Class**: `rook-ceph-block` (network) or `openebs-local-nvme` (local)

### Limitations

**KRaft Mode**:
- Cannot migrate from ZooKeeper mode (requires full cluster rebuild)
- Cannot add brokers without rebalancing partitions (use Cruise Control)
- Cannot use some legacy features (e.g., `authorizer.class.name` config)

**Strimzi**:
- Topic auto-creation disabled (requires KafkaTopic CRs)
- User management via KafkaUser CRs only (no manual ACL changes)
- Cluster CA rotation requires rolling restart
```

**T9.2**: Add architecture documentation
Update `docs/architecture.md` with Kafka cluster section (if not already present):
```markdown
### Messaging Platform (Kafka)

**Kafka Version**: 3.9.0 (KRaft mode)
**Cluster**: apps
**Namespace**: `messaging`
**Operator**: Strimzi v0.48.0

Production Kafka cluster with KRaft consensus (no ZooKeeper):
- **3 nodes**: Combined controller+broker mode
- **Storage**: 100Gi per node on rook-ceph-block
- **Replication**: Default factor 3, min.insync.replicas 2
- **Authentication**: SCRAM-SHA-512
- **Encryption**: TLS on port 9093
- **Monitoring**: JMX Prometheus exporter + Kafka Exporter
- **Management**: Declarative topics (KafkaTopic CR) and users (KafkaUser CR)
```

### T10: Validation and Commit

**T10.1**: Validate Kafka manifests
```bash
# Validate Kustomization build
kustomize build kubernetes/workloads/platform/messaging/kafka

# Validate Flux Kustomization
flux build kustomization cluster-apps-messaging-kafka \
  --path ./kubernetes/workloads/platform/messaging/kafka

# YAML lint
yamllint kubernetes/workloads/platform/messaging/kafka/
```

**T10.2**: Validate PrometheusRule syntax
```bash
# Check PrometheusRule structure
yq eval '.spec.groups[].rules[]' kubernetes/workloads/platform/messaging/kafka/prometheusrule.yaml

# Validate alert expressions (requires promtool)
promtool check rules kubernetes/workloads/platform/messaging/kafka/prometheusrule.yaml
```

**T10.3**: Verify no secrets in git
```bash
# Search for potential secrets
grep -r "password\|secret\|key" kubernetes/workloads/platform/messaging/kafka/ \
  | grep -v "SecretStore\|secretStoreRef\|authentication:\|name:\|key:"
```

**T10.4**: Commit manifests to git
```bash
git add kubernetes/workloads/platform/messaging/kafka/
git add kubernetes/clusters/apps/messaging-kafka.yaml
git add docs/runbooks/kafka-cluster.md
git add docs/architecture.md

git commit -m "feat(messaging): create Kafka cluster manifests for apps cluster

- Add Kafka CR with KRaft mode (3-node combined controller+broker)
- Add KafkaNodePool CR with JBOD storage (100Gi per node)
- Add metrics ConfigMap for JMX Prometheus exporter
- Add ServiceMonitors for brokers, exporter, entity operator
- Add PrometheusRule with 12 Kafka cluster alerts
- Add example KafkaTopic and KafkaUser manifests
- Add Flux Kustomization with health checks
- Add comprehensive Kafka cluster runbook
- Document client configuration, operations, troubleshooting

Related: Story 38 (STORY-MSG-KAFKA-CLUSTER-APPS)
"
```

## Runtime Validation (Story 45)

Runtime validation will be performed in Story 45 and includes:

### Cluster Deployment Validation
- Reconcile `cluster-apps-messaging-kafka` Kustomization
- Verify Kafka CR reaches Ready condition (may take 5-10 minutes)
- Verify 3 Kafka broker pods Running: `kafka-cluster-kafka-pool-{0,1,2}`
- Verify Entity Operator pod Running: `kafka-cluster-entity-operator-*`
- Verify Kafka Exporter pod Running: `kafka-cluster-kafka-exporter-*`
- Verify NO ZooKeeper pods (KRaft mode)

### Storage Validation
- Verify 3 PVCs bound: `data-0-kafka-cluster-kafka-pool-{0,1,2}`
- Verify PVC size: 100Gi per PVC
- Verify storage class: rook-ceph-block
- Total storage: 300Gi

### KRaft Validation
- Extract cluster ID: `kubectl -n messaging get kafka kafka-cluster -o jsonpath='{.status.clusterId}'`
- Verify controller logs show KRaft consensus messages
- Verify no ZooKeeper references in broker logs

### TLS Validation
- Verify cluster CA Secret exists: `kafka-cluster-cluster-ca-cert`
- Verify TLS listener exposed on port 9093
- Test TLS connection: `openssl s_client -connect kafka-cluster-kafka-bootstrap.messaging.svc.cluster.local:9093`

### Authentication Validation
- Apply example KafkaUser: `kubectl apply -f examples/kafkauser-example.yaml`
- Wait for Secret creation: `kubectl -n messaging get secret test-user`
- Extract credentials: username and password
- Verify SCRAM-SHA-512 authentication configured on listeners

### E2E Produce/Consume Test
- Apply example KafkaTopic: `kubectl apply -f examples/kafkatopic-example.yaml`
- Wait for topic creation (check in Kafka)
- Deploy test client pod with Kafka tools
- Produce 100 test messages with SCRAM-SHA-512 auth
- Consume messages and verify count matches
- Verify checksums or message content
- Cleanup: delete test-topic, test-user, test pod

### Metrics Validation
- Verify ServiceMonitors created and scraping
- Query Victoria Metrics for Kafka metrics:
  - `kafka_server_replicamanager_underreplicatedpartitions` (should be 0)
  - `kafka_controller_kafkacontroller_activecontrollercount` (should be 1)
  - `kafka_server_brokertopicmetrics_messagesinpersec_total`
- Port-forward to Kafka broker metrics endpoint: `curl http://localhost:9404/metrics | grep kafka_`

### Alert Validation
- Verify PrometheusRule loaded in Victoria Metrics
- Check alert definitions exist (12 alerts)
- Optionally simulate broker down to test alerting

## Definition of Done

- [x] **AC1-AC11 met**: All manifests created, validated, and committed to git
- [x] **Local validation passed**: `flux build`, `kustomize build`, `yamllint` all succeed
- [x] **No secrets in git**: Grep search confirms no hardcoded credentials
- [x] **Documentation complete**: Runbook with client config, operations, troubleshooting
- [x] **Manifests committed**: Git commit with descriptive message
- [ ] **Runtime validation**: Deferred to Story 45 (deployment, E2E test, metrics verification)

## Design Notes

### KRaft Architecture

**What is KRaft?**
- **Kafka Raft**: Kafka's internal consensus protocol (replacement for ZooKeeper)
- **Production-ready**: Generally available since Kafka 3.3.1
- **Simplified**: No external dependencies (ZooKeeper removed)
- **Performant**: Lower latency, higher throughput vs ZooKeeper mode

**Node Roles**:
- **Controller**: Manages cluster metadata (topics, partitions, ACLs, configs)
- **Broker**: Handles data plane (message storage, replication, client requests)
- **Combined**: Single node acts as both controller and broker (our configuration)

**Why Combined Mode?**
- Resource efficient: No dedicated controller nodes
- Simpler configuration: Single node pool
- Suitable for small-to-medium clusters (< 10 brokers)
- Trade-off: Controllers share resources with brokers (acceptable for our use case)

**When to Use Separated Mode?**
- Large clusters (10+ brokers)
- High metadata churn (many topic/partition changes)
- Dedicated controller resources for stability

**KRaft Quorum**:
- 3-node quorum: Tolerates 1 node failure
- Metadata stored in PVCs (persistent)
- Quorum loss = cluster unavailable (need 2/3 nodes for quorum)

### Storage Strategy

**JBOD vs Single Volume**:
- **JBOD** (Just a Bunch Of Disks): Multiple volumes per broker
  - Better performance (parallel I/O)
  - Complex failure scenarios
- **Single volume** (our configuration): Simpler, sufficient for most workloads

**Storage Class Choice**:
- **rook-ceph-block**: Network storage, shared across nodes
  - Pros: Flexible (pod can move to any node), easy resize
  - Cons: Network overhead, higher latency
- **openebs-local-nvme**: Local NVMe storage
  - Pros: Very fast, low latency
  - Cons: Pod pinned to node, no migration

**Sizing**:
- 100Gi per broker = 300Gi total
- With replication factor 3, effective capacity = 100Gi
- Example: 10GB topic with RF=3 uses 30GB total (10GB per replica)

### Listener Configuration

**Plain Listener (Port 9092)**:
- No TLS encryption (plaintext)
- SCRAM-SHA-512 authentication required
- Use for internal cluster communication (lower overhead)

**TLS Listener (Port 9093)**:
- TLS encryption (encrypted)
- SCRAM-SHA-512 authentication required
- Use for sensitive data or external access

**Why SCRAM-SHA-512?**
- Username/password authentication
- Credentials stored in Kubernetes Secrets (managed by Strimzi)
- Salted hashing (secure)
- Easier than TLS mutual auth (no client certificates)

**Why Not OAuth2?**
- Requires Keycloak or similar identity provider
- More complex setup
- Overkill for internal cluster communication
- Can add later if needed

### Replication Configuration

**Replication Factor 3**:
- Each partition replicated to 3 brokers
- Tolerates 2 broker failures (with proper acks)
- Industry standard for production

**min.insync.replicas: 2**:
- Producer with `acks=all` waits for 2 replicas to acknowledge
- Ensures durability: Data written to leader + 1 follower
- Prevents data loss on single broker failure

**acks Setting (Producer)**:
- `acks=0`: Fire and forget (no durability guarantee)
- `acks=1`: Leader acknowledges (data loss if leader fails before replication)
- `acks=all`: All in-sync replicas acknowledge (strongest durability)

**ISR (In-Sync Replicas)**:
- Replicas caught up with leader (within `replica.lag.time.max.ms`)
- Producer with `acks=all` waits for ISR (not all replicas)
- If ISR shrinks below `min.insync.replicas`, producer fails (prevents data loss)

### Resource Allocation

**Broker Resources**:
- CPU: 1000m request, 2000m limit
  - 1 core minimum, 2 cores burst
  - Kafka is multi-threaded (benefits from multiple cores)
- Memory: 2Gi request, 4Gi limit
  - JVM heap: 1024m-2048m (50% of request)
  - Off-heap: Page cache (OS uses remaining memory for disk caching)

**Why 50% Heap?**
- Kafka heavily uses OS page cache for zero-copy reads
- Page cache = file data cached in memory (faster than disk)
- More off-heap memory = better page cache performance

**JVM Tuning**:
- G1GC: Low-latency garbage collector (pauses < 20ms)
- Heap dump on OOM: Captures heap when memory exhausted (debugging)

**Entity Operator Resources**:
- Topic Operator: 100m CPU, 256Mi memory
- User Operator: 100m CPU, 256Mi memory
- Lightweight operators (low resource usage)

### Monitoring Strategy

**JMX Prometheus Exporter**:
- Kafka exposes metrics via JMX (Java Management Extensions)
- JMX exporter converts JMX → Prometheus format
- Metrics scraped by Victoria Metrics on infra cluster

**Kafka Exporter**:
- Separate exporter for consumer group metrics
- Tracks consumer lag (messages behind)
- Critical for consumer monitoring

**Key Metrics**:
- **Under-replicated partitions**: Should be 0 (healthy replication)
- **Offline partitions**: Should be 0 (all partitions available)
- **Active controller**: Should be 1 (exactly one controller elected)
- **Request handler idle**: Should be > 20% (broker not overloaded)
- **Consumer lag**: Monitor per consumer group (should be low)

**Alerts**:
- 12 PrometheusRule alerts covering availability, replication, performance
- Alert severity: Critical (broker down) → Warning (high GC time)

### Security Considerations

**SCRAM-SHA-512 Authentication**:
- Credentials stored in Secrets (base64-encoded)
- Strimzi manages password generation and rotation
- Never log passwords (Kafka redacts auth info)

**TLS Encryption**:
- Cluster CA managed by Strimzi (auto-rotation)
- Client must trust CA certificate
- TLS cipher suites: Modern, secure algorithms

**ACLs (Access Control Lists)**:
- Managed via KafkaUser CRs (declarative)
- Principle of least privilege (grant minimum required permissions)
- Deny by default (no ACL = no access)

**Pod Security**:
- Run as non-root user (uid 1001)
- fsGroup: 0 (required for Kafka log directory permissions)
- No privileged containers

### Limitations

**KRaft Limitations**:
- Cannot migrate from ZooKeeper mode (requires cluster rebuild)
- Cannot downgrade to ZooKeeper mode
- Some features not yet supported (e.g., JBOD with different storage classes)

**Strimzi Limitations**:
- Topic auto-creation disabled (requires KafkaTopic CRs)
- Cannot manage topics outside Strimzi (manual topics not recommended)
- Cluster CA rotation requires rolling restart

**Operational Limitations**:
- Scaling up requires partition rebalancing (manual step)
- Scaling down requires partition reassignment (complex procedure)
- Cannot reduce partition count (only increase)

### Performance Considerations

**Throughput**:
- Combined mode: ~50K msg/sec per broker (with replication)
- Network bound: 1 Gbps network → ~125 MB/s per broker
- Disk bound: Depends on storage backend (NVMe > SSD > HDD)

**Latency**:
- Produce latency: 5-50ms (p99) with `acks=all`
- Consume latency: <1ms (page cache hit) to 10ms (disk read)
- End-to-end latency: 10-100ms (depends on producer/consumer config)

**Bottlenecks**:
- Network: Inter-broker replication bandwidth
- Disk: Write throughput (log segments)
- CPU: Compression, decompression, protocol handling
- Memory: Page cache size (affects read performance)

### Disaster Recovery

**Metadata Backup**:
- KRaft metadata stored in PVCs
- Backup PVCs to protect against cluster loss
- Use VolSync for scheduled PVC backups

**Data Recovery**:
- Single broker failure: Kafka replicates from other replicas (automatic)
- Multiple broker failure: If quorum intact, cluster survives
- Complete cluster loss: Restore PVCs from backup, redeploy

**RPO/RTO**:
- RPO (Recovery Point Objective): Depends on backup frequency (e.g., daily = 24h RPO)
- RTO (Recovery Time Objective): ~15 minutes (PVC restore + cluster start)

### Testing Strategy

**Unit Tests** (Manifest Validation):
- `flux build kustomization` - Flux Kustomization syntax
- `kustomize build` - Kustomize resource composition
- `yamllint` - YAML syntax
- `promtool check rules` - PrometheusRule validation

**Integration Tests** (Story 45):
- Deploy Kafka cluster to apps cluster
- Verify all pods Running
- Verify PVCs bound
- Verify ServiceMonitors scraping

**E2E Tests** (Story 45):
- Create test topic (3 partitions, 3 replicas)
- Create test user (SCRAM-SHA-512)
- Produce 100 messages with authentication
- Consume messages and verify count
- Delete test resources and verify cleanup

**Performance Tests** (future):
- Benchmark throughput (messages/sec)
- Benchmark latency (p50, p99, p999)
- Benchmark consumer lag under load

### Future Enhancements

1. **Kafka Connect**: Data integration pipelines (STORY-MSG-KAFKA-CONNECT)
2. **Schema Registry**: Confluent Schema Registry for Avro/Protobuf (STORY-MSG-SCHEMA-REGISTRY)
3. **Cruise Control**: Automated partition rebalancing and throttling
4. **MirrorMaker 2**: Multi-cluster replication for DR
5. **Monitoring dashboards**: Pre-built Grafana dashboards
6. **Auto-scaling**: HPA based on consumer lag
7. **S3 tiered storage**: Offload old log segments to S3 (Kafka 3.6+ feature)

## Change Log

| Date       | Version | Description                                                                 | Author |
|------------|---------|-----------------------------------------------------------------------------|--------|
| 2025-10-26 | 3.0     | v3.0 manifests-first refinement: separate manifest creation from deployment | Claude |
| 2025-10-23 | 0.1     | Initial draft with KRaft mode support                                       | Sarah  |
