# 13 — STORY-NET-CLUSTERMESH-DNS — Create ClusterMesh DNS Configuration

Sequence: 13/50 | Prev: STORY-NET-CILIUM-CLUSTERMESH.md | Next: STORY-STO-OPENEBS-BASE.md
Sprint: 6 | Lane: Networking
Global Sequence: 13/50

Status: Draft (v3.0 Refinement)
Owner: Platform Engineering
Date: 2025-10-26 (v3.0 Refinement)
Links: docs/architecture.md §20; kubernetes/clusters/*/cluster-settings.yaml

---

## Story

As a platform engineer, I want to **create DNS configuration for ClusterMesh API servers**, so that when deployed in Story 45, clusters can discover each other via FQDNs instead of raw IP addresses, enabling easier rotation and more robust cross-cluster connectivity.

This story creates the DNS record requirements and configuration (DNSEndpoint manifests if using ExternalDNS, or manual DNS record documentation). Actual DNS propagation and ClusterMesh connectivity validation happen in Story 45 (VALIDATE-NETWORKING).

## Why / Outcome

- Create DNS configuration for ClusterMesh API server discovery
- Enable FQDN-based cross-cluster connectivity (decoupled from IP addresses)
- Support easier IP rotation and migration
- Provide deterministic discovery mechanism
- Foundation for resilient ClusterMesh operations

## Scope

**This Story (DNS Configuration Creation):**
- Document DNS record requirements for ClusterMesh API servers
- Create DNSEndpoint manifests (if using ExternalDNS automation)
- Update cluster-settings with ClusterMesh FQDN variables
- Define ClusterMesh LoadBalancer IP allocations
- Local validation (flux build, kubectl dry-run)

**Deferred to Story 45 (Deployment & Validation):**
- Deploying DNS records (via ExternalDNS or manual process)
- Verifying DNS resolution of ClusterMesh FQDNs
- Testing ClusterMesh connectivity via FQDN
- Validating LoadBalancer IP assignments
- Confirming DNS propagation

---

## Acceptance Criteria

**DNS Configuration Creation (This Story):**

1. **DNS Record Requirements Documented:**
   - Infra cluster: `clustermesh-infra.${SECRET_DOMAIN}` → `${CILIUM_CLUSTERMESH_LB_IP}` (infra)
   - Apps cluster: `clustermesh-apps.${SECRET_DOMAIN}` → `${CILIUM_CLUSTERMESH_LB_IP}` (apps)
   - Record type: A records
   - TTL: 300 seconds (5 minutes)

2. **DNSEndpoint Manifests Created (If Using ExternalDNS):**
   - `kubernetes/infrastructure/networking/cilium/clustermesh/dnsendpoint.yaml` exists
   - DNSEndpoint for each cluster's ClusterMesh API server
   - References LoadBalancer service or uses cluster-settings variables

3. **Cluster Settings Updated:**
   - Cluster-settings include ClusterMesh DNS variables:
     - Infra: `CILIUM_CLUSTERMESH_FQDN: "clustermesh-infra.${SECRET_DOMAIN}"`
     - Apps: `CILIUM_CLUSTERMESH_FQDN: "clustermesh-apps.${SECRET_DOMAIN}"`
   - ClusterMesh LoadBalancer IPs defined:
     - Infra: `CILIUM_CLUSTERMESH_LB_IP: "10.25.11.100"`
     - Apps: `CILIUM_CLUSTERMESH_LB_IP: "10.25.11.120"`

4. **Cilium ClusterMesh Configuration Updated:**
   - ClusterMesh peer configuration uses FQDNs instead of IPs
   - Cilium HelmRelease references `${CILIUM_CLUSTERMESH_FQDN}` for peer discovery

5. **Local Validation Passes:**
   - `flux build kustomization cluster-infra-infrastructure --path ./kubernetes/infrastructure` succeeds
   - `flux build kustomization cluster-apps-infrastructure --path ./kubernetes/infrastructure` succeeds
   - Output shows correct FQDN substitution for each cluster
   - `kubectl --dry-run=client` validates manifests

**Deferred to Story 45 (Deployment & Validation):**
- ❌ DNS records resolvable from both clusters
- ❌ `dig +short clustermesh-infra.${SECRET_DOMAIN}` returns correct IP
- ❌ `dig +short clustermesh-apps.${SECRET_DOMAIN}` returns correct IP
- ❌ ClusterMesh Connected status via FQDN
- ❌ LoadBalancer IPs assigned from correct pools

---

## Dependencies

**Prerequisites (v3.0):**
- Story 02 (STORY-NET-CILIUM-IPAM) complete (IPAM pools defined with LB IP ranges)
- Story 12 (STORY-NET-CILIUM-CLUSTERMESH) complete (ClusterMesh manifests created)
- Story 08 (STORY-DNS-EXTERNALDNS-CF-BIND-TUNNEL) complete (if using ExternalDNS automation)
- Cluster-settings ConfigMaps with domain variables
- Tools: kubectl (for dry-run), flux CLI, yq

**NOT Required (v3.0):**
- ❌ Cluster access (validation is local-only)
- ❌ DNS provider access (configuration in Story 45)
- ❌ Running clusters (Story 45 handles deployment)

---

## Implementation Tasks

### T1: Verify Prerequisites (Local Validation Only)

- [ ] Verify Story 02 complete (IPAM pool manifests with LB ranges):
  ```bash
  ls -la kubernetes/infrastructure/networking/cilium/ipam/lb-ippool-*.yaml
  grep -A 5 "start:" kubernetes/infrastructure/networking/cilium/ipam/lb-ippool-infra.yaml
  grep -A 5 "start:" kubernetes/infrastructure/networking/cilium/ipam/lb-ippool-apps.yaml
  ```

- [ ] Verify Story 12 complete (ClusterMesh manifests created):
  ```bash
  ls -la kubernetes/infrastructure/networking/cilium/clustermesh/
  ```

- [ ] Verify cluster-settings have domain variables:
  ```bash
  grep SECRET_DOMAIN kubernetes/clusters/infra/cluster-settings.yaml
  grep SECRET_DOMAIN kubernetes/clusters/apps/cluster-settings.yaml
  ```

---

### T2: Define DNS Record Requirements

- [ ] Document DNS record requirements in this story:
  ```markdown
  ## DNS Record Requirements

  ### Infra Cluster ClusterMesh API Server
  - FQDN: clustermesh-infra.${SECRET_DOMAIN}
  - Type: A
  - Value: ${CILIUM_CLUSTERMESH_LB_IP} (10.25.11.100)
  - TTL: 300

  ### Apps Cluster ClusterMesh API Server
  - FQDN: clustermesh-apps.${SECRET_DOMAIN}
  - Type: A
  - Value: ${CILIUM_CLUSTERMESH_LB_IP} (10.25.11.120)
  - TTL: 300

  ### Implementation Methods
  1. **Automated (ExternalDNS)**: Create DNSEndpoint manifests
  2. **Manual**: Create DNS records via Cloudflare API or web UI
  ```

---

### T3: Create DNSEndpoint Manifests (If Using ExternalDNS)

**Note**: This step is optional and depends on whether ExternalDNS automation is desired. For manual DNS management, skip to T4.

- [ ] Create DNSEndpoint manifest (if using ExternalDNS):
  ```yaml
  # kubernetes/infrastructure/networking/cilium/clustermesh/dnsendpoint.yaml
  ---
  apiVersion: externaldns.k8s.io/v1alpha1
  kind: DNSEndpoint
  metadata:
    name: clustermesh-apiserver
    namespace: kube-system
  spec:
    endpoints:
      - dnsName: ${CILIUM_CLUSTERMESH_FQDN}
        recordType: A
        recordTTL: 300
        targets:
          - ${CILIUM_CLUSTERMESH_LB_IP}
  ```

- [ ] Update clustermesh kustomization to include DNSEndpoint:
  ```yaml
  # kubernetes/infrastructure/networking/cilium/clustermesh/kustomization.yaml
  resources:
    - externalsecret.yaml
    - dnsendpoint.yaml  # ADD THIS LINE (if using ExternalDNS)
  ```

---

### T4: Update Cluster Settings

- [ ] Update infra cluster-settings with DNS variables:
  ```yaml
  # kubernetes/clusters/infra/cluster-settings.yaml
  CILIUM_CLUSTERMESH_FQDN: "clustermesh-infra.${SECRET_DOMAIN}"
  CILIUM_CLUSTERMESH_LB_IP: "10.25.11.100"
  CILIUM_CLUSTERMESH_APPS_FQDN: "clustermesh-apps.${SECRET_DOMAIN}"  # Peer cluster FQDN
  ```

- [ ] Update apps cluster-settings with DNS variables:
  ```yaml
  # kubernetes/clusters/apps/cluster-settings.yaml
  CILIUM_CLUSTERMESH_FQDN: "clustermesh-apps.${SECRET_DOMAIN}"
  CILIUM_CLUSTERMESH_LB_IP: "10.25.11.120"
  CILIUM_CLUSTERMESH_INFRA_FQDN: "clustermesh-infra.${SECRET_DOMAIN}"  # Peer cluster FQDN
  ```

---

### T5: Update Cilium ClusterMesh Configuration (If Needed)

- [ ] Verify Cilium HelmRelease uses LoadBalancer with static IP annotation:
  ```bash
  grep -A 10 "clustermesh:" kubernetes/infrastructure/networking/cilium/core/helmrelease.yaml | grep -A 3 "service:"
  ```

- [ ] If not configured, update to use static LoadBalancer IP:
  ```yaml
  # In kubernetes/infrastructure/networking/cilium/core/helmrelease.yaml
  clustermesh:
    useAPIServer: true
    apiserver:
      service:
        type: LoadBalancer
        annotations:
          io.cilium/lb-ipam-ips: ${CILIUM_CLUSTERMESH_LB_IP}
      replicas: 3
  ```

---

### T6: Local Validation (NO Cluster Access)

- [ ] Validate manifest syntax (if DNSEndpoint created):
  ```bash
  kubectl --dry-run=client -f kubernetes/infrastructure/networking/cilium/clustermesh/
  ```

- [ ] Validate with kustomize:
  ```bash
  kustomize build kubernetes/infrastructure/networking/cilium/clustermesh
  ```

- [ ] Validate Flux builds for both clusters:
  ```bash
  # Infra cluster - verify FQDN and IP substitution
  flux build kustomization cluster-infra-infrastructure --path ./kubernetes/infrastructure | \
    yq 'select(.kind == "DNSEndpoint" and .metadata.name == "clustermesh-apiserver") | .spec.endpoints[0]'
  # Expected: dnsName: clustermesh-infra.<domain>, targets: [10.25.11.100]

  # Apps cluster - verify FQDN and IP substitution
  flux build kustomization cluster-apps-infrastructure --path ./kubernetes/infrastructure | \
    yq 'select(.kind == "DNSEndpoint" and .metadata.name == "clustermesh-apiserver") | .spec.endpoints[0]'
  # Expected: dnsName: clustermesh-apps.<domain>, targets: [10.25.11.120]
  ```

- [ ] Verify ClusterMesh LoadBalancer service configuration:
  ```bash
  flux build kustomization cluster-infra-infrastructure --path ./kubernetes/infrastructure | \
    yq 'select(.kind == "HelmRelease" and .metadata.name == "cilium") | .spec.values.clustermesh.apiserver.service'
  # Expected: type: LoadBalancer, annotations with static IP
  ```

---

### T7: Create Manual DNS Record Documentation (If NOT Using ExternalDNS)

**Note**: If using ExternalDNS automation (T3), skip this step.

- [ ] Create DNS record creation guide:
  ```markdown
  # Manual DNS Record Creation for ClusterMesh

  ## Cloudflare Web UI Method

  1. Log in to Cloudflare dashboard
  2. Select domain: ${SECRET_DOMAIN}
  3. Navigate to DNS > Records
  4. Create A record for infra cluster:
     - Type: A
     - Name: clustermesh-infra
     - Content: 10.25.11.100
     - TTL: Auto (or 300)
     - Proxy status: DNS only (not proxied)
  5. Create A record for apps cluster:
     - Type: A
     - Name: clustermesh-apps
     - Content: 10.25.11.120
     - TTL: Auto (or 300)
     - Proxy status: DNS only (not proxied)

  ## Cloudflare API Method (via Terraform/OpenTofu)

  ```hcl
  resource "cloudflare_record" "clustermesh_infra" {
    zone_id = var.cloudflare_zone_id
    name    = "clustermesh-infra"
    value   = "10.25.11.100"
    type    = "A"
    ttl     = 300
    proxied = false
  }

  resource "cloudflare_record" "clustermesh_apps" {
    zone_id = var.cloudflare_zone_id
    name    = "clustermesh-apps"
    value   = "10.25.11.120"
    type    = "A"
    ttl     = 300
    proxied = false
  }
  ```

  ## Verification (Story 45)

  After DNS records are created, verify from both clusters:
  ```bash
  dig +short clustermesh-infra.${SECRET_DOMAIN}  # Expected: 10.25.11.100
  dig +short clustermesh-apps.${SECRET_DOMAIN}   # Expected: 10.25.11.120
  ```
  ```

---

### T8: Commit Configuration to Git

- [ ] Commit and push:
  ```bash
  git add kubernetes/infrastructure/networking/cilium/clustermesh/
  git add kubernetes/clusters/infra/cluster-settings.yaml
  git add kubernetes/clusters/apps/cluster-settings.yaml
  git commit -m "feat(networking): add ClusterMesh DNS configuration

  - Define DNS record requirements for ClusterMesh API servers
  - Configure cluster-specific FQDNs (clustermesh-infra, clustermesh-apps)
  - Set static LoadBalancer IPs for ClusterMesh API servers
  - Create DNSEndpoint manifests for ExternalDNS automation (optional)
  - Update cluster-settings with FQDN and peer discovery variables

  Part of Story 13 (v3.0 manifests-first approach)
  DNS deployment deferred to Story 45 (VALIDATE-NETWORKING)"
  git push origin main
  ```

---

### Runtime Validation (MOVED TO STORY 45)

The following validation happens in **Story 45 (VALIDATE-NETWORKING)** after cluster bootstrap:

```bash
# Verify ClusterMesh LoadBalancer services
kubectl --context infra -n kube-system get svc clustermesh-apiserver -o wide
kubectl --context apps -n kube-system get svc clustermesh-apiserver -o wide
# Expected: LoadBalancer IPs assigned (10.25.11.100 for infra, 10.25.11.120 for apps)

# Verify LoadBalancer IPs match cluster-settings
kubectl --context infra get configmap cluster-settings -n flux-system -o jsonpath='{.data.CILIUM_CLUSTERMESH_LB_IP}'
# Expected: 10.25.11.100

kubectl --context apps get configmap cluster-settings -n flux-system -o jsonpath='{.data.CILIUM_CLUSTERMESH_LB_IP}'
# Expected: 10.25.11.120

# If using ExternalDNS, verify DNSEndpoint created
kubectl --context infra -n kube-system get dnsendpoint clustermesh-apiserver
kubectl --context apps -n kube-system get dnsendpoint clustermesh-apiserver

# If using ExternalDNS, check ExternalDNS logs for DNS record creation
kubectl --context infra -n kube-system logs -l app.kubernetes.io/name=external-dns --tail=50 | grep clustermesh
# Expected: "CREATE" or "UPDATE" log entries for clustermesh DNS records

# Verify DNS resolution from external host (outside cluster)
dig +short clustermesh-infra.${SECRET_DOMAIN}
# Expected: 10.25.11.100

dig +short clustermesh-apps.${SECRET_DOMAIN}
# Expected: 10.25.11.120

# Verify DNS resolution from within clusters
kubectl --context infra run dns-test --image=busybox:latest --rm -it --restart=Never -- \
  nslookup clustermesh-apps.${SECRET_DOMAIN}
# Expected: 10.25.11.120

kubectl --context apps run dns-test --image=busybox:latest --rm -it --restart=Never -- \
  nslookup clustermesh-infra.${SECRET_DOMAIN}
# Expected: 10.25.11.100

# Verify ClusterMesh can reach peer via FQDN
kubectl --context infra -n kube-system exec ds/cilium -- \
  cilium-health status --probe clustermesh-apps.${SECRET_DOMAIN}:443
# Expected: Reachable

kubectl --context apps -n kube-system exec ds/cilium -- \
  cilium-health status --probe clustermesh-infra.${SECRET_DOMAIN}:443
# Expected: Reachable

# Verify ClusterMesh status shows FQDN-based connectivity
cilium --context infra clustermesh status --verbose
# Expected: Shows peer as clustermesh-apps.${SECRET_DOMAIN}

cilium --context apps clustermesh status --verbose
# Expected: Shows peer as clustermesh-infra.${SECRET_DOMAIN}

# Test DNS propagation timing
for i in {1..10}; do
  echo "Test $i: $(dig +short clustermesh-infra.${SECRET_DOMAIN})"
  sleep 1
done
# Expected: Consistent IP responses (DNS cache working)

# Verify DNS TTL settings
dig clustermesh-infra.${SECRET_DOMAIN} | grep -E "^clustermesh-infra"
# Expected: TTL 300 (5 minutes)

# If manual DNS records were created, verify via Cloudflare API
curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${CLOUDFLARE_ZONE_ID}/dns_records?name=clustermesh-infra.${SECRET_DOMAIN}" \
  -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
  -H "Content-Type: application/json" | jq '.result[0]'
# Expected: Record with correct IP and TTL

# Verify LoadBalancer IP pool hygiene
kubectl --context infra get ippools.cilium.io -o yaml | grep -A 10 "lb-ippool-infra"
# Verify 10.25.11.100 is within the pool range

kubectl --context apps get ippools.cilium.io -o yaml | grep -A 10 "lb-ippool-apps"
# Verify 10.25.11.120 is within the pool range
```

---

## Definition of Done

**DNS Configuration Creation Complete (This Story):**
- [ ] DNS record requirements documented (FQDNs, IPs, TTLs)
- [ ] DNSEndpoint manifests created (if using ExternalDNS automation) OR manual DNS creation guide documented
- [ ] Cluster-settings updated with:
  - [ ] ClusterMesh FQDNs for each cluster
  - [ ] ClusterMesh LoadBalancer IPs for each cluster
  - [ ] Peer cluster FQDNs for discovery
- [ ] Cilium HelmRelease configured with static LoadBalancer IP annotations
- [ ] Local validation passes:
  - [ ] `kubectl --dry-run=client` succeeds (if DNSEndpoint created)
  - [ ] `kustomize build` succeeds
  - [ ] `flux build` shows correct FQDN and IP substitution for both clusters
- [ ] Configuration committed to git
- [ ] Story 45 can proceed with DNS deployment and validation

**NOT Part of DoD (Moved to Story 45):**
- ❌ DNS records resolvable from both clusters
- ❌ `dig` commands return correct IPs
- ❌ ClusterMesh Connected status via FQDN
- ❌ LoadBalancer IPs assigned from correct pools
- ❌ DNS propagation verified
- ❌ FQDN-based peer health checks working

---

## Design Notes

### DNS-Based ClusterMesh Discovery

Using FQDNs for ClusterMesh API server discovery provides several benefits:
- **IP Rotation**: Easier to change IPs without updating Cilium configuration
- **Consistency**: Single source of truth in DNS
- **Resilience**: DNS-based discovery is more robust than hardcoded IPs
- **Multi-Region**: Enables future geo-distributed ClusterMesh deployments

### LoadBalancer IP Allocation

ClusterMesh API server LoadBalancer IPs are allocated from cluster-specific IPAM pools:
- **Infra cluster**: 10.25.11.100 (from pool 10.25.11.100-119)
- **Apps cluster**: 10.25.11.120 (from pool 10.25.11.120-139)
- **Static assignment**: Using `io.cilium/lb-ipam-ips` annotation for deterministic IPs

### DNS Implementation Options

**Option 1: ExternalDNS Automation (Recommended)**
- Create DNSEndpoint manifests in this story
- ExternalDNS automatically creates/updates DNS records
- Deployed in Story 45
- Pros: Fully automated, GitOps-native
- Cons: Requires ExternalDNS operator

**Option 2: Manual DNS Management**
- Document DNS record requirements in this story
- Manually create records via Cloudflare UI/API/Terraform
- Verify in Story 45
- Pros: Simple, no additional operators
- Cons: Manual process, not GitOps-native

### Security Considerations

- **DNS Only**: ClusterMesh DNS records should use "DNS only" mode (not Cloudflare proxied)
- **Private IPs**: LoadBalancer IPs are on private network (10.25.11.0/24)
- **Split-Horizon DNS**: Internal and external DNS may differ (Story 08)
- **TTL**: Low TTL (300s) enables faster failover/rotation

---

## Change Log

| Date       | Version | Description                          | Author  |
|------------|---------|--------------------------------------|---------|
| 2025-10-26 | 3.0     | **v3.0 Refinement**: Updated header, story, scope, AC, dependencies, tasks, DoD for manifests-first approach. Separated DNS configuration creation from deployment (moved to Story 45). Tasks restructured to T1-T8 with options for ExternalDNS automation or manual DNS management. Added comprehensive DNS validation in runtime section. Added design notes for DNS-based discovery and implementation options. | Platform Engineering |
| 2025-10-22 | 1.0     | Initial draft | Platform Engineering |
