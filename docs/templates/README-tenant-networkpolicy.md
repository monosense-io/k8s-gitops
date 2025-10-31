# Tenant Namespace NetworkPolicy Template

This template provides baseline network policies for tenant namespaces.

## Quick Start

1. Copy `tenant-namespace-networkpolicy.yaml` to your namespace directory:
   ```bash
   cp docs/templates/tenant-namespace-networkpolicy.yaml kubernetes/tenants/<your-namespace>/kustomization.yaml
   ```

2. Edit the file and replace `<TENANT-NAMESPACE>` with your namespace name

3. Add your application resources

4. (Optional) Customize FQDN allowlist if internet egress is needed

## Included Policies

- **deny-all**: Blocks all traffic by default
- **allow-dns**: Permits DNS resolution
- **allow-kube-api**: Permits Kubernetes API access
- **allow-internal**: Permits pod-to-pod communication within namespace

## Testing Your Policies

```bash
# Create test pod
kubectl -n <your-namespace> run curl --image=curlimages/curl -- sleep 3600

# Test DNS (should work)
kubectl -n <your-namespace> exec curl -- nslookup kubernetes.default

# Test kube-api (should work)
kubectl -n <your-namespace> exec curl -- curl -sfk https://kubernetes.default.svc

# Test internet egress (should fail unless FQDN allowlist added)
kubectl -n <your-namespace> exec curl -- curl -s https://example.com

# Cleanup
kubectl -n <your-namespace> delete pod curl
```

## Adding FQDN Allowlist

If your application needs to access external services:

1. Copy FQDN component:
   ```bash
   mkdir -p kubernetes/tenants/<your-namespace>/networkpolicy
   cp kubernetes/components/networkpolicy/allow-fqdn/ciliumnetworkpolicy.yaml \
      kubernetes/tenants/<your-namespace>/networkpolicy/allow-fqdn.yaml
   ```

2. Edit and customize FQDNs:
   ```yaml
   toFQDNs:
     - matchPattern: "*.your-service.com"
     - matchName: "api.external.io"
   ```

3. Add to kustomization:
   ```yaml
   resources:
     - networkpolicy/allow-fqdn.yaml
   ```

## Troubleshooting

### DNS not working
- Verify kube-dns is running: `kubectl -n kube-system get pods -l k8s-app=kube-dns`
- Check DNS policy is applied: `kubectl -n <namespace> get networkpolicies`

### Kube-API not accessible
- Verify allow-kube-api policy exists
- Check for conflicting policies

### FQDN allowlist not working
- Verify Cilium DNS proxy is enabled
- Check Cilium logs: `kubectl -n kube-system logs -l app.kubernetes.io/name=cilium | grep -i fqdn`
- Verify DNS resolution works first (FQDN requires DNS)
