# Allow Kube-API NetworkPolicy Component

Permits access to the Kubernetes API server.

## Usage

Add to your namespace Kustomization:

```yaml
components:
  - ../../../components/networkpolicy/allow-kube-api
```

## Behavior

- **Egress**: Allow TCP ports 443 and 6443 to kube-apiserver
- **Entity**: Cilium variant uses `toEntities: kube-apiserver` for built-in entity matching

## Prerequisites

- Must be combined with `deny-all` component to function as intended

## Testing

```bash
kubectl -n <namespace> run curl --image=curlimages/curl -- sleep 3600
kubectl -n <namespace> exec curl -- curl -sfk https://kubernetes.default.svc
# Expected: Kubernetes API server response (forbidden without token is OK)
```
