# Baseline NetworkPolicy Infrastructure

Applies baseline network policies to platform namespaces.

## Applied Policies

Each platform namespace gets:
1. **deny-all**: Block all ingress/egress by default
2. **allow-dns**: Permit DNS resolution
3. **allow-kube-api**: Permit Kubernetes API access
4. **allow-internal**: Permit pod-to-pod within namespace

## Platform Namespaces

- `observability` - VictoriaMetrics, VictoriaLogs, Grafana
- `cnpg-system` - CloudNativePG operator and clusters
- `dragonfly-system` - DragonflyDB cache
- `harbor` - Container registry
- `gitlab-system` - GitLab
- `flux-system` - Flux GitOps controllers

## Adding New Namespaces

1. Create `<namespace>-policies.yaml`:
   ```yaml
   apiVersion: kustomize.config.k8s.io/v1alpha1
   kind: Component

   namespace: <namespace>

   components:
     - ../../../components/networkpolicy/deny-all
     - ../../../components/networkpolicy/allow-dns
     - ../../../components/networkpolicy/allow-kube-api
     - ../../../components/networkpolicy/allow-internal
   ```

2. Add to `kustomization.yaml`:
   ```yaml
   resources:
     - <namespace>-policies.yaml
   ```

## Testing

See individual component READMEs for testing procedures.
