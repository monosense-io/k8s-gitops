# ⚠️ DEPRECATED - Cilium Managed via Bootstrap

## Status: NOT USED

**Cilium is deployed via the bootstrap helmfile, not via Flux/GitOps.**

### Why Bootstrap Instead of Flux?

Cilium is the **CNI (Container Network Interface)** - the foundation that enables pod networking. It must be deployed BEFORE Flux can function, since Flux itself needs networking to pull manifests from Git.

### Where is Cilium Actually Configured?

**Cilium Service Mesh configuration:**
- `bootstrap/clusters/infra/cilium-values.yaml`
- `bootstrap/clusters/apps/cilium-values.yaml`
- `bootstrap/helmfile.d/01-core.yaml` (deployment orchestration)

### What's in These Files?

These manifests were created during architecture exploration but are **NOT deployed**. They're kept for reference only.

If you need to modify Cilium configuration, edit:
```bash
bootstrap/clusters/infra/cilium-values.yaml
bootstrap/clusters/apps/cilium-values.yaml
```

Then re-run bootstrap:
```bash
task bootstrap:infra
# or
task bootstrap:apps
```

---

## Cilium Features Enabled

The bootstrap configuration includes **full service mesh features**:

### Prerequisites

1. **Talos clusters bootstrapped** with kubectl access
2. **FluxCD installed** on both clusters
3. **Cilium CLI installed** locally:
   ```bash
   brew install cilium-cli
   # or
   curl -L --remote-name-all https://github.com/cilium/cilium-cli/releases/latest/download/cilium-darwin-amd64.tar.gz
   sudo tar xzvfC cilium-darwin-amd64.tar.gz /usr/local/bin
   ```

### Step 1: Deploy via Git

```bash
# Commit and push to Git
git add kubernetes/infrastructure/cilium/
git commit -m "feat: add Cilium CNI with Service Mesh"
git push

# Flux will automatically reconcile
# Or manually trigger:
flux reconcile source git flux-system --context infra
flux reconcile source git flux-system --context apps
```

### Step 2: Verify Deployment

```bash
# Check Cilium status on infra cluster
cilium status --wait --context infra

# Check Cilium status on apps cluster
cilium status --wait --context apps

# Verify all components are running
kubectl get pods -n kube-system -l k8s-app=cilium --context infra
kubectl get pods -n kube-system -l k8s-app=cilium --context apps
```

### Step 3: Validate Service Mesh Features

```bash
# Verify kube-proxy replacement (service mesh enabled)
cilium status --context infra | grep KubeProxyReplacement
# Expected: KubeProxyReplacement:    True

# Verify encryption is enabled
cilium encrypt status --context infra
# Expected: WireGuard keys and tunnels shown

# Verify Hubble is working
hubble status --context infra
# Expected: Healthcheck (via localhost:4245): Ok

# View live network flows
hubble observe --context infra --namespace kube-system
```

---

## Key Configuration Differences Between Clusters

| Setting | Infra Cluster | Apps Cluster |
|---------|--------------|-------------|
| `cluster.name` | `infra` | `apps` |
| `cluster.id` | `1` | `2` |
| `ipv4NativeRoutingCIDR` | `10.244.0.0/16` | `10.246.0.0/16` |

All other settings are identical to ensure consistent service mesh behavior across clusters.

---

## Service Mesh Features

### 1. Transparent Encryption (WireGuard)

All pod-to-pod traffic is automatically encrypted using WireGuard tunnels.

**Configuration:**
```yaml
encryption:
  enabled: true
  type: wireguard
```

**Verification:**
```bash
cilium encrypt status --context infra
```

### 2. Workload Identity (SPIRE)

SPIRE provides cryptographic identity to workloads for identity-based policies.

**Configuration:**
```yaml
authentication:
  enabled: true
  mutual:
    spire:
      enabled: true
      install:
        enabled: true
```

**Verification:**
```bash
kubectl get pods -n cilium-spire --context infra
```

### 3. Hubble Observability

Hubble provides L7 network observability including:
- Real-time flow visualization
- Service dependency maps
- Golden metrics (success rate, RPS, latency)
- Protocol-aware monitoring (HTTP, gRPC, DNS, Kafka, etc.)

**Access Hubble UI:**
```bash
cilium hubble ui --context infra
# Opens http://localhost:12000
```

**View flows via CLI:**
```bash
hubble observe --context infra --namespace default
```

### 4. Cluster Mesh (Multi-Cluster)

Cluster Mesh enables:
- Cross-cluster service discovery
- Load balancing across clusters
- Encrypted tunnels between clusters
- Global service definitions

**Setup** (performed in Week 3):
```bash
# Enable Cluster Mesh on both clusters
cilium clustermesh enable --context infra --service-type LoadBalancer
cilium clustermesh enable --context apps --service-type LoadBalancer

# Connect clusters
cilium clustermesh connect --context apps --destination-context infra

# Verify
cilium clustermesh status --context apps
```

---

> DEPRECATION NOTICE
>
> The manifests under `kubernetes/infrastructure/cilium/` are retained for historical reference only.
> Cilium is now managed via GitOps under `kubernetes/infrastructure/networking/cilium/core/`.
> Do not modify these files for live configuration.

## Observability

### Metrics

Cilium exports Prometheus metrics that are scraped by Victoria Metrics.

**Key metrics:**
- `cilium_endpoint_*`: Endpoint (pod) statistics
- `cilium_policy_*`: Network policy enforcement
- `hubble_flows_processed_total`: Network flows observed
- `hubble_drop_total`: Dropped packets
- `cilium_bpf_*`: eBPF program statistics

### Hubble Flow Logs

View real-time network flows:

```bash
# All flows in a namespace
hubble observe --namespace gitlab --context apps

# Flows from specific pod
hubble observe --from-pod frontend-12345 --context apps

# Flows to specific service
hubble observe --to-service postgres-rw --context apps

# HTTP flows only
hubble observe --protocol http --context apps

# Dropped packets
hubble observe --verdict DROPPED --context apps
```

### Distributed Tracing

Hubble can export traces to Jaeger (configured in Week 3 after Jaeger deployment).

**Configuration** (added in Week 3):
```yaml
hubble:
  export:
    dynamic:
      enabled: true
      config:
        content:
        - name: jaeger-otel
          dynamic:
            type: otel
            config:
              address: jaeger-collector.observability.svc.cluster.local:4317
```

---

## Network Policies

Cilium supports L3/L4/L7 network policies using CiliumNetworkPolicy CRDs.

### Example: Allow HTTP GET only

```yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: allow-http-get
  namespace: default
spec:
  endpointSelector:
    matchLabels:
      app: backend
  ingress:
  - fromEndpoints:
    - matchLabels:
        app: frontend
    toPorts:
    - ports:
      - port: "8080"
        protocol: TCP
      rules:
        http:
        - method: "GET"
          path: "/api/.*"
```

### Example: Cross-Cluster Policy

```yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: allow-cross-cluster-db
  namespace: databases
spec:
  endpointSelector:
    matchLabels:
      app: postgres
  ingress:
  - fromEndpoints:
    - {}  # All endpoints from all clusters
    toPorts:
    - ports:
      - port: "5432"
      rules:
        l7:
        - l7proto: postgres
```

---

## Troubleshooting

### Cilium agent not starting

```bash
# Check logs
kubectl logs -n kube-system -l k8s-app=cilium --context infra

# Common issues:
# 1. Kernel version too old (need 4.9.17+)
# 2. BPF filesystem not mounted
# 3. CNI config conflicts
```

### Encryption not working

```bash
# Verify WireGuard module loaded
kubectl exec -n kube-system ds/cilium --context infra -- lsmod | grep wireguard

# Check encryption status
cilium encrypt status --context infra

# If WireGuard unavailable, fallback to IPsec:
# Edit HelmRelease: encryption.type: ipsec
```

### Cluster Mesh connectivity issues

```bash
# Check API server status
kubectl get pods -n kube-system -l k8s-app=clustermesh-apiserver --context infra

# Check service LoadBalancer
kubectl get svc clustermesh-apiserver -n kube-system --context infra

# Verify connectivity
cilium clustermesh status --verbose --context apps

# Common issues:
# 1. LoadBalancer not provisioned (check MetalLB/cloud provider)
# 2. Firewall blocking port 2379
# 3. Certificate issues
```

### Hubble not showing flows

```bash
# Check Hubble relay
kubectl get pods -n kube-system -l k8s-app=hubble-relay --context infra

# Check Hubble status
hubble status --context infra

# Restart Hubble relay if needed
kubectl rollout restart deployment/hubble-relay -n kube-system --context infra
```

---

## Upgrading Cilium

```bash
# Update version in HelmRelease
# Edit helmrelease-infra.yaml and helmrelease-apps.yaml
# Change: version: ">=1.16.0 <1.17.0"
# To: version: ">=1.17.0 <1.18.0"

# Commit and push
git add kubernetes/infrastructure/cilium/
git commit -m "feat: upgrade Cilium to 1.17.x"
git push

# Flux will reconcile automatically
# Monitor the rollout
kubectl rollout status daemonset/cilium -n kube-system --context infra
kubectl rollout status daemonset/cilium -n kube-system --context apps

# Verify health after upgrade
cilium status --wait --context infra
cilium status --wait --context apps
```

---

## Resources

- **Cilium Docs**: https://docs.cilium.io/
- **Cluster Mesh Guide**: https://docs.cilium.io/en/stable/network/clustermesh/
- **Hubble Observability**: https://docs.cilium.io/en/stable/observability/hubble/
- **Network Policies**: https://docs.cilium.io/en/stable/security/policy/
- **Cilium Slack**: https://cilium.io/slack

---

## FAQ

**Q: Why Cilium instead of Linkerd?**
A: Cilium provides a unified CNI + service mesh stack with no sidecars, better GitOps support, and more efficient resource usage. See [docs/cilium-service-mesh-implementation-plan.md](../../../docs/cilium-service-mesh-implementation-plan.md) for detailed comparison.

**Q: Does Cilium replace kube-proxy?**
A: Yes, when `kubeProxyReplacement: "true"` is set, Cilium fully replaces kube-proxy using eBPF for better performance.

**Q: How does Cluster Mesh differ from Linkerd multi-cluster?**
A: Cluster Mesh provides direct pod-to-pod routing across clusters without separate gateway pods. Services are accessed via standard Kubernetes DNS (no special suffixes needed).

**Q: What's the performance overhead?**
A: Cilium has minimal overhead (<5% CPU) because it operates at the kernel level via eBPF, unlike sidecar proxies which add per-pod overhead.

**Q: Can I use Cilium with existing NetworkPolicies?**
A: Yes, Cilium supports standard Kubernetes NetworkPolicy resources and extends them with CiliumNetworkPolicy for L7 features.

**Q: How do I expose services externally?**
A: Use Gateway API (enabled by default) or configure LoadBalancer services. Cilium integrates with BGP for advanced routing.
