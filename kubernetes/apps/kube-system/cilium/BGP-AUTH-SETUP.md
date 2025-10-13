# BGP Authentication Setup Guide

## 🎯 Overview

This guide helps you coordinate BGP MD5 authentication between your Kubernetes cluster and the upstream router (Juniper SRX at 10.25.11.1).

## ⚠️ CRITICAL: Coordination Required

BGP authentication requires **synchronized configuration** on both sides:
1. Kubernetes cluster (Cilium)
2. Upstream router (SRX at 10.25.11.1)

**If authentication is configured on only one side, BGP sessions will FAIL and LoadBalancer IPs will become unreachable.**

## 📋 Pre-Implementation Checklist

- [ ] Schedule maintenance window (30-60 minutes)
- [ ] Coordinate with network team (who manages 10.25.11.1)
- [ ] Generate strong BGP authentication password
- [ ] Test communications with network team
- [ ] Have rollback plan ready
- [ ] Monitor BGP session status before, during, and after

## 🔐 Step 1: Generate Strong Password

Generate a strong, random password for BGP authentication:

```bash
# Generate 32-character random password
openssl rand -base64 32

# Or use:
pwgen -s 32 1

# Example output:
# K7mX9pQwR4nZ2vL8sT6yH3jC1fB5gD0a
```

**Save this password securely** - you'll need to share it with the network team.

## 📝 Step 2: Update Kubernetes Secret

Edit `kubernetes/apps/kube-system/cilium/config/bgp-auth-secret.yaml`:

```yaml
stringData:
  password: "K7mX9pQwR4nZ2vL8sT6yH3jC1fB5gD0a"  # Replace with your generated password
```

**IMPORTANT:** If using Git, consider using External Secrets Operator or Sealed Secrets instead of committing plaintext passwords.

## 🌐 Step 3: Configure Upstream Router (SRX)

**Share these instructions with your network team:**

### Juniper SRX Configuration

```junos
# Configure BGP authentication on SRX (10.25.11.1)

# 1. Enter configuration mode
configure

# 2. Set authentication key for the BGP group
set protocols bgp group cilium authentication-key "K7mX9pQwR4nZ2vL8sT6yH3jC1fB5gD0a"

# Or if using specific neighbor configuration:
set protocols bgp group cilium neighbor <NODE-IP> authentication-key "K7mX9pQwR4nZ2vL8sT6yH3jC1fB5gD0a"

# 3. Review configuration
show | compare

# 4. Commit configuration
commit check
commit

# 5. Verify BGP session
show bgp summary
show bgp neighbor <NODE-IP>
```

### Expected SRX Configuration

Your SRX should have BGP neighbors from ALL Kubernetes nodes (since nodeSelector matches all Linux nodes):

```junos
protocols {
    bgp {
        group cilium {
            type external;
            local-as 64512;
            authentication-key "K7mX9pQwR4nZ2vL8sT6yH3jC1fB5gD0a";
            neighbor <NODE-1-IP> {
                peer-as 64513;
            }
            neighbor <NODE-2-IP> {
                peer-as 64513;
            }
            # ... etc for each node
        }
    }
}
```

## 🚀 Step 4: Deployment Strategy

### Option A: Graceful Rollout (Recommended - Minimal Downtime)

This approach configures authentication on the router first, then enables it in Cilium:

```bash
# 1. Network team: Configure authentication on SRX (Step 3 above)
#    BGP sessions will stay up (authentication not yet enforced)

# 2. Wait 5 minutes, verify BGP sessions are still up
kubectl get ciliumnode -o wide
# Check "BGP Status" column

# 3. Apply Kubernetes secret
kubectl apply -f kubernetes/apps/kube-system/cilium/config/bgp-auth-secret.yaml

# 4. Apply updated BGP config (with authSecretRef)
kubectl apply -f kubernetes/apps/kube-system/cilium/config/l3.yaml

# 5. Monitor BGP session re-establishment
watch kubectl get ciliumnode -o wide

# 6. Verify BGP sessions are authenticated
kubectl exec -n kube-system ds/cilium -- cilium bgp peers

# 7. Network team: Verify on SRX
# show bgp neighbor <NODE-IP> detail | match authentication
```

**Expected downtime:** ~30-60 seconds per node as sessions re-establish with authentication

### Option B: Immediate Change (Higher Risk)

Both sides configured simultaneously:

```bash
# 1. Coordinate exact timing with network team (e.g., "on my mark...")

# 2. Network team: Configure SRX (Step 3)
# 3. Immediately: Apply Kubernetes config
kubectl apply -f kubernetes/apps/kube-system/cilium/config/bgp-auth-secret.yaml
kubectl apply -f kubernetes/apps/kube-system/cilium/config/l3.yaml

# 4. Monitor recovery
watch kubectl get ciliumnode -o wide
```

**Risk:** If timing is off or password mismatches, longer outage

## ✅ Step 5: Verification

### Verify BGP Sessions are Authenticated

```bash
# 1. Check Cilium BGP peer status
kubectl exec -n kube-system ds/cilium -- cilium bgp peers

# Expected output showing "Established" state:
# Node       Local AS  Peer AS  Peer Address  State        Uptime
# node1      64513     64512    10.25.11.1    Established  2m30s

# 2. Check CiliumNode status
kubectl get ciliumnode -o wide

# 3. Verify routes are being advertised
kubectl exec -n kube-system ds/cilium -- cilium bgp routes advertised ipv4 unicast

# 4. Test LoadBalancer connectivity
curl -v http://10.25.26.2  # envoy-external
curl -v http://10.25.26.3  # envoy-internal

# 5. Verify external access to services
curl -v https://external.monosense.dev
```

### Network Team: SRX Verification

```junos
# Verify BGP sessions are up and authenticated
show bgp summary
show bgp neighbor <NODE-IP>
show bgp neighbor <NODE-IP> | match Authentication

# Expected: "Authentication enabled"

# Verify routes are being received
show route receive-protocol bgp <NODE-IP>
show route protocol bgp table inet.0
```

## 🔥 Troubleshooting

### BGP Sessions Not Establishing

**Symptom:** BGP state shows "Connect" or "Active" instead of "Established"

```bash
# Check Cilium logs for BGP errors
kubectl logs -n kube-system ds/cilium | grep -i bgp

# Common errors:
# - "authentication failure" = Password mismatch
# - "connection refused" = Firewall blocking port 179
# - "open sent" = Router not responding
```

**Solutions:**

1. **Password Mismatch:**
   ```bash
   # Verify secret exists and has correct password
   kubectl get secret bgp-auth-secret -n kube-system -o jsonpath='{.data.password}' | base64 -d

   # Compare with router config (ask network team)
   ```

2. **Firewall Issues:**
   ```bash
   # Test TCP connectivity to BGP port
   kubectl run -it --rm debug --image=nicolaka/netshoot --restart=Never -- nc -zv 10.25.11.1 179

   # Should show: "Connection to 10.25.11.1 179 port [tcp/bgp] succeeded!"
   ```

3. **Configuration Not Applied:**
   ```bash
   # Verify CiliumBGPPeerConfig has authSecretRef
   kubectl get ciliumbgppeerconfig l3-bgp-peer-config -o yaml | grep -A 2 authSecretRef

   # Should show:
   # authSecretRef: bgp-auth-secret
   ```

### LoadBalancer Services Unreachable

**Symptom:** Can't reach LoadBalancer IPs (10.25.26.x)

```bash
# Check if routes are being advertised
kubectl exec -n kube-system ds/cilium -- cilium bgp routes advertised ipv4 unicast

# Should show routes for 10.25.26.0/24

# Check BGP session status
kubectl get ciliumnode -o wide

# If BGP is down, LoadBalancers won't work
```

## 🔙 Rollback Procedure

If authentication causes issues and you need to remove it:

### Quick Rollback (Remove Authentication)

```bash
# 1. Remove authSecretRef from BGP config
kubectl edit ciliumbgppeerconfig l3-bgp-peer-config
# Delete the "authSecretRef: bgp-auth-secret" line
# Save and exit

# 2. BGP sessions will re-establish without auth in ~30-60 seconds
kubectl get ciliumnode -o wide

# 3. Network team: Remove authentication from SRX
configure
delete protocols bgp group cilium authentication-key
commit

# 4. Verify BGP sessions are back up
kubectl exec -n kube-system ds/cilium -- cilium bgp peers
```

### Complete Rollback (Revert All Changes)

```bash
# Restore original l3.yaml from git
git checkout HEAD~1 -- kubernetes/apps/kube-system/cilium/config/l3.yaml
kubectl apply -f kubernetes/apps/kube-system/cilium/config/l3.yaml

# Delete secret
kubectl delete secret bgp-auth-secret -n kube-system

# Network team: Restore SRX config
```

## 📊 Post-Implementation Monitoring

Monitor for 24-48 hours after implementation:

```bash
# Check BGP session stability
watch -n 30 'kubectl get ciliumnode -o wide'

# Monitor for BGP flapping
kubectl logs -n kube-system ds/cilium --since=1h | grep -i "bgp.*down\|bgp.*up"

# Verify no LoadBalancer connectivity issues
# Test external access periodically
```

## 🎯 Success Criteria

- ✅ All BGP sessions show "Established" state
- ✅ LoadBalancer IPs (10.25.26.x) are reachable
- ✅ External access via Envoy Gateway works
- ✅ SRX shows "Authentication enabled" for all neighbors
- ✅ No BGP session flapping in logs
- ✅ Routes being advertised correctly (10.25.26.0/24)

## 📚 References

- [Cilium BGP Control Plane Documentation](https://docs.cilium.io/en/stable/network/bgp-control-plane/)
- [Juniper SRX BGP Configuration](https://www.juniper.net/documentation/us/en/software/junos/bgp/topics/topic-map/bgp-authentication.html)
- [RFC 5925: TCP Authentication Option](https://datatracker.ietf.org/doc/html/rfc5925)

## ⏱️ Timeline

- **Preparation:** 15 minutes (password generation, coordination)
- **SRX Configuration:** 5-10 minutes (network team)
- **Kubernetes Configuration:** 5 minutes
- **BGP Session Re-establishment:** 1-2 minutes per node
- **Verification:** 10-15 minutes
- **Total:** 30-60 minutes

---

**Remember:** Communication with your network team is KEY. Schedule a call/meeting to coordinate this change in real-time.
