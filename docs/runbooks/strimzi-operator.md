# Strimzi Kafka Operator - Operations Runbook

## Overview

The Strimzi Kafka Operator provides a Kubernetes-native way to deploy and manage Apache Kafka clusters using custom resources.

- **Version**: 0.48.0
- **Namespace**: `strimzi-operator-system`
- **Watched Namespaces**: `messaging`
- **Mode**: KRaft (ZooKeeper-less)
- **Cluster**: apps

## Architecture

### Components

1. **Cluster Operator**: Main operator managing Kafka cluster lifecycle
2. **Topic Operator**: Manages Kafka topics via `KafkaTopic` CRs
3. **User Operator**: Manages Kafka users via `KafkaUser` CRs
4. **Custom Resource Definitions (CRDs)**: Kubernetes API extensions for Kafka resources

### High Availability

- **Replicas**: 2 operator pods with anti-affinity
- **Leader Election**: Enabled for active-passive HA
- **PodDisruptionBudget**: Ensures 1 replica always available

### Resource Limits

```yaml
requests:
  cpu: 200m
  memory: 256Mi
limits:
  cpu: 1000m
  memory: 512Mi
```

---

## Custom Resource Definitions (CRDs)

### Core CRDs

#### 1. Kafka (`kafka.strimzi.io/v1beta2`)

Primary resource for deploying Kafka clusters.

**Example**:
```yaml
apiVersion: kafka.strimzi.io/v1beta2
kind: Kafka
metadata:
  name: my-cluster
  namespace: messaging
spec:
  kafka:
    version: 3.9.0
    replicas: 3
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
    storage:
      type: persistent-claim
      size: 100Gi
      class: rook-ceph-block
  entityOperator:
    topicOperator: {}
    userOperator: {}
```

#### 2. KafkaTopic (`kafka.strimzi.io/v1beta2`)

Manages Kafka topics declaratively.

**Example**:
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
    compression.type: producer
```

#### 3. KafkaUser (`kafka.strimzi.io/v1beta2`)

Manages Kafka users and ACLs.

**Example**:
```yaml
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaUser
metadata:
  name: my-user
  namespace: messaging
  labels:
    strimzi.io/cluster: my-cluster
spec:
  authentication:
    type: scram-sha-512
  authorization:
    type: simple
    acls:
      - resource:
          type: topic
          name: my-topic
          patternType: literal
        operations:
          - Read
          - Write
          - Describe
        host: "*"
      - resource:
          type: group
          name: my-consumer-group
          patternType: literal
        operations:
          - Read
        host: "*"
```

#### 4. KafkaConnect (`kafka.strimzi.io/v1beta2`)

Deploys Kafka Connect clusters.

**Example**:
```yaml
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaConnect
metadata:
  name: my-connect-cluster
  namespace: messaging
spec:
  version: 3.9.0
  replicas: 3
  bootstrapServers: my-cluster-kafka-bootstrap:9093
  tls:
    trustedCertificates:
      - secretName: my-cluster-cluster-ca-cert
        certificate: ca.crt
  config:
    group.id: connect-cluster
    offset.storage.topic: connect-cluster-offsets
    config.storage.topic: connect-cluster-configs
    status.storage.topic: connect-cluster-status
```

#### 5. KafkaMirrorMaker2 (`kafka.strimzi.io/v1beta2`)

Mirrors data between Kafka clusters.

**Example**:
```yaml
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaMirrorMaker2
metadata:
  name: my-mirror-maker2
  namespace: messaging
spec:
  version: 3.9.0
  replicas: 1
  connectCluster: "target"
  clusters:
    - alias: "source"
      bootstrapServers: source-cluster:9092
    - alias: "target"
      bootstrapServers: target-cluster:9092
  mirrors:
    - sourceCluster: "source"
      targetCluster: "target"
      sourceConnector: {}
```

#### 6. KafkaBridge (`kafka.strimzi.io/v1beta2`)

Provides HTTP API for Kafka.

**Example**:
```yaml
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaBridge
metadata:
  name: my-bridge
  namespace: messaging
spec:
  replicas: 1
  bootstrapServers: my-cluster-kafka-bootstrap:9093
  http:
    port: 8080
```

#### 7. KafkaNodePool (`kafka.strimzi.io/v1beta2`)

Groups Kafka brokers with shared configuration (KRaft mode).

**Example**:
```yaml
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaNodePool
metadata:
  name: pool-a
  namespace: messaging
  labels:
    strimzi.io/cluster: my-cluster
spec:
  replicas: 3
  roles:
    - broker
  storage:
    type: persistent-claim
    size: 100Gi
```

---

## Common Operations

### Check Operator Status

```bash
# Check operator pods
kubectl get pods -n strimzi-operator-system

# Check operator logs
kubectl logs -n strimzi-operator-system -l app.kubernetes.io/name=strimzi-cluster-operator -f

# Check operator version
kubectl get deployment -n strimzi-operator-system strimzi-cluster-operator \
  -o jsonpath='{.spec.template.spec.containers[0].image}'
```

### List Kafka Clusters

```bash
# List all Kafka clusters
kubectl get kafka -n messaging

# Get cluster details
kubectl describe kafka my-cluster -n messaging

# Check cluster status
kubectl get kafka my-cluster -n messaging -o jsonpath='{.status.conditions}'
```

### List Topics

```bash
# List all Kafka topics
kubectl get kafkatopic -n messaging

# Get topic details
kubectl describe kafkatopic my-topic -n messaging

# Check topic configuration
kubectl get kafkatopic my-topic -n messaging -o yaml
```

### List Users

```bash
# List all Kafka users
kubectl get kafkauser -n messaging

# Get user details
kubectl describe kafkauser my-user -n messaging

# Get user credentials (SCRAM-SHA-512)
kubectl get secret my-user -n messaging -o jsonpath='{.data.password}' | base64 -d
```

### Create Kafka Cluster (KRaft Mode)

```bash
cat <<EOF | kubectl apply -f -
apiVersion: kafka.strimzi.io/v1beta2
kind: Kafka
metadata:
  name: my-cluster
  namespace: messaging
spec:
  kafka:
    version: 3.9.0
    replicas: 3
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
    storage:
      type: persistent-claim
      size: 100Gi
      class: rook-ceph-block
  entityOperator:
    topicOperator: {}
    userOperator: {}
EOF
```

### Create Topic

```bash
cat <<EOF | kubectl apply -f -
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
    retention.ms: 604800000
    compression.type: producer
EOF
```

### Create User

```bash
cat <<EOF | kubectl apply -f -
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaUser
metadata:
  name: my-user
  namespace: messaging
  labels:
    strimzi.io/cluster: my-cluster
spec:
  authentication:
    type: scram-sha-512
  authorization:
    type: simple
    acls:
      - resource:
          type: topic
          name: my-topic
          patternType: literal
        operations:
          - Read
          - Write
        host: "*"
EOF
```

### Scale Kafka Cluster

```bash
# Scale to 5 brokers
kubectl patch kafka my-cluster -n messaging \
  --type merge -p '{"spec":{"kafka":{"replicas":5}}}'

# Verify scaling
kubectl get kafka my-cluster -n messaging -o jsonpath='{.spec.kafka.replicas}'
```

### Upgrade Kafka Version

```bash
# Update Kafka version (follow Strimzi upgrade procedures)
kubectl patch kafka my-cluster -n messaging \
  --type merge -p '{"spec":{"kafka":{"version":"3.9.0"}}}'

# Monitor upgrade status
kubectl get kafka my-cluster -n messaging -w
```

---

## Troubleshooting

### Operator Not Starting

**Symptoms**: Operator pods in CrashLoopBackOff or pending state

**Diagnosis**:
```bash
# Check pod status
kubectl get pods -n strimzi-operator-system

# Check pod events
kubectl describe pod <pod-name> -n strimzi-operator-system

# Check operator logs
kubectl logs <pod-name> -n strimzi-operator-system
```

**Common Causes**:
1. Insufficient resources (CPU/memory)
2. CRDs not installed
3. RBAC permissions missing
4. Image pull failures

**Resolution**:
```bash
# Check CRDs
kubectl get crd | grep strimzi

# Reinstall CRDs if missing
kubectl apply -f https://strimzi.io/install/latest?namespace=strimzi-operator-system

# Check resource quotas
kubectl describe resourcequota -n strimzi-operator-system
```

### Kafka Cluster Not Ready

**Symptoms**: Kafka CR status shows NotReady or ReconciliationPaused

**Diagnosis**:
```bash
# Check cluster status
kubectl get kafka my-cluster -n messaging -o yaml

# Check operator logs for errors
kubectl logs -n strimzi-operator-system -l app.kubernetes.io/name=strimzi-cluster-operator | grep ERROR

# Check Kafka pod status
kubectl get pods -n messaging -l strimzi.io/cluster=my-cluster
```

**Common Causes**:
1. Storage provisioning failures
2. Network policies blocking communication
3. Insufficient resources
4. Invalid configuration

**Resolution**:
```bash
# Check PVC status
kubectl get pvc -n messaging

# Check events
kubectl get events -n messaging --sort-by='.lastTimestamp'

# Verify storage class
kubectl get storageclass rook-ceph-block
```

### Topic Creation Failures

**Symptoms**: KafkaTopic CR exists but topic not created in Kafka

**Diagnosis**:
```bash
# Check topic operator logs
kubectl logs -n messaging -l strimzi.io/name=my-cluster-entity-operator -c topic-operator

# Check topic status
kubectl get kafkatopic my-topic -n messaging -o yaml
```

**Common Causes**:
1. Topic operator not running
2. Invalid topic configuration
3. Kafka cluster not ready
4. Insufficient permissions

**Resolution**:
```bash
# Restart topic operator
kubectl rollout restart deployment my-cluster-entity-operator -n messaging

# Verify topic configuration
kubectl get kafkatopic my-topic -n messaging -o jsonpath='{.spec}'
```

### User Creation Failures

**Symptoms**: KafkaUser CR exists but user not created

**Diagnosis**:
```bash
# Check user operator logs
kubectl logs -n messaging -l strimzi.io/name=my-cluster-entity-operator -c user-operator

# Check user status
kubectl get kafkauser my-user -n messaging -o yaml
```

**Common Causes**:
1. User operator not running
2. Invalid authentication configuration
3. Secret creation failures

**Resolution**:
```bash
# Restart user operator
kubectl rollout restart deployment my-cluster-entity-operator -n messaging

# Check secret exists
kubectl get secret my-user -n messaging
```

### High Memory Usage

**Symptoms**: Operator pods consuming excessive memory

**Diagnosis**:
```bash
# Check memory usage
kubectl top pod -n strimzi-operator-system

# Check memory limits
kubectl get deployment strimzi-cluster-operator -n strimzi-operator-system \
  -o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}'
```

**Resolution**:
```bash
# Increase memory limits (via HelmRelease values)
# Update kubernetes/bases/strimzi-operator/operator/helmrelease.yaml
# and commit to trigger Flux reconciliation
```

---

## Monitoring and Alerting

### Metrics

The operator exposes metrics at `/metrics` endpoint:

- `strimzi_reconciliations_total`: Total reconciliations
- `strimzi_reconciliations_duration_seconds`: Reconciliation duration
- `strimzi_reconciliations_failed_total`: Failed reconciliations
- `strimzi_resources`: Number of resources being managed

### Alerts

8 PrometheusRule alerts configured:

1. **StrimziOperatorDown** (critical): Operator unavailable for 5+ minutes
2. **StrimziOperatorHighRestarts** (warning): Frequent pod restarts
3. **StrimziOperatorNotHighlyAvailable** (warning): Less than 2 replicas
4. **StrimziReconciliationErrors** (warning): Reconciliation failures
5. **StrimziSlowReconciliation** (warning): Slow reconciliation (>300s)
6. **StrimziOperatorHighMemoryUsage** (warning): Memory usage >90%
7. **StrimziOperatorHighCPUThrottling** (warning): CPU throttling >50%
8. **StrimziCRDValidationErrors** (warning): Invalid CRs causing failures

### Grafana Dashboards

Recommended dashboards:
- Strimzi Kafka Operator Overview
- Strimzi Kafka Cluster
- Strimzi Kafka Topics
- Strimzi Kafka Connect

---

## Disaster Recovery

### Backup

**Operator Configuration**:
```bash
# Backup operator configuration
kubectl get helmrelease strimzi-operator -n strimzi-operator-system -o yaml > strimzi-operator-backup.yaml
```

**Kafka Resources**:
```bash
# Backup all Kafka resources
kubectl get kafka,kafkatopic,kafkauser -n messaging -o yaml > kafka-resources-backup.yaml
```

**PVCs**:
```bash
# List Kafka PVCs
kubectl get pvc -n messaging -l strimzi.io/cluster=my-cluster

# Use Velero/VolSync for PVC backups
```

### Restore

**Operator**:
```bash
# Restore operator (via GitOps - commit to repository)
git add kubernetes/bases/strimzi-operator/
git commit -m "Restore Strimzi operator configuration"
git push

# Force Flux reconciliation
flux reconcile kustomization strimzi-operator --with-source
```

**Kafka Resources**:
```bash
# Restore Kafka resources
kubectl apply -f kafka-resources-backup.yaml
```

---

## Upgrading

### Operator Upgrade

**Process**:
1. Review release notes: https://github.com/strimzi/strimzi-kafka-operator/releases
2. Update version in `kubernetes/bases/strimzi-operator/operator/helmrelease.yaml`
3. **Manually update CRDs** (Helm doesn't upgrade CRDs):
   ```bash
   kubectl apply -f https://strimzi.io/install/latest?namespace=strimzi-operator-system
   ```
4. Commit and push changes
5. Monitor Flux reconciliation:
   ```bash
   flux get helmreleases -n strimzi-operator-system --watch
   ```

### Kafka Version Upgrade

**Process**:
1. Check compatibility matrix: https://strimzi.io/downloads/
2. Update `.spec.kafka.version` in Kafka CR
3. Monitor rolling upgrade:
   ```bash
   kubectl get pods -n messaging -l strimzi.io/cluster=my-cluster -w
   ```

---

## Security

### Authentication Methods

- **SCRAM-SHA-512**: Password-based (recommended)
- **TLS Client Certificates**: Certificate-based
- **OAuth 2.0**: Token-based

### Authorization

- **Simple ACLs**: Kafka native ACLs
- **OPA (Open Policy Agent)**: Policy-based
- **Keycloak**: OAuth-based

### Network Policies

NetworkPolicy generation enabled (`generateNetworkPolicy: true`) to restrict pod-to-pod communication.

### Pod Security

- PSA: `restricted` (strimzi-operator-system)
- PSA: `restricted` (messaging namespace)
- Run as non-root user (uid: 1000)
- Read-only root filesystem
- Drop all capabilities

---

## References

- [Strimzi Documentation](https://strimzi.io/docs/operators/latest/)
- [Strimzi GitHub](https://github.com/strimzi/strimzi-kafka-operator)
- [Kafka Documentation](https://kafka.apache.org/documentation/)
- [KRaft Mode Guide](https://kafka.apache.org/documentation/#kraft)
- [Strimzi Examples](https://github.com/strimzi/strimzi-kafka-operator/tree/main/examples)

---

**Last Updated**: 2025-11-08
**Operator Version**: 0.48.0
**Kafka Versions Supported**: 3.9.0, 4.0.0, 4.1.0
