# Allow FQDN NetworkPolicy Component (Cilium)

Permits egress to specific fully-qualified domain names using Cilium's FQDN policy.

## Features

- **DNS-aware**: Cilium intercepts DNS responses and allows traffic to resolved IPs
- **Pattern Matching**: Use wildcards like `*.github.com`
- **Exact Matching**: Use `matchName` for specific domains

## Usage

Copy and customize this component for your namespace:

```yaml
# In your namespace kustomization
components:
  - ../../../components/networkpolicy/allow-fqdn
```

## Customization

Edit `ciliumnetworkpolicy.yaml` to match your required FQDNs:

```yaml
toFQDNs:
  - matchPattern: "*.mycompany.com"
  - matchName: "api.external-service.io"
```

## How It Works

1. Pod makes DNS query for allowed FQDN
2. Cilium intercepts DNS response and learns IP addresses
3. Cilium allows traffic to those IPs on specified ports
4. IPs are cached with TTL matching DNS record TTL

## Prerequisites

- Cilium with DNS proxy enabled (default in modern versions)
- Must be combined with `allow-dns` component for DNS resolution

## Testing

```bash
kubectl -n <namespace> run curl --image=curlimages/curl -- sleep 3600
kubectl -n <namespace> exec curl -- curl -s https://github.com
# Expected: Successful if github.com matches allowlist
```

## Security Notes

- Wildcards should be used carefully (e.g., `*.com` is too broad)
- FQDNs are resolved via DNS, so DNS spoofing protections are important
- Consider using IP-based policies for highly sensitive traffic
