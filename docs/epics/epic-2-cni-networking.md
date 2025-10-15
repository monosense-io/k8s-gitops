# EPIC-2: CNI & Networking
**Goal:** Deploy Cilium on both clusters with ClusterMesh
**Status:** ✅ 75% Complete (configs done, External-DNS missing)

## Story 2.1: Deploy Cilium with BGP, Gateway API, and ClusterMesh ✅
**Priority:** P0 | **Points:** 5 | **Days:** 1 | **Status:** ✅ CONFIG COMPLETE

**Acceptance Criteria:**
- [x] Cilium base HelmRelease created in `bases/cilium/`
- [x] Cilium infrastructure configs created in `infrastructure/networking/cilium/`
- [x] BGP control plane configured (`CiliumBGPPeeringPolicy`)
- [x] Gateway API (Envoy) enabled
- [x] ClusterMesh configuration prepared
- [x] Cluster variables defined in `clusters/infra/infrastructure.yaml`
- [ ] Cilium deployed and all infra nodes transition to Ready state
- [ ] Cilium status shows healthy: `cilium status --wait`
- [ ] BGP peering with upstream router verified
- [ ] LoadBalancer IP pool working (10.25.11.100-149)

**Tasks:**
- **Files already created** (verify they exist):
  - `kubernetes/bases/cilium/helmrelease.yaml`
  - `kubernetes/infrastructure/networking/cilium/kustomization.yaml`
  - `kubernetes/infrastructure/networking/cilium/bgp/bgppeeringpolicy.yaml`
  - `kubernetes/infrastructure/networking/cilium/clustermesh/externalsecret.yaml`
  - `kubernetes/infrastructure/networking/cilium/gateway/gatewayclass.yaml`
  - `clusters/infra/infrastructure.yaml` (with Cilium variables)

- **Deploy via Flux** (after Flux bootstrap):
  ```bash
  flux reconcile kustomization cluster-infra-infrastructure --context infra
  ```

- **Or deploy manually for testing:**
  ```bash
  kubectl --context infra apply -k kubernetes/infrastructure/networking/cilium/
  ```

- **Verify deployment:**
  ```bash
  kubectl --context infra rollout status -n kube-system ds/cilium
  cilium status --context infra
  kubectl --context infra get nodes  # Should now show Ready
  ```

- **Test LoadBalancer:**
  ```bash
  kubectl --context infra create service loadbalancer test-lb --tcp=80:80
  kubectl --context infra get svc test-lb  # Should get IP from pool
  kubectl --context infra delete svc test-lb
  ```

**Files Created:**
- ✅ `kubernetes/bases/cilium/helmrelease.yaml`
- ✅ `kubernetes/infrastructure/networking/cilium/kustomization.yaml`
- ✅ `kubernetes/infrastructure/networking/cilium/bgp/bgppeeringpolicy.yaml`
- ✅ `kubernetes/infrastructure/networking/cilium/clustermesh/externalsecret.yaml`
- ✅ `kubernetes/infrastructure/networking/cilium/gateway/gatewayclass.yaml`

**Variables Used** (from `clusters/infra/infrastructure.yaml`):
- `CLUSTER_ID: "1"`
- `POD_CIDR: "10.244.0.0/16"`
- `SERVICE_CIDR: "10.245.0.0/16"`
- `CLUSTERMESH_IP: "10.25.11.100"`
- `CILIUM_BGP_LOCAL_ASN: "64512"`
- `CILIUM_BGP_PEER_ASN: "64501"`
- `CILIUM_BGP_PEER_ADDRESS: "10.25.11.1/32"`
- `CILIUM_GATEWAY_LB_IP: "10.25.11.120"`

---

## Story 2.2: Configure Apps Cluster Cilium Variables ✅
**Priority:** P0 | **Points:** 1 | **Days:** 0.5 | **Status:** ✅ COMPLETE

**Acceptance Criteria:**
- [x] `clusters/apps/infrastructure.yaml` created with apps-specific variables
- [x] CLUSTER_ID set to "2"
- [x] POD_CIDR set to non-overlapping range (10.246.0.0/16)
- [x] SERVICE_CIDR set to non-overlapping range (10.247.0.0/16)
- [x] LoadBalancer IP pool variables set (10.25.11.150-199)
- [x] BGP ASN set to different value (64513)
- [x] CLUSTERMESH_IP set to apps pool (10.25.11.150)
- [ ] Apps cluster deployed and nodes transition to Ready

**Tasks:**
- Verify `clusters/apps/infrastructure.yaml` exists and contains:
  ```yaml
  postBuild:
    substitute:
      CLUSTER: apps
      CLUSTER_ID: "2"
      POD_CIDR: '["10.246.0.0/16"]'
      SERVICE_CIDR: '["10.247.0.0/16"]'
      CLUSTERMESH_IP: "10.25.11.150"
      CILIUM_BGP_LOCAL_ASN: "64513"
      # ... more variables
  ```

- **Deploy via Flux** (after Flux bootstrap):
  ```bash
  flux reconcile kustomization cluster-apps-infrastructure --context apps
  ```

- **Verify:**
  ```bash
  kubectl --context apps get nodes  # Should show Ready
  cilium status --context apps
  ```

**Files Modified:**
- ✅ `clusters/apps/infrastructure.yaml` (variables configured)

**Note:** No separate Cilium configs needed! Same shared base deploys to both clusters with different variables.

---

## Story 2.3: Enable and Configure Cilium ClusterMesh ✅
**Priority:** P0 | **Points:** 3 | **Days:** 1.5 | **Status:** ✅ CONFIG READY

**Acceptance Criteria:**
- [x] ClusterMesh externalsecret configured in `infrastructure/networking/cilium/clustermesh/`
- [ ] ClusterMesh enabled on infra cluster
- [ ] ClusterMesh enabled on apps cluster
- [ ] Clusters connected via ClusterMesh
- [ ] Cross-cluster connectivity verified
- [ ] Global services can be created
- [ ] Network policies tested

**Tasks:**
- **ClusterMesh is configured in Helm values** - verify:
  - `infrastructure/networking/cilium/clustermesh/externalsecret.yaml` exists
  - ClusterMesh enabled in `bases/cilium/helmrelease.yaml`

- **Enable ClusterMesh** (after both clusters have Cilium):
  ```bash
  cilium clustermesh enable --context infra
  cilium clustermesh enable --context apps
  ```

- **Connect clusters:**
  ```bash
  cilium clustermesh connect --context infra --destination-context apps
  ```

- **Verify status:**
  ```bash
  cilium clustermesh status --context infra
  cilium clustermesh status --context apps
  ```

- **Test cross-cluster connectivity:**
  ```bash
  # Deploy test workload on infra
  kubectl --context infra create deployment test --image=nginx
  kubectl --context infra expose deployment test --port=80

  # Mark as global service
  kubectl --context infra annotate service test service.cilium.io/global="true"

  # Deploy test pod on apps cluster
  kubectl --context apps run test-client --image=curlimages/curl -it --rm -- sh
  # Inside pod: curl test.default.svc.clusterset.local
  ```

- **Clean up:**
  ```bash
  kubectl --context infra delete deployment test
  kubectl --context infra delete service test
  ```

**Files Created:**
- ✅ `kubernetes/infrastructure/networking/cilium/clustermesh/externalsecret.yaml`

**ClusterMesh Configuration:**
- Infra ClusterMesh API: `10.25.11.100:2379`
- Apps ClusterMesh API: `10.25.11.150:2379`
- Secrets managed via 1Password ExternalSecret

---

## Story 2.4: Deploy External DNS
**Priority:** P1 | **Points:** 3 | **Days:** 1 | **Status:** ❌ NOT IMPLEMENTED

**Acceptance Criteria:**
- [ ] External DNS base HelmRelease created
- [ ] External DNS infrastructure config created
- [ ] Cloudflare provider configured
- [ ] ExternalSecret for Cloudflare API token created
- [ ] DNS records automatically created for test service
- [ ] Deployed to both clusters (shared base pattern)

**Tasks:**
- Create `kubernetes/bases/external-dns/helmrelease.yaml`
- Create `kubernetes/infrastructure/networking/external-dns/kustomization.yaml`
- Create `kubernetes/infrastructure/networking/external-dns/externalsecret.yaml`
- Update `kubernetes/infrastructure/networking/kustomization.yaml` to include external-dns
- Add variables to `clusters/*/infrastructure.yaml`:
  ```yaml
  SECRET_DOMAIN: "monosense.io"
  EXTERNAL_DNS_CLOUDFLARE_SECRET_PATH: "kubernetes/<cluster>/external-dns/cloudflare"
  ```

- **Deploy via Flux:**
  ```bash
  flux reconcile kustomization cluster-infra-infrastructure
  flux reconcile kustomization cluster-apps-infrastructure
  ```

- **Verify:**
  ```bash
  kubectl --context infra logs -n networking -l app=external-dns
  ```

- **Test:**
  ```bash
  # Create service with external-dns annotation
  kubectl --context infra create service loadbalancer test-dns --tcp=80:80
  kubectl --context infra annotate service test-dns external-dns.alpha.kubernetes.io/hostname=test.monosense.io
  # Verify DNS record created in Cloudflare
  kubectl --context infra delete service test-dns
  ```

**Files to Create:**
- 🔲 `kubernetes/bases/external-dns/helmrelease.yaml`
- 🔲 `kubernetes/infrastructure/networking/external-dns/kustomization.yaml`
- 🔲 `kubernetes/infrastructure/networking/external-dns/externalsecret.yaml`

---

## Story 2.5: Deploy Spegel (Container Image Mirror) ✅
**Priority:** P2 | **Points:** 2 | **Days:** 0.5 | **Status:** ✅ CONFIG COMPLETE

**Acceptance Criteria:**
- [x] Spegel base HelmRelease created
- [x] Spegel infrastructure config created
- [ ] Spegel deployed to both clusters
- [ ] Image mirroring verified

**Tasks:**
- Files already created, verify:
  - ✅ `kubernetes/bases/spegel/helmrelease.yaml`
  - ✅ `kubernetes/infrastructure/networking/spegel/kustomization.yaml`

- **Deploy via Flux** (automatic with infrastructure reconciliation)

- **Verify:**
  ```bash
  kubectl --context infra get pods -n kube-system -l app.kubernetes.io/name=spegel
  ```

**Files Created:**
- ✅ `kubernetes/bases/spegel/helmrelease.yaml`
- ✅ `kubernetes/infrastructure/networking/spegel/kustomization.yaml`

---
