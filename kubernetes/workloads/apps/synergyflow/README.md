# SynergyFlow ITSM+PM Platform - Deployment

Production-ready Kubernetes manifests for the SynergyFlow unified ITSM+PM platform with Flowable workflow engine, OPA policy enforcement, and event-driven architecture.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        Apps Cluster                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌───────────────────────────────────────────────────────┐     │
│  │              Messaging Namespace                       │     │
│  ├───────────────────────────────────────────────────────┤     │
│  │  • Kafka (3 brokers, KRaft mode)                      │     │
│  │  • Strimzi Operator                                    │     │
│  │  • Schema Registry (Confluent Community)              │     │
│  │  • 11 Event Topics                                     │     │
│  └───────────────────────────────────────────────────────┘     │
│                           │                                      │
│                           │ Events (CloudEvents + Avro)         │
│                           ▼                                      │
│  ┌───────────────────────────────────────────────────────┐     │
│  │            SynergyFlow Namespace                       │     │
│  ├───────────────────────────────────────────────────────┤     │
│  │  • PostgreSQL (CloudNative-PG, 3 replicas)            │     │
│  │  • SynergyFlow Backend (Spring Boot + Flowable)       │     │
│  │  • OPA Sidecar (Policy Enforcement)                   │     │
│  │  • DragonflyDB Cache (shared)                         │     │
│  │  • Victoria Metrics (shared)                          │     │
│  └───────────────────────────────────────────────────────┘     │
└─────────────────────────────────────────────────────────────────┘
```

## Technology Stack

- **Backend**: Spring Boot 3.x with Spring Modulith
- **Workflow Engine**: Flowable 7.x (embedded)
- **Policy Engine**: Open Policy Agent (OPA) 0.68+
- **Event Backbone**: Apache Kafka 3.8 (Strimzi)
- **Schema Registry**: Confluent Community Edition 7.8
- **Database**: PostgreSQL 16 (CloudNative-PG)
- **Cache**: DragonflyDB (Redis-compatible)
- **Monitoring**: Victoria Metrics
- **GitOps**: Flux CD

## Prerequisites

- Kubernetes cluster with:
  - CloudNative-PG operator
  - DragonflyDB instance
  - Victoria Metrics
  - External Secrets Operator
  - Strimzi operator (will be installed)
- Vault or similar secret backend
- S3-compatible storage for backups
- Flux CD installed

## Directory Structure

```
kubernetes/workloads/
├── platform/
│   └── messaging/
│       ├── kafka/
│       │   ├── namespace.yaml
│       │   ├── helmrelease-strimzi.yaml
│       │   ├── kafka-cluster.yaml
│       │   ├── kafka-metrics-configmap.yaml
│       │   ├── kafka-topics.yaml
│       │   ├── kafka-users.yaml
│       │   └── kustomization.yaml
│       └── schema-registry/
│           ├── deployment.yaml
│           ├── service.yaml
│           ├── externalsecret.yaml
│           ├── servicemonitor.yaml
│           └── kustomization.yaml
└── apps/
    └── synergyflow/
        ├── namespace.yaml
        ├── postgres-cluster.yaml
        ├── externalsecrets.yaml
        ├── configmap.yaml
        ├── deployment.yaml
        ├── service.yaml
        ├── servicemonitor.yaml
        ├── networkpolicy.yaml
        └── kustomization.yaml
```

## Kafka Topics

| Topic | Partitions | Retention | Purpose |
|-------|-----------|-----------|---------|
| `user-events` | 6 | 7 days | User lifecycle events |
| `incident-events` | 12 | 30 days | Incident management events |
| `change-events` | 6 | 90 days | Change management events |
| `problem-events` | 6 | 30 days | Problem management events |
| `workflow-events` | 12 | 30 days | Flowable workflow events |
| `notification-events` | 6 | 7 days | Notification delivery events |
| `cmdb-events` | 6 | 90 days | CMDB configuration events |
| `team-events` | 3 | 30 days | Team and routing events |
| `knowledge-events` | 3 | 30 days | Knowledge base events |
| `integration-events` | 6 | 7 days | External integration events |
| `dlq-events` | 3 | 30 days | Dead letter queue |

## Deployment

### Option 1: Manual Deployment

```bash
# 1. Deploy Kafka cluster
kubectl apply -k kubernetes/workloads/platform/messaging/kafka

# 2. Wait for Kafka to be ready
kubectl wait --for=condition=Ready kafka/synergyflow -n messaging --timeout=600s

# 3. Deploy Schema Registry
kubectl apply -k kubernetes/workloads/platform/messaging/schema-registry

# 4. Wait for Schema Registry
kubectl wait --for=condition=available deployment/schema-registry -n messaging --timeout=300s

# 5. Deploy SynergyFlow backend
kubectl apply -k kubernetes/workloads/apps/synergyflow

# 6. Wait for SynergyFlow
kubectl wait --for=condition=Ready cluster/synergyflow-db -n synergyflow --timeout=600s
kubectl wait --for=condition=available deployment/synergyflow-backend -n synergyflow --timeout=600s
```

### Option 2: Automated Deployment with Taskfile

```bash
# Bootstrap entire infrastructure
task synergyflow:bootstrap

# Deploy individual components
task synergyflow:deploy:kafka
task synergyflow:deploy:schema-registry
task synergyflow:deploy:app

# Validate deployment
task synergyflow:validate:all

# Check status
task synergyflow:status
```

### Option 3: GitOps with Flux

```bash
# Apply Flux Kustomizations (one-time)
kubectl apply -f kubernetes/clusters/apps/messaging.yaml
kubectl apply -f kubernetes/clusters/apps/synergyflow.yaml

# Flux will automatically deploy and manage the resources
flux get kustomizations -A
```

## Configuration

### Secrets Required

The deployment expects the following secrets in Vault:

**PostgreSQL**:
- `postgresql/synergyflow/username`
- `postgresql/synergyflow/password`

**Kafka Users**:
- `kafka/users/synergyflow-backend/username`
- `kafka/users/synergyflow-backend/password`
- `kafka/users/schema-registry/username`
- `kafka/users/schema-registry/password`

**Redis**:
- `redis/dragonfly/password`

**S3 Backup**:
- `s3/backup/access_key_id`
- `s3/backup/secret_access_key`

### Application Configuration

Application configuration is stored in `configmap.yaml`. Key settings:

```yaml
spring:
  datasource:
    url: jdbc:postgresql://synergyflow-db-rw.synergyflow.svc.cluster.local:5432/synergyflow

  kafka:
    bootstrap-servers: synergyflow-kafka-bootstrap.messaging.svc.cluster.local:9092

flowable:
  database-schema-update: true
  async-executor-activate: true

opa:
  url: http://localhost:8181/v1/data
  timeout: 100ms
```

## Monitoring and Observability

### Metrics

All components expose Prometheus metrics:

- **Kafka**: Port 9404 (JMX Exporter)
- **Schema Registry**: Port 8081/metrics
- **SynergyFlow Backend**: Port 8080/actuator/prometheus
- **PostgreSQL**: Via CloudNative-PG metrics

ServiceMonitors are configured for Victoria Metrics scraping.

### Health Checks

```bash
# Kafka cluster health
kubectl get kafka synergyflow -n messaging

# Schema Registry health
kubectl get pods -l app.kubernetes.io/name=schema-registry -n messaging

# SynergyFlow backend health
kubectl exec -n synergyflow deployment/synergyflow-backend -c synergyflow -- \
  curl -s http://localhost:8080/actuator/health | jq
```

### Logs

```bash
# View component logs
task synergyflow:logs COMPONENT=app
task synergyflow:logs COMPONENT=opa
task synergyflow:logs COMPONENT=kafka
task synergyflow:logs COMPONENT=schema-registry
```

## Development

### Port Forwarding

```bash
# SynergyFlow backend
task synergyflow:port-forward COMPONENT=app
# Access: http://localhost:8080

# Schema Registry
task synergyflow:port-forward COMPONENT=schema-registry
# Access: http://localhost:8081

# PostgreSQL
task synergyflow:port-forward COMPONENT=postgres
# Access: localhost:5432

# Kafka
task synergyflow:port-forward COMPONENT=kafka
# Access: localhost:9092
```

### Database Access

```bash
# Open psql shell
task synergyflow:db:shell

# Trigger manual backup
task synergyflow:db:backup

# List backups
task synergyflow:db:backups
```

### Kafka Operations

```bash
# List topics
task synergyflow:kafka:topics

# Open Kafka shell
task synergyflow:kafka:shell
```

## Troubleshooting

### Kafka Not Starting

Check Strimzi operator logs:
```bash
kubectl logs -n messaging -l name=strimzi-cluster-operator
```

Verify storage class exists:
```bash
kubectl get storageclass rook-ceph-block
```

### Schema Registry Connection Issues

Verify Kafka user credentials:
```bash
kubectl get secret schema-registry-kafka-credentials -n messaging -o yaml
```

Check Schema Registry logs:
```bash
kubectl logs -n messaging -l app.kubernetes.io/name=schema-registry
```

### SynergyFlow Backend Startup Failures

Check init container logs:
```bash
kubectl logs -n synergyflow <pod-name> -c wait-for-db
kubectl logs -n synergyflow <pod-name> -c wait-for-kafka
```

Verify database connectivity:
```bash
kubectl exec -n synergyflow synergyflow-db-1 -- pg_isready
```

### OPA Policy Evaluation Errors

Check OPA sidecar logs:
```bash
task synergyflow:logs COMPONENT=opa
```

Test policy directly:
```bash
kubectl exec -n synergyflow <pod-name> -c opa -- \
  curl -X POST http://localhost:8181/v1/data/synergyflow/authz/allow \
  -H "Content-Type: application/json" \
  -d '{"input": {"user": {"roles": ["AGENT"]}, "action": "incident.create"}}'
```

## Resource Requirements

### Minimum Resources

| Component | CPU (Request) | CPU (Limit) | Memory (Request) | Memory (Limit) |
|-----------|--------------|-------------|------------------|----------------|
| Kafka (per broker) | 2 cores | 2 cores | 4 GiB | 4 GiB |
| Schema Registry | 250m | 1000m | 768 MiB | 1 GiB |
| PostgreSQL (per instance) | 1000m | 2000m | 2 GiB | 2 GiB |
| SynergyFlow Backend | 500m | 2000m | 1.5 GiB | 2 GiB |
| OPA Sidecar | 100m | 500m | 128 MiB | 256 MiB |

### Total Cluster Requirements (with 3 replicas)

- **CPU**: ~20 cores
- **Memory**: ~40 GiB
- **Storage**: ~350 GiB (Kafka 300GB + PostgreSQL 50GB)

## High Availability

- **Kafka**: 3 brokers with `min.insync.replicas=2`
- **Schema Registry**: 2 replicas with leader election
- **PostgreSQL**: 3 instances with automatic failover
- **SynergyFlow Backend**: 3 replicas with pod anti-affinity

## Backup and Recovery

### Automatic Backups

PostgreSQL automatic backups are configured via CloudNative-PG:
- **Retention**: 30 days
- **Destination**: S3-compatible storage
- **Encryption**: AES256
- **Compression**: gzip

### Manual Backup

```bash
task synergyflow:db:backup
```

### Recovery

Follow CloudNative-PG recovery procedures:
```bash
kubectl apply -f restore-cluster.yaml
```

## Security

### Network Policies

NetworkPolicy enforces:
- Ingress only from Envoy Gateway and Prometheus
- Egress to PostgreSQL, Kafka, Schema Registry, DragonflyDB
- DNS resolution allowed

### Authentication

- **Kafka**: SCRAM-SHA-512 authentication
- **PostgreSQL**: User/password authentication
- **Schema Registry**: Kafka authentication
- **SynergyFlow**: OAuth2/JWT (via Envoy Gateway)

### Authorization

OPA policies enforce RBAC/ABAC authorization:
- Role hierarchy: SYSTEM_ADMIN > TENANT_ADMIN > AGENT > END_USER
- Resource-level permissions
- Audit trail for all decisions

## Performance Tuning

### Kafka

Tuning parameters in `kafka-cluster.yaml`:
- `num.network.threads: 8`
- `num.io.threads: 16`
- `log.segment.bytes: 1073741824` (1GB)

### PostgreSQL

Tuning parameters in `postgres-cluster.yaml`:
- `max_connections: 200`
- `shared_buffers: 512MB`
- `effective_cache_size: 1536MB`

### Application

JVM tuning in `deployment.yaml`:
- Heap: 1GB (Xms=Xmx)
- GC: G1GC with 200ms pause target

## Cleanup

### Remove All Resources

```bash
task synergyflow:clean:all
```

### Remove Individual Components

```bash
task synergyflow:clean:app
task synergyflow:clean:messaging
```

## References

- [Flowable Documentation](https://www.flowable.com/open-source/docs)
- [OPA Documentation](https://www.openpolicyagent.org/docs/)
- [Strimzi Documentation](https://strimzi.io/docs/)
- [CloudNative-PG Documentation](https://cloudnative-pg.io/documentation/)
- [Technical Research Report](../../../../../synergyflow/docs/research-technical-2025-10-17.md)

## Support

For issues or questions, please refer to:
- Technical research: `/Users/monosense/repository/synergyflow/docs/research-technical-2025-10-17.md`
- Brainstorming results: `/Users/monosense/repository/synergyflow/docs/brainstorming-session-results-2025-10-05.md`
