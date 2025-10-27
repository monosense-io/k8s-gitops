# 09 — STORY-NET-CILIUM-BGP — Create Cilium BGP Control Plane Manifests

Sequence: 09/50 | Prev: STORY-DNS-EXTERNALDNS-CF-BIND-TUNNEL.md | Next: STORY-NET-CILIUM-BGP-CP-IMPLEMENT.md
Sprint: 4 | Lane: Networking
Global Sequence: 09/50

Status: Draft (v3.0 Refinement)
Owner: Platform Engineering
Date: 2025-10-26 (v3.0 Refinement)
Links: docs/architecture.md §9; kubernetes/infrastructure/networking/cilium/bgp/

---

## Story

As a platform engineer, I want to **create Cilium BGP Control Plane manifests** for advertising LoadBalancer Service IPs to the upstream router via BGP, so that when deployed in Story 45, clusters automatically publish LoadBalancer VIPs (ClusterMesh, Gateway) to the network infrastructure with ECMP and proper pool isolation.

This story creates the declarative Cilium BGP configuration manifests (CiliumBGPPeerConfig, CiliumBGPClusterConfig, CiliumBGPAdvertisement). Actual deployment and BGP session validation happen in Story 45 (VALIDATE-NETWORKING).

## Why / Outcome

- Create Cilium BGP Control Plane manifests for northbound routing
- Configure BGP peering with upstream router using cluster-specific ASNs
- Enable automatic LoadBalancer IP advertisement from IPAM pools
- Support ECMP for redundancy across cluster nodes
- Foundation for external access to ClusterMesh and Gateway services

## Scope

**This Story (Manifest Creation):**
- Create Cilium BGP manifests in `kubernetes/infrastructure/networking/cilium/bgp/cplane/`
- Create CiliumBGPPeerConfig for session parameters (timers, graceful restart)
- Create CiliumBGPClusterConfig for peering configuration (ASNs, peer address)
- Create CiliumBGPAdvertisement for LoadBalancer IP advertisements
- Create Kustomization for BGP resources
- Update cluster-settings with BGP variables (if needed)
- Local validation (flux build, kubectl dry-run)

**Deferred to Story 45 (Deployment & Validation):**
- Deploying BGP configuration to clusters
- Verifying BGP sessions Established with router
- Testing LoadBalancer IP advertisement and reachability
- Validating ECMP routing paths
- Verifying pool isolation (infra vs apps)

---

## Acceptance Criteria

**Manifest Creation (This Story):**

1. **CiliumBGPPeerConfig Manifest Created:**
   - `kubernetes/infrastructure/networking/cilium/bgp/cplane/bgp-peer-config.yaml` exists
   - Session timers: keepAlive=3s, holdTime=9s
   - Graceful restart enabled
   - Families: ipv4-unicast
   - Multipath (ECMP) enabled

2. **CiliumBGPClusterConfig Manifest Created:**
   - `kubernetes/infrastructure/networking/cilium/bgp/cplane/bgp-cluster-config.yaml` exists
   - Local ASN configured via `${CILIUM_BGP_LOCAL_ASN}`
   - Peer ASN configured via `${CILIUM_BGP_PEER_ASN}`
   - Peer address configured via `${CILIUM_BGP_PEER_ADDRESS}`
   - Node selector: all nodes (or control-plane only if needed)
   - References bgp-peer-config

3. **CiliumBGPAdvertisement Manifest Created:**
   - `kubernetes/infrastructure/networking/cilium/bgp/cplane/bgp-advertisements.yaml` exists
   - Advertise LoadBalancer IPs: enabled
   - Advertise PodCIDRs: disabled (default)

4. **Kustomization Created:**
   - `kubernetes/infrastructure/networking/cilium/bgp/ks.yaml` exists
   - References all BGP manifests
   - Includes dependency on cilium-ipam
   - `kubernetes/infrastructure/networking/cilium/bgp/cplane/kustomization.yaml` glue file exists

5. **Cluster Settings Alignment:**
   - Cluster-settings include BGP variables:
     - Infra: `CILIUM_BGP_LOCAL_ASN: "64512"`, `CILIUM_BGP_PEER_ASN: "64501"`, `CILIUM_BGP_PEER_ADDRESS: "10.25.11.1"`
     - Apps: `CILIUM_BGP_LOCAL_ASN: "64513"`, `CILIUM_BGP_PEER_ASN: "64501"`, `CILIUM_BGP_PEER_ADDRESS: "10.25.11.1"`

6. **Local Validation Passes:**
   - `flux build kustomization cluster-infra-infrastructure --path ./kubernetes/infrastructure` succeeds
   - `flux build kustomization cluster-apps-infrastructure --path ./kubernetes/infrastructure` succeeds
   - Output shows correct ASN and peer address substitution for each cluster
   - `kubectl --dry-run=client` validates manifests

**Deferred to Story 45 (Deployment & Validation):**
- ❌ BGP sessions Established with router
- ❌ LoadBalancer IPs advertised to upstream router
- ❌ Infra cluster advertises pool 10.25.11.100-119
- ❌ Apps cluster advertises pool 10.25.11.120-139
- ❌ ECMP routing paths verified
- ❌ Reachability tested from upstream network
- ❌ Pool isolation verified (no cross-cluster advertisements)

---

## Dependencies

**Prerequisites (v3.0):**
- Story 01 (STORY-NET-CILIUM-CORE-GITOPS) complete (Cilium core manifests with `bgpControlPlane.enabled: true`)
- Story 02 (STORY-NET-CILIUM-IPAM) complete (IPAM pools created with correct ranges)
- Cluster-settings ConfigMaps with `CILIUM_BGP_LOCAL_ASN`, `CILIUM_BGP_PEER_ASN`, `CILIUM_BGP_PEER_ADDRESS`
- Tools: kubectl (for dry-run), flux CLI, yq

**NOT Required (v3.0):**
- ❌ Cluster access (validation is local-only)
- ❌ BGP router configured (deployment in Story 45)
- ❌ Running clusters (Story 45 handles deployment)

---

## Implementation Tasks

### T1: Verify Prerequisites (Local Validation Only)

- [ ] Verify Story 01 complete (Cilium core manifests with BGP enabled):
  ```bash
  grep -i "bgpControlPlane" kubernetes/infrastructure/networking/cilium/core/helmrelease.yaml
  # Confirm: bgpControlPlane.enabled: true
  ```

- [ ] Verify Story 02 complete (IPAM pool manifests created):
  ```bash
  ls -la kubernetes/infrastructure/networking/cilium/ipam/lb-ippool-*.yaml
  ```

- [ ] Verify cluster-settings have BGP variables:
  ```bash
  grep -E '(CILIUM_BGP_LOCAL_ASN|CILIUM_BGP_PEER_ASN|CILIUM_BGP_PEER_ADDRESS)' kubernetes/clusters/infra/cluster-settings.yaml
  grep -E '(CILIUM_BGP_LOCAL_ASN|CILIUM_BGP_PEER_ASN|CILIUM_BGP_PEER_ADDRESS)' kubernetes/clusters/apps/cluster-settings.yaml
  ```

---

### T2: Create Cilium BGP Control Plane Manifests

- [ ] Create directory:
  ```bash
  mkdir -p kubernetes/infrastructure/networking/cilium/bgp/cplane
  ```

- [ ] Create `bgp-peer-config.yaml`:
  ```yaml
  ---
  apiVersion: cilium.io/v2alpha1
  kind: CiliumBGPPeerConfig
  metadata:
    name: bgp-peer-config
  spec:
    timers:
      holdTimeSeconds: 9
      keepAliveTimeSeconds: 3
    gracefulRestart:
      enabled: true
      restartTimeSeconds: 120
    families:
      - afi: ipv4
        safi: unicast
        advertisements:
          matchLabels:
            advertise: bgp
    ebgpMultihop: 1
  ```

- [ ] Create `bgp-cluster-config.yaml`:
  ```yaml
  ---
  apiVersion: cilium.io/v2alpha1
  kind: CiliumBGPClusterConfig
  metadata:
    name: bgp-cluster-config
  spec:
    nodeSelector:
      matchLabels: {}  # All nodes
    bgpInstances:
      - name: instance-${CILIUM_BGP_LOCAL_ASN}
        localASN: ${CILIUM_BGP_LOCAL_ASN}
        peers:
          - name: peer-${CILIUM_BGP_PEER_ASN}
            peerAddress: ${CILIUM_BGP_PEER_ADDRESS}
            peerASN: ${CILIUM_BGP_PEER_ASN}
            peerConfigRef:
              name: bgp-peer-config
  ```

- [ ] Create `bgp-advertisements.yaml`:
  ```yaml
  ---
  apiVersion: cilium.io/v2alpha1
  kind: CiliumBGPAdvertisement
  metadata:
    name: bgp-loadbalancer-ips
    labels:
      advertise: bgp
  spec:
    advertisements:
      - advertisementType: Service
        service:
          addresses:
            - LoadBalancerIP
        selector:
          matchExpressions:
            - key: somekey
              operator: NotIn
              values:
                - never-used-value
  ```

- [ ] Create `kustomization.yaml` (glue file):
  ```yaml
  ---
  apiVersion: kustomize.config.k8s.io/v1beta1
  kind: Kustomization
  resources:
    - bgp-peer-config.yaml
    - bgp-cluster-config.yaml
    - bgp-advertisements.yaml
  ```

---

### T3: Create Flux Kustomization

- [ ] Create `ks.yaml`:
  ```yaml
  ---
  apiVersion: kustomize.toolkit.fluxcd.io/v1
  kind: Kustomization
  metadata:
    name: cilium-bgp
    namespace: flux-system
  spec:
    interval: 10m
    retryInterval: 1m
    timeout: 5m
    sourceRef:
      kind: GitRepository
      name: flux-system
    path: ./kubernetes/infrastructure/networking/cilium/bgp/cplane
    prune: true
    wait: true
    dependsOn:
      - name: cilium-ipam
    postBuild:
      substitute: {}
      substituteFrom:
        - kind: ConfigMap
          name: cluster-settings
    healthChecks:
      - apiVersion: cilium.io/v2alpha1
        kind: CiliumBGPClusterConfig
        name: bgp-cluster-config
        namespace: ""
  ```

---

### T4: Local Validation (NO Cluster Access)

- [ ] Validate manifest syntax:
  ```bash
  kubectl --dry-run=client -f kubernetes/infrastructure/networking/cilium/bgp/cplane/
  ```

- [ ] Validate with kustomize:
  ```bash
  kustomize build kubernetes/infrastructure/networking/cilium/bgp/cplane
  ```

- [ ] Validate Flux builds for both clusters:
  ```bash
  # Infra cluster (should substitute ASN 64512)
  flux build kustomization cluster-infra-infrastructure --path ./kubernetes/infrastructure | \
    yq 'select(.kind == "CiliumBGPClusterConfig") | .spec.bgpInstances[0].localASN'
  # Expected: 64512

  # Apps cluster (should substitute ASN 64513)
  flux build kustomization cluster-apps-infrastructure --path ./kubernetes/infrastructure | \
    yq 'select(.kind == "CiliumBGPClusterConfig") | .spec.bgpInstances[0].localASN'
  # Expected: 64513
  ```

- [ ] Verify peer address substitution:
  ```bash
  flux build kustomization cluster-infra-infrastructure --path ./kubernetes/infrastructure | \
    yq 'select(.kind == "CiliumBGPClusterConfig") | .spec.bgpInstances[0].peers[0].peerAddress'
  # Expected: 10.25.11.1
  ```

---

### T5: Update Infrastructure Kustomization

- [ ] Update `kubernetes/infrastructure/networking/cilium/kustomization.yaml`:
  ```yaml
  resources:
    - core/ks.yaml
    - ipam/ks.yaml
    - gateway/ks.yaml
    - bgp/ks.yaml  # ADD THIS LINE
  ```

---

### T6: Update Cluster Settings (If Needed)

- [ ] Verify infra cluster-settings have BGP variables:
  ```yaml
  # kubernetes/clusters/infra/cluster-settings.yaml
  CILIUM_BGP_LOCAL_ASN: "64512"
  CILIUM_BGP_PEER_ASN: "64501"
  CILIUM_BGP_PEER_ADDRESS: "10.25.11.1"
  ```

- [ ] Verify apps cluster-settings have BGP variables:
  ```yaml
  # kubernetes/clusters/apps/cluster-settings.yaml
  CILIUM_BGP_LOCAL_ASN: "64513"
  CILIUM_BGP_PEER_ASN: "64501"
  CILIUM_BGP_PEER_ADDRESS: "10.25.11.1"
  ```

- [ ] If variables missing, add them to cluster-settings ConfigMaps

---

### T7: Commit Manifests to Git

- [ ] Commit and push:
  ```bash
  git add kubernetes/infrastructure/networking/cilium/bgp/
  git commit -m "feat(networking): add Cilium BGP Control Plane manifests

  - Create CiliumBGPPeerConfig with session timers and graceful restart
  - Create CiliumBGPClusterConfig with cluster-specific ASNs
  - Create CiliumBGPAdvertisement for LoadBalancer IP advertisements
  - Configure ECMP multipath for redundancy
  - Enable automatic advertisement of IPAM pool IPs

  Part of Story 09 (v3.0 manifests-first approach)
  Deployment deferred to Story 45 (VALIDATE-NETWORKING)"
  git push origin main
  ```

---

### Runtime Validation (MOVED TO STORY 45)

The following validation happens in **Story 45 (VALIDATE-NETWORKING)** after cluster bootstrap:

```bash
# Deploy BGP configuration (Story 45 only)
flux reconcile kustomization cilium-bgp --with-source

# Verify BGP sessions
cilium bgp peers
# Expected: Established sessions to 10.25.11.1

# Check advertised routes
cilium bgp routes advertised ipv4 unicast
# Expected:
# - Infra: 10.25.11.100/32, 10.25.11.110/32
# - Apps: 10.25.11.120/32, 10.25.11.121/32

# Router-side verification (on BGP router 10.25.11.1)
show bgp summary
# Expected:
# - Neighbor 64512 (infra nodes) - Established
# - Neighbor 64513 (apps nodes) - Established

show ip route bgp
# Expected routes:
# - 10.25.11.100-119 via infra cluster nodes (ECMP)
# - 10.25.11.120-139 via apps cluster nodes (ECMP)

show ip bgp 10.25.11.110
show ip bgp 10.25.11.121
# Verify specific IPs are advertised from correct cluster with ECMP paths

# Reachability test from upstream network
ping 10.25.11.100  # Infra ClusterMesh
ping 10.25.11.110  # Infra Gateway
ping 10.25.11.120  # Apps ClusterMesh
ping 10.25.11.121  # Apps Gateway

curl -v http://10.25.11.110  # Test Gateway HTTP
curl -v http://10.25.11.121  # Test Gateway HTTP

# Verify pool isolation
# Infra nodes should ONLY advertise 10.25.11.100-119
# Apps nodes should ONLY advertise 10.25.11.120-139
```

---

## Definition of Done

**Manifest Creation Complete (This Story):**
- [ ] Directory created: `kubernetes/infrastructure/networking/cilium/bgp/cplane/`
- [ ] CiliumBGPPeerConfig manifest created with session timers and graceful restart
- [ ] CiliumBGPClusterConfig manifest created with cluster-specific ASNs
- [ ] CiliumBGPAdvertisement manifest created for LoadBalancer IPs
- [ ] Kustomization glue file created
- [ ] Flux Kustomization created with correct dependencies
- [ ] Cluster-settings have BGP variables (ASNs, peer address)
- [ ] Local validation passes:
  - [ ] `kubectl --dry-run=client` succeeds
  - [ ] `kustomize build` succeeds
  - [ ] `flux build` shows correct ASN and peer address substitution for both clusters
- [ ] Infrastructure kustomization updated to include BGP
- [ ] Manifests committed to git
- [ ] Story 45 can proceed with deployment

**NOT Part of DoD (Moved to Story 45):**
- ❌ BGP sessions Established with router
- ❌ LoadBalancer IPs advertised to upstream router
- ❌ Infra cluster advertises pool 10.25.11.100-119
- ❌ Apps cluster advertises pool 10.25.11.120-139
- ❌ ECMP routing paths verified
- ❌ Reachability tested from upstream network
- ❌ Pool isolation verified (no cross-cluster advertisements)

---

## Change Log

| Date       | Version | Description                          | Author  |
|------------|---------|--------------------------------------|---------|
| 2025-10-26 | 3.0     | **v3.0 Refinement**: Updated header, story, scope, AC, dependencies, tasks, DoD for manifests-first approach. Separated manifest creation from deployment (moved to Story 45). Tasks simplified to T1-T7 focusing on local validation only. Added comprehensive BGP session and routing validation in runtime validation section. | Platform Engineering |
| 2025-10-21 | 1.0     | Initial draft | Platform Engineering |
