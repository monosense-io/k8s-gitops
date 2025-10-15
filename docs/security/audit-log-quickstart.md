# Audit Logging Quick Start Guide

**Quick Reference for Enabling Kubernetes Audit Logging**
**Security BLOCKER #2 - Implementation Guide**

---

## ✅ Prerequisites Completed

1. ✅ Audit policy added to `talos/machineconfig.yaml.j2` (lines 126-199)
2. ✅ Fluent Bit config created (`kubernetes/workloads/platform/observability/fluent-bit/audit-logs-config.yaml`)
3. ✅ Documentation complete (`docs/security/talos-audit-policy.md`)

---

## 🚀 Deployment Steps

### Step 1: Regenerate Talos Machine Configs

The audit policy is now embedded in the machine config template. Regenerate configs for all control plane nodes:

```bash
# Infra cluster
task talos:apply-node NODE=10.25.11.11 CLUSTER=infra MACHINE_TYPE=controlplane
task talos:apply-node NODE=10.25.11.12 CLUSTER=infra MACHINE_TYPE=controlplane
task talos:apply-node NODE=10.25.11.13 CLUSTER=infra MACHINE_TYPE=controlplane

# Apps cluster
task talos:apply-node NODE=10.25.11.14 CLUSTER=apps MACHINE_TYPE=controlplane
task talos:apply-node NODE=10.25.11.15 CLUSTER=apps MACHINE_TYPE=controlplane
task talos:apply-node NODE=10.25.11.16 CLUSTER=apps MACHINE_TYPE=controlplane
```

### Step 2: Verify Audit Logs Locally

```bash
# Check audit log directory exists
talosctl ls /var/log/audit/ --nodes 10.25.11.11

# Tail audit logs
talosctl read /var/log/audit/kube-apiserver-audit.log --nodes 10.25.11.11 | tail -20

# Verify JSON format
talosctl read /var/log/audit/kube-apiserver-audit.log --nodes 10.25.11.11 | tail -1 | jq .
```

### Step 3: Update Fluent Bit Configuration

Add audit log configuration to your Fluent Bit HelmRelease:

```yaml
# kubernetes/bases/fluent-bit/helmrelease.yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: fluent-bit
  namespace: monitoring
spec:
  values:
    config:
      # Existing inputs...
      inputs: |
        # ... existing inputs ...

        # Kubernetes Audit Logs (NEW)
        [INPUT]
            Name              tail
            Tag               audit.kube-apiserver
            Path              /var/log/audit/kube-apiserver-audit.log
            Parser            json
            DB                /var/fluent-bit/state/audit.db
            Mem_Buf_Limit     50MB
            Skip_Long_Lines   On
            Refresh_Interval  10

      # Existing filters...
      filters: |
        # ... existing filters ...

        # Audit log enrichment (NEW)
        [FILTER]
            Name    modify
            Match   audit.kube-apiserver
            Add     cluster ${CLUSTER_NAME}
            Add     stream audit.kube-apiserver

      # Existing outputs...
      outputs: |
        # ... existing outputs ...

        # Victoria Logs output for audit (NEW)
        [OUTPUT]
            Name                 http
            Match                audit.kube-apiserver
            Host                 victoria-logs.monitoring.svc.cluster.local
            Port                 9428
            URI                  /insert/jsonline?_stream_fields=stream,cluster
            Format               json_lines
            Header               AccountID 0
            Header               ProjectID 0
            compress             gzip

    # Add volume mount for audit logs (NEW)
    extraVolumes:
      - name: varlogaudit
        hostPath:
          path: /var/log/audit
          type: DirectoryOrCreate

    extraVolumeMounts:
      - name: varlogaudit
        mountPath: /var/log/audit
        readOnly: true
```

### Step 4: Deploy Fluent Bit Changes

```bash
# Commit and push Fluent Bit config changes
git add kubernetes/bases/fluent-bit/helmrelease.yaml
git commit -m "feat(security): enable audit log forwarding to Victoria Logs"
git push

# Force reconcile Fluent Bit
flux reconcile helmrelease fluent-bit -n monitoring --force
```

### Step 5: Verify Logs in Victoria Logs

```bash
# Port-forward to Victoria Logs
kubectl port-forward -n monitoring svc/victoria-logs 9428:9428

# Query audit logs
curl 'http://localhost:9428/select/logsql/query' \
  -d 'query={stream="audit.kube-apiserver"} | limit 10' | jq .

# Check log volume
curl 'http://localhost:9428/select/logsql/query' \
  -d 'query={stream="audit.kube-apiserver"} | stats count() by cluster'
```

---

## 🔍 Validation Checks

### ✅ Checklist

- [ ] Audit logs present in `/var/log/audit/kube-apiserver-audit.log` on each control plane
- [ ] Logs are valid JSON format
- [ ] Log rotation working (multiple `.log.*` files after 100MB)
- [ ] Fluent Bit pod running on control plane nodes
- [ ] Fluent Bit tailing audit log file (check logs: `kubectl logs -n monitoring daemonset/fluent-bit | grep audit`)
- [ ] Victoria Logs receiving audit events (query shows results)
- [ ] No permission errors in Fluent Bit logs
- [ ] Audit log volume reasonable (~8-10GB/day compressed)

### 🧪 Test Scenarios

```bash
# 1. Test: Create a secret (should be logged at Request level)
kubectl create secret generic test-audit --from-literal=key=value -n default
sleep 5
curl 'http://localhost:9428/select/logsql/query' \
  -d 'query={stream="audit.kube-apiserver"} | json | objectRef.name="test-audit"' | jq .

# 2. Test: RBAC change (should be logged at Request level)
kubectl create clusterrole test-audit-role --verb=get --resource=pods
sleep 5
curl 'http://localhost:9428/select/logsql/query' \
  -d 'query={stream="audit.kube-apiserver"} | json | objectRef.name="test-audit-role"' | jq .

# 3. Test: Normal pod operation (should be logged at Metadata level)
kubectl get pods -A
sleep 5
curl 'http://localhost:9428/select/logsql/query' \
  -d 'query={stream="audit.kube-apiserver"} | json | verb="list" AND objectRef.resource="pods"' | jq .
```

---

## 🚨 Troubleshooting

### Issue: No audit logs in Victoria Logs

```bash
# Check 1: Logs exist locally?
talosctl ls /var/log/audit/ --nodes 10.25.11.11

# Check 2: Fluent Bit running on control plane?
kubectl get pods -n monitoring -l app.kubernetes.io/name=fluent-bit -o wide | grep "10.25.11.11"

# Check 3: Fluent Bit can access file?
kubectl logs -n monitoring daemonset/fluent-bit | grep -i audit

# Check 4: Victoria Logs reachable?
kubectl exec -n monitoring daemonset/fluent-bit -- wget -qO- http://victoria-logs:9428/health
```

### Issue: Excessive audit log volume

```bash
# Identify noisy users
curl 'http://localhost:9428/select/logsql/query' \
  -d 'query={stream="audit.kube-apiserver"} | json | stats count() by user.username | sort by count desc'

# Add exclusions to audit policy in machineconfig.yaml.j2:
# - level: None
#   users: [system:serviceaccount:namespace:noisy-app]
```

### Issue: Audit logs filling disk

```bash
# Check current usage
talosctl df /var/log/audit --nodes 10.25.11.11

# Reduce retention (edit machineconfig.yaml.j2):
# audit-log-maxage: "3"     # Keep for 3 days instead of 7
# audit-log-maxbackup: "2"  # Keep 2 files instead of 3
```

---

## 📊 Useful Queries

### Security Investigations

```bash
# Find all Secret accesses
curl 'http://localhost:9428/select/logsql/query' \
  -d 'query={stream="audit.kube-apiserver"} | json | objectRef.resource="secrets" | limit 100'

# Find failed auth attempts
curl 'http://localhost:9428/select/logsql/query' \
  -d 'query={stream="audit.kube-apiserver"} | json | responseStatus.code="403" | limit 50'

# Find RBAC modifications
curl 'http://localhost:9428/select/logsql/query' \
  -d 'query={stream="audit.kube-apiserver"} | json | objectRef.resource=~".*role.*" AND verb=~"create|delete" | limit 50'
```

### Operational Insights

```bash
# Top API users
curl 'http://localhost:9428/select/logsql/query' \
  -d 'query={stream="audit.kube-apiserver"} | json | stats count() by user.username | sort by count desc | limit 20'

# API request rate
curl 'http://localhost:9428/select/logsql/query' \
  -d 'query={stream="audit.kube-apiserver"} | json | stats count() by bin(1m)'

# Flux reconciliation activity
curl 'http://localhost:9428/select/logsql/query' \
  -d 'query={stream="audit.kube-apiserver"} | json | user.username=~".*flux.*" | limit 50'
```

---

## 🔗 Related Documentation

- **Full Policy Documentation**: [docs/security/talos-audit-policy.md](./talos-audit-policy.md)
- **RBAC Model**: [docs/security/rbac-model.md](./rbac-model.md)
- **Victoria Logs**: [kubernetes/workloads/platform/observability/victoria-logs/](../../kubernetes/workloads/platform/observability/victoria-logs/)

---

**Status**: ✅ Ready for Deployment
**Estimated Time**: 30 minutes
**Risk Level**: Low (non-breaking change, adds logging only)
