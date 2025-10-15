# ESO + 1Password Connect Migration Guide

**Date**: 2025-10-15
**Status**: Ready for Deployment
**Migration Type**: Configuration Update (Non-Breaking)

## Executive Summary

Migrated External Secrets Operator (ESO) configuration from potentially using 1Password cloud API (rate-limited) to local 1Password Connect Server (unlimited after cache).

### Key Changes
- ✅ Updated Connect host from `https://op-connect.monosense.io` → `http://opconnect.monosense.dev`
- ✅ Fixed secret naming consistency (`onepassword-connect-token`)
- ✅ Added vault configuration for performance optimization
- ✅ Created validation tooling

### Benefits
- 🚀 **Unlimited secret requests** after initial cache
- 🎯 **No more rate limiting** from 1Password API
- ⚡ **Faster secret lookups** with vault scoping
- 🔒 **Local infrastructure** - reduced external dependencies

---

## Configuration Changes Made

### 1. Cluster Settings Updates

**Files Modified**:
- `kubernetes/clusters/infra/cluster-settings.yaml`
- `kubernetes/clusters/apps/cluster-settings.yaml`

**Change**:
```yaml
# BEFORE
ONEPASSWORD_CONNECT_HOST: "https://op-connect.monosense.io"

# AFTER
ONEPASSWORD_CONNECT_HOST: "http://opconnect.monosense.dev"
```

**Rationale**:
- Correct hostname for local Docker service
- HTTP protocol (Connect Server on port 80, not 443)

### 2. Bootstrap Prerequisites Update

**File Modified**: `bootstrap/prerequisites/resources.yaml`

**Change**:
```yaml
# BEFORE
metadata:
  name: onepassword-connect

# AFTER
metadata:
  name: onepassword-connect-token
```

**Rationale**:
- Matches ClusterSecretStore reference
- Follows naming conventions
- Removed unused `1password-credentials.json` field (only needed by Connect Server itself)

### 3. ClusterSecretStore Enhancement

**File Modified**: `kubernetes/infrastructure/security/external-secrets/clustersecretstore.yaml`

**Added**:
```yaml
vaults:
  - K8s            # Primary vault for Kubernetes secrets
  - Infrastructure # Fallback vault
```

**Rationale**:
- Faster secret lookups (scoped search)
- Explicit vault access (better security)
- Ordered priority (searches first match)

---

## Deployment Steps

### Prerequisites

1. **Verify Docker Service Running**:
   ```bash
   curl http://opconnect.monosense.dev/health
   # Expected: HTTP 200 with JSON health status
   ```

2. **Verify 1Password Token Available**:
   - Ensure you have a valid 1Password Connect token
   - Token should be stored in 1Password at: `op://K8s/1password-connect/token`

### Step 1: Commit Configuration Changes

```bash
cd /Users/monosense/iac/k8s-gitops

# Review changes
git status
git diff

# Commit
git add \
  kubernetes/clusters/*/cluster-settings.yaml \
  kubernetes/infrastructure/security/external-secrets/clustersecretstore.yaml \
  bootstrap/prerequisites/resources.yaml \
  scripts/validate-eso-1password.sh \
  docs/eso-1password-migration-guide.md

git commit -m "fix: migrate ESO to local 1Password Connect Server

- Update ONEPASSWORD_CONNECT_HOST to opconnect.monosense.dev
- Fix protocol from HTTPS to HTTP (Connect Server on port 80)
- Fix secret naming consistency (onepassword-connect-token)
- Add vault configuration for performance optimization
- Add validation script for troubleshooting

This eliminates 1Password API rate limiting by using local
Connect Server which provides unlimited requests after initial cache.

Refs: docs/eso-1password-migration-guide.md"
```

### Step 2: Update Bootstrap Secret (If Needed)

If the secret doesn't exist or needs updating:

```bash
# Option A: Apply with op CLI injection
op inject -i bootstrap/prerequisites/resources.yaml | kubectl apply -f -

# Option B: Manual application (update secret value first)
kubectl apply -f bootstrap/prerequisites/resources.yaml

# Verify
kubectl get secret onepassword-connect-token -n external-secrets
```

### Step 3: Apply Infrastructure Changes

If using GitOps (Flux):
```bash
# Push to repository
git push origin main

# Flux will automatically reconcile within 5 minutes
# Or trigger immediately:
flux reconcile source git flux-system
flux reconcile kustomization cluster
```

If applying manually:
```bash
# Update cluster settings (will trigger ConfigMap update)
kubectl apply -f kubernetes/clusters/infra/cluster-settings.yaml

# Update ClusterSecretStore
kubectl apply -f kubernetes/infrastructure/security/external-secrets/clustersecretstore.yaml

# Restart ESO pods to pick up new configuration
kubectl rollout restart deployment -n external-secrets -l app.kubernetes.io/name=external-secrets
```

### Step 4: Run Validation Script

```bash
./scripts/validate-eso-1password.sh
```

**Expected Output**: All checks should pass (✅)

### Step 5: Monitor ExternalSecret Sync

```bash
# Watch ClusterSecretStore status
kubectl get clustersecretstore onepassword -w

# Watch ExternalSecrets
kubectl get externalsecrets -A -w

# Monitor ESO logs
kubectl logs -n external-secrets -l app.kubernetes.io/name=external-secrets -f

# Check for rate limiting (should be NONE)
kubectl logs -n external-secrets -l app.kubernetes.io/name=external-secrets --tail=1000 | grep -i rate
```

### Step 6: Verify No Rate Limiting

**Before Migration**:
```
Error: rate limit exceeded
429 Too Many Requests
```

**After Migration**:
```
Successfully synced secret
SecretSynced
```

---

## Validation Checklist

Use this checklist to verify successful migration:

- [ ] Connect Server accessible at `http://opconnect.monosense.dev/health`
- [ ] Secret `onepassword-connect-token` exists in `external-secrets` namespace
- [ ] ClusterSecretStore status shows `Ready`
- [ ] ESO pods running and healthy (2 replicas)
- [ ] No rate limiting errors in ESO logs
- [ ] Existing ExternalSecrets syncing successfully
- [ ] New ExternalSecrets can be created and synced
- [ ] Prometheus metrics showing healthy sync rate
- [ ] No 429 errors from 1Password

---

## Troubleshooting

### Issue: Connect Server Unreachable

**Symptoms**:
```
curl: (7) Failed to connect to opconnect.monosense.dev
```

**Solutions**:
1. Check Docker service status on host `10.25.10.24`
2. Verify DNS resolution: `nslookup opconnect.monosense.dev`
3. Check firewall rules between Kubernetes and Docker host
4. Verify Connect Server containers running:
   - `op-connect-sync`
   - `op-connect-api`

### Issue: Authentication Failed

**Symptoms**:
```
Authentication failed - check token validity
401 Unauthorized
```

**Solutions**:
1. Verify token in secret:
   ```bash
   kubectl get secret onepassword-connect-token -n external-secrets -o jsonpath='{.data.token}' | base64 -d
   ```
2. Test token manually:
   ```bash
   TOKEN=$(kubectl get secret onepassword-connect-token -n external-secrets -o jsonpath='{.data.token}' | base64 -d)
   curl -H "Authorization: Bearer $TOKEN" http://opconnect.monosense.dev/v1/health
   ```
3. Regenerate token in 1Password if expired
4. Re-apply prerequisites with fresh token

### Issue: Vault Not Found

**Symptoms**:
```
Error: vault "K8s" not found
```

**Solutions**:
1. Check vault names in 1Password
2. Update `clustersecretstore.yaml` with correct vault names
3. Verify Connect Server has access to vaults
4. Check token permissions for vault access

### Issue: ExternalSecrets Not Syncing

**Symptoms**:
```
Status: SecretSyncError
```

**Solutions**:
1. Check ClusterSecretStore status: `kubectl describe clustersecretstore onepassword`
2. Verify secret path exists in 1Password
3. Check ESO logs for specific error
4. Ensure item title in 1Password matches `remoteRef.key`
5. Verify property/field names match

---

## Rollback Procedure

If migration causes issues, rollback with:

```bash
# 1. Revert git commit
git revert HEAD

# 2. Or manually restore old values
# In kubernetes/clusters/*/cluster-settings.yaml:
ONEPASSWORD_CONNECT_HOST: "https://op-connect.monosense.io"

# 3. Apply changes
kubectl apply -f kubernetes/clusters/infra/cluster-settings.yaml
kubectl rollout restart deployment -n external-secrets -l app.kubernetes.io/name=external-secrets

# 4. Monitor recovery
kubectl get externalsecrets -A -w
```

**Note**: Rollback will restore rate limiting issues.

---

## Performance Comparison

### Before Migration (Estimated)

| Metric | Value |
|--------|-------|
| Rate Limit | 600 req/min |
| Max ExternalSecrets | ~600 (with 1min refresh) |
| Rate Limit Errors | Frequent during reconciliation |
| Sync Latency | Variable (cloud dependent) |

### After Migration (Expected)

| Metric | Value |
|--------|-------|
| Rate Limit | **Unlimited (cached)** |
| Max ExternalSecrets | **No practical limit** |
| Rate Limit Errors | **None** |
| Sync Latency | **<10ms (local network)** |

---

## Security Considerations

### HTTP vs HTTPS

**Current**: Using HTTP between Kubernetes and Connect Server

**Risk Assessment**:
- ⚠️ **Low Risk** if on isolated network segment
- ✅ **Acceptable** for internal infrastructure network
- ❌ **NOT acceptable** over public internet

**Mitigation Options** (Future):
1. Add TLS termination at Connect Server
2. Use network policies to restrict access
3. Deploy Connect Server in-cluster with service mesh encryption

**Recommendation**:
- Current setup is acceptable for internal network `10.25.10.0/24`
- Monitor for any network exposure
- Consider adding TLS if Connect Server exposed to wider network

### Token Security

**Current**: Token stored in Kubernetes secret

**Best Practices Applied**:
- ✅ Token scoped to specific vaults
- ✅ Stored in external-secrets namespace (restricted)
- ✅ Referenced by ClusterSecretStore only
- ✅ Not exposed in logs

**Additional Hardening** (Optional):
- Use cert-manager for TLS certificates
- Implement network policies for ESO namespace
- Enable audit logging for secret access
- Rotate tokens periodically

---

## Post-Migration Monitoring

### Metrics to Monitor

**ESO Health**:
```promql
# Sync success rate
rate(externalsecret_sync_calls_total{status="success"}[5m])

# Sync errors
rate(externalsecret_sync_calls_total{status="error"}[5m])

# Sync duration
histogram_quantile(0.99, rate(externalsecret_sync_duration_seconds_bucket[5m]))
```

**1Password Connect**:
- Check Connect Server logs for errors
- Monitor memory/CPU usage
- Track cache hit rate

**Alerting Rules** (Already in place):
- `kubernetes/infrastructure/security/external-secrets/prometheusrule.yaml`

---

## Success Criteria

Migration is successful when:

1. ✅ No rate limiting errors for 24 hours
2. ✅ All ExternalSecrets syncing successfully
3. ✅ Sync latency < 100ms consistently
4. ✅ ClusterSecretStore showing "Ready" status
5. ✅ ESO pods stable with no restarts
6. ✅ Validation script passes all checks

---

## References

- [External Secrets Operator - 1Password Provider](https://external-secrets.io/latest/provider/1password-automation/)
- [1Password Connect Documentation](https://developer.1password.com/docs/connect/)
- [1Password Connect Rate Limits](https://developer.1password.com/docs/service-accounts/rate-limits/)
- [ESO GitHub Releases](https://github.com/external-secrets/external-secrets/releases)

---

## Change History

| Date | Change | Author |
|------|--------|--------|
| 2025-10-15 | Initial migration from op-connect.monosense.io to opconnect.monosense.dev | Alex (DevOps Platform) |

---

## Next Steps

**Immediate** (0-1 week):
- [ ] Monitor for 24 hours post-deployment
- [ ] Verify no rate limiting in logs
- [ ] Document actual vault names in ClusterSecretStore
- [ ] Update runbooks with new troubleshooting steps

**Short-term** (1-4 weeks):
- [ ] Add TLS termination if needed
- [ ] Implement network policies for ESO namespace
- [ ] Review token rotation policy
- [ ] Optimize refresh intervals based on usage patterns

**Long-term** (1-6 months):
- [ ] Evaluate 1Password SDK provider as alternative
- [ ] Consider in-cluster Connect Server deployment
- [ ] Implement automated validation testing
- [ ] Review disaster recovery procedures

---

For questions or issues, refer to: `scripts/validate-eso-1password.sh` for diagnostics.
