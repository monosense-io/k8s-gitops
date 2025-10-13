# Keycloak Deployment Instructions

## Overview

This document provides step-by-step instructions for deploying Keycloak v26.0.4 with a custom Red Hat theme to replace Authentik.

## Prerequisites

### 1. Add Secrets to 1Password

Before deploying, you MUST add the following secrets to your 1Password vaults:

#### Vault: `dev-cnpg`

Add the following fields to your existing `dev-cnpg` vault:

- **Field Name**: `keycloak_postgres_username`
  - **Value**: `keycloak` (or your preferred database username)

- **Field Name**: `keycloak_postgres_password`
  - **Value**: Generate a strong password (20+ characters recommended)
  - Use 1Password's password generator with these settings:
    - Length: 32 characters
    - Include: Letters, Numbers, Symbols
    - Exclude: Ambiguous characters

#### Vault: `keycloak` (NEW VAULT - Create if it doesn't exist)

Create a new vault called `keycloak` and add:

- **Field Name**: `keycloak_admin_username`
  - **Value**: `admin` (or your preferred admin username)

- **Field Name**: `keycloak_admin_password`
  - **Value**: Generate a strong password (minimum 12 characters)
  - Use 1Password's password generator with these settings:
    - Length: 24 characters
    - Include: Letters, Numbers, Symbols
    - Exclude: Ambiguous characters

**IMPORTANT**: The ExternalSecrets will fail if these fields don't exist in 1Password. Make sure to create them before proceeding with deployment.

### 2. Build and Push Theme Docker Image

The Keycloak deployment uses a custom Red Hat-themed login page delivered via an init container.

#### Prerequisites for Building

- Docker installed and running
- Authenticated to GitHub Container Registry (ghcr.io)

#### Authenticate to GitHub Container Registry

```bash
# Create a GitHub Personal Access Token with package:write permission
# Then authenticate:
echo $GITHUB_TOKEN | docker login ghcr.io -u YOUR_GITHUB_USERNAME --password-stdin
```

#### Build and Push Theme

```bash
cd kubernetes/apps/security/keycloak/theme/
./build.sh
```

This will:
1. Build a Docker image containing the custom Red Hat theme
2. Tag it as `ghcr.io/trosvald/keycloak-theme:1.0.0` and `:latest`
3. Push to GitHub Container Registry

**Optional**: Add custom logo/favicon to `custom-redhat/login/resources/img/` before building:
- `logo.png` - Recommended size: 200x50px, transparent PNG
- `favicon.ico` - Standard 16x16 or 32x32 favicon

See `kubernetes/apps/security/keycloak/theme/README.md` for more customization options.

### 3. Verify Existing Infrastructure

Ensure the following are deployed and healthy:

```bash
# Check CloudNativePG
kubectl get cluster postgres -n databases

# Check External Secrets Operator
kubectl get clustersecretstore onepassword

# Check Envoy Gateway
kubectl get gateway envoy-external -n networking

# Check TLS certificate
kubectl get secret monosense-dev-tls -n networking
```

All should show "Ready" or exist.

## Deployment Steps

### Step 1: Review Changes

Review all the created files:

```bash
# View the directory structure
tree kubernetes/apps/security/keycloak/

# Review key configuration files
cat kubernetes/apps/security/keycloak/app/keycloak.yaml
cat kubernetes/apps/security/keycloak/app/externalsecret.yaml
```

### Step 2: Commit and Push (Operator First)

First, deploy only the operator:

```bash
# Stage only operator files
git add kubernetes/apps/security/keycloak-operator/
git add kubernetes/apps/security/kustomization.yaml

# Commit operator
git commit -m "feat(security): add Keycloak operator v26.0.4"

# Push to trigger Flux
git push
```

### Step 3: Wait for Operator to Deploy

Monitor the operator deployment:

```bash
# Watch Flux reconciliation
flux get kustomizations -n flux-system --watch

# Wait for operator to be ready (may take 2-3 minutes)
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=keycloak-operator \
  -n security --timeout=300s

# Verify operator is running
kubectl get pods -n security -l app.kubernetes.io/name=keycloak-operator
```

Expected output:
```
NAME                                  READY   STATUS    RESTARTS   AGE
keycloak-operator-xxxxxxxxxx-xxxxx    1/1     Running   0          2m
```

### Step 4: Deploy Keycloak Instance

Now deploy the Keycloak application:

```bash
# Stage Keycloak application and theme files
git add kubernetes/apps/security/keycloak/
git add kubernetes/apps/security/kustomization.yaml

# Commit
git commit -m "feat(security): deploy Keycloak v26.0.4 with Red Hat theme"

# Push
git push
```

### Step 5: Monitor Deployment

Watch the deployment progress:

```bash
# Watch Flux Kustomization
flux get kustomizations keycloak -n flux-system --watch

# Watch Keycloak CR status
kubectl get keycloak keycloak -n security -w

# Watch pods (Ctrl+C to stop)
kubectl get pods -n security -l app=keycloak -w
```

Wait for:
1. ExternalSecrets to sync (1-2 minutes)
2. Database initialization job to complete (30 seconds)
3. Keycloak pods to be Running (2-5 minutes)

### Step 6: Verify Deployment

Run these verification checks:

```bash
# Check Keycloak CR status
kubectl describe keycloak keycloak -n security

# Check pods are running
kubectl get pods -n security -l app=keycloak

# Expected output:
# NAME           READY   STATUS    RESTARTS   AGE
# keycloak-0     1/1     Running   0          3m
# keycloak-1     1/1     Running   0          2m

# Check HTTPRoute
kubectl get httproute keycloak -n security

# Check ExternalSecrets synced
kubectl get externalsecret -n security

# Check database initialization
kubectl get job keycloak-init-db -n security

# Test health endpoint
curl https://sso.monosense.dev/health/ready

# Expected: {"status": "UP", "checks": [...]}
```

### Step 7: Access Admin Console

1. Open browser: https://sso.monosense.dev
2. You should see the Red Hat-styled login page
3. Click **"Administration Console"**
4. Login with your 1Password credentials:
   - Username: Value from `keycloak_admin_username`
   - Password: Value from `keycloak_admin_password`

## Post-Deployment Configuration

### Create a Realm

1. In Admin Console, click **"Master"** dropdown (top-left)
2. Click **"Create Realm"**
3. Name: `home-ops` (or your preferred name)
4. Click **"Create"**

### Configure Realm Settings

1. Go to **Realm Settings → Login**
   - Require SSL: `all requests`
   - Login with email: `Enabled`

2. Go to **Realm Settings → Themes**
   - Login theme: `custom-redhat`
   - Account theme: `custom-redhat`

### Create OAuth2 Client for Spring Boot

1. Go to **Clients → Create client**
2. Client ID: `spring-app`
3. Client Protocol: `openid-connect`
4. Click **"Next"**
5. Client authentication: `ON`
6. Authorization: `ON`
7. Authentication flow:
   - ✅ Standard flow
   - ✅ Direct access grants
   - ✅ Service accounts roles
8. Click **"Save"**

Configure client:
- Valid redirect URIs: `https://app.monosense.dev/*`
- Valid post logout URIs: `https://app.monosense.dev/*`
- Web origins: `https://app.monosense.dev`
- Go to **"Credentials"** tab → Copy **Client secret** (save for Spring Boot config)

### Create Test User

1. Go to **Users → Add user**
2. Username: `testuser`
3. Email: `test@monosense.dev`
4. First name: `Test`
5. Last name: `User`
6. Email verified: `ON`
7. Click **"Create"**
8. Go to **Credentials** tab
9. Set password: `Test123!` (or stronger)
10. Temporary: `OFF`
11. Click **"Set password"**

## Integration with Spring Boot

Update your Spring Boot application's `application.yml`:

```yaml
spring:
  security:
    oauth2:
      client:
        provider:
          keycloak:
            issuer-uri: https://sso.monosense.dev/realms/home-ops
        registration:
          keycloak:
            client-id: spring-app
            client-secret: <PASTE_CLIENT_SECRET_FROM_ADMIN_CONSOLE>
            scope:
              - openid
              - profile
              - email
```

Test by navigating to your application - it should redirect to Keycloak for login.

## Monitoring

### Check Metrics

```bash
# Metrics endpoint
curl https://sso.monosense.dev/metrics | grep keycloak

# Check ServiceMonitor
kubectl get servicemonitor keycloak -n security

# View logs
kubectl logs -n security -l app=keycloak --tail=100 -f

# Check resource usage
kubectl top pods -n security -l app=keycloak
```

### Access Grafana Dashboard

Import Keycloak dashboard:
1. Go to Grafana
2. Import dashboard ID: **10441**
3. Select Victoria Metrics as datasource

## Troubleshooting

### Issue: Pods Not Starting

Check logs and events:
```bash
kubectl describe pod -n security -l app=keycloak
kubectl logs -n security -l app=keycloak --tail=100
```

Common causes:
- Missing 1Password secrets → Check ExternalSecrets
- Database not accessible → Check CNPG cluster
- Theme image not available → Verify `ghcr.io/trosvald/keycloak-theme:latest` exists

### Issue: ExternalSecrets Not Syncing

```bash
kubectl get externalsecret -n security
kubectl describe externalsecret keycloak-pguser -n security
```

Ensure 1Password fields exist exactly as named.

### Issue: Theme Not Loading

```bash
# Check init container ran
kubectl describe pod -n security keycloak-0 | grep -A 20 "Init Containers"

# Verify theme files
kubectl exec -n security keycloak-0 -- ls -la /opt/keycloak/themes/custom-redhat/
```

If theme is missing, rebuild and push the theme image.

### Issue: Cannot Access via HTTPRoute

```bash
kubectl get httproute keycloak -n security
kubectl describe httproute keycloak -n security
kubectl get gateway envoy-external -n networking
```

Check ReferenceGrant exists and external-dns has created the DNS record.

## Rollback Procedure

If you need to rollback:

```bash
# Remove Keycloak from security kustomization
# Edit kubernetes/apps/security/kustomization.yaml and comment out:
# - ./keycloak/ks.yaml
# - ./keycloak-operator/ks.yaml

# Commit and push
git add kubernetes/apps/security/kustomization.yaml
git commit -m "chore(security): rollback Keycloak deployment"
git push

# Flux will automatically remove resources
# Or manually delete:
kubectl delete kustomization keycloak -n flux-system
kubectl delete kustomization keycloak-operator -n flux-system
```

## Next Steps

1. **Test thoroughly** with your Spring Boot applications
2. **Configure additional realms** as needed
3. **Set up user federation** (LDAP/Active Directory) if required
4. **Configure identity providers** (Google, GitHub, etc.) if needed
5. **Plan migration from Authentik** (see main implementation plan)
6. **Set up backup procedures** for the database

## Support

For issues or questions:
- Review the main implementation plan: `docs/keycloak-implementation-plan.md`
- Check Keycloak documentation: https://www.keycloak.org/docs/
- Check operator documentation: https://www.keycloak.org/operator/installation

## Success Criteria

✅ Keycloak operator running (1 pod)
✅ Keycloak instances running (2 pods)
✅ Database connectivity verified
✅ HTTPRoute responding (200 OK)
✅ Admin console accessible
✅ Custom Red Hat theme applied
✅ Metrics endpoint scraped
✅ Test user can login

Once all criteria are met, Keycloak is successfully deployed and ready for production use!
