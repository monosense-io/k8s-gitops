# Phase 2: ClusterMesh Activation & Verification Guide

## Overview
Phase 2 activates Cilium ClusterMesh to enable cross-cluster service discovery and load balancing. This allows the apps cluster to access DragonflyDB running in the infra cluster via the same DNS name.

## Configuration Changes

### 1. Cilium HelmRelease (helmrelease-infra.yaml)
- **Enabled**: `clustermesh.config.enabled: true`
- **Added**: Apps cluster configuration
  - Cluster name: `apps`
  - Address: `apps-cilium-apiserver.monosense.io`
  - Port: `443`
  - TLS validation mode: `skip` (can be set to `strict` after cert validation)

### 2. DragonflyDB Service Annotations (service.yaml)
- **Added**: `service.cilium.io/shared: "true"` (explicit cross-cluster sharing flag)
- **Existing**: `service.cilium.io/global: "true"` (makes service visible across clusters)

## Pre-Deployment Checklist

Before applying Phase 2 changes, verify:

```bash
# 1. Verify Cilium ClusterMesh APIServer is running in infra cluster
kubectl get pods -n kube-system | grep clustermesh-apiserver

# 2. Verify LoadBalancer service is accessible
kubectl get svc -n kube-system clustermesh-apiserver -o wide

# 3. Verify SPIRE is running (required for mTLS)
kubectl get pods -n spire-system

# 4. Check current ClusterMesh status (before enabling)
cilium clustermesh status

# 5. Verify DragonflyDB operator is running
kubectl get pods -n dragonfly-system
```

## Deployment Steps

### Step 1: Apply Phase 2 Changes
```bash
# Validate manifests first
task kubernetes:validate -- TARGET=infrastructure

# Apply changes via Flux
flux reconcile source git flux-system --with-source
flux reconcile ks cluster-infra-infrastructure --with-source

# Monitor reconciliation
flux get kustomizations -A --watch
```

### Step 2: Monitor Cilium Deployment
```bash
# Watch Cilium operator and agents
kubectl get pods -n kube-system -l app.kubernetes.io/name=cilium -w

# Watch Cilium agents restart (this may take a few minutes)
# Once all Cilium pods are ready, proceed to verification
```

## Post-Deployment Verification

### Verification 1: ClusterMesh Status
```bash
# Check ClusterMesh connection status
cilium clustermesh status

# Expected output:
# ✓ ClusterMesh is OK
# - apps: 1/1 reachable  (should show connectivity to apps cluster)
```

### Verification 2: Global Service Registration
```bash
# List services with global annotations
cilium service list -n dragonfly-system

# Expected output showing dragonfly-global service with:
# - Global: true
# - Endpoints from both clusters (initially just infra)

# Alternative check with kubectl
kubectl get svc -n dragonfly-system dragonfly-global -o wide
kubectl describe svc -n dragonfly-system dragonfly-global
```

### Verification 3: Service Endpoints
```bash
# Check endpoints for global service (infra cluster perspective)
kubectl get endpoints -n dragonfly-system dragonfly-global

# Expected: Shows all 3 DragonflyDB pod IPs (master + 2 replicas)
# Format: 10.244.x.y:6379,10.244.x.y:6379,10.244.x.y:6379
```

### Verification 4: DNS Resolution
```bash
# From infra cluster pod, verify DNS resolves correctly
kubectl run -it --rm debug --image=busybox --restart=Never -- \
  nslookup dragonfly.dragonfly-system.svc.cluster.local

# Expected: Returns A record with one or more IPs
# Example output:
# Server:    10.96.0.10
# Address:   10.96.0.10:53
#
# Name:      dragonfly.dragonfly-system.svc.cluster.local
# Address:   10.244.x.y
```

### Verification 5: Service Connectivity
```bash
# Test connectivity to DragonflyDB from infra cluster
kubectl run -it --rm redis-test \
  --image=redis:7 \
  --restart=Never \
  -- redis-cli -h dragonfly.dragonfly-system.svc.cluster.local -p 6379 ping

# Expected: PONG (may require auth after full setup)

# With authentication (once SynergyFlow is updated)
kubectl run -it --rm redis-test \
  --image=redis:7 \
  --restart=Never \
  -- redis-cli -h dragonfly.dragonfly-system.svc.cluster.local -p 6379 -a <password> ping
```

### Verification 6: ClusterMesh API Server Connectivity
```bash
# Verify ClusterMesh API server is accessible from apps cluster
# Run this from apps cluster:
kubectl get nodes

# If this works, the ClusterMesh connection to infra is established
```

## Troubleshooting

### Issue: ClusterMesh status shows "Not Connected"
```bash
# 1. Check ClusterMesh API server logs in infra cluster
kubectl logs -n kube-system -l app=clustermesh-apiserver --tail=100

# 2. Verify LoadBalancer service has external IP
kubectl get svc -n kube-system clustermesh-apiserver
# If EXTERNAL-IP is <pending>, check cloud provider/metallb status

# 3. Verify DNS/connectivity from apps to infra
# From apps cluster, try to reach the LoadBalancer IP
nslookup apps-cilium-apiserver.monosense.io
ping <IP-from-DNS>
```

### Issue: Global service not showing up in apps cluster
```bash
# 1. Check service has both annotations
kubectl get svc -n dragonfly-system dragonfly-global -o yaml | grep service.cilium.io

# 2. Check Cilium agent status in apps cluster
cilium status

# 3. Check if ClusterMesh service export is enabled
kubectl get ciliumnodes -o json | jq '.items[].spec.networking.clustermesh'
```

### Issue: DNS not resolving in apps cluster
```bash
# 1. Check CoreDNS status
kubectl get pods -n kube-system -l k8s-app=kube-dns

# 2. Test DNS from pod in apps cluster
kubectl run -it --rm debug \
  --image=busybox \
  --restart=Never \
  -n synergyflow \
  -- nslookup dragonfly.dragonfly-system.svc.cluster.local

# 3. Check if DNS cache is stale
kubectl delete pod -n kube-system -l k8s-app=kube-dns
```

## Monitoring & Observability

### Hubble Flow Logs
```bash
# View network flows involving DragonflyDB
hubble observe -n dragonfly-system -l "app.kubernetes.io/name=dragonfly"

# View flows from apps cluster to dragonfly (cross-cluster)
hubble observe --from-namespace apps --to-namespace dragonfly-system
```

### Prometheus Metrics
```bash
# Verify Cilium metrics are being scraped
# In Prometheus UI, run: count(cilium_build_info) by (cluster_name)
# Should show metrics from both clusters after Phase 3

# ClusterMesh specific metrics:
# cilium_clustermesh_apiserver_endpoints_total
# cilium_clustermesh_apiserver_synchronization_errors_total
```

## Next Steps

Once Phase 2 verification is complete:

1. **Phase 3 (Fix Consumer Applications)**:
   - Update SynergyFlow configmap with correct namespace reference
   - Fix SynergyFlow NetworkPolicy for cross-cluster access
   - Verify Harbor configuration

2. **Phase 4 (Cross-Cluster Connectivity & Monitoring)**:
   - Test data access from apps cluster pods
   - Simulate failover scenarios
   - Monitor cross-cluster latency

## Rollback Plan

If issues occur during Phase 2 deployment:

```bash
# 1. Disable ClusterMesh config
# Edit helmrelease-infra.yaml: change config.enabled back to false

# 2. Apply rollback
flux reconcile ks cluster-infra-infrastructure --with-source

# 3. Remove service.cilium.io/shared annotation
# Edit service.yaml to remove the annotation

# 4. Re-apply workloads
flux reconcile ks cluster-infra-workloads --with-source
```

## Documentation References

- [Cilium ClusterMesh Documentation](https://docs.cilium.io/en/stable/network/clustermesh/)
- [Global Services](https://docs.cilium.io/en/stable/network/clustermesh/services/)
- [ServiceMonitor Integration](https://docs.cilium.io/en/stable/observability/metrics/)

## Timeline Estimate

- **Deployment**: 5-10 minutes (Cilium pod restarts)
- **Verification**: 10-15 minutes (service sync + DNS propagation)
- **Total Phase 2**: ~30 minutes

---

**Document Version**: 1.0
**Created**: 2024-10-19
**Status**: Ready for Phase 2 Deployment
