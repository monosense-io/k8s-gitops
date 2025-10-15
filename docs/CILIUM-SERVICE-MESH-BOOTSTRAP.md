# Cilium Service Mesh - Bootstrap Integration Guide

**Date:** 2025-10-15
**Architecture:** Cilium 1.18.x Service Mesh via Helmfile Bootstrap

---

## 🎯 Overview

Your infrastructure deploys **Cilium with full service mesh features** via the bootstrap helmfile. This guide explains what was configured and how to use it.

### Why Bootstrap (Not Flux)?

Cilium is your **CNI** - the networking foundation. It must be deployed BEFORE Flux, since Flux needs networking to function. The bootstrap sequence is:

```
1. Talos boots → 2. Helmfile deploys Cilium → 3. Networking works → 4. Flux deploys everything else
```

---

## 📁 Configuration Files

### Bootstrap Configuration

```
bootstrap/
├── helmfile.d/
│   └── 01-core.yaml              # Orchestrates Cilium deployment
└── clusters/
    ├── infra/
    │   ├── values.yaml           # Infra cluster settings
    │   └── cilium-values.yaml    # ✨ Cilium service mesh config (infra)
    └── apps/
        ├── values.yaml           # Apps cluster settings
        └── cilium-values.yaml    # ✨ Cilium service mesh config (apps)
```

### What Changed

**File: `bootstrap/helmfile.d/01-core.yaml`**
```yaml
# BEFORE (basic Cilium):
version: 1.18.2  # Pinned version
values: [minimal inline config]

# AFTER (service mesh):
version: ">=1.18.0 <1.19.0"  # Semantic versioning
values:
  - ../clusters/{{ .Environment.Name }}/cilium-values.yaml  # Full config
```

**New Files:**
- `bootstrap/clusters/infra/cilium-values.yaml` - 300+ lines of service mesh config
- `bootstrap/clusters/apps/cilium-values.yaml` - Same, with different cluster ID/CIDR

---

## ✨ Service Mesh Features Enabled

Your Cilium deployment now includes:

### 1. **WireGuard Encryption** (Transparent mTLS)
- ✅ All pod-to-pod traffic automatically encrypted
- ✅ Zero application changes required
- ✅ Kernel-level performance

```yaml
encryption:
  enabled: true
  type: wireguard
```

### 2. **SPIRE Workload Identity**
- ✅ Cryptographic identity for each workload
- ✅ Enables identity-based L7 policies
- ✅ Automatic certificate rotation

```yaml
authentication:
  enabled: true
  mutual:
    spire:
      enabled: true
```

### 3. **Hubble Observability**
- ✅ L7 protocol awareness (HTTP, gRPC, DNS, Kafka, etc.)
- ✅ Service dependency maps
- ✅ Golden metrics (success rate, RPS, latency)
- ✅ Real-time flow visualization

```yaml
hubble:
  enabled: true
  relay:
    enabled: true  # Cluster-wide aggregation
  ui:
    enabled: true  # Web-based service map
```

### 4. **Cluster Mesh** (Multi-Cluster)
- ✅ Cross-cluster service discovery
- ✅ Encrypted tunnels between clusters
- ✅ Global service load balancing
- ✅ No separate gateway pods needed

```yaml
clustermesh:
  useAPIServer: true
  apiserver:
    replicas: 2
    service:
      type: LoadBalancer
```

### 5. **BGP Control Plane**
- ✅ Native BGP support for advanced routing
- ✅ Integrates with your network infrastructure

```yaml
bgpControlPlane:
  enabled: true
```

### 6. **Gateway API**
- ✅ Modern ingress/egress management
- ✅ Replaces Ingress resources

```yaml
gatewayAPI:
  enabled: true
```

---

## 🚀 Deployment

### First-Time Bootstrap

```bash
# Bootstrap infra cluster with Cilium service mesh
task bootstrap:infra

# Bootstrap apps cluster
task bootstrap:apps

# Verify Cilium deployment
cilium status --wait --context infra
cilium status --wait --context apps
```

### Verify Service Mesh Features

```bash
# 1. Check kube-proxy replacement (service mesh enabled)
cilium status --context infra | grep KubeProxyReplacement
# Expected: KubeProxyReplacement:    True

# 2. Verify encryption
cilium encrypt status --context infra
# Expected: WireGuard keys and tunnels

# 3. Check Hubble
hubble status --context infra
# Expected: Healthcheck (via localhost:4245): Ok

# 4. View live flows
hubble observe --namespace kube-system --context infra

# 5. Launch Hubble UI
cilium hubble ui --context infra
# Opens http://localhost:12000
```

---

## 🌐 Multi-Cluster Setup (Week 3)

After both clusters are bootstrapped, connect them via Cluster Mesh:

```bash
# Enable Cluster Mesh (creates API servers)
cilium clustermesh enable --context infra --service-type LoadBalancer
cilium clustermesh enable --context apps --service-type LoadBalancer

# Connect clusters
cilium clustermesh connect --context apps --destination-context infra

# Verify connection
cilium clustermesh status --context apps
# Expected: ✅ infra: reachable, ready

# Export services from infra cluster
kubectl annotate svc/<service-name> -n <namespace> \
  io.cilium/global-service="true" \
  --context infra

# Access from apps cluster
# Service is available via standard DNS:
# <service-name>.<namespace>.svc.cluster.local
```

---

## 📊 Observability Stack

### Hubble CLI

```bash
# View all flows
hubble observe --context infra

# Specific namespace
hubble observe --namespace gitlab --context apps

# HTTP traffic only
hubble observe --protocol http --context apps

# Dropped packets (policy violations)
hubble observe --verdict DROPPED --context apps

# Cross-cluster traffic
hubble observe \
  --from-namespace gitlab \
  --to-namespace databases \
  --context apps
```

### Hubble UI

```bash
# Launch UI
cilium hubble ui --context infra

# Features:
# - Service dependency map
# - Real-time flow visualization
# - Protocol-aware inspection
# - Policy enforcement visualization
```

### Metrics

Hubble exports Prometheus metrics automatically scraped by Victoria Metrics:

```promql
# HTTP request rate
sum(rate(hubble_http_requests_total[5m])) by (namespace, pod)

# Success rate
sum(rate(hubble_http_requests_total{code=~"2.."}[5m]))
  /
sum(rate(hubble_http_requests_total[5m]))

# Dropped packets
sum(rate(hubble_drop_total[5m])) by (reason)
```

### Distributed Tracing (Week 3)

After deploying Jaeger, enable Hubble → Jaeger export:

```yaml
# Edit bootstrap/clusters/infra/cilium-values.yaml
hubble:
  export:
    dynamic:
      enabled: true  # Change from false
      config:
        configMapName: hubble-export-config
```

Then create the ConfigMap:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: hubble-export-config
  namespace: kube-system
data:
  config.yaml: |
    exports:
    - name: jaeger-otel
      dynamic:
        type: otel
        config:
          address: jaeger-collector.observability.svc.cluster.local:4317
          retryInterval: 30s
          exportInterval: 30s
```

```bash
# Re-run bootstrap to apply changes
task bootstrap:infra

# Restart Cilium pods
kubectl rollout restart daemonset/cilium -n kube-system --context infra
```

---

## 🔧 Modifying Configuration

### Update Cilium Settings

```bash
# 1. Edit configuration
vim bootstrap/clusters/infra/cilium-values.yaml
# or
vim bootstrap/clusters/apps/cilium-values.yaml

# 2. Re-run bootstrap
task bootstrap:infra
# or
task bootstrap:apps

# 3. Verify changes
cilium status --context infra
```

### Common Modifications

**Enable host firewall:**
```yaml
hostFirewall:
  enabled: true
```

**Adjust resource limits:**
```yaml
resources:
  requests:
    cpu: 300m      # Increase if needed
    memory: 768Mi
  limits:
    cpu: 2000m
    memory: 4Gi
```

**Tune BPF map sizes:**
```yaml
bpf:
  ctTcpMax: 1048576  # Double for large clusters
  natMax: 1048576
```

---

## 📈 Resource Usage

**Per Cluster:**
```
Cilium Overhead:
├─ Operator (2 replicas): 200m CPU, 256 MB RAM
├─ Agents (DaemonSet): 200m CPU × nodes, 512 MB RAM × nodes
├─ Hubble Relay: 100m CPU, 128 MB RAM
├─ Hubble UI: 50m CPU, 64 MB RAM
├─ Cluster Mesh API: 200m CPU, 256 MB RAM
└─ SPIRE: 100m CPU, 128 MB RAM

Total (3-node cluster): ~1.5 CPU, ~3 GB RAM
```

**No sidecars** - all traffic handled at kernel level (eBPF), not per-pod proxies.

---

## 🆚 Comparison: Your Architecture vs Alternatives

| Aspect | Your Setup (Cilium Bootstrap) | Linkerd (Rejected) |
|--------|------------------------------|-------------------|
| **Deployment** | ✅ Helmfile bootstrap | ❌ CLI-based |
| **GitOps** | ✅ Configuration in Git | ⚠️ Complex GitOps |
| **Version Management** | ✅ Semantic versioning | ❌ Pinned versions |
| **Resource Overhead** | ✅ ~1.5 CPU/cluster | ❌ ~6.9 CPU/cluster |
| **Sidecars** | ✅ None (eBPF) | ❌ One per pod |
| **Multi-Cluster** | ✅ Cluster Mesh (mature) | ⚠️ Service mirroring (newer) |
| **Observability** | ✅ Hubble (L7 aware) | ✅ Linkerd Viz (L7 aware) |
| **Encryption** | ✅ WireGuard (kernel) | ✅ Proxy mTLS |

---

## 🐛 Troubleshooting

### Cilium Not Starting

```bash
# Check pod status
kubectl get pods -n kube-system -l k8s-app=cilium --context infra

# Check logs
kubectl logs -n kube-system -l k8s-app=cilium --context infra --tail=50

# Common issues:
# 1. Kernel version too old (need 4.9.17+)
# 2. SELinux blocking (Talos doesn't have this)
# 3. Previous CNI remnants (Talos uses cni: none so no issue)
```

### Encryption Not Working

```bash
# Verify WireGuard module
kubectl exec -n kube-system ds/cilium --context infra -- lsmod | grep wireguard

# If missing, check Talos kernel (should include WireGuard)
talosctl get members --context infra

# Check encryption status
cilium encrypt status --context infra
```

### Hubble Not Showing Flows

```bash
# Check Hubble relay
kubectl get pods -n kube-system -l k8s-app=hubble-relay --context infra

# Restart if needed
kubectl rollout restart deployment/hubble-relay -n kube-system --context infra

# Check hubble status
hubble status --context infra

# If "connection refused", port-forward manually:
cilium hubble port-forward --context infra
```

### Cluster Mesh Not Connecting

```bash
# Check API server status
kubectl get pods -n kube-system -l k8s-app=clustermesh-apiserver --context infra

# Verify LoadBalancer service
kubectl get svc clustermesh-apiserver -n kube-system --context infra
# Should have EXTERNAL-IP

# Check connectivity
cilium clustermesh status --verbose --context apps

# Common fix: Re-establish connection
cilium clustermesh disconnect --context apps --destination-context infra
cilium clustermesh connect --context apps --destination-context infra
```

---

## 📚 Next Steps

### Week 1-2 (Now): Foundation ✅

- [x] Cilium deployed with service mesh features
- [x] Hubble observability enabled
- [x] Encryption active (WireGuard)
- [x] SPIRE identity enabled
- [ ] Deploy Victoria Metrics (for Hubble metrics)

### Week 3: Multi-Cluster

- [ ] Enable Cluster Mesh on both clusters
- [ ] Connect infra ↔ apps clusters
- [ ] Deploy Jaeger for distributed tracing
- [ ] Enable Hubble → Jaeger export
- [ ] Test cross-cluster service discovery

### Week 4+: Platform Services

- [ ] Deploy CloudNativePG (infra cluster)
- [ ] Export database services via Cluster Mesh
- [ ] Deploy applications (apps cluster)
- [ ] Validate cross-cluster communication
- [ ] Implement Cilium Network Policies

---

## 📖 Reference Documentation

- **Your Cilium Config:** `bootstrap/clusters/{infra,apps}/cilium-values.yaml`
- **Cilium Docs:** https://docs.cilium.io/
- **Cluster Mesh:** https://docs.cilium.io/en/stable/network/clustermesh/
- **Hubble:** https://docs.cilium.io/en/stable/observability/hubble/
- **Detailed Observability Guide:** `docs/hubble-observability-guide.md`
- **Full Implementation Plan:** `docs/cilium-service-mesh-implementation-plan.md`

---

## ✅ Success Metrics

After deployment, you should see:

```bash
# All checks pass
cilium status --context infra

# Output shows:
#     /¯¯\
#  /¯¯\__/¯¯\    Cilium:             OK
#  \__/¯¯\__/    Operator:           OK
#  /¯¯\__/¯¯\    Hubble Relay:       OK
#  \__/¯¯\__/    ClusterMesh:        OK
#     \__/       Encryption:         Wireguard [cilium_wg0]
#
# KubeProxyReplacement:  True
# Encryption:            Wireguard
```

**You're ready for Week 3: Multi-Cluster Service Mesh!** 🚀

---

*Generated: 2025-10-15*
*Architecture: Cilium 1.18.x Service Mesh on Talos Linux*
*Deployment Method: Helmfile Bootstrap → Flux GitOps*
