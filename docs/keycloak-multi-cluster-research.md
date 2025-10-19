# Keycloak Multi-Cluster Implementation Research
## Strategic Analysis for Cilium Cluster Mesh Environment

**Research Date:** October 2025
**Environment:** Multi-cluster Kubernetes with Cilium Cluster Mesh
**Version:** Keycloak 26.2.0, Cilium 1.18.x

---

## Executive Summary

This research provides a comprehensive analysis of implementing Keycloak with the Keycloak Operator in a multi-cluster Kubernetes environment leveraging Cilium Cluster Mesh. The existing infrastructure provides excellent foundations for a highly available, secure authentication service that can serve both the `infra` and `apps` clusters seamlessly.

### Key Findings
- **High Feasibility**: Existing Cilium Cluster Mesh with SPIRE authentication creates ideal foundation
- **Zero-Configuration Benefits**: Keycloak 26.2.0 introduces zero-configuration secure cluster communication
- **Database Ready**: CloudNative-PG cluster with `keycloak_app` user and `keycloak-pooler` already provisioned
- **Security Synergy**: SPIRE integration enhances overall security posture
- **Cost Efficiency**: Leverages existing shared PostgreSQL infrastructure without additional database setup

---

## Current Infrastructure Analysis

### Cluster Architecture
```
┌─────────────────┐    Cilium Cluster Mesh    ┌─────────────────┐
│   Infra Cluster │◄─────────────────────────►│   Apps Cluster  │
│   (ID: 1)       │     BGP + SPIRE Mesh      │   (ID: 2)       │
│                 │                           │                 │
│ • Pod CIDR:     │                           │ • Pod CIDR:     │
│   10.244.0.0/16 │                           │   10.246.0.0/16 │
│ • Service CIDR: │                           │ • Service CIDR: │
│   10.245.0.0/16 │                           │   10.247.0.0/16 │
└─────────────────┘                           └─────────────────┘
```

### Relevant Existing Components

#### Cilium Configuration
- **Version**: 1.18.x with full feature set
- **Cluster Mesh**: Enabled with API server (LoadBalancer exposure)
- **Authentication**: SPIRE-based mutual authentication already configured
- **Encryption**: WireGuard for pod-to-pod traffic
- **Gateway API**: Enabled for L7 ingress management
- **BGP Control Plane**: For network routing between clusters

#### Storage & Database
- **CloudNative-PG**: v1.25.1 with PostgreSQL 16.8
- **Shared PostgreSQL Cluster**: `shared-postgres` in `cnpg-system` namespace (3 instances, 2-4 CPU, 8-16Gi RAM each)
- **Keycloak Database**: Already provisioned with `keycloak_app` user and `keycloak-pooler` (3 PgBouncer instances)
- **Storage Classes**: `rook-ceph-block` and `openebs-local-nvme`
- **Backup Strategy**: Automated with BarmanObjectStore (S3), 30-day retention, AES256 encryption
- **Database Features**: TLS 1.3, pg_audit, replication slots, high availability, automatic failover

#### Security & Secrets
- **External Secrets Operator**: 1Password integration
- **cert-manager**: Cloudflare TLS certificates
- **SPIRE**: Already integrated with Cilium for identity management

#### Observability
- **Victoria Metrics**: Metrics collection and retention
- **Hubble**: Network flow visibility and service mesh observability
- **Grafana**: Dashboards and alerting

---

## Keycloak Deployment Architecture

### Recommended Architecture: Primary-Secondary Model

```
┌─────────────────────────────────────────────────────────────────┐
│                     Authentication Layer                       │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐              ┌─────────────────┐         │
│  │   Infra Cluster │              │   Apps Cluster  │         │
│  │                 │              │                 │         │
│  │ ┌─────────────┐ │              │ ┌─────────────┐ │         │
│  │ │   Keycloak  │ │◄────────────►│ │ Keycloak    │ │         │
│  │ │   Primary    │ │  Cluster    │ │   Secondary  │ │         │
│  │ │   (Active)   │ │   Mesh      │ │   (Passive)  │ │         │
│  │ └─────────────┘ │              │ └─────────────┘ │         │
│  │                 │              │                 │         │
│  │ ┌─────────────┐ │              │                 │         │
│  │ │ PostgreSQL  │ │              │   Read-only    │         │
│  │ │  (Primary)  │ │              │   Access       │         │
│  │ └─────────────┘ │              │                 │         │
│  └─────────────────┘              └─────────────────┘         │
└─────────────────────────────────────────────────────────────────┘
                               │
                               ▼
                    ┌─────────────────┐
                    │  External       │
                    │  Services       │
                    │  (via Gateway   │
                    │   API)          │
                    └─────────────────┘
```

### Component Distribution Strategy

#### Infra Cluster (Primary)
- **Keycloak Primary Instance**: 3 replicas for high availability
- **Shared PostgreSQL Database**: Uses existing `shared-postgres` cluster via `keycloak-pooler`
- **Database Access**: Connects via `keycloak-pooler-cnpg-system.rw.svc.cluster.local:5432`
- **Backup Services**: Leverages existing BarmanObjectStore backup (30-day retention)
- **Monitoring**: Primary metrics and alerting integrated with existing Victoria Metrics

#### Apps Cluster (Secondary)
- **Keycloak Secondary Instance**: 2 replicas for read operations and failover
- **Database Access**: Cross-cluster connection to `keycloak-pooler` in infra cluster
- **Local Caching**: Reduces cross-cluster latency for authentication requests
- **Health Monitoring**: Service health and connectivity checks via Cilium cluster mesh

---

## Implementation Strategy

### Phase 1: Foundation Setup (Week 1-2)

#### 1.1 Database Preparation - ✅ ALREADY COMPLETED
Your existing CloudNative-PG setup includes:
- **Shared PostgreSQL Cluster**: `shared-postgres` (3 instances, production-grade)
- **Keycloak Database User**: `keycloak_app` already provisioned
- **Connection Pooler**: `keycloak-pooler` with 3 PgBouncer instances (session mode)
- **External Secrets**: `keycloak-pooler-auth` already configured

#### 1.2 Create Keycloak Database
```sql
-- Connect to shared-postgres as superuser and create Keycloak database
CREATE DATABASE keycloak_db
    OWNER = keycloak_app
    ENCODING = 'UTF8'
    LC_COLLATE = 'en_US.utf8'
    LC_CTYPE = 'en_US.utf8'
    TEMPLATE = template0;

-- Grant necessary permissions
GRANT ALL PRIVILEGES ON DATABASE keycloak_db TO keycloak_app;
```

#### 1.3 Verify Database Configuration
```yaml
# Database connection details for Keycloak
# Host: keycloak-pooler-cnpg-system.rw.svc.cluster.local
# Port: 5432
# Database: keycloak_db (to be created)
# Username: keycloak_app
# Password: Retrieved from keycloak-pooler-auth secret
```

### Phase 2: Keycloak Operator Deployment (Week 3-4)

#### 2.1 Operator Installation
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: keycloak-operator
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: keycloak-operator
  namespace: keycloak-operator
spec:
  channel: stable
  name: keycloak-operator
  source: community-operators
  sourceNamespace: openshift-marketplace
```

#### 2.2 Keycloak Custom Resource
```yaml
apiVersion: k8s.keycloak.org/v2alpha1
kind: Keycloak
metadata:
  name: keycloak
  namespace: identity
  labels:
    app: keycloak
    tier: frontend
spec:
  instances: 3

  # Use existing shared PostgreSQL infrastructure
  db:
    vendor: postgres
    host: keycloak-pooler-cnpg-system.rw.svc.cluster.local
    port: 5432
    database: keycloak_db  # Database to be created in existing cluster
    usernameSecret:
      name: keycloak-pooler-auth
      key: username
    passwordSecret:
      name: keycloak-pooler-auth
      key: password

  http:
    tlsSecret: keycloak-tls

  hostname:
    hostname: keycloak.monosense.io

  proxy:
    mode: edge
    headers: xforwarded

  features:
    enabled:
      - "hostname:v1"
      - "token-exchange"
      - "admin-fine-grained-authz"

  cache:
    configMapFile: /opt/keycloak/conf/cache-configuration.xml

  transaction:
    xaEnabled: false

  resources:
    requests:
      cpu: "1000m"
      memory: "2Gi"
    limits:
      cpu: "2000m"
      memory: "4Gi"
```

### Phase 3: Multi-Cluster Configuration (Week 5-6)

#### 3.1 Cross-Cluster Service Discovery
```yaml
# Service for cross-cluster discovery (in infra cluster)
apiVersion: v1
kind: Service
metadata:
  name: keycloak-cluster-mesh
  namespace: identity
  annotations:
    io.cilium/global-service: "true"  # Expose to cluster mesh
spec:
  selector:
    app.kubernetes.io/name: keycloak
  ports:
    - name: https
      port: 8443
      targetPort: 8443
  type: ClusterIP

# In apps cluster - import the service
apiVersion: v1
kind: Service
metadata:
  name: keycloak-infra
  namespace: identity
  annotations:
    io.cilium/global-service: "imported"
spec:
  ports:
    - name: https
      port: 8443
      targetPort: 8443
```

#### 3.2 Cilium Network Policies for Authentication
```yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: keycloak-auth-policy
  namespace: identity
spec:
  endpointSelector:
    matchLabels:
      app.kubernetes.io/name: keycloak

  ingress:
    - fromEndpoints:
        - matchLabels:
            k8s:io.kubernetes.pod.namespace: identity
            app.kubernetes.io/name: keycloak
      toPorts:
        - ports:
            - port: "8443"
              protocol: TCP
          rules:
            http:
              - {}

    - fromEndpoints:
        - matchLabels:
            "io.cilium.k8s.policy.cluster": "apps"
      toPorts:
        - ports:
            - port: "8443"
              protocol: TCP

  egress:
    - toEndpoints:
        - matchLabels:
            k8s:io.kubernetes.pod.namespace: cnpg-system
            cnpg.io/cluster: shared-postgres
      toPorts:
        - ports:
            - port: "5432"
              protocol: TCP

    - toEndpoints:
        - matchLabels:
            k8s:io.kubernetes.pod.namespace: cnpg-system
            cnpg.io/poolerName: keycloak-pooler
      toPorts:
        - ports:
            - port: "5432"
              protocol: TCP

  authentication:
    mode: "required"
    spiffe:
      peerIdentities:
        - "spiffe://monosense.io/ns/identity/sa/keycloak"
        - "spiffe://monosense.io/ns/cnpg-system/sa/shared-postgres"
        - "spiffe://monosense.io/ns/cnpg-system/sa/keycloak-pooler"
```

### Phase 4: Gateway API Configuration (Week 7)

#### 4.1 Multi-Cluster Gateway
```yaml
apiVersion: gateway.networking.k8s.io/v1beta1
kind: Gateway
metadata:
  name: keycloak-gateway
  namespace: identity
  annotations:
    io.cilium/gateway-type: "managed"
spec:
  gatewayClassName: cilium
  listeners:
    - name: https
      protocol: HTTPS
      port: 443
      hostname: keycloak.monosense.io
      allowedRoutes:
        namespaces:
          from: Same
      tls:
        mode: Terminate
        certificateRefs:
          - name: keycloak-tls
---
apiVersion: gateway.networking.k8s.io/v1beta1
kind: HTTPRoute
metadata:
  name: keycloak-route
  namespace: identity
spec:
  parentRefs:
    - name: keycloak-gateway
      namespace: identity
  hostnames:
    - "keycloak.monosense.io"
  rules:
    - matches:
        - path:
            type: Prefix
            value: /
      backendRefs:
        - name: keycloak-service
          port: 8443
```

---

## Security Architecture

### Defense in Depth Strategy

#### 1. Network Security (L4)
- **Cilium Network Policies**: Restrict traffic to Keycloak components
- **WireGuard Encryption**: All cross-cluster traffic encrypted
- **SPIRE Authentication**: Mutual TLS between services

#### 2. Application Security (L7)
- **OAuth 2.0 / OpenID Connect**: Standard authentication protocols
- **JWT Token Security**: Short-lived tokens with refresh机制
- **Fine-Grained Authorization**: Role-based access control (RBAC)

#### 3. Data Security
- **PostgreSQL Encryption**: At-rest and in-transit encryption
- **Secrets Management**: External Secrets with 1Password backend
- **Certificate Management**: Automated TLS with cert-manager

#### 4. Identity Federation
- **SPIFFE Integration**: Workload identity federation
- **Social Identities**: SSO with external providers
- **Service Mesh Integration**: Identity propagation across services

### Security Monitoring
```yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: keycloak-monitoring
  namespace: identity
spec:
  endpointSelector:
    matchLabels:
      app.kubernetes.io/name: keycloak

  egress:
    - toEndpoints:
        - matchLabels:
            k8s:io.kubernetes.pod.namespace: monitoring
            app.kubernetes.io/name: prometheus
      toPorts:
        - ports:
            - port: "9090"
              protocol: TCP

    - toFQDNs:
        - matchName: "victoriametrics.monitoring.svc.cluster.local"
      toPorts:
        - ports:
            - port: "8428"
              protocol: TCP
```

---

## High Availability & Disaster Recovery

### Multi-Cluster HA Strategy

#### 1. Database Replication
```yaml
# PostgreSQL Streaming Replication
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: keycloak-postgres
spec:
  instances: 3
  primaryUpdateStrategy: unsupervised

  replicationSlots:
    highAvailability:
      enabled: true
      slotPrefix: "_ha_"

  externalClusters:
    - name: replica-cluster
      connectionParameters:
        host: keycloak-postgres-ro.apps.svc.cluster.local
        user: streaming_replica
      password:
        name: postgres-replica-credentials
        key: password
```

#### 2. Cross-Cluster Failover
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: keycloak-failover-config
  namespace: identity
data:
  failover.yaml: |
    failover:
      enabled: true
      strategy: "active-passive"
      healthCheck:
        interval: "30s"
        timeout: "10s"
        failureThreshold: 3
      switchback:
        enabled: true
        delay: "5m"
```

#### 3. Backup Strategy
```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Backup
metadata:
  name: keycloak-backup-hourly
  namespace: identity
spec:
  cluster:
    name: keycloak-postgres
  method: barmanObjectStore
  barmanObjectStore:
    destinationPath: "s3://monosense-cnpg/keycloak"
    s3Credentials:
      accessKeyId:
        name: backup-credentials
        key: ACCESS_KEY_ID
      secretAccessKey:
        name: backup-credentials
        key: SECRET_ACCESS_KEY
    wal:
      compression: gzip
      encryption: AES256
    data:
      compression: gzip
      encryption: AES256
      jobs: 2
  retentionPolicy: "30d"
```

---

## Performance Optimization

### Caching Strategy
```xml
<!-- Keycloak Cache Configuration -->
<cache-container name="keycloak">
    <local-cache name="realms">
        <expiration lifespan="-1"/>
    </local-cache>

    <local-cache name="users">
        <expiration lifespan="3600"/>
    </local-cache>

    <distributed-cache name="sessions" owners="2">
        <expiration lifespan="1800"/>
    </distributed-cache>

    <distributed-cache name="loginFailures" owners="2">
        <expiration lifespan="300"/>
    </distributed-cache>
</cache-container>
```

### Resource Scaling
```yaml
apiVersion: k8s.keycloak.org/v2alpha1
kind: Keycloak
metadata:
  name: keycloak
spec:
  instances: 3

  resources:
    requests:
      cpu: "1000m"
      memory: "2Gi"
    limits:
      cpu: "2000m"
      memory: "4Gi"

  storage:
    size: 10Gi
    storageClassName: rook-ceph-block

  # Horizontal Pod Autoscaler
  autoscaling:
    enabled: true
    minReplicas: 3
    maxReplicas: 10
    targetCPUUtilizationPercentage: 70
    targetMemoryUtilizationPercentage: 80
```

---

## Monitoring & Observability

### Prometheus Metrics
```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: keycloak-metrics
  namespace: identity
  labels:
    prometheus: kube-prometheus
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: keycloak
  endpoints:
    - port: http
      path: /metrics
      interval: 30s
      honorLabels: true
```

### Hubble Network Monitoring
```yaml
apiVersion: cilium.io/v2alpha1
kind: CiliumNetworkPolicy
metadata:
  name: keycloak-observability
  namespace: identity
spec:
  endpointSelector:
    matchLabels:
      app.kubernetes.io/name: keycloak

  # Enable flow logging for Keycloak
  egress:
    - toEndpoints: []
      toPorts:
        - ports:
            - port: "8443"
      rules:
        l7:
          http:
            - method: "GET"
              path: "/auth/realms/*"
```

### Grafana Dashboard
```json
{
  "dashboard": {
    "title": "Keycloak Multi-Cluster Dashboard",
    "panels": [
      {
        "title": "Authentication Requests",
        "type": "graph",
        "targets": [
          {
            "expr": "rate(keycloak_authentication_requests_total[5m])",
            "legendFormat": "{{cluster}} - {{realm}}"
          }
        ]
      },
      {
        "title": "Cross-Cluster Traffic",
        "type": "graph",
        "targets": [
          {
            "expr": "cilium_drop_bytes_total{reason=\"Policy denied\", source_cluster=\"apps\", destination_cluster=\"infra\"}",
            "legendFormat": "Dropped Traffic: Apps → Infra"
          }
        ]
      },
      {
        "title": "Database Connections",
        "type": "singlestat",
        "targets": [
          {
            "expr": "pg_stat_database_numbackends{datname=\"keycloak\"}",
            "legendFormat": "Active Connections"
          }
        ]
      }
    ]
  }
}
```

---

## Implementation Roadmap

### Phase 1: Foundation (Weeks 1-2)
- [x] Deploy PostgreSQL cluster with CloudNative-PG ✅ ALREADY DONE
- [x] Configure External Secrets for Keycloak credentials ✅ ALREADY DONE
- [ ] Create Keycloak database in existing shared-postgres cluster
- [ ] Set up network policies and security contexts

### Phase 2: Core Deployment (Weeks 3-4)
- [ ] Install Keycloak Operator
- [ ] Deploy Keycloak instance in infra cluster
- [ ] Configure SPIRE integration for service authentication
- [ ] Set up TLS certificates with cert-manager

### Phase 3: Multi-Cluster Setup (Weeks 5-6)
- [ ] Configure cross-cluster service discovery via Cilium global services
- [ ] Deploy secondary Keycloak instance in apps cluster
- [ ] Set up cross-cluster database access via keycloak-pooler
- [ ] Implement failover and recovery procedures

### Phase 4: Gateway & Ingress (Week 7)
- [ ] Configure Cilium Gateway API for external access
- [ ] Set up load balancing and traffic routing
- [ ] Implement health checks and readiness probes
- [ ] Configure external DNS and SSL termination

### Phase 5: Testing & Validation (Week 8)
- [ ] Performance testing and optimization
- [ ] Security testing and penetration testing
- [ ] Disaster recovery testing
- [ ] User acceptance testing

### Phase 6: Production Rollout (Week 9-10)
- [ ] Gradual traffic migration
- [ ] Monitoring and alerting fine-tuning
- [ ] Documentation and knowledge transfer
- [ ] Production support procedures

---

## Risk Assessment & Mitigation

### Technical Risks

#### 1. Cross-Cluster Network Latency
**Risk**: High latency between clusters affecting authentication performance
**Mitigation**:
- Deploy read replicas in apps cluster
- Implement aggressive caching strategies
- Use connection pooling

#### 2. Database Synchronization
**Risk**: Database replication lag or split-brain scenarios
**Mitigation**:
- Configure synchronous replication for critical data
- Implement automated failover testing
- Monitor replication lag metrics

#### 3. Certificate Management
**Risk**: Certificate expiration affecting cross-cluster communication
**Mitigation**:
- Automated certificate rotation with cert-manager
- Certificate expiry monitoring and alerting
- Backup certificate management procedures

### Security Risks

#### 1. Identity Spoofing
**Risk**: Compromised SPIFFE identities
**Mitigation**:
- Regular SPIRE bundle rotation
- Strict identity validation policies
- Audit logging for all authentication attempts

#### 2. Data Exposure
**Risk**: Unauthorized access to authentication data
**Mitigation**:
- End-to-end encryption for all traffic
- Network segmentation with Cilium policies
- Regular security audits and penetration testing

---

## Cost Analysis

### Infrastructure Costs

#### Compute Resources
- **Keycloak Instances**: 3 replicas × 2 CPU × 4Gi RAM = 6 CPU, 12Gi RAM
- **PostgreSQL Cluster**: ✅ ALREADY EXISTS - Shared cluster (6 CPU, 24Gi RAM)
- **PgBouncer Pooler**: ✅ ALREADY EXISTS - keycloak-pooler (0.75 CPU, 768Mi RAM)
- **Supporting Services**: ✅ ALREADY EXISTS - Monitoring, logging, backup
- **Additional Total**: ~6 CPU, 12Gi RAM (Keycloak only)

#### Storage Costs
- **PostgreSQL Data**: ✅ ALREADY EXISTS - Shared cluster storage
- **Backups**: ✅ ALREADY EXISTS - BarmanObjectStore backup infrastructure
- **Additional Storage**: Minimal (Keycloak database within existing cluster)

#### Network Costs
- **Cross-Cluster Traffic**: Minimal due to local caching
- **External Traffic**: Standard authentication request volume
- **Monitoring Data**: Metrics and logs传输

### Operational Costs
- **Maintenance**: Database backups, certificate rotation, updates
- **Monitoring**: Alert management, performance tuning
- **Security**: Regular audits, penetration testing

---

## Conclusion & Recommendations

### Key Advantages of This Approach

1. **Leverages Existing Infrastructure**: Maximizes ROI on current Cilium Cluster Mesh investment
2. **Enhanced Security**: SPIRE integration provides additional security layer
3. **High Availability**: Multi-cluster deployment ensures service continuity
4. **Scalability**: Designed to grow with organizational needs
5. **Observability**: Comprehensive monitoring and troubleshooting capabilities

### Immediate Next Steps

1. **Stakeholder Approval**: Review and approve the implementation plan
2. **Resource Allocation**: Provision necessary compute and storage resources
3. **Team Training**: Ensure team is familiar with Keycloak and multi-cluster concepts
4. **PoC Implementation**: Start with proof of concept in development environment
5. **Timeline Finalization**: Lock in implementation dates and milestones

### Long-term Considerations

1. **Federation Planning**: Consider future federation with external identity providers
2. **Compliance Requirements**: Ensure GDPR, SOC2, and other compliance needs are met
3. **Capacity Planning**: Regular reviews of usage patterns and scaling requirements
4. **Technology Evolution**: Stay current with Keycloak and Cilium feature updates

---

## Appendix

### A. Configuration Templates
[Full configuration templates for all components]

### B. Troubleshooting Guide
[Common issues and resolution procedures]

### C. Migration Checklist
[Step-by-step migration from current authentication system]

### D. Performance Benchmarks
[Baseline performance metrics and testing procedures]

---

**Document Version**: 1.0
**Last Updated**: October 2025
**Next Review**: December 2025
**Document Owner**: Platform Architecture Team