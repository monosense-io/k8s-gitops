# Default Deny All NetworkPolicy Component

Blocks all ingress and egress traffic by default.

## Usage

Add to your namespace Kustomization:

```yaml
components:
  - ../../../components/networkpolicy/deny-all
```

## Behavior

- **Ingress**: All inbound traffic blocked (including from same namespace)
- **Egress**: All outbound traffic blocked (including DNS, kube-api)

**IMPORTANT**: This component alone will break DNS and kube-api access. Always combine with `allow-dns` and `allow-kube-api` components.

## Policy Types

- **Kubernetes NetworkPolicy**: `default-deny-all-ingress`, `default-deny-all-egress`
- **CiliumNetworkPolicy**: `default-deny-all`

Both policy types are applied for defense-in-depth.
