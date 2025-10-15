# Talos Kubernetes Audit Logging Policy

**Document Version:** 1.0
**Last Updated:** 2025-10-14
**Status:** ✅ Approved for Implementation
**Validation:** Infrastructure Validation - Security BLOCKER #2

---

## Executive Summary

This document defines the Kubernetes audit logging policy for the multi-cluster Talos platform. Audit logs provide forensic capability for security incidents, compliance evidence, and operational troubleshooting by recording all API server requests.

---

## 🎯 Audit Logging Objectives

### Primary Goals

1. **Security Incident Response** - Forensic trail of unauthorized access attempts
2. **Compliance Evidence** - Audit trail for regulatory requirements
3. **Operational Troubleshooting** - Debug authentication, authorization, and API issues
4. **Change Tracking** - Record who made what changes and when
5. **Anomaly Detection** - Identify unusual API access patterns

### What Gets Audited

```
┌─────────────────────────────────────────────────────────────────┐
│ Kubernetes API Server                                            │
│   ↓ All incoming requests                                        │
│   ├─ Authentication (who)                                        │
│   ├─ Authorization (can they)                                    │
│   ├─ Resource operations (what)                                  │
│   └─ Response (success/failure)                                  │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ Audit Policy (filter & enrich)                                   │
│   - High-value: Secrets, RBAC, ConfigMaps                       │
│   - Medium-value: Deployments, Services, PVCs                   │
│   - Low-value: GET requests, status checks                      │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ Audit Log Storage                                                │
│   ├─ Local: /var/log/audit/kube-apiserver-audit.log            │
│   └─ Centralized: Victoria Logs (via Fluent Bit)               │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📜 Audit Policy Levels

Kubernetes audit supports 4 verbosity levels:

| Level | Description | Use Case | Data Size |
|-------|-------------|----------|-----------|
| **None** | Don't log | Noise reduction (health checks, metrics) | 0 bytes |
| **Metadata** | Log request metadata only | Most operations (who, what, when) | ~500 bytes |
| **Request** | Log metadata + request body | Create/update operations (see what was created) | ~2-10 KB |
| **RequestResponse** | Log metadata + request + response | Debugging (full audit trail) | ~10-50 KB |

**Our Strategy**: Metadata for most, Request for high-value changes, None for noise

---

## 🔐 Audit Policy Rules

### Rule Priority (First Match Wins)

```yaml
# 1. Don't log (noise reduction)
# 2. Request level (high-value resources)
# 3. Metadata level (default for most)
# 4. None (catch-all for low-value)
```

### Rule Categories

#### 1. **Exclude: Health Checks & Metrics** (None)
- `/healthz`, `/readyz`, `/livez`, `/metrics`
- System components polling status
- **Rationale**: Excessive noise, no security value

#### 2. **Request Level: Security-Critical Resources**
- Secrets (read/write)
- RBAC (Roles, ClusterRoles, Bindings)
- ServiceAccounts
- Certificates
- **Rationale**: High-value targets for attackers

#### 3. **Request Level: Infrastructure Changes**
- Namespaces (create/delete)
- PersistentVolumes
- StorageClasses
- NetworkPolicies
- **Rationale**: Infrastructure-level changes need full audit

#### 4. **Metadata Level: Application Workloads**
- Deployments, StatefulSets, DaemonSets
- Services, Ingresses
- ConfigMaps (non-sensitive)
- Jobs, CronJobs
- **Rationale**: Track changes without excessive data

#### 5. **Metadata Level: Read Operations**
- GET requests (except Secrets)
- LIST requests (except Secrets)
- WATCH requests (except Secrets)
- **Rationale**: Track who accessed what

#### 6. **None: System Noise**
- System components (kube-proxy, kubelet, etc.)
- Read-only operations on low-value resources
- **Rationale**: Reduce log volume

---

## 📄 Audit Policy Configuration

### Talos Machine Config Integration

The audit policy is embedded in the Talos machine configuration:

```yaml
# talos/machineconfig.yaml.j2
cluster:
  apiServer:
    auditPolicy:
      apiVersion: audit.k8s.io/v1
      kind: Policy
      rules:
        # [Full policy defined below]
```

### Full Audit Policy (Production-Ready)

```yaml
apiVersion: audit.k8s.io/v1
kind: Policy
# Audit policy for multi-cluster Kubernetes (infra + apps)
# Security BLOCKER #2 - Talos Audit Logging
omitStages:
  - RequestReceived  # Only log after authorization (reduce noise)
  - ResponseStarted  # Don't log streaming responses

rules:
  # ========================================================================
  # RULE 1: Don't audit health checks and metrics endpoints
  # ========================================================================
  - level: None
    nonResourceURLs:
      - /healthz*
      - /readyz*
      - /livez*
      - /metrics*
      - /version
    userGroups:
      - system:authenticated
      - system:unauthenticated

  # ========================================================================
  # RULE 2: Don't audit system component read-only operations
  # ========================================================================
  - level: None
    users:
      - system:kube-proxy
      - system:kube-scheduler
      - system:kube-controller-manager
      - system:serviceaccount:kube-system:namespace-controller
      - system:serviceaccount:kube-system:generic-garbage-collector
      - system:serviceaccount:kube-system:attachdetach-controller
      - system:serviceaccount:kube-system:certificate-controller
      - system:serviceaccount:kube-system:clusterrole-aggregation-controller
      - system:serviceaccount:kube-system:cronjob-controller
      - system:serviceaccount:kube-system:daemon-set-controller
      - system:serviceaccount:kube-system:deployment-controller
      - system:serviceaccount:kube-system:disruption-controller
      - system:serviceaccount:kube-system:endpoint-controller
      - system:serviceaccount:kube-system:endpointslice-controller
      - system:serviceaccount:kube-system:horizontal-pod-autoscaler
      - system:serviceaccount:kube-system:job-controller
      - system:serviceaccount:kube-system:persistent-volume-binder
      - system:serviceaccount:kube-system:pod-garbage-collector
      - system:serviceaccount:kube-system:replicaset-controller
      - system:serviceaccount:kube-system:replication-controller
      - system:serviceaccount:kube-system:resourcequota-controller
      - system:serviceaccount:kube-system:service-account-controller
      - system:serviceaccount:kube-system:statefulset-controller
      - system:serviceaccount:kube-system:ttl-controller
    verbs: ["get", "list", "watch"]

  # ========================================================================
  # RULE 3: Don't audit Cilium agent noise
  # ========================================================================
  - level: None
    users:
      - system:serviceaccount:kube-system:cilium
      - system:serviceaccount:kube-system:cilium-operator
    verbs: ["get", "list", "watch"]
    resources:
      - group: ""
        resources: ["nodes", "nodes/status", "endpoints", "services"]
      - group: "cilium.io"
        resources: ["*"]

  # ========================================================================
  # RULE 4: REQUEST LEVEL - Secrets access (HIGH SECURITY)
  # ========================================================================
  - level: Request
    omitManagedFields: true
    resources:
      - group: ""
        resources: ["secrets"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]

  # ========================================================================
  # RULE 5: REQUEST LEVEL - RBAC changes (HIGH SECURITY)
  # ========================================================================
  - level: Request
    omitManagedFields: true
    resources:
      - group: "rbac.authorization.k8s.io"
        resources:
          - "clusterroles"
          - "clusterrolebindings"
          - "roles"
          - "rolebindings"
      - group: ""
        resources: ["serviceaccounts"]
    verbs: ["create", "update", "patch", "delete"]

  # ========================================================================
  # RULE 6: REQUEST LEVEL - Certificate operations (HIGH SECURITY)
  # ========================================================================
  - level: Request
    omitManagedFields: true
    resources:
      - group: "certificates.k8s.io"
        resources: ["certificatesigningrequests", "certificatesigningrequests/approval"]
      - group: "cert-manager.io"
        resources: ["certificates", "issuers", "clusterissuers"]
    verbs: ["create", "update", "patch", "delete"]

  # ========================================================================
  # RULE 7: REQUEST LEVEL - External Secrets (HIGH SECURITY)
  # ========================================================================
  - level: Request
    omitManagedFields: true
    resources:
      - group: "external-secrets.io"
        resources: ["externalsecrets", "secretstores", "clustersecretstores"]
    verbs: ["create", "update", "patch", "delete"]

  # ========================================================================
  # RULE 8: REQUEST LEVEL - Namespace lifecycle (INFRASTRUCTURE)
  # ========================================================================
  - level: Request
    omitManagedFields: true
    resources:
      - group: ""
        resources: ["namespaces"]
    verbs: ["create", "delete"]

  # ========================================================================
  # RULE 9: REQUEST LEVEL - Network policies (SECURITY)
  # ========================================================================
  - level: Request
    omitManagedFields: true
    resources:
      - group: "networking.k8s.io"
        resources: ["networkpolicies", "ingresses"]
      - group: "cilium.io"
        resources: ["ciliumnetworkpolicies", "ciliumclusterwidenetworkpolicies"]
    verbs: ["create", "update", "patch", "delete"]

  # ========================================================================
  # RULE 10: REQUEST LEVEL - Storage infrastructure (INFRASTRUCTURE)
  # ========================================================================
  - level: Request
    omitManagedFields: true
    resources:
      - group: ""
        resources: ["persistentvolumes"]
      - group: "storage.k8s.io"
        resources: ["storageclasses", "volumeattachments"]
      - group: "ceph.rook.io"
        resources: ["cephclusters", "cephblockpools", "cephfilesystems"]
    verbs: ["create", "update", "patch", "delete"]

  # ========================================================================
  # RULE 11: METADATA LEVEL - Workload changes (APPLICATION)
  # ========================================================================
  - level: Metadata
    omitManagedFields: true
    resources:
      - group: "apps"
        resources: ["deployments", "statefulsets", "daemonsets", "replicasets"]
      - group: "batch"
        resources: ["jobs", "cronjobs"]
      - group: ""
        resources: ["pods", "services", "configmaps"]
    verbs: ["create", "update", "patch", "delete"]

  # ========================================================================
  # RULE 12: METADATA LEVEL - PVC operations
  # ========================================================================
  - level: Metadata
    omitManagedFields: true
    resources:
      - group: ""
        resources: ["persistentvolumeclaims"]
    verbs: ["create", "update", "patch", "delete"]

  # ========================================================================
  # RULE 13: METADATA LEVEL - Flux GitOps changes
  # ========================================================================
  - level: Metadata
    omitManagedFields: true
    resources:
      - group: "kustomize.toolkit.fluxcd.io"
        resources: ["kustomizations"]
      - group: "helm.toolkit.fluxcd.io"
        resources: ["helmreleases"]
      - group: "source.toolkit.fluxcd.io"
        resources: ["gitrepositories", "helmrepositories", "helmcharts"]
    verbs: ["create", "update", "patch", "delete"]

  # ========================================================================
  # RULE 14: METADATA LEVEL - Read operations (all authenticated users)
  # ========================================================================
  - level: Metadata
    omitManagedFields: true
    verbs: ["get", "list", "watch"]
    resources:
      - group: ""
        resources: ["pods", "services", "configmaps", "events"]
      - group: "apps"
        resources: ["deployments", "statefulsets", "daemonsets"]

  # ========================================================================
  # RULE 15: METADATA LEVEL - Authentication & authorization failures
  # ========================================================================
  - level: Metadata
    omitManagedFields: false  # Include full details for security incidents
    # Log all authentication/authorization failures

  # ========================================================================
  # RULE 16: None - Catch-all for low-value operations
  # ========================================================================
  - level: None
```

---

## 🚀 Implementation Steps

### Step 1: Update Talos Machine Config Template

Add audit policy to `talos/machineconfig.yaml.j2`:

```jinja2
cluster:
  {% if machinetype == 'controlplane' %}
  apiServer:
    image: registry.k8s.io/kube-apiserver:v1.34.1
    extraArgs:
      enable-aggregator-routing: true
      feature-gates: ImageVolume=true
      audit-log-path: /var/log/audit/kube-apiserver-audit.log
      audit-log-maxage: "7"        # Keep for 7 days locally
      audit-log-maxbackup: "3"     # Keep 3 backup files
      audit-log-maxsize: "100"     # 100MB per file
    certSANs: ["k8s.monosense.io"]
    disablePodSecurityPolicy: true
    auditPolicy:
      apiVersion: audit.k8s.io/v1
      kind: Policy
      # [Insert full policy from above]
  {% endif %}
```

### Step 2: Configure Log Forwarding to Victoria Logs

Fluent Bit will tail audit logs and forward to Victoria Logs:

```yaml
# kubernetes/bases/fluent-bit/helmrelease.yaml
config:
  inputs: |
    [INPUT]
        Name              tail
        Path              /var/log/audit/kube-apiserver-audit.log
        Tag               audit.kube-apiserver
        DB                /var/fluent-bit/state/audit.db
        Mem_Buf_Limit     50MB
        Skip_Long_Lines   On
        Refresh_Interval  10

  filters: |
    [FILTER]
        Name    parser
        Match   audit.*
        Parser  json

  outputs: |
    [OUTPUT]
        Name                 http
        Match                audit.*
        Host                 victoria-logs.monitoring.svc.cluster.local
        Port                 9428
        URI                  /insert/jsonline?_stream_fields=stream,namespace,pod
        Format               json_lines
        Header               AccountID 0
        Header               ProjectID 0
        compress             gzip
```

### Step 3: Apply Configuration

```bash
# Regenerate machine configs with new audit policy
task talos:apply-node NODE=10.25.11.11 CLUSTER=infra MACHINE_TYPE=controlplane

# Verify audit logging is working
talosctl logs -f -k --nodes 10.25.11.11 | grep audit
```

### Step 4: Query Audit Logs

```bash
# Via kubectl (local files)
kubectl exec -n monitoring victoria-logs-0 -- cat /var/log/audit/kube-apiserver-audit.log | tail -50

# Via Victoria Logs (centralized)
kubectl port-forward -n monitoring svc/victoria-logs 9428:9428
curl 'http://localhost:9428/select/logsql/query' -d 'query={stream="audit.kube-apiserver"} | limit 100'
```

---

## 📊 Audit Log Retention Strategy

| Storage Location | Retention | Size Limit | Purpose |
|------------------|-----------|------------|---------|
| **Local Node** | 7 days | 3 × 100MB = 300MB | Immediate forensics if Victoria Logs unavailable |
| **Victoria Logs** | 90 days | Unlimited | Centralized search and analysis |
| **Cold Storage** | 1 year | MinIO S3 | Compliance and long-term forensics |

### Storage Estimates

```
Audit Log Volume Estimation:
- API requests/sec: ~500 (estimate for 6-node cluster)
- Average log entry: ~2KB (Metadata level)
- Logs per day: 500 * 86400 = 43.2M requests
- Storage per day: 43.2M * 2KB = ~86GB (uncompressed)
- Compressed (gzip): ~8.6GB/day
- 90-day retention: ~774GB

Local Node:
- 300MB × 6 nodes = 1.8GB

Victoria Logs (90 days):
- ~774GB (acceptable for home lab)
```

---

## 🔍 Audit Log Analysis Examples

### Security Incident Investigation

```bash
# Find all Secret access by a specific user
curl 'http://victoria-logs:9428/select/logsql/query' \
  -d 'query={stream="audit.kube-apiserver"} | json | user.username="suspicious@example.com" AND objectRef.resource="secrets"'

# Find all failed authentication attempts
curl 'http://victoria-logs:9428/select/logsql/query' \
  -d 'query={stream="audit.kube-apiserver"} | json | responseStatus.code="403"'

# Find all RBAC changes in last 24h
curl 'http://victoria-logs:9428/select/logsql/query' \
  -d 'query={stream="audit.kube-apiserver"} | json | verb=~"create|update|delete" AND objectRef.resource=~".*role.*" | last 24h'
```

### Compliance Reporting

```bash
# Generate audit report for compliance
curl 'http://victoria-logs:9428/select/logsql/query' \
  -d 'query={stream="audit.kube-apiserver"} | json | objectRef.resource="secrets" | stats count() by user.username | sort by count desc'

# Track who accessed production namespaces
curl 'http://victoria-logs:9428/select/logsql/query' \
  -d 'query={stream="audit.kube-apiserver"} | json | objectRef.namespace="production" | stats count() by user.username'
```

### Operational Troubleshooting

```bash
# Debug Flux reconciliation issues
curl 'http://victoria-logs:9428/select/logsql/query' \
  -d 'query={stream="audit.kube-apiserver"} | json | user.username="system:serviceaccount:flux-system:flux" | last 1h'

# Track deployment failures
curl 'http://victoria-logs:9428/select/logsql/query' \
  -d 'query={stream="audit.kube-apiserver"} | json | verb="create" AND objectRef.resource="deployments" AND responseStatus.code!="201"'
```

---

## 🚨 Alerting Rules

### Critical Security Alerts

```yaml
# kubernetes/workloads/platform/observability/victoria-metrics/alerts/audit-alerts.yaml
apiVersion: operator.victoriametrics.com/v1beta1
kind: VMRule
metadata:
  name: audit-security-alerts
  namespace: monitoring
spec:
  groups:
    - name: kubernetes-audit-security
      interval: 1m
      rules:
        # Alert on Secret access by non-operator users
        - alert: UnauthorizedSecretAccess
          expr: |
            sum(increase(apiserver_audit_event_total{
              objectRef_resource="secrets",
              verb=~"get|list",
              user_username!~"system:serviceaccount:.*"
            }[5m])) > 0
          for: 0m
          labels:
            severity: critical
            category: security
          annotations:
            summary: "Unauthorized Secret access detected"
            description: "User {{ $labels.user_username }} accessed Secrets"

        # Alert on RBAC modifications
        - alert: RBACModification
          expr: |
            sum(increase(apiserver_audit_event_total{
              objectRef_resource=~".*role.*",
              verb=~"create|update|delete"
            }[5m])) > 0
          for: 0m
          labels:
            severity: warning
            category: security
          annotations:
            summary: "RBAC modification detected"
            description: "RBAC resource {{ $labels.objectRef_resource }} modified by {{ $labels.user_username }}"

        # Alert on excessive API failures (potential attack)
        - alert: HighAPIFailureRate
          expr: |
            sum(rate(apiserver_audit_event_total{responseStatus_code=~"4.*|5.*"}[5m]))
            / sum(rate(apiserver_audit_event_total[5m])) > 0.1
          for: 5m
          labels:
            severity: warning
            category: security
          annotations:
            summary: "High API failure rate detected (>10%)"
            description: "Potential attack or misconfiguration"
```

---

## 🔧 Troubleshooting

### Audit Logs Not Appearing

```bash
# Check API server is writing logs locally
talosctl ls /var/log/audit/ --nodes 10.25.11.11

# Check API server logs for errors
talosctl logs -k --nodes 10.25.11.11 | grep apiserver

# Verify Fluent Bit is tailing the file
kubectl logs -n monitoring daemonset/fluent-bit | grep audit
```

### Excessive Log Volume

```bash
# Identify noisy users/resources
curl 'http://victoria-logs:9428/select/logsql/query' \
  -d 'query={stream="audit.kube-apiserver"} | json | stats count() by user.username | sort by count desc | limit 20'

# Add exclusion rules to audit policy for noisy components
```

### Missing Audit Events

```bash
# Check if events are being filtered by policy
# Review audit policy rules and adjust levels
```

---

## 📋 Implementation Checklist

- [ ] Update `talos/machineconfig.yaml.j2` with audit policy
- [ ] Configure `auditPolicy` in apiServer section
- [ ] Set audit log file path and rotation settings
- [ ] Update Fluent Bit to tail audit logs
- [ ] Configure Victoria Logs to receive audit streams
- [ ] Apply updated machine configs to all control plane nodes
- [ ] Verify audit logs are being written locally
- [ ] Verify audit logs are streaming to Victoria Logs
- [ ] Create audit alert rules in Victoria Metrics
- [ ] Test audit log queries
- [ ] Schedule quarterly audit log review
- [ ] Document audit access procedures

---

## 🔗 Related Documentation

- [RBAC Security Model](./rbac-model.md) - BLOCKER #1
- [Data Classification](./data-classification.md) - BLOCKER #3
- [Victoria Logs Configuration](../../kubernetes/workloads/platform/observability/victoria-logs/)
- [Fluent Bit Configuration](../../kubernetes/workloads/platform/observability/fluent-bit/)
- [Architecture Decision Record](../architecture-decision-record.md)

---

**Status**: 📋 Ready for Implementation
**Next Action**: Update Talos machine config and apply
**Owner**: Platform Team
**Review Date**: Before Phase 1 Deployment
