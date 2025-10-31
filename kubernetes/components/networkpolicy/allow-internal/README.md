# Allow Internal NetworkPolicy Component

Permits pod-to-pod communication within the same namespace.

## Usage

Add to your namespace Kustomization:

```yaml
components:
  - ../../../components/networkpolicy/allow-internal
```

## Behavior

- **Ingress**: Allow from any pod in same namespace
- **Egress**: Allow to any pod in same namespace

## Use Cases

- Microservices within a namespace need to communicate
- Database pods need to talk to each other (e.g., replication)
- Application pods need to access local cache (e.g., Redis in same namespace)

## Security Note

This component allows all traffic within the namespace. For finer-grained control, use specific label-based policies instead.
