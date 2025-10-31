# NetworkPolicy Components

Reusable Kustomize components for baseline network security policies.

## Available Components

| Component | Purpose | Required | KNP | CNP |
|-----------|---------|----------|-----|-----|
| `deny-all` | Block all ingress/egress | Yes | ✓ | ✓ |
| `allow-dns` | Permit DNS resolution | Yes | ✓ | ✓ |
| `allow-kube-api` | Permit Kubernetes API access | Yes | ✓ | ✓ |
| `allow-internal` | Permit pod-to-pod within namespace | Recommended | ✓ | ✓ |
| `allow-fqdn` | Permit specific external FQDNs | Optional | ✗ | ✓ |

**KNP** = Kubernetes NetworkPolicy, **CNP** = CiliumNetworkPolicy

## Policy Ordering

NetworkPolicies are **additive** - multiple policies apply simultaneously. Order doesn't matter for different policies.

### Recommended Application Order

1. `deny-all` - Establish default-deny baseline
2. `allow-dns` - Enable DNS resolution
3. `allow-kube-api` - Enable Kubernetes API access
4. `allow-internal` - Enable pod-to-pod communication
5. `allow-fqdn` - (Optional) Enable specific external access

## Usage Patterns

### Platform Namespace (Recommended)

```yaml
apiVersion: kustomize.config.k8s.io/v1alpha1
kind: Component

namespace: my-platform-service

components:
  - ../../../components/networkpolicy/deny-all
  - ../../../components/networkpolicy/allow-dns
  - ../../../components/networkpolicy/allow-kube-api
  - ../../../components/networkpolicy/allow-internal
```

### Tenant Namespace (Minimal)

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: tenant-app

components:
  - ../../components/networkpolicy/deny-all
  - ../../components/networkpolicy/allow-dns
  - ../../components/networkpolicy/allow-kube-api
```

### Internet-Facing Service

```yaml
components:
  - ../../components/networkpolicy/deny-all
  - ../../components/networkpolicy/allow-dns
  - ../../components/networkpolicy/allow-kube-api
  - ../../components/networkpolicy/allow-internal
  - ../../components/networkpolicy/allow-fqdn  # Customize FQDNs
```

## Testing

See individual component READMEs for detailed testing procedures.

### Quick Test

```bash
NS=<your-namespace>

# Create test pod
kubectl -n $NS run curl --image=curlimages/curl -- sleep 3600

# Test DNS (should work with allow-dns)
kubectl -n $NS exec curl -- nslookup kubernetes.default

# Test kube-API (should work with allow-kube-api)
kubectl -n $NS exec curl -- curl -sfk https://kubernetes.default.svc

# Test internal (should work with allow-internal)
kubectl -n $NS run nginx --image=nginx --port=80
kubectl -n $NS exec curl -- curl -s http://nginx

# Test internet (should fail unless allow-fqdn configured)
kubectl -n $NS exec curl -- curl -s https://example.com

# Cleanup
kubectl -n $NS delete pod curl nginx
```

## Troubleshooting

### Common Issues

1. **DNS not working**
   - Verify kube-dns pod label: `k8s-app: kube-dns`
   - Check namespace label on kube-system
   - Verify allow-dns component is applied

2. **Kube-API not accessible**
   - Check allow-kube-api component is applied
   - Verify ports 443/6443 are allowed

3. **FQDN allowlist not working (Cilium)**
   - Ensure DNS works first (FQDN requires DNS resolution)
   - Verify Cilium DNS proxy is enabled
   - Check Cilium agent logs for FQDN policy errors

4. **Policies not enforced**
   - Verify Cilium policy enforcement mode: `kubectl get cm -n kube-system cilium-config -o yaml | grep policy-enforcement`
   - Should be `default` or higher

### Validation Commands

```bash
# List all NetworkPolicies in namespace
kubectl -n <namespace> get networkpolicies

# List all CiliumNetworkPolicies in namespace
kubectl -n <namespace> get ciliumnetworkpolicies

# Check Cilium policy enforcement
cilium policy get

# View Cilium endpoint policies
cilium endpoint list
cilium endpoint get <endpoint-id>
```

## Best Practices

1. **Always start with deny-all**: Establishes zero-trust baseline
2. **Always include allow-dns**: Nearly all workloads need DNS
3. **Always include allow-kube-api**: Controllers and operators need API access
4. **Use allow-internal judiciously**: Only if pod-to-pod communication needed
5. **Minimize FQDN allowlists**: Use specific domains, avoid wildcards like `*.com`
6. **Test policies in non-prod first**: Verify no breakage before production
7. **Document exceptions**: If you skip deny-all, document why

## References

- [Kubernetes NetworkPolicy](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
- [Cilium NetworkPolicy](https://docs.cilium.io/en/stable/security/policy/)
- [Cilium FQDN Policy](https://docs.cilium.io/en/stable/security/policy/language/#dns-based)
