# Allow DNS NetworkPolicy Component

Permits DNS resolution to kube-dns in kube-system namespace.

## Usage

Add to your namespace Kustomization:

```yaml
components:
  - ../../../components/networkpolicy/allow-dns
```

## Behavior

- **Egress**: Allow UDP/TCP port 53 to kube-dns pods in kube-system
- **DNS Pattern**: Cilium variant includes DNS rule matching all patterns (`*`)

## Prerequisites

- Must be combined with `deny-all` component to function as intended
- kube-dns must be labeled with `k8s-app: kube-dns`

## Testing

```bash
kubectl -n <namespace> run curl --image=curlimages/curl -- sleep 3600
kubectl -n <namespace> exec curl -- nslookup kubernetes.default
# Expected: Successful DNS resolution
```
