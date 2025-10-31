# ExternalDNS + Cloudflare Tunnel - Prerequisites Setup Guide

This guide covers the manual prerequisites required before deploying Story 08 (ExternalDNS + Cloudflare Tunnel). Complete these steps before creating any Kubernetes manifests.

**Estimated Time**: 30 minutes
**Skill Level**: Intermediate (DNS, BIND, Cloudflare familiarity required)

---

## Overview

Story 08 implements split-horizon DNS automation using:
- **Cloudflare ExternalDNS**: Manages public DNS records via Cloudflare API
- **RFC2136 ExternalDNS**: Manages internal DNS records via BIND dynamic updates
- **Cloudflare Tunnel (cloudflared)**: Zero-trust ingress for public traffic

This guide covers 4 prerequisite phases:
1. **BIND TSIG Configuration**: Enable secure dynamic DNS updates
2. **Cloudflare Tunnel Setup**: Create tunnel and external DNS anchor
3. **1Password Secret Storage**: Store all credentials securely
4. **Cluster Settings**: Add required configuration variables

---

## Phase 1: BIND TSIG Key Generation and Zone Configuration

### Why TSIG?

TSIG (Transaction Signature) provides cryptographic authentication for DNS dynamic updates, ensuring only authorized clients (ExternalDNS) can modify DNS records.

### Prerequisites

- SSH access to BIND server (10.25.10.30)
- Root or sudo privileges on BIND server
- BIND 9.x installed and running
- Zone `monosense.io` already configured

### Step 1.1: Generate TSIG Key

**On your BIND server:**

```bash
# Generate TSIG key with hmac-sha256 algorithm
sudo tsig-keygen -a hmac-sha256 externaldns-key | sudo tee /etc/bind/externaldns.key

# Output will look like:
# key "externaldns-key" {
#   algorithm hmac-sha256;
#   secret "96Ah/a2g0/nLeFGK+d/0tzQcccf9hCEIy34PoXX2Qg8=";
# };
```

**Important Notes:**
- The secret is base64-encoded and randomly generated
- Keep this terminal output - you'll need the secret for 1Password (Step 3)
- The key name `externaldns-key` must match what we configure in ExternalDNS

**Verify key file:**
```bash
sudo cat /etc/bind/externaldns.key
```

### Step 1.2: Configure BIND to Use TSIG Key

**Edit BIND main configuration:**

```bash
sudo vim /etc/bind/named.conf
```

**Add at the top of the file:**

```bind
# Include ExternalDNS TSIG key
include "/etc/bind/externaldns.key";
```

**Example context:**
```bind
// named.conf
include "/etc/bind/named.conf.options";
include "/etc/bind/named.conf.local";
include "/etc/bind/externaldns.key";  # ADD THIS LINE
```

### Step 1.3: Configure Zone to Allow Dynamic Updates

**Edit your zone configuration:**

```bash
sudo vim /etc/bind/named.conf.local
```

**Update the `monosense.io` zone block:**

```bind
zone "monosense.io" {
    type master;
    file "/etc/bind/zones/db.monosense.io";

    # Allow updates ONLY with TSIG key (secure)
    allow-update { key externaldns-key; };

    # Allow zone transfers ONLY with TSIG key (for AXFR)
    allow-transfer { key externaldns-key; };

    # Disable updates from any other source
    allow-update { none; };  # This line can be removed if only key auth is desired
};
```

**Critical Security Notes:**
- `allow-update { key externaldns-key; };` - ONLY the TSIG key can update DNS
- `allow-transfer { key externaldns-key; };` - AXFR queries require TSIG authentication
- Never use `allow-update { any; };` - this is a security vulnerability!

### Step 1.4: Set Proper Permissions

```bash
# Ensure BIND can read the key file
sudo chown bind:bind /etc/bind/externaldns.key
sudo chmod 640 /etc/bind/externaldns.key

# Verify permissions
ls -la /etc/bind/externaldns.key
# Expected: -rw-r----- 1 bind bind ... /etc/bind/externaldns.key
```

### Step 1.5: Validate Configuration

**Check BIND configuration syntax:**

```bash
sudo named-checkconf
# No output = configuration is valid
# Any errors = fix before proceeding
```

**Check zone file syntax:**

```bash
sudo named-checkzone monosense.io /etc/bind/zones/db.monosense.io
# Expected output: zone monosense.io/IN: loaded serial XXXXXX
#                  OK
```

### Step 1.6: Reload BIND Configuration

**Apply changes without downtime:**

```bash
# Reload configuration
sudo rndc reload

# Verify BIND is running
sudo systemctl status bind9
# or (on some systems)
sudo systemctl status named
```

**Expected output:**
```
● bind9.service - BIND Domain Name Server
   Active: active (running) since ...
```

### Step 1.7: Test Dynamic Update (Optional but Recommended)

**From a client machine with `nsupdate` installed:**

```bash
# Extract the secret from the key file
SECRET=$(sudo grep secret /etc/bind/externaldns.key | awk '{print $2}' | tr -d '";')

# Test dynamic update
cat <<EOF | nsupdate
server 10.25.10.30
zone monosense.io
key hmac-sha256:externaldns-key $SECRET
update add test-external-dns.monosense.io. 300 A 192.0.2.1
send
EOF

# Verify the record was created
dig @10.25.10.30 test-external-dns.monosense.io +short
# Expected: 192.0.2.1
```

**Clean up test record:**

```bash
cat <<EOF | nsupdate
server 10.25.10.30
zone monosense.io
key hmac-sha256:externaldns-key $SECRET
update delete test-external-dns.monosense.io.
send
EOF
```

### Step 1.8: Save TSIG Information for Next Phase

**Extract and save this information (needed for 1Password in Phase 3):**

```bash
# Get the TSIG secret (base64-encoded)
sudo grep secret /etc/bind/externaldns.key | awk '{print $2}' | tr -d '";'
# Save this output!
```

**Information to save:**
- TSIG Key Name: `externaldns-key`
- TSIG Algorithm: `hmac-sha256`
- TSIG Secret: `<output from command above>`
- BIND Host: `10.25.10.30`
- BIND Port: `53`
- DNS Zone: `monosense.io`

### Troubleshooting BIND TSIG

#### Issue: "update failed: REFUSED"

**Cause**: Zone doesn't allow updates with the TSIG key

**Fix:**
```bash
# Check zone configuration
sudo grep -A 5 "zone \"monosense.io\"" /etc/bind/named.conf.local

# Ensure allow-update includes: key externaldns-key;
# Reload: sudo rndc reload
```

#### Issue: "update failed: BADKEY"

**Cause**: TSIG key mismatch or incorrect algorithm

**Fix:**
```bash
# Verify key name in nsupdate matches /etc/bind/externaldns.key
sudo cat /etc/bind/externaldns.key

# Ensure algorithm is hmac-sha256 in both places
```

#### Issue: Permission denied reading key file

**Cause**: BIND process can't read /etc/bind/externaldns.key

**Fix:**
```bash
sudo chown bind:bind /etc/bind/externaldns.key
sudo chmod 640 /etc/bind/externaldns.key
sudo systemctl restart bind9
```

---

## Phase 2: Cloudflare Tunnel Setup

### Why Cloudflare Tunnel?

Cloudflare Tunnel provides zero-trust ingress without exposing origin IPs. Traffic flows:
- Internet → Cloudflare Edge → Tunnel (encrypted) → Kubernetes Gateway → Services

This eliminates the need to expose Kubernetes LoadBalancer IPs directly to the internet.

### Prerequisites

- Cloudflare account with `monosense.io` zone
- `cloudflared` CLI installed locally
- Zone editing permissions in Cloudflare

### Step 2.1: Install cloudflared CLI

**macOS (Homebrew):**
```bash
brew install cloudflare/cloudflare/cloudflared
```

**Linux (Direct download):**
```bash
# Download latest release (replace with current version)
wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64

# Make executable and move to PATH
chmod +x cloudflared-linux-amd64
sudo mv cloudflared-linux-amd64 /usr/local/bin/cloudflared

# Verify installation
cloudflared --version
```

**Windows (using Chocolatey):**
```powershell
choco install cloudflared
```

### Step 2.2: Authenticate with Cloudflare

**Login to Cloudflare:**

```bash
cloudflared tunnel login
```

**What happens:**
1. Opens browser to Cloudflare login page
2. Select your account and authorize the domain (`monosense.io`)
3. Downloads certificate to `~/.cloudflared/cert.pem`

**Verify authentication:**
```bash
ls -la ~/.cloudflared/cert.pem
# Should show: -rw------- ... cert.pem

cat ~/.cloudflared/cert.pem | head -5
# Should show: -----BEGIN CERTIFICATE-----
```

### Step 2.3: Create Tunnel

**Create a tunnel named `k8s-external`:**

```bash
cloudflared tunnel create k8s-external
```

**Expected output:**
```
Created tunnel k8s-external with id <TUNNEL_UUID>
Credentials saved to: /Users/you/.cloudflared/<TUNNEL_UUID>.json
```

**Save the Tunnel UUID** - you'll need it for DNS routing!

**Verify tunnel creation:**
```bash
cloudflared tunnel list
# Should show: ID=<TUNNEL_UUID> NAME=k8s-external STATUS=inactive
```

**Examine credentials file:**
```bash
# Note: Replace <TUNNEL_UUID> with your actual UUID
cat ~/.cloudflared/<TUNNEL_UUID>.json
```

**Credentials file structure:**
```json
{
  "AccountTag": "...",
  "TunnelSecret": "...",
  "TunnelID": "..."
}
```

**Save this entire file** - you'll need it for 1Password!

### Step 2.4: Create External DNS Anchor (CNAME)

**Route DNS for the external anchor:**

```bash
cloudflared tunnel route dns k8s-external external.monosense.io
```

**Expected output:**
```
Successfully created route for external.monosense.io
```

**What this does:**
- Creates a CNAME record: `external.monosense.io` → `<TUNNEL_UUID>.cfargotunnel.com`
- Sets proxied mode (orange cloud) automatically
- This becomes the target for all public HTTPRoutes

### Step 2.5: Verify Tunnel DNS Configuration

**Check DNS resolution:**

```bash
dig external.monosense.io CNAME +short
# Expected: <TUNNEL_UUID>.cfargotunnel.com
```

**Verify in Cloudflare Dashboard:**
1. Go to https://dash.cloudflare.com
2. Select `monosense.io` zone
3. Navigate to **DNS** → **Records**
4. Verify record exists:
   - Type: CNAME
   - Name: external
   - Content: `<TUNNEL_UUID>.cfargotunnel.com`
   - Proxy status: Proxied (orange cloud)
   - TTL: Auto

### Step 2.6: Save Tunnel Information for Next Phase

**Extract and save this information (needed for 1Password in Phase 3):**

```bash
# Get Tunnel ID
cloudflared tunnel list | grep k8s-external | awk '{print $1}'

# Get Tunnel Token (from credentials file)
cat ~/.cloudflared/<TUNNEL_UUID>.json | jq -r '.TunnelSecret'

# Or get the entire credentials as one-liner JSON
cat ~/.cloudflared/<TUNNEL_UUID>.json | jq -c
```

**Information to save:**
- Tunnel Name: `k8s-external`
- Tunnel ID: `<TUNNEL_UUID>`
- Tunnel Token: `<from credentials file>`
- Credentials JSON: `<entire file content>`
- External Anchor: `external.monosense.io`
- Tunnel CNAME: `<TUNNEL_UUID>.cfargotunnel.com`

### Troubleshooting Cloudflare Tunnel

#### Issue: "cloudflared: command not found"

**Cause**: CLI not installed or not in PATH

**Fix:**
```bash
# Check if installed
which cloudflared

# If not found, reinstall using method for your OS
# Then verify: cloudflared --version
```

#### Issue: "Failed to authenticate: invalid certificate"

**Cause**: cert.pem is missing or invalid

**Fix:**
```bash
# Remove old cert and re-authenticate
rm -f ~/.cloudflared/cert.pem
cloudflared tunnel login
```

#### Issue: "Tunnel already exists with that name"

**Cause**: Tunnel name collision

**Fix:**
```bash
# List existing tunnels
cloudflared tunnel list

# Either use existing tunnel or create with different name
cloudflared tunnel create k8s-external-v2
```

#### Issue: DNS routing failed

**Cause**: Zone not authorized or DNS API permissions missing

**Fix:**
- Verify you selected correct zone during `cloudflared tunnel login`
- Check Cloudflare account has DNS editing permissions
- Manually create CNAME in Cloudflare dashboard:
  - Type: CNAME
  - Name: external
  - Content: `<TUNNEL_UUID>.cfargotunnel.com`
  - Proxy: On (orange cloud)

---

## Phase 3: 1Password Secret Storage

### Why 1Password?

All credentials are stored in 1Password and synced to Kubernetes via External Secrets Operator (Story 05). This provides:
- Centralized secret management
- Secret rotation without manifest changes
- Audit trail of secret access
- No secrets in Git repository

### Prerequisites

- 1Password CLI (`op`) installed and configured
- Access to 1Password vaults: `Infra` (shared for both clusters)
- External Secrets Operator deployed (Story 05)

### Secret Organization

We'll create 3 secret items in 1Password:

| Secret Path | Purpose | Clusters |
|-------------|---------|----------|
| `kubernetes/infra/rfc2136` | BIND TSIG credentials | infra |
| `kubernetes/apps/rfc2136` | BIND TSIG credentials | apps |
| `kubernetes/infra/cloudflared` | Cloudflare Tunnel credentials | infra |
| `kubernetes/apps/cloudflared` | Cloudflare Tunnel credentials | apps |
| `kubernetes/infra/cloudflare` | Cloudflare API token (already exists from Story 06) | infra |
| `kubernetes/apps/cloudflare` | Cloudflare API token (already exists from Story 06) | apps |

**Note**: RFC2136 and cloudflared secrets are cluster-specific, Cloudflare API token is shared.

### Step 3.1: Verify 1Password Access

```bash
# Login to 1Password CLI
eval $(op signin)

# List vaults
op vault list

# Verify Infra vault exists
op vault get Infra
```

### Step 3.2: Create RFC2136 Secret (Infra Cluster)

**Using 1Password CLI:**

```bash
# Create item with TSIG credentials
op item create \
  --category=password \
  --vault=Infra \
  --title="kubernetes/infra/rfc2136" \
  RFC2136_HOST=10.25.10.30 \
  RFC2136_PORT=53 \
  RFC2136_ZONE=monosense.io \
  RFC2136_TSIG_KEYNAME=externaldns-key \
  RFC2136_TSIG_SECRET_BASE64='<TSIG_SECRET_FROM_PHASE_1>' \
  RFC2136_TSIG_ALG=hmac-sha256
```

**Replace `<TSIG_SECRET_FROM_PHASE_1>` with the secret you saved in Phase 1, Step 1.8!**

**Using 1Password Web/App:**

1. Open 1Password app or https://my.1password.com
2. Select **Infra** vault
3. Click **New Item** → **Password**
4. Set Title: `kubernetes/infra/rfc2136`
5. Add fields:
   - Field: `RFC2136_HOST`, Value: `10.25.10.30`
   - Field: `RFC2136_PORT`, Value: `53`
   - Field: `RFC2136_ZONE`, Value: `monosense.io`
   - Field: `RFC2136_TSIG_KEYNAME`, Value: `externaldns-key`
   - Field: `RFC2136_TSIG_SECRET_BASE64`, Value: `<TSIG secret from Phase 1>`
   - Field: `RFC2136_TSIG_ALG`, Value: `hmac-sha256`
6. Click **Save**

**Verify creation:**

```bash
op item get "kubernetes/infra/rfc2136" --vault Infra
```

### Step 3.3: Create RFC2136 Secret (Apps Cluster)

**Repeat for apps cluster with same values:**

```bash
op item create \
  --category=password \
  --vault=Infra \
  --title="kubernetes/apps/rfc2136" \
  RFC2136_HOST=10.25.10.30 \
  RFC2136_PORT=53 \
  RFC2136_ZONE=monosense.io \
  RFC2136_TSIG_KEYNAME=externaldns-key \
  RFC2136_TSIG_SECRET_BASE64='<TSIG_SECRET_FROM_PHASE_1>' \
  RFC2136_TSIG_ALG=hmac-sha256
```

**Note**: Both clusters use the same BIND server and TSIG key.

### Step 3.4: Create Cloudflared Secret (Infra Cluster)

**The ExternalSecret will build the tunnel token from three separate fields from the credentials file.**

**Extract credentials from tunnel:**

```bash
# Get tunnel UUID
TUNNEL_UUID=$(cloudflared tunnel list | grep k8s-external | awk '{print $1}')

# Extract the three required fields
CF_ACCOUNT_ID=$(cat ~/.cloudflared/${TUNNEL_UUID}.json | jq -r '.AccountTag')
CF_TUNNEL_ID=$(cat ~/.cloudflared/${TUNNEL_UUID}.json | jq -r '.TunnelID')
CF_TUNNEL_SECRET=$(cat ~/.cloudflared/${TUNNEL_UUID}.json | jq -r '.TunnelSecret')

echo "Account ID: $CF_ACCOUNT_ID"
echo "Tunnel ID: $CF_TUNNEL_ID"
echo "Tunnel Secret: $CF_TUNNEL_SECRET"
```

**Using 1Password CLI:**

```bash
op item create \
  --category=password \
  --vault=Infra \
  --title="kubernetes/infra/cloudflared" \
  CF_ACCOUNT_ID="${CF_ACCOUNT_ID}" \
  CF_TUNNEL_ID="${CF_TUNNEL_ID}" \
  CF_TUNNEL_SECRET="${CF_TUNNEL_SECRET}"
```

**Using 1Password Web/App:**

1. Open 1Password app or https://my.1password.com
2. Select **Infra** vault
3. Click **New Item** → **Password**
4. Set Title: `kubernetes/infra/cloudflared`
5. Add three fields (get values from command above):
   - Field: `CF_ACCOUNT_ID`, Value: `<AccountTag from credentials.json>`
   - Field: `CF_TUNNEL_ID`, Value: `<TunnelID from credentials.json>`
   - Field: `CF_TUNNEL_SECRET`, Value: `<TunnelSecret from credentials.json>`
6. Click **Save**

**Example 1Password item structure:**
```
Title: kubernetes/infra/cloudflared
Fields:
  CF_ACCOUNT_ID: "abc123def456ghi789jkl012"
  CF_TUNNEL_ID: "12345678-90ab-cdef-1234-567890abcdef"
  CF_TUNNEL_SECRET: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/="
```

**Verify creation:**

```bash
op item get "kubernetes/infra/cloudflared" --vault Infra
op item get "kubernetes/infra/cloudflared" --vault Infra --fields label=CF_ACCOUNT_ID
op item get "kubernetes/infra/cloudflared" --vault Infra --fields label=CF_TUNNEL_ID
op item get "kubernetes/infra/cloudflared" --vault Infra --fields label=CF_TUNNEL_SECRET
```

**How ExternalSecret will use these fields:**

The ExternalSecret will build the tunnel token dynamically:
```yaml
TUNNEL_TOKEN: |-
  {{ toJson (dict "a" .CF_ACCOUNT_ID "t" .CF_TUNNEL_ID "s" .CF_TUNNEL_SECRET) | b64enc }}
```

This creates a base64-encoded JSON: `{"a":"account","t":"tunnel-id","s":"secret"}`

### Step 3.5: Create Cloudflared Secret (Apps Cluster)

**For apps cluster, you can create a separate tunnel or share the same tunnel.**

**Option A: Separate Tunnel per Cluster (Recommended for production)**

Repeat Phase 2 to create a second tunnel:
```bash
cloudflared tunnel create k8s-external-apps
cloudflared tunnel route dns k8s-external-apps external-apps.monosense.io

# Extract credentials
TUNNEL_UUID=$(cloudflared tunnel list | grep k8s-external-apps | awk '{print $1}')
CF_ACCOUNT_ID=$(cat ~/.cloudflared/${TUNNEL_UUID}.json | jq -r '.AccountTag')
CF_TUNNEL_ID=$(cat ~/.cloudflared/${TUNNEL_UUID}.json | jq -r '.TunnelID')
CF_TUNNEL_SECRET=$(cat ~/.cloudflared/${TUNNEL_UUID}.json | jq -r '.TunnelSecret')

# Store in 1Password
op item create \
  --category=password \
  --vault=Infra \
  --title="kubernetes/apps/cloudflared" \
  CF_ACCOUNT_ID="${CF_ACCOUNT_ID}" \
  CF_TUNNEL_ID="${CF_TUNNEL_ID}" \
  CF_TUNNEL_SECRET="${CF_TUNNEL_SECRET}"
```

**Option B: Share Tunnel (Simpler for home lab)**

Use the same tunnel credentials for both clusters (from Step 3.4):
```bash
op item create \
  --category=password \
  --vault=Infra \
  --title="kubernetes/apps/cloudflared" \
  CF_ACCOUNT_ID="${CF_ACCOUNT_ID}" \
  CF_TUNNEL_ID="${CF_TUNNEL_ID}" \
  CF_TUNNEL_SECRET="${CF_TUNNEL_SECRET}"
```

**Note**: For this story, we'll use **Option B (shared tunnel)** for simplicity. Both clusters will use the same tunnel and route through the same `external.monosense.io` anchor.

### Step 3.6: Verify/Update Cloudflare API Token Secret

**This secret should already exist from Story 06 (cert-manager). Verify and add Zone ID if missing:**

```bash
# Check existing secret
op item get "kubernetes/infra/cloudflare" --vault Infra

# If CLOUDFLARE_ZONE_ID is missing, edit to add it
op item edit "kubernetes/infra/cloudflare" --vault Infra \
  CLOUDFLARE_ZONE_ID='<YOUR_ZONE_ID>'
```

**Get your Zone ID from Cloudflare Dashboard:**
1. Go to https://dash.cloudflare.com
2. Select `monosense.io` domain
3. Scroll down to **API** section on Overview page
4. Copy **Zone ID**

**Expected fields in `kubernetes/infra/cloudflare`:**
- `CLOUDFLARE_API_TOKEN`: API token with Zone Read + DNS Edit permissions
- `CLOUDFLARE_ZONE_ID`: Zone ID for monosense.io
- `CLOUDFLARE_EMAIL`: (if using API Key auth instead of token)
- `CLOUDFLARE_API_KEY`: (if using API Key auth instead of token)

**Verify for apps cluster:**

```bash
op item get "kubernetes/apps/cloudflare" --vault Infra
# Should have same fields as infra
```

### Step 3.7: Validation Checklist

Verify all secrets exist:

```bash
# RFC2136 secrets
op item get "kubernetes/infra/rfc2136" --vault Infra --fields label=RFC2136_HOST
op item get "kubernetes/apps/rfc2136" --vault Infra --fields label=RFC2136_HOST

# Cloudflared secrets (3 fields each)
op item get "kubernetes/infra/cloudflared" --vault Infra --fields label=CF_ACCOUNT_ID
op item get "kubernetes/infra/cloudflared" --vault Infra --fields label=CF_TUNNEL_ID
op item get "kubernetes/infra/cloudflared" --vault Infra --fields label=CF_TUNNEL_SECRET
op item get "kubernetes/apps/cloudflared" --vault Infra --fields label=CF_ACCOUNT_ID
op item get "kubernetes/apps/cloudflared" --vault Infra --fields label=CF_TUNNEL_ID
op item get "kubernetes/apps/cloudflared" --vault Infra --fields label=CF_TUNNEL_SECRET

# Cloudflare API secrets
op item get "kubernetes/infra/cloudflare" --vault Infra --fields label=CLOUDFLARE_ZONE_ID
op item get "kubernetes/apps/cloudflare" --vault Infra --fields label=CLOUDFLARE_ZONE_ID
```

**All commands should return values without errors.**

### Troubleshooting 1Password

#### Issue: "op: command not found"

**Fix:**
```bash
# Install 1Password CLI
# macOS: brew install 1password-cli
# Linux: https://developer.1password.com/docs/cli/get-started/

# Login
eval $(op signin)
```

#### Issue: "Item not found"

**Cause**: Item path mismatch

**Fix:**
```bash
# List all items in Infra vault
op item list --vault Infra

# Verify exact title matches what you created
op item get "kubernetes/infra/rfc2136" --vault Infra
```

#### Issue: External Secrets not syncing

**Cause**: Path or field name mismatch between 1Password and ExternalSecret

**Fix:**
- ExternalSecret `dataFrom.extract.key` must match 1Password item title exactly
- Field names in 1Password must match what ExternalSecret expects
- Check ExternalSecret logs: `kubectl logs -n <namespace> <externalsecret-pod>`

---

## Phase 4: Cluster Settings Variables

### Why Cluster Settings?

The `cluster-settings.yaml` ConfigMap provides environment-specific variables that Flux substitutes into manifests via `postBuild.substituteFrom`. This allows:
- Single manifest set for multiple clusters
- Cluster-specific IP addresses and configurations
- No hardcoded values in manifests

### Prerequisites

- Git repository cloned locally
- Write access to the repository

### Step 4.1: Update Infra Cluster Settings

**Edit infra cluster settings:**

```bash
vim kubernetes/clusters/infra/cluster-settings.yaml
```

**Add these variables to the `data:` section:**

```yaml
  # Gateway Configuration (ExternalDNS)
  CILIUM_GATEWAY_EXTERNAL_NAME: "cilium-gateway-external"  # NEW
  CILIUM_GATEWAY_INTERNAL_NAME: "cilium-gateway-internal"  # NEW
  CILIUM_GATEWAY_LB_IP_EXTERNAL: "10.25.11.110"            # NEW (matches CILIUM_GATEWAY_LB_IP)
  CILIUM_GATEWAY_LB_IP_INTERNAL: "10.25.11.111"            # NEW

  # ExternalDNS Configuration
  EXTERNALDNS_INTERVAL: "1m"                                # NEW

  # Cloudflared Configuration
  CLOUDFLARED_TARGET_SERVICE: "https://cilium-gateway-external.kube-system.svc.cluster.local"  # NEW
  CLOUDFLARED_REPLICAS: "2"                                 # NEW
```

**Important Notes:**
- `CILIUM_GATEWAY_LB_IP_EXTERNAL`: `10.25.11.110` (same as existing `CILIUM_GATEWAY_LB_IP`)
- `CILIUM_GATEWAY_LB_IP_INTERNAL`: `10.25.11.111` (new LoadBalancer IP for internal Gateway)
- Both IPs must be within the infra LoadBalancer pool: `10.25.11.100-119`

### Step 4.2: Update Apps Cluster Settings

**Edit apps cluster settings:**

```bash
vim kubernetes/clusters/apps/cluster-settings.yaml
```

**Add these variables to the `data:` section:**

```yaml
  # Gateway Configuration (ExternalDNS)
  CILIUM_GATEWAY_EXTERNAL_NAME: "cilium-gateway-external"  # NEW
  CILIUM_GATEWAY_INTERNAL_NAME: "cilium-gateway-internal"  # NEW
  CILIUM_GATEWAY_LB_IP_EXTERNAL: "10.25.11.121"            # NEW (matches CILIUM_GATEWAY_LB_IP)
  CILIUM_GATEWAY_LB_IP_INTERNAL: "10.25.11.122"            # NEW

  # ExternalDNS Configuration
  EXTERNALDNS_INTERVAL: "1m"                                # NEW

  # Cloudflared Configuration
  CLOUDFLARED_TARGET_SERVICE: "https://cilium-gateway-external.kube-system.svc.cluster.local"  # NEW
  CLOUDFLARED_REPLICAS: "2"                                 # NEW
```

**Important Notes:**
- `CILIUM_GATEWAY_LB_IP_EXTERNAL`: `10.25.11.121` (same as existing `CILIUM_GATEWAY_LB_IP`)
- `CILIUM_GATEWAY_LB_IP_INTERNAL`: `10.25.11.122` (new LoadBalancer IP for internal Gateway)
- Both IPs must be within the apps LoadBalancer pool: `10.25.11.120-139`

### Step 4.3: Verify Cluster Settings Changes

**Check infra cluster settings:**

```bash
git diff kubernetes/clusters/infra/cluster-settings.yaml
```

**Verify:**
- 7 new variables added
- IPs are within correct range (10.25.11.100-119)
- No syntax errors (proper YAML indentation)

**Check apps cluster settings:**

```bash
git diff kubernetes/clusters/apps/cluster-settings.yaml
```

**Verify:**
- 7 new variables added
- IPs are within correct range (10.25.11.120-139)
- No syntax errors (proper YAML indentation)

### Step 4.4: Validate YAML Syntax

```bash
# Validate infra settings
yq eval . kubernetes/clusters/infra/cluster-settings.yaml > /dev/null
echo $?  # Should be 0

# Validate apps settings
yq eval . kubernetes/clusters/apps/cluster-settings.yaml > /dev/null
echo $?  # Should be 0
```

**If errors appear, fix YAML syntax before proceeding.**

### Step 4.5: Variable Reference Summary

**Complete variable set for ExternalDNS (Story 08):**

| Variable | Infra Value | Apps Value | Purpose |
|----------|-------------|------------|---------|
| `CILIUM_GATEWAY_EXTERNAL_NAME` | cilium-gateway-external | cilium-gateway-external | External Gateway resource name |
| `CILIUM_GATEWAY_INTERNAL_NAME` | cilium-gateway-internal | cilium-gateway-internal | Internal Gateway resource name |
| `CILIUM_GATEWAY_LB_IP_EXTERNAL` | 10.25.11.110 | 10.25.11.121 | External Gateway LoadBalancer IP |
| `CILIUM_GATEWAY_LB_IP_INTERNAL` | 10.25.11.111 | 10.25.11.122 | Internal Gateway LoadBalancer IP |
| `EXTERNALDNS_INTERVAL` | 1m | 1m | ExternalDNS sync interval |
| `CLOUDFLARED_TARGET_SERVICE` | https://cilium-gateway-external... | https://cilium-gateway-external... | Tunnel target backend |
| `CLOUDFLARED_REPLICAS` | 2 | 2 | Cloudflared pod replicas |

**Existing variables used by Story 08:**
- `SECRET_DOMAIN`: monosense.io (DNS zone)
- `CLUSTER`: infra / apps (for ExternalSecret paths)

### Step 4.6: Commit Cluster Settings (Do NOT Push Yet)

**Stage changes:**

```bash
git add kubernetes/clusters/infra/cluster-settings.yaml
git add kubernetes/clusters/apps/cluster-settings.yaml
```

**Commit locally (DO NOT PUSH):**

```bash
git commit -m "feat(config): add ExternalDNS and Cloudflared cluster settings variables

Add configuration variables for Story 08 (ExternalDNS + Cloudflare Tunnel):
- Gateway resource names (external/internal)
- LoadBalancer IP assignments
- ExternalDNS sync interval
- Cloudflared target service and replicas

Changes:
- Infra cluster: 7 new variables
- Apps cluster: 7 new variables
- IP allocations within existing IPAM pools

Prepares-for: Story 08 manifest creation
"
```

**Important**: Do not push to remote yet! We'll push all Story 08 changes together after manifest creation.

### Troubleshooting Cluster Settings

#### Issue: IP address conflicts

**Symptom**: LoadBalancer IP already in use

**Check existing IP assignments:**

```bash
# Infra cluster IPs in use
grep "10.25.11.1" kubernetes/clusters/infra/cluster-settings.yaml

# Should see:
# - 10.25.11.100: ClusterMesh
# - 10.25.11.110: Gateway (external)
# - 10.25.11.111: Gateway (internal) <- NEW
```

**If conflict exists, choose different IP within range.**

#### Issue: YAML indentation errors

**Symptom**: yq validation fails

**Fix:**
```bash
# Check indentation (must be 2 spaces)
cat kubernetes/clusters/infra/cluster-settings.yaml | grep -A 2 "CILIUM_GATEWAY"

# Ensure:
# data:
#   VARIABLE: "value"  <- 2 space indent
```

---

## Phase 5: Internal DNS Anchor Configuration

### Why Internal DNS Anchor?

Unlike the external anchor (handled by Cloudflare Tunnel), the internal anchor must be manually added to your BIND server. This anchor (`internal.monosense.io`) will point to the internal Gateway LoadBalancer IP.

### Step 5.1: Add Internal Anchor to BIND Zone

**Edit your BIND zone file:**

```bash
sudo vim /etc/bind/zones/db.monosense.io
```

**Add A records for internal anchors:**

```bind
; Internal Gateway Anchors (for ExternalDNS RFC2136)
; TTL 300 seconds (5 minutes)
internal-infra    300    IN    A    10.25.11.111
internal-apps     300    IN    A    10.25.11.122

; Alternative: single internal anchor (if using shared)
internal          300    IN    A    10.25.11.111
```

**Important Notes:**
- Use cluster-specific anchors if routing differs per cluster
- Use single `internal` anchor if both clusters handle the same services
- TTL 300 (5 minutes) allows reasonably fast updates
- IPs match `CILIUM_GATEWAY_LB_IP_INTERNAL` from cluster-settings

### Step 5.2: Increment Zone Serial Number

**CRITICAL**: BIND requires serial number increment for zone changes.

**In the zone file SOA record:**

```bind
@    IN    SOA    ns1.monosense.io. admin.monosense.io. (
                  2025103101  ; Serial (YYYYMMDDNN) - INCREMENT THIS!
                  3600        ; Refresh
                  1800        ; Retry
                  604800      ; Expire
                  86400 )     ; Minimum TTL
```

**Serial number format**: `YYYYMMDDNN` where NN is update counter for the day
- Example: `2025103101` → `2025103102` (second update on Oct 31, 2025)

### Step 5.3: Validate and Reload BIND

**Check zone syntax:**

```bash
sudo named-checkzone monosense.io /etc/bind/zones/db.monosense.io
# Expected: zone monosense.io/IN: loaded serial 2025103102
#           OK
```

**Reload BIND:**

```bash
sudo rndc reload monosense.io
# Expected: zone monosense.io/IN: loaded serial 2025103102
```

### Step 5.4: Verify Internal Anchor Resolution

**Test from any client:**

```bash
dig @10.25.10.30 internal.monosense.io +short
# Expected: 10.25.11.111 (infra)

dig @10.25.10.30 internal-infra.monosense.io +short
# Expected: 10.25.11.111

dig @10.25.10.30 internal-apps.monosense.io +short
# Expected: 10.25.11.122
```

**Test from Kubernetes (after CoreDNS deployed):**

```bash
kubectl run -it --rm debug --image=nicolaka/netshoot -- dig internal.monosense.io +short
# Expected: 10.25.11.111
```

### Step 5.5: Document DNS Anchor Configuration

**Save this configuration for reference:**

| Anchor Type | FQDN | Target | DNS Provider | Notes |
|-------------|------|--------|--------------|-------|
| External (Infra) | external.monosense.io | <TUNNEL_UUID>.cfargotunnel.com | Cloudflare | Proxied, managed by Cloudflare |
| External (Apps) | external.monosense.io | <TUNNEL_UUID>.cfargotunnel.com | Cloudflare | Shared tunnel |
| Internal (Infra) | internal-infra.monosense.io | 10.25.11.111 | BIND | Direct A record |
| Internal (Apps) | internal-apps.monosense.io | 10.25.11.122 | BIND | Direct A record |
| Internal (Shared) | internal.monosense.io | 10.25.11.111 | BIND | Points to infra |

---

## ✅ Prerequisites Completion Checklist

Before proceeding to Story 08 manifest creation, verify all prerequisites are complete:

### Phase 1: BIND TSIG
- [ ] TSIG key generated (`/etc/bind/externaldns.key`)
- [ ] TSIG key included in `named.conf`
- [ ] Zone configured with `allow-update { key externaldns-key; }`
- [ ] Zone configured with `allow-transfer { key externaldns-key; }`
- [ ] Permissions set correctly (640, bind:bind)
- [ ] Configuration validated (`named-checkconf`)
- [ ] BIND reloaded successfully
- [ ] Dynamic update test passed (optional)
- [ ] TSIG secret saved for 1Password

### Phase 2: Cloudflare Tunnel
- [ ] `cloudflared` CLI installed
- [ ] Authenticated with Cloudflare (`cert.pem` exists)
- [ ] Tunnel created (`k8s-external`)
- [ ] Tunnel UUID saved
- [ ] Credentials file saved (`~/.cloudflared/<UUID>.json`)
- [ ] DNS anchor created (`external.monosense.io`)
- [ ] CNAME verified in Cloudflare dashboard
- [ ] DNS resolution tested (`dig external.monosense.io`)
- [ ] Tunnel token extracted for 1Password

### Phase 3: 1Password Secrets
- [ ] 1Password CLI working (`op signin`)
- [ ] RFC2136 secret created for infra cluster
- [ ] RFC2136 secret created for apps cluster
- [ ] Cloudflared secret created for infra cluster
- [ ] Cloudflared secret created for apps cluster
- [ ] Cloudflare API secret verified (both clusters)
- [ ] Zone ID added to Cloudflare secrets
- [ ] All secrets validated (`op item get`)

### Phase 4: Cluster Settings
- [ ] Infra cluster-settings updated (7 new variables)
- [ ] Apps cluster-settings updated (7 new variables)
- [ ] IP addresses verified (within IPAM pools)
- [ ] YAML syntax validated (`yq eval`)
- [ ] Changes committed locally (not pushed)
- [ ] Variable reference documented

### Phase 5: Internal DNS Anchor
- [ ] Internal anchor A records added to BIND zone
- [ ] Zone serial number incremented
- [ ] Zone syntax validated (`named-checkzone`)
- [ ] BIND reloaded successfully
- [ ] Internal anchor DNS resolution tested
- [ ] DNS configuration documented

### Ready for Next Phase
- [ ] All 5 phases completed
- [ ] All validation tests passed
- [ ] Secrets stored securely in 1Password
- [ ] Configuration documented
- [ ] Ready to proceed with manifest creation

---

## 📚 Reference Information

### Key Files Created/Modified

| File | Purpose | Cluster |
|------|---------|---------|
| `/etc/bind/externaldns.key` | TSIG key for DNS updates | BIND server |
| `/etc/bind/named.conf` | Include TSIG key | BIND server |
| `/etc/bind/named.conf.local` | Zone allow-update config | BIND server |
| `/etc/bind/zones/db.monosense.io` | Internal anchor A records | BIND server |
| `~/.cloudflared/cert.pem` | Cloudflare authentication | Local machine |
| `~/.cloudflared/<UUID>.json` | Tunnel credentials | Local machine |
| `kubernetes/clusters/infra/cluster-settings.yaml` | ExternalDNS variables | Git repo |
| `kubernetes/clusters/apps/cluster-settings.yaml` | ExternalDNS variables | Git repo |

### Important Commands Reference

```bash
# BIND Management
sudo named-checkconf                    # Validate BIND configuration
sudo named-checkzone monosense.io /etc/bind/zones/db.monosense.io
sudo rndc reload                        # Reload BIND configuration
sudo rndc reload monosense.io          # Reload specific zone
sudo systemctl status bind9             # Check BIND status

# Cloudflare Tunnel
cloudflared tunnel login                # Authenticate
cloudflared tunnel create <name>        # Create tunnel
cloudflared tunnel list                 # List tunnels
cloudflared tunnel route dns <tunnel> <hostname>  # Route DNS

# 1Password CLI
eval $(op signin)                       # Login
op vault list                           # List vaults
op item create --vault Infra ...        # Create item
op item get "path" --vault Infra        # Get item
op item list --vault Infra              # List items

# DNS Testing
dig @10.25.10.30 <hostname> +short      # Test BIND resolution
dig <hostname> CNAME +short             # Test public DNS
nslookup <hostname> 10.25.10.30         # Alternative DNS test
```

### Next Steps

Once all prerequisites are complete, proceed to:
1. **Story 08 Manifest Creation** - Create Kubernetes manifests
2. **Validation** - Use `flux build` and `kubectl dry-run`
3. **Commit** - Push all Story 08 changes together
4. **Deploy** - Deferred to Story 45 (Flux Deployment)

---

**Prerequisites guide complete!** You're now ready to begin Story 08 manifest creation.

### Step 3.8: ExternalSecret Manifest Structure

**For reference, here's how the ExternalSecret will be structured in the manifests:**

**Cloudflared ExternalSecret:**
```yaml
---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: cloudflared
  namespace: networking
spec:
  secretStoreRef:
    kind: ClusterSecretStore
    name: onepassword
  target:
    name: cloudflared-secret
    creationPolicy: Owner
    template:
      data:
        # Build TUNNEL_TOKEN from three fields
        TUNNEL_TOKEN: |-
          {{ toJson (dict "a" .CF_ACCOUNT_ID "t" .CF_TUNNEL_ID "s" .CF_TUNNEL_SECRET) | b64enc }}
  dataFrom:
    - extract:
        key: kubernetes/${CLUSTER}/cloudflared
```

**How it works:**
1. Extracts three fields from 1Password: `CF_ACCOUNT_ID`, `CF_TUNNEL_ID`, `CF_TUNNEL_SECRET`
2. Uses `dict` to create JSON object: `{"a":"...","t":"...","s":"..."}`
3. Uses `toJson` to serialize to JSON string
4. Uses `b64enc` to base64-encode the result
5. Stores as `TUNNEL_TOKEN` in the Kubernetes Secret

**The resulting Secret will contain:**
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: cloudflared-secret
  namespace: networking
type: Opaque
data:
  TUNNEL_TOKEN: eyJhIjoiYWJjLi4uIiwidCI6IjEyMy4uLiIsInMiOiJBQkMuLi4ifQ==
```

**Cloudflared pod will use this Secret:**
```yaml
env:
  - name: TUNNEL_TOKEN
    valueFrom:
      secretKeyRef:
        name: cloudflared-secret
        key: TUNNEL_TOKEN
```

This is the **correct** pattern that matches Cloudflare's official tunnel token format.

---
