# LoadBalancer IP Allocation Summary

**Last Updated:** 2025-10-22 (Architectural Review & Correction)
**Status:** Greenfield-Ready

---

## 🎯 Network Topology

- **Shared L2 Subnet:** `10.25.11.0/24`
- **BGP Router:** `10.25.11.1` (ASN 64501)
- **Infra Cluster ASN:** 64512
- **Apps Cluster ASN:** 64513

---

## 📊 IP Pool Allocation

### Infra Cluster: `10.25.11.100-119` (20 IPs)

| IP Address | Assignment | Service | Status |
|---|---|---|---|
| `10.25.11.100` | ClusterMesh API | `clustermesh-apiserver.kube-system.svc` | ✅ Reserved |
| `10.25.11.101-109` | - | Available | 🟢 Available |
| `10.25.11.110` | Gateway API | `cilium-gateway.kube-system.svc` | ✅ Reserved |
| `10.25.11.111-119` | - | Available | 🟢 Available |

**Total:** 18 available IPs for future LoadBalancer services

### Apps Cluster: `10.25.11.120-139` (20 IPs)

| IP Address | Assignment | Service | Status |
|---|---|---|---|
| `10.25.11.120` | ClusterMesh API | `clustermesh-apiserver.kube-system.svc` | ✅ Reserved |
| `10.25.11.121` | Gateway API | `cilium-gateway.kube-system.svc` | ✅ Reserved |
| `10.25.11.122-139` | - | Available | 🟢 Available |

**Total:** 18 available IPs for future LoadBalancer services

---

## 🔧 Configuration Locations

### Bootstrap (Helmfile Phase 1)

**Files:**
- `bootstrap/clusters/infra/cilium-values.yaml`
- `bootstrap/clusters/apps/cilium-values.yaml`

**Critical Annotations:**
```yaml
# Infra Cluster
clustermesh:
  apiserver:
    service:
      annotations:
        io.cilium/lb-ipam-ips: "10.25.11.100"

gatewayAPI:
  envoy:
    service:
      annotations:
        io.cilium/lb-ipam-ips: "10.25.11.110"
```

```yaml
# Apps Cluster
clustermesh:
  apiserver:
    service:
      annotations:
        io.cilium/lb-ipam-ips: "10.25.11.120"

gatewayAPI:
  envoy:
    service:
      annotations:
        io.cilium/lb-ipam-ips: "10.25.11.121"
```

### Cluster Settings (Flux Phase 2+)

**Files:**
- `kubernetes/clusters/infra/cluster-settings.yaml`
- `kubernetes/clusters/apps/cluster-settings.yaml`

**Infra Cluster:**
```yaml
CLUSTERMESH_IP: "10.25.11.100"
CILIUM_GATEWAY_LB_IP: "10.25.11.110"
INFRA_POOL_DISABLED: "false"
APPS_POOL_DISABLED: "true"
CILIUM_LB_POOL_START: "10.25.11.100"
CILIUM_LB_POOL_END: "10.25.11.119"
```

**Apps Cluster:**
```yaml
CLUSTERMESH_IP: "10.25.11.120"
CILIUM_GATEWAY_LB_IP: "10.25.11.121"
INFRA_POOL_DISABLED: "true"
APPS_POOL_DISABLED: "false"
CILIUM_LB_POOL_START: "10.25.11.120"
CILIUM_LB_POOL_END: "10.25.11.139"
```

### IPAM Pool Manifests

**Files:**
- `kubernetes/infrastructure/networking/cilium/ipam/lb-ippool-infra.yaml`
- `kubernetes/infrastructure/networking/cilium/ipam/lb-ippool-apps.yaml`

**Pool Isolation Pattern:**
```yaml
spec:
  disabled: ${CLUSTER}_POOL_DISABLED  # Controlled per cluster
  blocks:
    - start: "${CILIUM_LB_POOL_START}"
      stop: "${CILIUM_LB_POOL_END}"
  serviceSelector: {}  # Default pool when enabled
```

---

## ✅ Validation Commands

### Check Pool Deployment
```bash
# Infra cluster
kubectl --context=infra get ciliumloadbalancerippool -A -o yaml

# Apps cluster
kubectl --context=apps get ciliumloadbalancerippool -A -o yaml
```

### Verify Service IPs
```bash
# Infra ClusterMesh (expect: 10.25.11.100)
kubectl --context=infra get svc -n kube-system clustermesh-apiserver \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

# Infra Gateway (expect: 10.25.11.110)
kubectl --context=infra get gateway -n kube-system \
  -o jsonpath='{.items[0].status.addresses[0].value}'

# Apps ClusterMesh (expect: 10.25.11.120)
kubectl --context=apps get svc -n kube-system clustermesh-apiserver \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

# Apps Gateway (expect: 10.25.11.121)
kubectl --context=apps get gateway -n kube-system \
  -o jsonpath='{.items[0].status.addresses[0].value}'
```

### Check BGP Advertisement
```bash
# On BGP router (10.25.11.1)
show ip bgp summary
show ip route bgp

# Expected routes:
# - 10.25.11.100/32 via infra nodes
# - 10.25.11.110/32 via infra nodes
# - 10.25.11.120/32 via apps nodes
# - 10.25.11.121/32 via apps nodes
```

---

## 🚨 Critical Corrections Made

### Issue 1: Apps Bootstrap Subnet Mismatch
**Problem:** `bootstrap/clusters/apps/cilium-values.yaml` used wrong subnet (`10.25.12.x`)
**Fix:** Changed to `10.25.11.x` (shared L2 subnet per architecture)

### Issue 2: IP Pool Conflicts
**Problem:** Infra Gateway at `.120` (in apps pool range), Apps ClusterMesh at `.101` (in infra pool range)
**Fix:** 
- Infra Gateway: `.120` → `.110`
- Apps ClusterMesh: `.101` → `.120`

### Issue 3: Cross-Cluster Pool Pollution
**Problem:** `serviceSelector: {}` matched ALL services on both clusters (shared manifests)
**Fix:** Added `disabled` flag controlled by cluster-settings

---

## 📖 Related Documentation

- **Story:** `docs/stories/STORY-NET-CILIUM-IPAM.md` (03/41)
- **Architecture:** `docs/architecture.md` §9 (Networking)
- **Gateway Story:** `docs/stories/STORY-NET-CILIUM-GATEWAY.md` (04/41)
- **BGP Story:** `docs/stories/STORY-NET-CILIUM-BGP.md` (19/41)

---

## 🎯 Design Principles

1. **Pool Isolation:** Each cluster has dedicated range; no cross-cluster allocation
2. **Clean Segmentation:** Contiguous ranges, no gaps or overlaps
3. **Predictable Assignment:** Critical infrastructure at start of pools
4. **Scalability:** ~18 IPs available per cluster for growth
5. **BGP-Friendly:** Each cluster advertises only its own range
6. **GitOps-Aligned:** Single source of truth via cluster-settings substitution

---

**Generated:** 2025-10-22 by Architect (Winston)
