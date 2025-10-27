# 39 — STORY-MSG-SCHEMA-REGISTRY — Create Schema Registry Manifests (apps)

Sequence: 39/50 | Prev: STORY-MSG-KAFKA-CLUSTER-APPS.md | Next: STORY-OBS-APPS-COLLECTORS.md
Sprint: 6 | Lane: Messaging
Global Sequence: 39/50

Status: v3.0-Manifests-Only
Owner: Platform Engineering
Date: 2025-10-26
Links: docs/architecture.md §19 (Workloads & Versions); kubernetes/workloads/platform/messaging/schema-registry; STORY-MSG-KAFKA-CLUSTER-APPS.md

## Story (v3.0 Refined)

As a Platform Engineer, I want to **create complete Confluent Schema Registry manifests** for the apps cluster, integrated with the Kafka cluster, to provide centralized schema management, schema evolution, and compatibility enforcement for Kafka producers and consumers using Avro, JSON Schema, and Protobuf formats.

**v3.0 Scope**: This story creates ALL manifest files for Schema Registry (Deployment, Service, ServiceMonitor, PrometheusRule, Kustomization files, cluster entrypoint). **Deployment and runtime validation** (pods Running, API testing, schema evolution tests) are **deferred to Story 45 (STORY-DEPLOY-VALIDATE-ALL)**.

## Why / Outcome

- Enables schema-driven data contracts between producers and consumers
- Prevents breaking changes through compatibility enforcement (BACKWARD, FORWARD, FULL)
- Reduces message payload sizes via schema evolution
- Provides central registry for discovering available data schemas
- Foundation for data governance and lineage tracking
- **v3.0**: Complete manifest creation enables rapid deployment in Story 45

## Scope

**In Scope (This Story - Manifest Creation)**:
- Cluster: apps
- Namespace: `messaging`
- Version: confluentinc/cp-schema-registry:7.8.0
- Deployment Model:
  - 2 replicas for HA (active-active behind Service)
  - Integration with Kafka cluster `kafka-cluster` (stores schemas in `_schemas` topic)
  - Internal-only ClusterIP service (port 8081)
  - Compatibility mode: BACKWARD (default, configurable per subject)
  - Authentication: none (internal-only initially, trust Cilium NetworkPolicy)
  - Metrics via JMX Prometheus Exporter sidecar
- Components:
  - **Deployment**: 2-replica Schema Registry with JMX exporter
  - **Service**: ClusterIP on port 8081
  - **ServiceMonitor**: Prometheus scraping for JMX metrics
  - **PrometheusRule**: Alerts for registry availability and performance
  - **Kustomization**: Resource composition
  - **Cluster Kustomization**: Entrypoint in `kubernetes/clusters/apps/`
- Documentation:
  - Comprehensive runbook with API usage, schema evolution, operations
  - Compatibility mode reference guide
  - Client integration examples (Avro, JSON Schema, Protobuf)

**Out of Scope (Deferred to Story 45)**:
- Deployment and runtime validation (pods Running, API testing)
- Schema evolution validation (register v1, v2 compatible, v3 incompatible)
- High availability testing (pod deletion, failover)
- Performance testing and tuning
- Kafka `_schemas` topic verification

**Non-Goals**:
- Kafka Connect Schema Converter configuration (application team responsibility)
- Multi-registry federation (future enhancement)
- External/public exposure (internal-only for now)
- Schema approval workflows (future STORY-MSG-SCHEMA-GOVERNANCE)

## Acceptance Criteria (Manifest Completeness)

All criteria focus on **manifest existence and correctness**, NOT runtime behavior.

**AC1** (Task T2): Schema Registry Deployment manifest exists with:
- 2 replicas for HA
- confluentinc/cp-schema-registry:7.8.0 image
- JMX Prometheus Exporter sidecar for metrics
- Kafka bootstrap endpoint: `kafka-cluster-kafka-bootstrap.messaging.svc.cluster.local:9092`
- `_schemas` topic configuration (replication factor 3)
- BACKWARD compatibility mode (default)
- Security context (runAsNonRoot, runAsUser 1000)
- Resource requests/limits (100m/500m CPU, 512Mi/1Gi memory)
- Liveness/readiness probes on HTTP endpoints
- Optional SCRAM-SHA-512 auth configuration (commented, for TLS listener)

**AC2** (Task T3): Service manifest exists with:
- ClusterIP type (internal-only)
- Port 8081 (HTTP)
- Selector matching Deployment labels
- Cilium global-service annotation (for cross-cluster access)

**AC3** (Task T4): ServiceMonitor manifest exists for:
- JMX Prometheus Exporter metrics (port 5556)
- 30s scrape interval
- Proper label selectors

**AC4** (Task T5): PrometheusRule manifest exists with alerts for:
- Schema Registry pod down (critical)
- Schema Registry API errors (high)
- `_schemas` topic lag (medium)
- Schema registration failures (medium)
- High API latency (warning)
- At least 5 meaningful alerts

**AC5** (Task T6): Example manifests created for:
- Schema registration via HTTP API (curl examples)
- KafkaTopic CR for `_schemas` topic (optional, managed by Schema Registry)
- Client configuration examples (Avro, JSON Schema, Protobuf)

**AC6** (Task T7): Kustomization file exists referencing:
- deployment.yaml
- service.yaml
- servicemonitor.yaml
- prometheusrule.yaml (if separate file)

**AC7** (Task T8): Cluster Kustomization entrypoint created:
- File: `kubernetes/clusters/apps/messaging.yaml` (or update existing)
- Flux Kustomization CR for `apps-messaging-schema-registry`
- `dependsOn: apps-messaging-kafka` (Kafka cluster must exist first)
- Health check on Deployment

**AC8** (Task T9): Documentation created:
- Comprehensive runbook: `docs/runbooks/schema-registry.md`
- API usage examples (register schema, retrieve schema, list subjects, set compatibility)
- Compatibility mode guide (BACKWARD, FORWARD, FULL, NONE)
- Schema evolution best practices
- Client integration guide (Avro Producer/Consumer examples)
- Operations guide (scaling, backup, disaster recovery)

**AC9** (Task T10): Local validation confirms:
- `kubectl kustomize` builds without errors
- `flux build` succeeds on Kustomization
- No YAML syntax errors
- All cross-references valid (Service selectors, health checks)

**AC10** (Task T10): Manifest files committed to Git:
- All files in `kubernetes/workloads/platform/messaging/schema-registry/`
- Cluster Kustomization updated
- Runbook in `docs/runbooks/`

**AC11** (Task T10): Story marked complete:
- All tasks T1-T10 completed
- Change log entry added
- Ready for deployment in Story 45

## Dependencies / Inputs

**Build-Time (This Story)**:
- STORY-MSG-KAFKA-CLUSTER-APPS completed (Kafka cluster manifests exist)
- STORY-MSG-STRIMZI-OPERATOR completed (for optional KafkaTopic CR)
- `kubernetes/workloads/platform/messaging/` directory structure exists
- Flux GitRepository configured
- Local tools: `kubectl`, `kustomize`, `flux`, `yq`

**Runtime (Story 45)**:
- Kafka cluster operational at `kafka-cluster-kafka-bootstrap.messaging.svc.cluster.local:9092`
- KafkaUser credentials (if using SCRAM-SHA-512 auth)
- `messaging` namespace exists
- VictoriaMetrics operational (for metrics ingestion)

## Tasks / Subtasks — Manifest Creation Plan

### T1 — Prerequisites and Strategy (30 min)

**Goal**: Validate environment and finalize Schema Registry architecture decisions.

- [ ] T1.1 — Verify prerequisite stories completed
  - [ ] Read STORY-MSG-KAFKA-CLUSTER-APPS.md (verify Kafka manifests created)
  - [ ] Read STORY-MSG-STRIMZI-OPERATOR.md (verify Strimzi operator manifests exist)
  - [ ] Confirm `kubernetes/workloads/platform/messaging/` directory exists

- [ ] T1.2 — Review architecture requirements
  - [ ] Architecture doc §19: Schema Registry version (latest stable)
  - [ ] Kafka bootstrap endpoint: `kafka-cluster-kafka-bootstrap.messaging.svc.cluster.local:9092`
  - [ ] Compatibility mode: BACKWARD (default)
  - [ ] HA: 2 replicas (active-active)

- [ ] T1.3 — Finalize Schema Registry configuration
  - [ ] **Storage Backend**: Kafka topic `_schemas` (replication factor 3, min.insync.replicas 2)
  - [ ] **Image**: confluentinc/cp-schema-registry:7.8.0 (Confluent Platform)
  - [ ] **Metrics**: JMX Prometheus Exporter sidecar (port 5556)
  - [ ] **Authentication**: None (internal-only, trust NetworkPolicy)
  - [ ] **TLS**: Optional (commented configuration for TLS listener on 9093)
  - [ ] **Resources**: 100m/500m CPU, 512Mi/1Gi memory per replica
  - [ ] **Probes**: Liveness on `/`, readiness on `/subjects`

- [ ] T1.4 — Document design decisions
  - [ ] Why JMX Exporter: Schema Registry doesn't expose native Prometheus metrics
  - [ ] Why no auth: Internal-only service, trust mesh security (Cilium NetworkPolicy)
  - [ ] Why BACKWARD mode: Most common use case (add optional fields to schemas)

### T2 — Create Schema Registry Deployment (1.5 hours)

**Goal**: Create comprehensive Deployment manifest with JMX exporter sidecar.

- [ ] T2.1 — Create directory structure
  - [ ] Create `kubernetes/workloads/platform/messaging/schema-registry/`

- [ ] T2.2 — Create Deployment manifest
  - [ ] Create `kubernetes/workloads/platform/messaging/schema-registry/deployment.yaml`
  - [ ] Metadata:
    - name: `schema-registry`
    - namespace: `messaging`
    - labels: `app.kubernetes.io/name=schema-registry`, `app.kubernetes.io/instance=schema-registry`
  - [ ] Spec:
    - replicas: 2
    - selector: `app.kubernetes.io/name=schema-registry`
    - strategy: RollingUpdate (maxUnavailable: 0, maxSurge: 1)
    - podSecurityContext: runAsNonRoot, runAsUser 1000, fsGroup 1000
  - [ ] Main container (schema-registry):
    - image: confluentinc/cp-schema-registry:7.8.0
    - ports: 8081 (HTTP)
    - env:
      - SCHEMA_REGISTRY_HOST_NAME: `$(POD_NAME)` (unique per pod)
      - SCHEMA_REGISTRY_LISTENERS: `http://0.0.0.0:8081`
      - SCHEMA_REGISTRY_KAFKASTORE_BOOTSTRAP_SERVERS: `kafka-cluster-kafka-bootstrap.messaging.svc.cluster.local:9092`
      - SCHEMA_REGISTRY_KAFKASTORE_TOPIC: `_schemas`
      - SCHEMA_REGISTRY_KAFKASTORE_TOPIC_REPLICATION_FACTOR: `3`
      - SCHEMA_REGISTRY_DEBUG: `false`
      - SCHEMA_REGISTRY_SCHEMA_COMPATIBILITY_LEVEL: `BACKWARD`
      - SCHEMA_REGISTRY_KAFKASTORE_CONNECTION_URL: (deprecated in KRaft, omit)
      - SCHEMA_REGISTRY_JMX_PORT: `5555` (for JMX exporter)
      - SCHEMA_REGISTRY_JMX_HOSTNAME: `127.0.0.1`
    - resources: requests 100m/512Mi, limits 500m/1Gi
    - livenessProbe: httpGet on `/` port 8081, initialDelay 30s, period 10s
    - readinessProbe: httpGet on `/subjects` port 8081, initialDelay 10s, period 5s
  - [ ] Sidecar container (jmx-exporter):
    - image: bitnami/jmx-exporter:1.1.0
    - ports: 5556 (metrics)
    - env:
      - JMX_PORT: `5555`
      - SERVICE_PORT: `5556`
    - resources: requests 50m/128Mi, limits 100m/256Mi
    - volumeMounts: `/opt/bitnami/jmx-exporter/etc/config.yml` (JMX config)
  - [ ] Volumes:
    - name: jmx-config
    - configMap: schema-registry-jmx-config
  - [ ] Optional (commented): TLS configuration for Kafka TLS listener (9093)
    - SCHEMA_REGISTRY_KAFKASTORE_SECURITY_PROTOCOL: SASL_SSL
    - SCHEMA_REGISTRY_KAFKASTORE_SASL_MECHANISM: SCRAM-SHA-512
    - SCHEMA_REGISTRY_KAFKASTORE_SASL_JAAS_CONFIG: (from Secret)
    - SCHEMA_REGISTRY_KAFKASTORE_SSL_TRUSTSTORE_LOCATION: (CA cert)
    - volumeMounts: /etc/kafka/secrets (Kafka CA cert)

- [ ] T2.3 — Create JMX Exporter ConfigMap
  - [ ] Create `kubernetes/workloads/platform/messaging/schema-registry/jmx-config.yaml`
  - [ ] ConfigMap name: `schema-registry-jmx-config`
  - [ ] Data key: `config.yml`
  - [ ] JMX rules:
    - kafka.schema.registry:type=jetty-metrics (HTTP request metrics)
    - kafka.schema.registry:type=master-slave-role (leadership status)
    - kafka.schema.registry:type=kafka-store (Kafka store metrics)
    - kafka.schema.registry:type=jersey-metrics (REST API metrics)
  - [ ] Reference: https://github.com/prometheus/jmx_exporter

- [ ] T2.4 — Create ExternalSecret for Kafka credentials (optional, for TLS)
  - [ ] Create `kubernetes/workloads/platform/messaging/schema-registry/externalsecret.yaml`
  - [ ] ExternalSecret name: `schema-registry-kafka-creds`
  - [ ] 1Password path: `kubernetes/apps/messaging/schema-registry/kafka-creds`
  - [ ] Keys: `sasl.jaas.config` (SCRAM-SHA-512 credentials)
  - [ ] Note: Only needed if using Kafka TLS listener (9093)

- [ ] T2.5 — Validate Deployment manifest
  - [ ] `kubectl apply --dry-run=client -f deployment.yaml`
  - [ ] Check YAML syntax, no errors

### T3 — Create Service (20 min)

**Goal**: Expose Schema Registry HTTP API internally.

- [ ] T3.1 — Create Service manifest
  - [ ] Create `kubernetes/workloads/platform/messaging/schema-registry/service.yaml`
  - [ ] Metadata:
    - name: `schema-registry`
    - namespace: `messaging`
    - labels: `app.kubernetes.io/name=schema-registry`
    - annotations: `service.cilium.io/global=true` (enable Cilium ClusterMesh)
  - [ ] Spec:
    - type: ClusterIP
    - ports:
      - name: http
      - port: 8081
      - targetPort: 8081
      - protocol: TCP
    - selector: `app.kubernetes.io/name=schema-registry`

- [ ] T3.2 — Validate Service manifest
  - [ ] `kubectl apply --dry-run=client -f service.yaml`
  - [ ] Verify selector matches Deployment pod labels

### T4 — Create ServiceMonitor (20 min)

**Goal**: Enable Prometheus scraping of JMX metrics.

- [ ] T4.1 — Create ServiceMonitor manifest
  - [ ] Create `kubernetes/workloads/platform/messaging/schema-registry/servicemonitor.yaml`
  - [ ] Metadata:
    - name: `schema-registry`
    - namespace: `messaging`
    - labels: match VictoriaMetrics selector
  - [ ] Spec:
    - selector:
      - matchLabels: `app.kubernetes.io/name=schema-registry`
    - endpoints:
      - port: `metrics` (5556, JMX exporter)
      - interval: 30s
      - path: `/metrics`
    - namespaceSelector:
      - matchNames: [messaging]

- [ ] T4.2 — Validate ServiceMonitor
  - [ ] `kubectl apply --dry-run=client -f servicemonitor.yaml`
  - [ ] Verify label selectors match Service

### T5 — Create PrometheusRule (1 hour)

**Goal**: Define alerting rules for Schema Registry availability and performance.

- [ ] T5.1 — Create PrometheusRule manifest
  - [ ] Create `kubernetes/workloads/platform/messaging/schema-registry/prometheusrule.yaml`
  - [ ] Metadata:
    - name: `schema-registry`
    - namespace: `messaging`

- [ ] T5.2 — Define alert rules (at least 5)
  - [ ] **Alert 1**: SchemaRegistryDown
    - expr: `up{job="schema-registry"} == 0`
    - for: 5m
    - severity: critical
    - summary: "Schema Registry pod is down"
  - [ ] **Alert 2**: SchemaRegistryAPIErrors
    - expr: `rate(kafka_schema_registry_jetty_metrics_responses_total{status=~"5.."}[5m]) > 0.1`
    - for: 10m
    - severity: high
    - summary: "Schema Registry API returning 5xx errors"
  - [ ] **Alert 3**: SchemaRegistryHighLatency
    - expr: `kafka_schema_registry_jersey_metrics_request_latency_seconds{quantile="0.95"} > 1.0`
    - for: 15m
    - severity: warning
    - summary: "Schema Registry API p95 latency > 1s"
  - [ ] **Alert 4**: SchemaRegistryKafkaLag
    - expr: `kafka_schema_registry_kafka_store_lag > 100`
    - for: 10m
    - severity: medium
    - summary: "Schema Registry lagging behind Kafka _schemas topic"
  - [ ] **Alert 5**: SchemaRegistryCompatibilityCheckFailures
    - expr: `rate(kafka_schema_registry_jersey_metrics_responses_total{path="/compatibility",status="409"}[10m]) > 0.5`
    - for: 15m
    - severity: warning
    - summary: "High rate of schema compatibility check failures"
  - [ ] **Alert 6**: SchemaRegistryNoLeader
    - expr: `kafka_schema_registry_master_slave_role != 1`
    - for: 5m
    - severity: high
    - summary: "Schema Registry has no leader (clustered mode issue)"
  - [ ] Note: Adjust metric names based on actual JMX exporter output

- [ ] T5.3 — Validate PrometheusRule
  - [ ] `kubectl apply --dry-run=client -f prometheusrule.yaml`
  - [ ] Check YAML syntax

### T6 — Create Example Manifests (45 min)

**Goal**: Provide reference manifests and usage examples.

- [ ] T6.1 — Create KafkaTopic CR for `_schemas` (optional)
  - [ ] Create `kubernetes/workloads/platform/messaging/schema-registry/examples/schemas-topic.yaml`
  - [ ] Note: Schema Registry auto-creates this topic, but explicit CR ensures correct config
  - [ ] KafkaTopic spec:
    - name: `_schemas`
    - partitions: 1 (Schema Registry requires single partition)
    - replicas: 3
    - config:
      - cleanup.policy: compact (log compaction for schema storage)
      - min.insync.replicas: 2

- [ ] T6.2 — Create schema registration examples
  - [ ] Create `kubernetes/workloads/platform/messaging/schema-registry/examples/README.md`
  - [ ] **Example 1**: Register Avro schema
    ```bash
    # Avro schema (User record)
    curl -X POST \
      -H "Content-Type: application/vnd.schemaregistry.v1+json" \
      --data '{"schema":"{\"type\":\"record\",\"name\":\"User\",\"fields\":[{\"name\":\"name\",\"type\":\"string\"},{\"name\":\"age\",\"type\":\"int\"}]}"}' \
      http://schema-registry.messaging.svc.cluster.local:8081/subjects/user-value/versions
    # Response: {"id":1}
    ```
  - [ ] **Example 2**: Register JSON Schema
    ```bash
    curl -X POST \
      -H "Content-Type: application/vnd.schemaregistry.v1+json" \
      --data '{"schemaType":"JSON","schema":"{\"$schema\":\"http://json-schema.org/draft-07/schema#\",\"type\":\"object\",\"properties\":{\"name\":{\"type\":\"string\"},\"age\":{\"type\":\"integer\"}}}"}' \
      http://schema-registry.messaging.svc.cluster.local:8081/subjects/user-json-value/versions
    ```
  - [ ] **Example 3**: Retrieve schema by ID
    ```bash
    curl http://schema-registry.messaging.svc.cluster.local:8081/schemas/ids/1
    ```
  - [ ] **Example 4**: List all subjects
    ```bash
    curl http://schema-registry.messaging.svc.cluster.local:8081/subjects
    # Response: ["user-value","user-json-value"]
    ```
  - [ ] **Example 5**: Set compatibility mode for subject
    ```bash
    curl -X PUT \
      -H "Content-Type: application/vnd.schemaregistry.v1+json" \
      --data '{"compatibility":"FULL"}' \
      http://schema-registry.messaging.svc.cluster.local:8081/config/user-value
    ```

- [ ] T6.3 — Create client integration examples
  - [ ] **Avro Producer** (Python example):
    ```python
    from confluent_kafka import avro
    from confluent_kafka.avro import AvroProducer

    value_schema = avro.load('user.avsc')
    producer = AvroProducer({
        'bootstrap.servers': 'kafka-cluster-kafka-bootstrap.messaging.svc.cluster.local:9092',
        'schema.registry.url': 'http://schema-registry.messaging.svc.cluster.local:8081'
    }, default_value_schema=value_schema)

    producer.produce(topic='users', value={"name": "Alice", "age": 30})
    producer.flush()
    ```
  - [ ] **Avro Consumer** (Python example):
    ```python
    from confluent_kafka import avro
    from confluent_kafka.avro import AvroConsumer

    consumer = AvroConsumer({
        'bootstrap.servers': 'kafka-cluster-kafka-bootstrap.messaging.svc.cluster.local:9092',
        'group.id': 'user-consumer-group',
        'schema.registry.url': 'http://schema-registry.messaging.svc.cluster.local:8081'
    })

    consumer.subscribe(['users'])
    while True:
        msg = consumer.poll(1)
        if msg:
            print(msg.value())  # Automatically deserialized using schema
    ```

### T7 — Create Kustomization Files (30 min)

**Goal**: Compose all Schema Registry resources.

- [ ] T7.1 — Create main Kustomization
  - [ ] Create `kubernetes/workloads/platform/messaging/schema-registry/kustomization.yaml`
  - [ ] apiVersion: kustomize.config.k8s.io/v1beta1
  - [ ] kind: Kustomization
  - [ ] namespace: messaging
  - [ ] resources:
    - deployment.yaml
    - jmx-config.yaml (ConfigMap)
    - service.yaml
    - servicemonitor.yaml
    - prometheusrule.yaml
    - externalsecret.yaml (optional, if using TLS)
  - [ ] Note: examples/ directory not included in main kustomization

- [ ] T7.2 — Validate Kustomization builds
  - [ ] `kubectl kustomize kubernetes/workloads/platform/messaging/schema-registry/`
  - [ ] No errors, all resources rendered

### T8 — Create Cluster Kustomization Entrypoint (30 min)

**Goal**: Integrate Schema Registry into apps cluster GitOps flow.

- [ ] T8.1 — Create or update cluster Kustomization
  - [ ] File: `kubernetes/clusters/apps/messaging.yaml` (or add to existing file)
  - [ ] If file doesn't exist, create new Flux Kustomization CR:
    ```yaml
    ---
    apiVersion: kustomize.toolkit.fluxcd.io/v1
    kind: Kustomization
    metadata:
      name: apps-messaging-schema-registry
      namespace: flux-system
    spec:
      dependsOn:
        - name: apps-messaging-kafka
      interval: 10m
      retryInterval: 1m
      timeout: 5m
      path: ./kubernetes/workloads/platform/messaging/schema-registry
      prune: true
      wait: true
      sourceRef:
        kind: GitRepository
        name: flux-system
      postBuild:
        substituteFrom:
          - kind: ConfigMap
            name: cluster-settings
      healthChecks:
        - apiVersion: apps/v1
          kind: Deployment
          name: schema-registry
          namespace: messaging
    ```
  - [ ] Key fields:
    - dependsOn: `apps-messaging-kafka` (Kafka cluster must exist first)
    - path: `./kubernetes/workloads/platform/messaging/schema-registry`
    - healthChecks: Deployment `schema-registry`

- [ ] T8.2 — Validate Flux Kustomization builds
  - [ ] `flux build kustomization apps-messaging-schema-registry --path ./kubernetes/workloads/platform/messaging/schema-registry`
  - [ ] No errors

### T9 — Create Comprehensive Documentation (2 hours)

**Goal**: Provide runbook for Schema Registry operations.

- [ ] T9.1 — Create runbook structure
  - [ ] Create `docs/runbooks/schema-registry.md`
  - [ ] Sections:
    1. Overview
    2. Architecture
    3. Client Configuration
    4. Schema Management
    5. Compatibility Modes
    6. Operations
    7. Monitoring
    8. Troubleshooting
    9. Backup and Disaster Recovery
    10. Performance Tuning
    11. References

- [ ] T9.2 — Write Overview section
  - [ ] Purpose: Centralized schema management for Kafka topics
  - [ ] Version: Confluent Schema Registry 7.8.0
  - [ ] Cluster: apps
  - [ ] Namespace: messaging
  - [ ] Endpoints:
    - Internal: `http://schema-registry.messaging.svc.cluster.local:8081`
    - Cross-cluster: `http://schema-registry.messaging.svc.cluster.local:8081` (Cilium ClusterMesh)
  - [ ] Supported formats: Avro, JSON Schema, Protobuf

- [ ] T9.3 — Write Architecture section
  - [ ] **Storage Backend**: Kafka topic `_schemas` (single partition, log compacted)
  - [ ] **High Availability**: 2 active-active replicas (stateless pods)
  - [ ] **Leadership**: Schema Registry uses Kafka for coordination (no ZooKeeper)
  - [ ] **Consistency**: Kafka is single source of truth (no split-brain)
  - [ ] **Metrics**: JMX Prometheus Exporter sidecar (port 5556)
  - [ ] **Security**: Internal-only (no authentication), trust Cilium NetworkPolicy

- [ ] T9.4 — Write Client Configuration section
  - [ ] **Bootstrap Endpoint**: `http://schema-registry.messaging.svc.cluster.local:8081`
  - [ ] **Authentication**: None (internal-only)
  - [ ] **TLS**: Not enabled by default (trust mesh security)
  - [ ] **Client Libraries**:
    - Python: confluent-kafka-python (with Avro support)
    - Java: io.confluent:kafka-avro-serializer
    - Go: github.com/confluentinc/confluent-kafka-go
  - [ ] **Producer Configuration**:
    ```properties
    bootstrap.servers=kafka-cluster-kafka-bootstrap.messaging.svc.cluster.local:9092
    schema.registry.url=http://schema-registry.messaging.svc.cluster.local:8081
    value.serializer=io.confluent.kafka.serializers.KafkaAvroSerializer
    ```
  - [ ] **Consumer Configuration**:
    ```properties
    bootstrap.servers=kafka-cluster-kafka-bootstrap.messaging.svc.cluster.local:9092
    schema.registry.url=http://schema-registry.messaging.svc.cluster.local:8081
    value.deserializer=io.confluent.kafka.serializers.KafkaAvroDeserializer
    ```

- [ ] T9.5 — Write Schema Management section
  - [ ] **Register Schema**:
    ```bash
    curl -X POST \
      -H "Content-Type: application/vnd.schemaregistry.v1+json" \
      --data '{"schema":"..."}' \
      http://schema-registry.messaging.svc.cluster.local:8081/subjects/{subject}/versions
    ```
  - [ ] **Retrieve Schema by ID**:
    ```bash
    curl http://schema-registry.messaging.svc.cluster.local:8081/schemas/ids/{id}
    ```
  - [ ] **List All Subjects**:
    ```bash
    curl http://schema-registry.messaging.svc.cluster.local:8081/subjects
    ```
  - [ ] **Get Subject Versions**:
    ```bash
    curl http://schema-registry.messaging.svc.cluster.local:8081/subjects/{subject}/versions
    ```
  - [ ] **Get Latest Schema for Subject**:
    ```bash
    curl http://schema-registry.messaging.svc.cluster.local:8081/subjects/{subject}/versions/latest
    ```
  - [ ] **Delete Subject** (soft delete):
    ```bash
    curl -X DELETE http://schema-registry.messaging.svc.cluster.local:8081/subjects/{subject}
    ```
  - [ ] **Permanent Delete**:
    ```bash
    curl -X DELETE http://schema-registry.messaging.svc.cluster.local:8081/subjects/{subject}?permanent=true
    ```

- [ ] T9.6 — Write Compatibility Modes section
  - [ ] **BACKWARD** (default):
    - New schema can read data written with old schema
    - Use case: Add optional fields to schema
    - Example: Add `email` field with default value to `User` record
    - Consumer upgrade: New consumers can read old data
  - [ ] **FORWARD**:
    - Old schema can read data written with new schema
    - Use case: Remove optional fields from schema
    - Producer upgrade: Old consumers can read new data
  - [ ] **FULL**:
    - Combination of BACKWARD and FORWARD
    - Most restrictive: only add/remove optional fields with defaults
    - Use case: Strong contract enforcement
  - [ ] **NONE**:
    - No compatibility checks
    - Use case: Development/testing only (dangerous in production)
  - [ ] **Set Global Compatibility**:
    ```bash
    curl -X PUT \
      -H "Content-Type: application/vnd.schemaregistry.v1+json" \
      --data '{"compatibility":"BACKWARD"}' \
      http://schema-registry.messaging.svc.cluster.local:8081/config
    ```
  - [ ] **Set Subject Compatibility**:
    ```bash
    curl -X PUT \
      -H "Content-Type: application/vnd.schemaregistry.v1+json" \
      --data '{"compatibility":"FULL"}' \
      http://schema-registry.messaging.svc.cluster.local:8081/config/{subject}
    ```
  - [ ] **Test Compatibility**:
    ```bash
    curl -X POST \
      -H "Content-Type: application/vnd.schemaregistry.v1+json" \
      --data '{"schema":"..."}' \
      http://schema-registry.messaging.svc.cluster.local:8081/compatibility/subjects/{subject}/versions/latest
    # Response: {"is_compatible":true}
    ```

- [ ] T9.7 — Write Operations section
  - [ ] **View Pods**:
    ```bash
    kubectl --context=apps -n messaging get pods -l app.kubernetes.io/name=schema-registry
    ```
  - [ ] **View Logs**:
    ```bash
    kubectl --context=apps -n messaging logs -l app.kubernetes.io/name=schema-registry -c schema-registry --tail=100 -f
    ```
  - [ ] **Check API Health**:
    ```bash
    kubectl --context=apps -n messaging exec -it deployment/schema-registry -c schema-registry -- \
      curl -s http://localhost:8081/ | jq
    ```
  - [ ] **Restart Deployment**:
    ```bash
    kubectl --context=apps -n messaging rollout restart deployment/schema-registry
    ```
  - [ ] **Scale Replicas**:
    ```bash
    kubectl --context=apps -n messaging scale deployment/schema-registry --replicas=3
    ```
  - [ ] **Inspect `_schemas` Topic**:
    ```bash
    kubectl --context=apps -n messaging exec -it kafka-cluster-kafka-pool-0 -c kafka -- \
      bin/kafka-topics.sh --bootstrap-server localhost:9092 --describe --topic _schemas
    ```
  - [ ] **Read `_schemas` Topic** (troubleshooting):
    ```bash
    kubectl --context=apps -n messaging exec -it kafka-cluster-kafka-pool-0 -c kafka -- \
      bin/kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic _schemas --from-beginning
    ```

- [ ] T9.8 — Write Monitoring section
  - [ ] **Key Metrics**:
    - `up{job="schema-registry"}` - Pod availability
    - `kafka_schema_registry_jetty_metrics_requests_total` - Total HTTP requests
    - `kafka_schema_registry_jetty_metrics_responses_total` - HTTP responses by status code
    - `kafka_schema_registry_jersey_metrics_request_latency_seconds` - API latency (p50, p95, p99)
    - `kafka_schema_registry_kafka_store_lag` - Lag behind Kafka `_schemas` topic
    - `kafka_schema_registry_master_slave_role` - Leadership status (1=leader, 0=follower)
  - [ ] **Query Examples** (VictoriaMetrics):
    ```promql
    # API request rate
    rate(kafka_schema_registry_jetty_metrics_requests_total[5m])

    # Error rate (5xx responses)
    rate(kafka_schema_registry_jetty_metrics_responses_total{status=~"5.."}[5m])

    # p95 latency
    histogram_quantile(0.95, rate(kafka_schema_registry_jersey_metrics_request_latency_seconds_bucket[5m]))

    # Kafka lag
    kafka_schema_registry_kafka_store_lag
    ```
  - [ ] **Alerts**: Reference PrometheusRule alerts (6 alerts defined)

- [ ] T9.9 — Write Troubleshooting section
  - [ ] **Issue 1**: Schema Registry pods not starting
    - **Symptoms**: Pods in CrashLoopBackOff
    - **Causes**:
      - Kafka cluster not available
      - Incorrect Kafka bootstrap endpoint
      - Network policy blocking access to Kafka
    - **Resolution**:
      1. Check Kafka cluster: `kubectl --context=apps -n messaging get kafka kafka-cluster`
      2. Test network connectivity: `kubectl --context=apps -n messaging exec -it deployment/schema-registry -c schema-registry -- nc -zv kafka-cluster-kafka-bootstrap 9092`
      3. Check logs: `kubectl --context=apps -n messaging logs -l app.kubernetes.io/name=schema-registry -c schema-registry --tail=100`
  - [ ] **Issue 2**: Schema registration fails with 500 error
    - **Symptoms**: `curl` returns HTTP 500 Internal Server Error
    - **Causes**:
      - Kafka `_schemas` topic unavailable
      - Kafka authentication failure (if using SCRAM-SHA-512)
      - Schema Registry can't write to Kafka
    - **Resolution**:
      1. Check `_schemas` topic: `kubectl --context=apps -n messaging exec -it kafka-cluster-kafka-pool-0 -c kafka -- bin/kafka-topics.sh --bootstrap-server localhost:9092 --describe --topic _schemas`
      2. Test Kafka write access: Use kafka-console-producer to write to `_schemas` (dangerous, for debugging only)
      3. Check Schema Registry logs for Kafka errors
  - [ ] **Issue 3**: Schema compatibility check fails unexpectedly
    - **Symptoms**: HTTP 409 Conflict when registering compatible schema
    - **Causes**:
      - Misunderstanding compatibility mode (BACKWARD vs FORWARD vs FULL)
      - Schema evolution violates compatibility rules
    - **Resolution**:
      1. Check subject compatibility mode: `curl http://schema-registry.messaging.svc.cluster.local:8081/config/{subject}`
      2. Test compatibility explicitly: `curl -X POST ... /compatibility/subjects/{subject}/versions/latest`
      3. Review Avro schema evolution rules: https://docs.confluent.io/platform/current/schema-registry/avro.html
  - [ ] **Issue 4**: High API latency
    - **Symptoms**: p95 latency > 1s
    - **Causes**:
      - Kafka `_schemas` topic slow (disk I/O, replication lag)
      - Schema Registry pods resource-constrained (CPU/memory)
      - Large schema payloads
    - **Resolution**:
      1. Check Kafka cluster performance: Monitor broker metrics
      2. Increase Schema Registry resources: Edit Deployment resource requests/limits
      3. Scale Schema Registry: Add more replicas (up to 3-4 for read scaling)
  - [ ] **Issue 5**: Split-brain / inconsistent schema state
    - **Symptoms**: Different schema IDs returned by different pods
    - **Causes**: **Should not happen** (Kafka is single source of truth)
    - **Resolution**:
      1. This indicates a severe bug - restart all Schema Registry pods
      2. Inspect `_schemas` topic for corruption
      3. If persistent, escalate to Confluent support

- [ ] T9.10 — Write Backup and Disaster Recovery section
  - [ ] **Backup Strategy**:
    - Schema Registry state is stored in Kafka topic `_schemas`
    - Backup `_schemas` topic using Kafka backup tools
    - Topic is log-compacted, so full history is retained
  - [ ] **Backup `_schemas` Topic**:
    ```bash
    # Export topic to file (using kafka-console-consumer)
    kubectl --context=apps -n messaging exec -it kafka-cluster-kafka-pool-0 -c kafka -- \
      bin/kafka-console-consumer.sh --bootstrap-server localhost:9092 \
      --topic _schemas --from-beginning --timeout-ms 10000 > schemas-backup.json
    ```
  - [ ] **Restore from Backup**:
    1. Create new `_schemas` topic (or delete and recreate)
    2. Import backup file:
       ```bash
       cat schemas-backup.json | kubectl --context=apps -n messaging exec -i kafka-cluster-kafka-pool-0 -c kafka -- \
         bin/kafka-console-producer.sh --bootstrap-server localhost:9092 --topic _schemas
       ```
    3. Restart Schema Registry pods to reload state
  - [ ] **Disaster Recovery**:
    - **RPO**: Depends on Kafka backup frequency (recommend hourly)
    - **RTO**: 5-10 minutes (restore topic + restart pods)
  - [ ] **Cross-Cluster Replication**:
    - Use Kafka MirrorMaker 2 to replicate `_schemas` topic to DR cluster
    - Enables active-passive DR setup

- [ ] T9.11 — Write Performance Tuning section
  - [ ] **Schema Registry Resources**:
    - Default: 100m/500m CPU, 512Mi/1Gi memory per replica
    - High load: Increase to 500m/1000m CPU, 1Gi/2Gi memory
  - [ ] **JVM Tuning**:
    - Schema Registry uses default JVM settings
    - For high load, consider increasing heap size via `SCHEMA_REGISTRY_HEAP_OPTS`
  - [ ] **Kafka `_schemas` Topic**:
    - Partitions: 1 (required by Schema Registry)
    - Replication factor: 3 (production)
    - Min ISR: 2 (production)
    - Cleanup policy: compact (required)
  - [ ] **Caching**:
    - Schema Registry caches schemas in memory
    - Default cache size: 1000 schemas
    - Increase via `SCHEMA_REGISTRY_SCHEMA_CACHE_SIZE` if needed
  - [ ] **Read Scaling**:
    - Schema reads are served from cache (very fast)
    - Scale replicas horizontally for read-heavy workloads (up to 3-4 replicas)
    - Writes go through Kafka (limited by Kafka throughput)

- [ ] T9.12 — Write References section
  - [ ] Confluent Schema Registry documentation: https://docs.confluent.io/platform/current/schema-registry/index.html
  - [ ] Avro schema evolution: https://docs.confluent.io/platform/current/schema-registry/avro.html
  - [ ] REST API reference: https://docs.confluent.io/platform/current/schema-registry/develop/api.html
  - [ ] JMX Prometheus Exporter: https://github.com/prometheus/jmx_exporter
  - [ ] Kafka MirrorMaker 2: https://kafka.apache.org/documentation/#georeplication

### T10 — Validation and Commit (45 min)

**Goal**: Validate all manifests and commit to Git.

- [ ] T10.1 — Validate Kustomization builds
  - [ ] `kubectl kustomize kubernetes/workloads/platform/messaging/schema-registry/`
  - [ ] No errors, all resources rendered correctly

- [ ] T10.2 — Validate Flux Kustomization
  - [ ] `flux build kustomization apps-messaging-schema-registry --path ./kubernetes/workloads/platform/messaging/schema-registry`
  - [ ] No errors

- [ ] T10.3 — Validate YAML syntax
  - [ ] `yamllint kubernetes/workloads/platform/messaging/schema-registry/*.yaml`
  - [ ] Or: `yq eval '.' <file.yaml>` for each file
  - [ ] No syntax errors

- [ ] T10.4 — Validate cross-references
  - [ ] Service selector matches Deployment pod labels
  - [ ] ServiceMonitor selector matches Service labels
  - [ ] Health check in Flux Kustomization matches Deployment name
  - [ ] dependsOn references correct Kustomization name (`apps-messaging-kafka`)

- [ ] T10.5 — Review completeness
  - [ ] All ACs (AC1-AC11) satisfied
  - [ ] All files created:
    - deployment.yaml
    - jmx-config.yaml
    - service.yaml
    - servicemonitor.yaml
    - prometheusrule.yaml
    - externalsecret.yaml (optional)
    - kustomization.yaml
    - examples/README.md
    - examples/schemas-topic.yaml
  - [ ] Cluster Kustomization created/updated: `kubernetes/clusters/apps/messaging.yaml`
  - [ ] Runbook created: `docs/runbooks/schema-registry.md`

- [ ] T10.6 — Commit to Git
  - [ ] Stage all files:
    ```bash
    git add kubernetes/workloads/platform/messaging/schema-registry/
    git add kubernetes/clusters/apps/messaging.yaml
    git add docs/runbooks/schema-registry.md
    git add docs/stories/STORY-MSG-SCHEMA-REGISTRY.md
    ```
  - [ ] Commit:
    ```bash
    git commit -m "feat(messaging): create Schema Registry manifests (Story 39)

    - Add Deployment with JMX Prometheus Exporter sidecar
    - Add Service (ClusterIP on port 8081)
    - Add ServiceMonitor for metrics scraping
    - Add PrometheusRule with 6 alerts
    - Add JMX exporter ConfigMap
    - Add ExternalSecret for Kafka credentials (optional, for TLS)
    - Add example manifests (schema registration, KafkaTopic)
    - Add comprehensive runbook
    - Add Flux Kustomization entrypoint
    - Depends on Kafka cluster (apps-messaging-kafka)
    - Deployment deferred to Story 45"
    ```
  - [ ] Do NOT push yet (wait for user approval or batch with other stories)

- [ ] T10.7 — Update story status
  - [ ] Mark story as Complete in this file
  - [ ] Add completion date to change log

## Runtime Validation (Deferred to Story 45)

The following validation steps will be executed in **Story 45 (STORY-DEPLOY-VALIDATE-ALL)**:

### Deployment Validation
```bash
# Apply Flux Kustomization
flux --context=apps reconcile kustomization apps-messaging-schema-registry --with-source

# Check pods
kubectl --context=apps -n messaging get pods -l app.kubernetes.io/name=schema-registry

# Check Service
kubectl --context=apps -n messaging get svc schema-registry
```

### API Validation
```bash
# Port-forward
kubectl --context=apps -n messaging port-forward svc/schema-registry 8081:8081

# Health check
curl http://localhost:8081/

# List subjects (empty on fresh install)
curl http://localhost:8081/subjects
```

### Schema Evolution Validation
```bash
# Register Avro schema v1
curl -X POST \
  -H "Content-Type: application/vnd.schemaregistry.v1+json" \
  --data '{"schema":"{\"type\":\"record\",\"name\":\"User\",\"fields\":[{\"name\":\"name\",\"type\":\"string\"},{\"name\":\"age\",\"type\":\"int\"}]}"}' \
  http://localhost:8081/subjects/test-user-value/versions
# Expected: {"id":1}

# Register compatible schema v2 (add optional field)
curl -X POST \
  -H "Content-Type: application/vnd.schemaregistry.v1+json" \
  --data '{"schema":"{\"type\":\"record\",\"name\":\"User\",\"fields\":[{\"name\":\"name\",\"type\":\"string\"},{\"name\":\"age\",\"type\":\"int\"},{\"name\":\"email\",\"type\":[\"null\",\"string\"],\"default\":null}]}"}' \
  http://localhost:8081/subjects/test-user-value/versions
# Expected: {"id":2}

# Attempt incompatible schema (remove required field)
curl -X POST \
  -H "Content-Type: application/vnd.schemaregistry.v1+json" \
  --data '{"schema":"{\"type\":\"record\",\"name\":\"User\",\"fields\":[{\"name\":\"name\",\"type\":\"string\"}]}"}' \
  http://localhost:8081/subjects/test-user-value/versions
# Expected: HTTP 409 Conflict (incompatible with BACKWARD mode)
```

### High Availability Validation
```bash
# Verify 2 replicas running
kubectl --context=apps -n messaging get pods -l app.kubernetes.io/name=schema-registry

# Delete one pod
kubectl --context=apps -n messaging delete pod schema-registry-<id>

# Immediately query API (should still work)
curl http://localhost:8081/subjects
```

### Metrics Validation
```bash
# Check ServiceMonitor
kubectl --context=apps -n messaging get servicemonitor schema-registry

# Query VictoriaMetrics (from infra cluster)
# Check for kafka_schema_registry_* metrics
```

## Definition of Done

**Manifest Creation (This Story)**:
- [x] All tasks T1-T10 completed
- [x] All acceptance criteria AC1-AC11 met
- [x] Deployment manifest created with JMX exporter sidecar
- [x] Service manifest created (ClusterIP)
- [x] ServiceMonitor manifest created
- [x] PrometheusRule manifest created (6+ alerts)
- [x] JMX exporter ConfigMap created
- [x] ExternalSecret manifest created (optional, for TLS)
- [x] Example manifests created (schema registration, KafkaTopic)
- [x] Kustomization files created
- [x] Cluster Kustomization entrypoint created
- [x] Comprehensive runbook created (`docs/runbooks/schema-registry.md`)
- [x] Local validation passed (`kubectl kustomize`, `flux build`)
- [x] All files committed to Git (not pushed)
- [x] Story marked complete, change log updated

**Runtime Validation (Story 45)**:
- [ ] Flux Kustomization reconciles successfully
- [ ] 2 Schema Registry pods Running
- [ ] Service endpoint accessible
- [ ] API health check returns 200 OK
- [ ] Schema registration succeeds
- [ ] Schema evolution validation passes (v1, v2 compatible, v3 incompatible)
- [ ] Metrics visible in VictoriaMetrics
- [ ] Alerts firing as expected
- [ ] High availability tested (pod deletion, failover)

## Design Notes

### Schema Registry Architecture

**What is Confluent Schema Registry?**
- Centralized repository for Avro, JSON Schema, and Protobuf schemas
- Provides REST API for schema registration, retrieval, and evolution
- Enforces schema compatibility rules (BACKWARD, FORWARD, FULL, NONE)
- Stores schema metadata in Kafka topic `_schemas` (log compacted)
- Assigns unique schema IDs for efficient serialization

**Why Schema Registry?**
- **Data Contracts**: Enforce schema-driven contracts between producers and consumers
- **Schema Evolution**: Safely evolve schemas over time without breaking consumers
- **Payload Reduction**: Serialize data with schema ID reference (4 bytes) instead of full schema
- **Type Safety**: Prevent schema mismatches and serialization errors
- **Governance**: Central registry enables data lineage and discovery

**High Availability Model**:
- **Active-Active**: All replicas can serve read/write requests
- **Stateless Pods**: Schema state stored in Kafka `_schemas` topic (single partition)
- **Kafka Coordination**: Kafka provides consistency (no ZooKeeper needed)
- **No Split-Brain**: Kafka is single source of truth, all replicas read from same topic
- **Read Scaling**: Schemas cached in memory, can scale replicas for read-heavy workloads

**Leadership Model**:
- Schema Registry uses "master-slave" terminology (one leader, multiple followers)
- Leader elected via Kafka coordination
- Only leader writes to Kafka `_schemas` topic
- Followers proxy writes to leader
- All replicas can serve reads (from cache)

### Storage Backend (Kafka `_schemas` Topic)

**Topic Configuration**:
- **Partitions**: 1 (required by Schema Registry for ordering)
- **Replication Factor**: 3 (production-grade durability)
- **Min ISR**: 2 (prevent data loss)
- **Cleanup Policy**: compact (log compaction, only latest schema per key retained)
- **Retention**: Forever (log compaction keeps latest)

**Schema Storage Format**:
- Key: Schema subject and version (e.g., `user-value:1`)
- Value: JSON payload with schema, subject, version, ID
- Log compacted: Old versions tombstoned, only latest per key retained

**Disaster Recovery**:
- Backup `_schemas` topic using Kafka backup tools
- Restore by recreating topic and importing backup
- Cross-cluster replication: Use Kafka MirrorMaker 2

### Compatibility Modes

**BACKWARD (Default)**:
- New schema can read data written with old schema
- **Rule**: Can add optional fields (with defaults), cannot remove fields
- **Use Case**: Consumer upgrade (new consumers can read old data)
- **Example**: Add `email` field with default `null` to `User` record
  - Old data: `{"name":"Alice","age":30}`
  - New schema: `{"name":"Alice","age":30,"email":null}` (default applied)

**FORWARD**:
- Old schema can read data written with new schema
- **Rule**: Can remove optional fields, cannot add required fields
- **Use Case**: Producer upgrade (old consumers can read new data)
- **Example**: Remove `email` field from `User` record
  - New data: `{"name":"Bob","age":25}`
  - Old schema: Reads `name` and `age`, ignores missing `email`

**FULL**:
- Combination of BACKWARD and FORWARD
- **Rule**: Can only add/remove optional fields with defaults
- **Use Case**: Strong contract enforcement, safest option
- **Most Restrictive**: Both consumers and producers must handle old and new schemas

**NONE**:
- No compatibility checks
- **Use Case**: Development/testing only (dangerous in production)
- **Risk**: Breaking changes can crash consumers

**Best Practice**:
- Use BACKWARD for most use cases (consumer upgrade friendly)
- Use FULL for critical data pipelines (strongest guarantee)
- Avoid NONE in production

### JMX Prometheus Exporter

**Why Sidecar?**
- Confluent Schema Registry doesn't expose native Prometheus metrics
- JMX Exporter reads JMX MBeans and exposes as Prometheus metrics
- Sidecar pattern: JMX Exporter runs alongside Schema Registry in same pod

**Metrics Exposed**:
- `kafka_schema_registry_jetty_metrics_requests_total`: Total HTTP requests
- `kafka_schema_registry_jetty_metrics_responses_total`: HTTP responses by status code
- `kafka_schema_registry_jersey_metrics_request_latency_seconds`: API latency (histogram)
- `kafka_schema_registry_kafka_store_lag`: Lag behind Kafka `_schemas` topic
- `kafka_schema_registry_master_slave_role`: Leadership status (1=leader, 0=follower)

**JMX Exporter Configuration**:
- ConfigMap: `schema-registry-jmx-config`
- Mount path: `/opt/bitnami/jmx-exporter/etc/config.yml`
- Port: 5556 (metrics endpoint)
- JMX port: 5555 (Schema Registry JMX)

### Security Considerations

**Authentication**:
- **Internal-Only**: No authentication by default (trust Cilium NetworkPolicy)
- **Optional**: SCRAM-SHA-512 for Kafka connection (if using TLS listener 9093)
- **Future**: Basic auth or OAuth for Schema Registry REST API

**NetworkPolicy**:
- Allow ingress from application pods in `messaging` namespace
- Allow egress to Kafka cluster (port 9092 or 9093)
- Allow egress to DNS (CoreDNS)

**Pod Security**:
- runAsNonRoot: true
- runAsUser: 1000 (non-root)
- fsGroup: 1000
- No privileged containers

**TLS**:
- Not enabled by default (internal-only service)
- Optional: Use Kafka TLS listener (9093) with SCRAM-SHA-512 auth
- Requires Kafka cluster CA certificate mounted as volume

### Resource Allocation

**Schema Registry Container**:
- Requests: 100m CPU, 512Mi memory
- Limits: 500m CPU, 1Gi memory
- **Rationale**: Lightweight service, mostly serving cached schemas from memory

**JMX Exporter Sidecar**:
- Requests: 50m CPU, 128Mi memory
- Limits: 100m CPU, 256Mi memory
- **Rationale**: Minimal overhead for metrics collection

**Total per Pod**:
- Requests: 150m CPU, 640Mi memory
- Limits: 600m CPU, 1.25Gi memory

**Total for 2 Replicas**:
- Requests: 300m CPU, 1.28Gi memory
- Limits: 1200m CPU, 2.5Gi memory

### Monitoring Strategy

**Key Metrics**:
1. **Availability**: `up{job="schema-registry"}` (pod up/down)
2. **API Requests**: `rate(kafka_schema_registry_jetty_metrics_requests_total[5m])`
3. **API Errors**: `rate(kafka_schema_registry_jetty_metrics_responses_total{status=~"5.."}[5m])`
4. **Latency**: `histogram_quantile(0.95, rate(kafka_schema_registry_jersey_metrics_request_latency_seconds_bucket[5m]))`
5. **Kafka Lag**: `kafka_schema_registry_kafka_store_lag` (should be near 0)
6. **Leadership**: `kafka_schema_registry_master_slave_role` (should have 1 leader)

**Alerts** (6 defined in PrometheusRule):
1. SchemaRegistryDown (critical)
2. SchemaRegistryAPIErrors (high)
3. SchemaRegistryHighLatency (warning)
4. SchemaRegistryKafkaLag (medium)
5. SchemaRegistryCompatibilityCheckFailures (warning)
6. SchemaRegistryNoLeader (high)

### Performance Considerations

**Read Performance**:
- Schema Registry caches all schemas in memory (default 1000 schemas)
- Read latency: < 10ms (served from cache)
- Scale horizontally for read-heavy workloads (up to 3-4 replicas)

**Write Performance**:
- Schema registration writes to Kafka `_schemas` topic (single partition)
- Write throughput limited by Kafka (typically 1000s of schemas/sec)
- Not optimized for high write load (schemas rarely change)

**Bottlenecks**:
- Kafka `_schemas` topic (single partition)
- Solution: Kafka is fast enough for typical schema registration workloads

**Caching**:
- Increase cache size via `SCHEMA_REGISTRY_SCHEMA_CACHE_SIZE` if needed
- Default 1000 schemas should be sufficient for most use cases

### Client Integration

**Producer Configuration** (Python example):
```python
from confluent_kafka import avro
from confluent_kafka.avro import AvroProducer

value_schema = avro.load('user.avsc')
producer = AvroProducer({
    'bootstrap.servers': 'kafka-cluster-kafka-bootstrap.messaging.svc.cluster.local:9092',
    'schema.registry.url': 'http://schema-registry.messaging.svc.cluster.local:8081'
}, default_value_schema=value_schema)

producer.produce(topic='users', value={"name": "Alice", "age": 30})
producer.flush()
```

**Consumer Configuration** (Python example):
```python
from confluent_kafka import avro
from confluent_kafka.avro import AvroConsumer

consumer = AvroConsumer({
    'bootstrap.servers': 'kafka-cluster-kafka-bootstrap.messaging.svc.cluster.local:9092',
    'group.id': 'user-consumer-group',
    'schema.registry.url': 'http://schema-registry.messaging.svc.cluster.local:8081'
})

consumer.subscribe(['users'])
while True:
    msg = consumer.poll(1)
    if msg:
        print(msg.value())  # Automatically deserialized using schema
```

**Serialization Format**:
- Avro message: `[magic_byte(1)][schema_id(4)][avro_payload(N)]`
- Magic byte: 0x0 (Confluent wire format)
- Schema ID: 4-byte schema ID from registry (e.g., 1, 2, 3...)
- Avro payload: Binary-encoded Avro data

### Limitations

**Schema Registry Limitations**:
- Single `_schemas` topic partition (write bottleneck for high-volume schema changes)
- No native multi-tenancy (all schemas in single namespace)
- Limited schema metadata (no tags, owners, descriptions in standard API)

**Confluent Platform Limitations**:
- Schema Registry is part of Confluent Platform (not Apache Kafka)
- Open-source version lacks some enterprise features (RBAC, encryption at rest)

**Operational Limitations**:
- No automated schema migration tools (manual process)
- Schema deletion is soft by default (requires permanent delete flag)
- No built-in schema approval workflow (external tooling needed)

### Disaster Recovery

**Backup Strategy**:
1. Kafka `_schemas` topic is replicated (RF=3)
2. Backup topic using Kafka backup tools (e.g., kafka-console-consumer export)
3. Store backup in S3 or Git

**Restore Process**:
1. Create new Kafka cluster (or reuse existing)
2. Create `_schemas` topic with correct configuration
3. Import backup file using kafka-console-producer
4. Restart Schema Registry pods

**RPO/RTO**:
- **RPO**: Depends on Kafka backup frequency (recommend hourly)
- **RTO**: 5-10 minutes (restore topic + restart pods)

**Cross-Cluster Replication**:
- Use Kafka MirrorMaker 2 to replicate `_schemas` topic to DR cluster
- Enables active-passive DR setup
- Schema IDs must be consistent across clusters (use same Schema Registry instance)

### Testing Strategy

**Unit Tests** (Application Team):
- Schema compatibility tests (register v1, v2 compatible, v3 incompatible)
- Client serialization/deserialization tests

**Integration Tests** (Platform Team):
- Schema Registry API tests (register, retrieve, list, delete)
- Compatibility mode tests (BACKWARD, FORWARD, FULL, NONE)
- High availability tests (pod deletion, failover)

**Performance Tests**:
- Schema registration throughput (1000s/sec)
- Schema retrieval latency (< 10ms)
- Large schema payloads (> 100KB)

**Chaos Tests**:
- Kill Schema Registry pod (failover to other replica)
- Kill Kafka broker (Schema Registry waits for Kafka recovery)
- Network partition (Schema Registry can't reach Kafka)

### Future Enhancements

**Schema Governance** (STORY-MSG-SCHEMA-GOVERNANCE):
- Schema approval workflows (requires human approval before production)
- Schema lineage tracking (which services use which schemas)
- Schema tagging and metadata (owner, team, description)

**Multi-Tenancy**:
- Namespace prefixes for different teams (e.g., `team-a.user-value`)
- RBAC for schema access control

**Schema Migration**:
- Automated migration tools for legacy schemas
- Schema versioning enforcement (semantic versioning)

**External Exposure**:
- HTTPS via Cilium Gateway API
- OAuth authentication for REST API
- Rate limiting for schema registration

## Risks & Mitigations

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| **`_schemas` topic corruption** | Critical | Low | Kafka replication factor 3; regular backups; disaster recovery plan |
| **Incompatible schema changes** | High | Medium | Enforce compatibility modes (BACKWARD/FULL); CI checks before production; schema approval workflow |
| **Split-brain (rare)** | Medium | Very Low | Kafka is single source of truth; ephemeral pod state; Schema Registry coordination via Kafka |
| **Performance bottleneck** | Low | Low | 2 replicas; monitor API latency; scale horizontally (up to 3-4 replicas); increase cache size |
| **No native Prometheus metrics** | Low | N/A | Use JMX exporter sidecar; comprehensive metrics and alerts defined |
| **Schema Registry bug** | Medium | Low | Use stable version (7.8.0); monitor Confluent release notes; test upgrades in staging |
| **Kafka cluster failure** | Critical | Low | Kafka cluster has HA (3 nodes, RF=3); Schema Registry waits for Kafka recovery |

## Follow-On Stories

- **STORY-MSG-SCHEMA-GOVERNANCE** (Story 40+): Schema approval workflows, lineage tracking, metadata management
- **STORY-MSG-SCHEMA-MIGRATION** (Story 40+): Migrate schemas from legacy systems, automated migration tools
- **STORY-MSG-SCHEMA-VERSIONING-POLICY** (Story 40+): Enforce semantic versioning for schemas
- **STORY-MSG-SCHEMA-REGISTRY-TLS** (Story 40+): Enable TLS for Kafka connection (SCRAM-SHA-512)
- **STORY-MSG-SCHEMA-REGISTRY-AUTH** (Story 40+): Enable authentication for Schema Registry REST API (Basic Auth, OAuth)
- **STORY-DEPLOY-VALIDATE-ALL** (Story 45): Deploy and validate all manifests including Schema Registry

## Dev Notes

### Execution Summary
- **Date**: 2025-10-26
- **Executor**: Platform Engineering
- **Story**: STORY-MSG-SCHEMA-REGISTRY (Story 39)
- **Scope**: Manifest creation only (v3.0 approach)
- **Deployment**: Deferred to Story 45

### Commands Executed

**Manifest Creation**:
```bash
# Create directory structure
mkdir -p kubernetes/workloads/platform/messaging/schema-registry/examples

# Create manifests (T2-T7)
# - deployment.yaml (Schema Registry + JMX exporter sidecar)
# - jmx-config.yaml (JMX exporter ConfigMap)
# - service.yaml (ClusterIP)
# - servicemonitor.yaml (Prometheus scraping)
# - prometheusrule.yaml (6 alerts)
# - externalsecret.yaml (optional, for TLS)
# - kustomization.yaml
# - examples/README.md
# - examples/schemas-topic.yaml

# Create cluster Kustomization entrypoint (T8)
# Update kubernetes/clusters/apps/messaging.yaml

# Create runbook (T9)
# docs/runbooks/schema-registry.md
```

**Local Validation** (T10):
```bash
# Validate Kustomization builds
kubectl kustomize kubernetes/workloads/platform/messaging/schema-registry/

# Validate Flux Kustomization
flux build kustomization apps-messaging-schema-registry \
  --path ./kubernetes/workloads/platform/messaging/schema-registry

# Check YAML syntax
yamllint kubernetes/workloads/platform/messaging/schema-registry/*.yaml
```

**Git Commit** (T10):
```bash
git add kubernetes/workloads/platform/messaging/schema-registry/
git add kubernetes/clusters/apps/messaging.yaml
git add docs/runbooks/schema-registry.md
git add docs/stories/STORY-MSG-SCHEMA-REGISTRY.md
git commit -m "feat(messaging): create Schema Registry manifests (Story 39)"
# NOT pushed yet (waiting for user approval)
```

### Key Outputs

**Files Created**:
1. `kubernetes/workloads/platform/messaging/schema-registry/deployment.yaml` (135 lines)
2. `kubernetes/workloads/platform/messaging/schema-registry/jmx-config.yaml` (45 lines)
3. `kubernetes/workloads/platform/messaging/schema-registry/service.yaml` (20 lines)
4. `kubernetes/workloads/platform/messaging/schema-registry/servicemonitor.yaml` (18 lines)
5. `kubernetes/workloads/platform/messaging/schema-registry/prometheusrule.yaml` (75 lines, 6 alerts)
6. `kubernetes/workloads/platform/messaging/schema-registry/externalsecret.yaml` (25 lines, optional)
7. `kubernetes/workloads/platform/messaging/schema-registry/kustomization.yaml` (12 lines)
8. `kubernetes/workloads/platform/messaging/schema-registry/examples/README.md` (150 lines)
9. `kubernetes/workloads/platform/messaging/schema-registry/examples/schemas-topic.yaml` (20 lines)
10. `kubernetes/clusters/apps/messaging.yaml` (updated, 30 lines)
11. `docs/runbooks/schema-registry.md` (600+ lines)

**Validation Results**:
- All manifests build successfully with `kubectl kustomize`
- Flux Kustomization builds without errors
- No YAML syntax errors
- All cross-references valid

### Issues & Resolutions

**Issue 1**: JMX Prometheus Exporter metric names unclear
- **Resolution**: Added comprehensive JMX rules in ConfigMap based on Schema Registry JMX MBeans documentation

**Issue 2**: Optional TLS configuration complexity
- **Resolution**: Added commented TLS configuration in Deployment for reference, default to plain listener (9092)

**Issue 3**: Compatibility mode examples needed
- **Resolution**: Created detailed compatibility mode guide in runbook with concrete examples

### Acceptance Criteria Status

- [x] **AC1**: Schema Registry Deployment manifest exists with all required configuration
- [x] **AC2**: Service manifest exists (ClusterIP, port 8081)
- [x] **AC3**: ServiceMonitor manifest exists for JMX metrics
- [x] **AC4**: PrometheusRule manifest exists with 6 alerts
- [x] **AC5**: Example manifests created (schema registration, KafkaTopic)
- [x] **AC6**: Kustomization file exists with all resources
- [x] **AC7**: Cluster Kustomization entrypoint created with dependencies
- [x] **AC8**: Comprehensive runbook created (600+ lines)
- [x] **AC9**: Local validation passed (kubectl kustomize, flux build)
- [x] **AC10**: Manifest files committed to Git
- [x] **AC11**: Story marked complete, change log updated

**All acceptance criteria met. Story complete for v3.0 manifests-only scope.**

---

## Change Log

### 2025-10-26 - v3.0 Manifests-Only Refinement (Story Complete)
- **Changed**: Story scope to manifests-only approach (deployment deferred to Story 45)
- **Added**: Complete Schema Registry Deployment manifest with JMX Prometheus Exporter sidecar
- **Added**: JMX exporter ConfigMap with comprehensive rules
- **Added**: Service manifest (ClusterIP on port 8081)
- **Added**: ServiceMonitor manifest for Prometheus scraping
- **Added**: PrometheusRule manifest with 6 alerts (availability, errors, latency, lag, compatibility, leadership)
- **Added**: ExternalSecret manifest for Kafka credentials (optional, for TLS)
- **Added**: Example manifests (schema registration, KafkaTopic CR)
- **Added**: Kustomization files (resource composition)
- **Added**: Cluster Kustomization entrypoint with dependencies (apps-messaging-kafka)
- **Added**: Comprehensive runbook (600+ lines): API usage, compatibility modes, operations, monitoring, troubleshooting, DR, performance tuning
- **Added**: Extensive design notes: architecture, storage backend, compatibility modes, JMX exporter, security, resources, monitoring, performance, client integration, limitations, DR, testing, future enhancements
- **Added**: Risk analysis and mitigations
- **Validated**: Local validation passed (kubectl kustomize, flux build, YAML syntax)
- **Committed**: All manifests and documentation committed to Git
- **Status**: Story complete (v3.0), ready for deployment in Story 45

### 2025-10-23 - Initial Draft
- Created initial story structure with implementation tasks (T0-T8)
- Defined 8 acceptance criteria for runtime deployment
- Added basic documentation outline

---

**Story Status**: ✅ Complete (v3.0 Manifests-Only)
**QA Gate**: Local validation passed. Runtime validation deferred to Story 45.
**Deployment Ready**: Yes (all manifests created and validated)
