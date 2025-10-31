# ClusterMesh DNS Configuration

This document describes the DNS configuration required for Cilium ClusterMesh discovery using FQDNs instead of direct IP addresses.

## Architecture Overview

### Split-Horizon DNS

This setup uses split-horizon DNS for the `monosense.io` domain:

- **Internal DNS (BIND)**: Resolves ClusterMesh FQDNs to private LoadBalancer IPs (10.25.11.x)
- **External DNS (Cloudflare)**: Handles public-facing services (not used for ClusterMesh)

### DNS Resolution Chain

```
Pod
  ↓
CoreDNS (kube-dns service)
  ↓ (forward . /etc/resolv.conf)
Talos Node DNS (10.25.10.30)
  ↓
BIND DNS Server
  ↓
clustermesh-*.monosense.io → 10.25.11.x
```

### Why DNS-Based Discovery?

- **Resilience**: FQDNs remain stable if LoadBalancer IPs change
- **Best Practice**: Recommended by Cilium for production deployments
- **Security**: Private IPs stay internal (not exposed via public DNS)
- **Future Automation**: Enables ExternalDNS integration later if needed

## DNS Record Requirements

### Required A Records

Add these records to your **internal BIND DNS server ONLY**:

| FQDN | IP Address | TTL | Type | Location |
|------|-----------|-----|------|----------|
| `clustermesh-infra.monosense.io` | `10.25.11.100` | 300 | A | BIND (Internal) |
| `clustermesh-apps.monosense.io` | `10.25.11.120` | 300 | A | BIND (Internal) |

**⚠️ CRITICAL**: Do NOT add these records to Cloudflare or any public DNS. These are internal-only records for private network communication.

## BIND Configuration

### Zone File Entry

Add the following entries to your `monosense.io` zone file on the BIND server:

```bind
; ClusterMesh API Server Records (Internal Only - Do Not Publish Externally)
; TTL 300 seconds (5 minutes)
clustermesh-infra    300    IN    A    10.25.11.100
clustermesh-apps     300    IN    A    10.25.11.120
```

### Alternative: Full FQDN Format

If your BIND configuration requires fully qualified names:

```bind
clustermesh-infra.monosense.io.    300    IN    A    10.25.11.100
clustermesh-apps.monosense.io.     300    IN    A    10.25.11.120
```

Note the trailing dot (`.`) which indicates a fully qualified domain name.

### Reload BIND Configuration

After adding the records, reload BIND configuration:

```bash
# SystemD
sudo systemctl reload bind9
# or
sudo systemctl reload named

# Legacy init
sudo service bind9 reload
# or
sudo rndc reload
```

## Cluster Settings Variables

The following variables have been added to cluster-settings ConfigMaps:

### Infra Cluster

File: `kubernetes/clusters/infra/cluster-settings.yaml`

```yaml
CILIUM_CLUSTERMESH_FQDN: "clustermesh-infra.monosense.io"
CILIUM_CLUSTERMESH_APPS_FQDN: "clustermesh-apps.monosense.io"
```

### Apps Cluster

File: `kubernetes/clusters/apps/cluster-settings.yaml`

```yaml
CILIUM_CLUSTERMESH_FQDN: "clustermesh-apps.monosense.io"
CILIUM_CLUSTERMESH_INFRA_FQDN: "clustermesh-infra.monosense.io"
```

These variables will be used by Cilium during ClusterMesh connection in Story 45.

## Validation Steps

### 1. Verify BIND DNS Resolution

Test DNS resolution directly from BIND server:

```bash
# Test from any host that can reach BIND
dig @10.25.10.30 clustermesh-infra.monosense.io +short
# Expected output: 10.25.11.100

dig @10.25.10.30 clustermesh-apps.monosense.io +short
# Expected output: 10.25.11.120
```

### 2. Verify from Talos Nodes

SSH to any Talos node and test resolution:

```bash
# Test DNS resolution (Talos uses 10.25.10.30 as nameserver)
nslookup clustermesh-infra.monosense.io
# Expected: Server: 10.25.10.30, Address: 10.25.11.100

nslookup clustermesh-apps.monosense.io
# Expected: Server: 10.25.10.30, Address: 10.25.11.120
```

### 3. Verify from Kubernetes Pods

Test DNS resolution from within the cluster (after CoreDNS is deployed):

```bash
# Run a debug pod with DNS tools
kubectl run -it --rm debug --image=nicolaka/netshoot --restart=Never -- bash

# Inside the debug pod:
dig clustermesh-infra.monosense.io +short
# Expected output: 10.25.11.100

dig clustermesh-apps.monosense.io +short
# Expected output: 10.25.11.120

nslookup clustermesh-infra.monosense.io
# Should show CoreDNS service IP (10.245.0.10 or 10.247.0.10) as server
```

### 4. Verify LoadBalancer Services

Confirm ClusterMesh LoadBalancer services have correct IPs:

```bash
# Infra cluster
kubectl --context infra get svc -n kube-system cilium-clustermesh
# EXTERNAL-IP should be 10.25.11.100

# Apps cluster
kubectl --context apps get svc -n kube-system cilium-clustermesh
# EXTERNAL-IP should be 10.25.11.120
```

### 5. Verify CoreDNS Forwarding

Check CoreDNS configuration includes forward plugin:

```bash
kubectl --context infra get cm -n kube-system coredns -o yaml | grep -A 5 forward
# Should see: forward . /etc/resolv.conf (default configuration)
```

## Troubleshooting

### DNS Resolution Fails from Pods

**Symptom**: `dig` or `nslookup` fails from pods, but works from nodes.

**Possible Causes**:
1. CoreDNS not running
2. CoreDNS not forwarding correctly

**Resolution**:
```bash
# Check CoreDNS pods
kubectl get pods -n kube-system -l k8s-app=kube-dns

# Check CoreDNS logs
kubectl logs -n kube-system -l k8s-app=kube-dns

# Verify CoreDNS service
kubectl get svc -n kube-system kube-dns
```

### DNS Resolution Works but Returns Wrong IP

**Symptom**: DNS resolves but returns incorrect IP address.

**Possible Causes**:
1. Incorrect BIND zone file entry
2. DNS caching (stale records)

**Resolution**:
```bash
# Verify BIND records directly
dig @10.25.10.30 clustermesh-infra.monosense.io +norecurse

# Clear CoreDNS cache (restart pods)
kubectl rollout restart deployment -n kube-system coredns
```

### DNS Resolution Times Out

**Symptom**: DNS queries hang or time out.

**Possible Causes**:
1. Network connectivity to BIND server
2. Firewall blocking DNS (port 53)
3. BIND not listening on 10.25.10.30

**Resolution**:
```bash
# Test connectivity from node to BIND
nc -vz 10.25.10.30 53

# Check BIND status
sudo systemctl status bind9  # or named

# Check BIND listening addresses
sudo netstat -tulpn | grep :53
```

### ClusterMesh Connection Fails (After Story 45)

**Symptom**: ClusterMesh status shows connection errors.

**Possible Causes**:
1. DNS resolution failing
2. Network connectivity blocked
3. TLS certificate issues

**Resolution**:
```bash
# Check ClusterMesh status
cilium clustermesh status --context infra
cilium clustermesh status --context apps

# Test connectivity to ClusterMesh API servers
curl -k https://clustermesh-infra.monosense.io:2379/healthz
curl -k https://clustermesh-apps.monosense.io:2379/healthz

# Check Cilium logs
kubectl logs -n kube-system -l k8s-app=cilium | grep clustermesh
```

## Post-Deployment Validation (Story 45)

After ClusterMesh is connected in Story 45, verify end-to-end functionality:

### Check ClusterMesh Connection Status

```bash
# From infra cluster
cilium clustermesh status --context infra
# Should show: "apps: connected"

# From apps cluster
cilium clustermesh status --context apps
# Should show: "infra: connected"
```

### Verify DNS-Based Discovery

```bash
# Check ClusterMesh configuration uses FQDNs
kubectl --context infra get cm -n kube-system cilium-config -o yaml | grep clustermesh

# Expected: Should reference FQDNs, not IPs
```

### Test Cross-Cluster Connectivity

```bash
# Deploy test services and verify pod-to-pod connectivity across clusters
# (Detailed in Story 45 validation)
```

## References

- **Story 12**: ClusterMesh LoadBalancer Configuration
- **Story 13**: ClusterMesh DNS Configuration (this document)
- **Story 45**: Flux Deployment and ClusterMesh Connection
- [Cilium ClusterMesh Documentation](https://docs.cilium.io/en/stable/network/clustermesh/)
- [CoreDNS Forward Plugin](https://coredns.io/plugins/forward/)

## Summary

This configuration enables DNS-based ClusterMesh discovery using internal BIND DNS:

✅ **DNS Records Added**: clustermesh-infra/apps.monosense.io → 10.25.11.100/120
✅ **Variables Configured**: CILIUM_CLUSTERMESH_FQDN in both cluster-settings
✅ **CoreDNS Forward**: Default configuration forwards to BIND (10.25.10.30)
✅ **Security**: Private IPs stay internal, not exposed publicly
✅ **Ready for Story 45**: ClusterMesh connection can use DNS discovery
