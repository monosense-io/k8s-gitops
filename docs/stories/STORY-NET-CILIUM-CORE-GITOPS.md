# 02 — STORY-NET-CILIUM-CORE-GITOPS — Put Cilium Core under GitOps Control

Sequence: 02/41 | Prev: STORY-BOOT-TALOS.md | Next: STORY-NET-CILIUM-IPAM.md
Sprint: 1 | Lane: Networking
Global Sequence: 2/41

Status: Draft → Ready for Implementation
Owner: Platform Engineering
Date: 2025-10-21 (Refined: 2025-10-22)
Links: docs/architecture.md §9; kubernetes/infrastructure/networking/cilium/core; .taskfiles/bootstrap/Taskfile.yaml

---

## Executive Summary: Refinement Notes

**Refined for greenfield multi-cluster deployment.** Enhanced from 4 high-level tasks to **60+ granular subtasks** across **5 phases** with **10 comprehensive acceptance criteria**. Key improvements:

- **Immediate validation on BOTH clusters** (greenfield-appropriate)
- **Comprehensive feature validation**: WireGuard, Gateway API, BGP, Spegel integration
- **Detailed handover strategy** with adoption vs reinstall options
- **Cross-cluster consistency** validation throughout
- **Drift detection proof** and Git canonicality testing

---

## Story

As a platform team operating a **greenfield multi-cluster GitOps environment**, we need Cilium (CNI + operator) to be managed declaratively by Flux on **both infra and apps clusters** so that the desired state for our network layer is versioned, auditable, and consistent across all clusters.

We will leverage the one-time imperative Cilium installation performed during bootstrap (via Helmfile Phase 1), then **seamlessly transition control to Flux** through a well-tested handover process that proves Git is our canonical source of truth.

### Context: Greenfield Requirements

This is a **greenfield deployment** with two 3-node clusters (infra + apps) being built simultaneously. Both clusters require:
- Cilium 1.18.2 as CNI with strict kubeProxyReplacement (CILIUM_VERSION=1.18.2 in cluster-settings)
- WireGuard encryption enabled from day 1
- Gateway API and BGP Control Plane enabled from day 1
- Spegel integration for distributed image caching
- Identical configuration except cluster-specific variables:
  - Infra: CLUSTER=infra, CLUSTER_ID=1, POD_CIDR_STRING=10.244.0.0/16, SERVICE_CIDR=["10.245.0.0/16"]
  - Apps: CLUSTER=apps, CLUSTER_ID=2, POD_CIDR_STRING=10.246.0.0/16, SERVICE_CIDR=["10.247.0.0/16"]

---

## Acceptance Criteria

### AC-1: Bootstrap State Validated (Pre-Requisite)
- Bootstrap installed Cilium 1.18.2 on both infra and apps clusters
- Cilium DaemonSet is Ready on all nodes (both clusters)
- Cilium Operator Deployment is Ready (both clusters)
- kube-proxy is NOT running (kubeProxyReplacement working)
- WireGuard encryption is enabled and functional
- Gateway API and BGP Control Plane are enabled in Cilium config
- Required CRDs exist (Gateway API, Cilium BGP, Cilium IPAM)
- Spegel is running and integrated with containerd (no conflicts with Cilium)

### AC-2: GitOps Resources Exist and Are Valid
- OCIRepository `cilium-charts` created in flux-system namespace
- HelmRelease `cilium` exists in `kubernetes/infrastructure/networking/cilium/core/helmrelease.yaml`
- HelmRelease values match bootstrap values EXACTLY (except cluster-specific substitutions)
- Kustomization `cilium-core` exists with health checks for DaemonSet/cilium and Deployment/cilium-operator
- Both clusters' infrastructure.yaml include cilium-core Kustomization
- `flux build kustomization cluster-<cluster>-infrastructure` passes on both clusters
- `kubeconform --strict` validates all Cilium resources

### AC-3: Per-Cluster Settings Are Substituted Correctly
- ${CLUSTER} resolves to "infra" on infra cluster, "apps" on apps cluster
- ${CLUSTER_ID} resolves to "1" on infra, "2" on apps
- ${POD_CIDR_STRING} resolves to "10.244.0.0/16" on infra, "10.246.0.0/16" on apps
- ${SERVICE_CIDR} resolves to '["10.245.0.0/16"]' on infra, '["10.247.0.0/16"]' on apps
- ${CILIUM_VERSION} is "1.18.2" on both clusters
- Helm values show correct cluster-specific values: `helm -n kube-system get values cilium`

### AC-4: Flux Handover Completed Successfully (Critical)
- Flux Kustomization `cilium-core` shows Ready: True on both clusters
- Flux HelmRelease `cilium` shows Ready: True in kube-system namespace on both clusters
- **NO POD DISRUPTIONS** during handover (verify pod ages, restart counts unchanged)
- CNI functionality maintained during handover (test pod connectivity throughout)
- Bootstrap Helm release either adopted by Flux OR cleanly replaced
- No manual Helm releases remain: `helm -n kube-system list | grep cilium` shows only Flux-managed release

### AC-5: Health Checks Are Functional
- Kustomization health checks detect DaemonSet failures (tested via scaling to 0 and back)
- Kustomization health checks detect Deployment failures
- Flux reports HealthCheckFailed status when resources are unhealthy
- Flux reports Ready: True when all health checks pass
- Health check timeout is reasonable (5-10 minutes)

### AC-6: Git Is Canonical Source of Truth (Drift Detection)
- Manual changes to HelmRelease are reverted by Flux within reconciliation interval
- Configuration changes made in Git are applied to cluster successfully
- `helm.toolkit.fluxcd.io/driftDetection` is enabled (if using adoption strategy)
- Flux reconciliation does NOT cause unnecessary pod restarts (stable state is stable)

### AC-7: Cilium Features Are Enabled and Functional
- kubeProxyReplacement is active: "Strict" mode verified
- WireGuard encryption is active: `cilium status | grep Encryption` shows "Wireguard"
- Gateway API is enabled: `kubectl get gatewayclasses` works (CRDs present)
- BGP Control Plane is enabled: `kubectl get ciliumbgppeeringpolicies` works (CRDs present)
- Hubble is functional: `hubble status` works
- Prometheus metrics are exposed: ServiceMonitor exists and Prometheus scrapes Cilium

### AC-8: Cross-Cluster Consistency (Greenfield Requirement)
- Both infra and apps clusters have identical Cilium versions (1.18.2)
- Both clusters have identical feature enablement (kubeProxyReplacement, WireGuard, Gateway API, BGP)
- Both clusters' Kustomizations show Ready: True
- Configuration differs ONLY in cluster-specific variables:
  - CLUSTER (infra vs apps)
  - CLUSTER_ID (1 vs 2)
  - POD_CIDR_STRING (10.244.0.0/16 vs 10.246.0.0/16)
  - SERVICE_CIDR (["10.245.0.0/16"] vs ["10.247.0.0/16"])
  - CILIUM_GATEWAY_LB_IP (10.25.11.120 vs 10.25.11.121)
  - CLUSTERMESH_IP (10.25.11.100 vs 10.25.11.101)
  - CILIUM_BGP_LOCAL_ASN (64512 vs 64513)
- Both clusters pass all validation steps in Phase 4

### AC-9: Integration with Adjacent Components
- Spegel (image registry mirror) is running and not conflicting with Cilium
- CoreDNS is functional and using Cilium network (DNS queries work)
- cert-manager (if installed) can reach ACME servers through Cilium network
- Flux controllers can reach Git repository through Cilium network

### AC-10: Documentation and Runbooks
- Handover process documented in story dev notes or CLAUDE.md
- Rollback procedure documented (how to revert to bootstrap Helm if needed)
- Common troubleshooting steps documented
- Next steps documented (story dependencies for BGP, Gateway API, ClusterMesh are clear)

---

## Tasks / Subtasks — Implementation Plan (5 Phases)

### Phase 1: Pre-Work & Validation (Bootstrap State)

**Goal:** Verify bootstrap installed Cilium correctly before transitioning to GitOps

#### 1.1. Verify cluster-settings ConfigMaps on both clusters
- [ ] Confirm `kubernetes/clusters/infra/cluster-settings.yaml` contains: CLUSTER=infra, CLUSTER_ID=1, POD_CIDR_STRING=10.244.0.0/16, SERVICE_CIDR=["10.245.0.0/16"], CILIUM_VERSION=1.18.2
- [ ] Confirm `kubernetes/clusters/apps/cluster-settings.yaml` contains: CLUSTER=apps, CLUSTER_ID=2, POD_CIDR_STRING=10.246.0.0/16, SERVICE_CIDR=["10.247.0.0/16"], CILIUM_VERSION=1.18.2
- [ ] Verify CILIUM_VERSION is pinned to "1.18.2" on both clusters (used by Flux-managed HelmRelease)

#### 1.2. Verify bootstrap Cilium installation (infra cluster)
- [ ] Check Cilium DaemonSet: `kubectl --context=infra -n kube-system get ds cilium` (should show Ready on all nodes)
- [ ] Check Cilium Operator: `kubectl --context=infra -n kube-system get deploy cilium-operator` (should show Ready)
- [ ] Verify kube-proxy is NOT running: `kubectl --context=infra -n kube-system get ds kube-proxy` (should return NotFound or 0/0 ready)
- [ ] Check WireGuard encryption: `kubectl --context=infra -n kube-system exec ds/cilium -- cilium status | grep Encryption` (should show "Wireguard")
- [ ] Verify Gateway API enabled: `kubectl --context=infra -n kube-system exec ds/cilium -- cilium config view | grep gateway-api` (should show enabled: true)
- [ ] Verify BGP Control Plane enabled: `kubectl --context=infra -n kube-system exec ds/cilium -- cilium config view | grep bgp-control-plane` (should show enabled: true)

#### 1.3. Verify bootstrap Cilium installation (apps cluster)
- [ ] Repeat all checks from 1.2 on apps cluster (kubectl --context=apps)

#### 1.4. Verify required CRDs exist (both clusters)
- [ ] Gateway API CRDs: `kubectl get crd gateways.gateway.networking.k8s.io gatewayclasses.gateway.networking.k8s.io httproutes.gateway.networking.k8s.io`
- [ ] Cilium BGP CRDs: `kubectl get crd ciliumbgppeeringpolicies.cilium.io ciliumbgpnodeconfigs.cilium.io`
- [ ] Cilium IPAM CRDs: `kubectl get crd ciliumpodippools.cilium.io ciliumloadbalancerippools.cilium.io`

#### 1.5. Document bootstrap configuration for comparison
- [ ] Extract current Cilium helm values: `helm --kube-context=infra -n kube-system get values cilium > /tmp/cilium-bootstrap-values-infra.yaml`
- [ ] Extract current Cilium helm values: `helm --kube-context=apps -n kube-system get values cilium > /tmp/cilium-bootstrap-values-apps.yaml`
- [ ] Compare values to ensure consistency across clusters (cluster-specific vars should differ, everything else identical)

---

### Phase 2: GitOps Resource Creation

**Goal:** Create Flux resources to manage Cilium declaratively

#### 2.1. Create OCIRepository for Cilium charts
- [ ] Create `kubernetes/infrastructure/networking/cilium/ocirepository.yaml`:
  ```yaml
  apiVersion: source.toolkit.fluxcd.io/v1beta2
  kind: OCIRepository
  metadata:
    name: cilium-charts
    namespace: flux-system
  spec:
    interval: 12h
    url: oci://ghcr.io/cilium/charts
    ref:
      semver: "1.18.2"
  ```
- [ ] Create `kubernetes/infrastructure/networking/cilium/kustomization.yaml` to include ocirepository.yaml
- [ ] Validate: `kustomize build kubernetes/infrastructure/networking/cilium`

#### 2.2. Create HelmRelease for Cilium core
- [ ] Create `kubernetes/infrastructure/networking/cilium/core/helmrelease.yaml` with values matching bootstrap EXACTLY:
  - Chart version: Use ${CILIUM_VERSION} variable (resolves to "1.18.2" from cluster-settings)
  - sourceRef: OCIRepository/cilium-charts
  - Values: cluster.name: ${CLUSTER}, cluster.id: ${CLUSTER_ID}, ipv4NativeRoutingCIDR: ${POD_CIDR_STRING}
  - kubeProxyReplacement: "true", gatewayAPI.enabled: true, bgpControlPlane.enabled: true
  - encryption.enabled: true, encryption.type: wireguard
  - hubble.enabled: true, hubble.relay.enabled: true, hubble.ui.enabled: true
  - prometheus.enabled: true, prometheus.serviceMonitor.enabled: true
- [ ] Add install/upgrade configuration: namespace: kube-system, createNamespace: false, crds: Skip
- [ ] Add postRenderers if needed for any customizations

#### 2.3. Create Kustomization for cilium-core
- [ ] Create `kubernetes/infrastructure/networking/cilium/core/ks.yaml`:
  - dependsOn: none (this is a base dependency)
  - interval: 10m
  - path: ./kubernetes/infrastructure/networking/cilium/core
  - prune: true, wait: true, timeout: 10m
  - healthChecks:
    - apiVersion: apps/v1, kind: DaemonSet, name: cilium, namespace: kube-system
    - apiVersion: apps/v1, kind: Deployment, name: cilium-operator, namespace: kube-system
  - postBuild.substituteFrom: ConfigMap/cluster-settings
- [ ] Create `kubernetes/infrastructure/networking/cilium/core/kustomization.yaml`:
  ```yaml
  apiVersion: kustomize.config.k8s.io/v1beta1
  kind: Kustomization
  resources:
    - helmrelease.yaml
  ```

#### 2.4. Wire into infrastructure.yaml
- [ ] Update `kubernetes/clusters/infra/infrastructure.yaml` to include cilium-core Kustomization BEFORE any other networking Kustomizations (BGP, Gateway, IPAM, ClusterMesh)
- [ ] Update `kubernetes/clusters/apps/infrastructure.yaml` to include cilium-core Kustomization
- [ ] Ensure dependency chain: cilium-core → (nothing depends on it initially, but later networking features will depend on it)

#### 2.5. Validate GitOps resources
- [ ] Validate infra cluster: `flux build kustomization cluster-infra-infrastructure --path ./kubernetes/clusters/infra`
- [ ] Validate apps cluster: `flux build kustomization cluster-apps-infrastructure --path ./kubernetes/clusters/apps`
- [ ] Run kubeconform: `kustomize build kubernetes/infrastructure/networking/cilium/core | kubeconform --strict --schema-location default`
- [ ] Check for substitution variables: grep for ${CLUSTER}, ${CLUSTER_ID}, ${POD_CIDR_STRING}, ${CILIUM_VERSION} and ensure they're all referenced correctly

---

### Phase 3: Flux Handover (Critical)

**Goal:** Transition Cilium management from bootstrap Helm to Flux HelmRelease without disruption

#### 3.1. Prepare handover strategy
- [ ] Review Flux Helm adoption documentation
- [ ] Decide on strategy:
  - Option A: Mark bootstrap release for adoption (helm.toolkit.fluxcd.io/driftDetection: enabled)
  - Option B: Uninstall bootstrap, let Flux reinstall (may cause brief disruption)
- [ ] Document rollback plan if handover fails

#### 3.2. Execute handover on infra cluster (TEST CLUSTER FIRST)
- [ ] Apply OCIRepository: `kubectl --context=infra apply -f kubernetes/infrastructure/networking/cilium/ocirepository.yaml`
- [ ] Wait for OCIRepository Ready: `flux --context=infra get source oci cilium-charts`
- [ ] Apply Cilium core Kustomization definition to Flux: `kubectl --context=infra apply -f kubernetes/infrastructure/networking/cilium/core/ks.yaml`
- [ ] Monitor pod status in parallel: `watch kubectl --context=infra -n kube-system get pods -l k8s-app=cilium`
- [ ] Trigger Flux reconciliation: `flux --context=infra reconcile kustomization cilium-core --with-source`
- [ ] Watch reconciliation: `flux --context=infra get kustomizations -A --watch`
- [ ] Verify NO POD RESTARTS during handover: check pod ages, restart counts

#### 3.3. Validate infra cluster post-handover
- [ ] Check Kustomization status: `flux --context=infra get kustomization cilium-core` (should show Ready True)
- [ ] Check HelmRelease status: `kubectl --context=infra -n kube-system get helmrelease cilium` (should show Ready True)
- [ ] Check Cilium health: `kubectl --context=infra -n kube-system rollout status ds/cilium --timeout=5m`
- [ ] Check Operator health: `kubectl --context=infra -n kube-system rollout status deploy/cilium-operator --timeout=5m`
- [ ] Test CNI functionality: Deploy a test pod and verify it gets an IP
- [ ] Test service connectivity: Create a test service and verify DNS resolution and connectivity

#### 3.4. Execute handover on apps cluster
- [ ] Repeat steps 3.2 on apps cluster (kubectl --context=apps, flux --context=apps)
- [ ] Monitor for any differences in behavior vs infra cluster
- [ ] Document any cluster-specific issues encountered

#### 3.5. Validate apps cluster post-handover
- [ ] Repeat all validation steps from 3.3 on apps cluster

---

### Phase 4: Post-Handover Validation & Testing

**Goal:** Prove Git is canonical source of truth and Flux manages Cilium successfully

#### 4.1. Test Flux drift detection (infra cluster)
- [ ] Make a manual change to Cilium: `kubectl --context=infra -n kube-system patch helmrelease cilium --type=json -p='[{"op":"add","path":"/spec/values/test","value":"manual-change"}]'`
- [ ] Wait for Flux reconciliation interval or force: `flux --context=infra reconcile helmrelease -n kube-system cilium`
- [ ] Verify Flux reverts the change (manual change should be gone)
- [ ] Confirm drift detection is working as expected

#### 4.2. Test configuration changes via Git (infra cluster)
- [ ] Make a safe, visible change in Git (e.g., add a label to helmrelease metadata or add a comment)
- [ ] Commit and push change
- [ ] Trigger reconciliation: `flux --context=infra reconcile source git flux-system --with-source`
- [ ] Verify change is applied: `kubectl --context=infra -n kube-system get helmrelease cilium -o yaml | grep <your-label-or-comment>`
- [ ] Verify no pod disruption from the change

#### 4.3. Verify health checks are functional
- [ ] Simulate DaemonSet failure: `kubectl --context=infra -n kube-system scale ds cilium --replicas=0` (DANGEROUS - be ready to revert)
- [ ] Watch Kustomization status: `flux --context=infra get kustomization cilium-core` (should show HealthCheckFailed)
- [ ] Restore DaemonSet: `kubectl --context=infra -n kube-system scale ds cilium --replicas=<original-count>`
- [ ] Verify Kustomization returns to Ready state
- [ ] Repeat for Operator deployment

#### 4.4. Verify cross-cluster consistency
- [ ] Compare Cilium versions: `kubectl --context=infra -n kube-system get helmrelease cilium -o jsonpath='{.spec.chart.spec.version}'` vs apps
- [ ] Compare key configuration values: `helm --kube-context=infra -n kube-system get values cilium` vs apps (should differ only in cluster-specific vars)
- [ ] Verify both clusters show Ready: `flux --context=infra get kustomization cilium-core` and `flux --context=apps get kustomization cilium-core`

#### 4.5. Validate Spegel integration (registry mirror)
- [ ] Verify Spegel is running: `kubectl --context=infra -n kube-system get ds spegel`
- [ ] Check Spegel logs for registry configuration: `kubectl --context=infra -n kube-system logs ds/spegel | grep containerd`
- [ ] Verify no conflicts between Cilium and Spegel (both use hostPort, different ports)
- [ ] Test image pull performance: pull a test image and verify Spegel caching works

---

### Phase 5: Cleanup, Documentation & Completion

**Goal:** Clean up temporary resources and document final state

#### 5.1. Remove bootstrap Helm releases (if not auto-replaced)
- [ ] Check if bootstrap Cilium release still exists: `helm --kube-context=infra -n kube-system list | grep cilium`
- [ ] If exists and not managed by Flux, document why (adoption vs replacement strategy)
- [ ] Remove any temporary test resources created during validation

#### 5.2. Update documentation
- [ ] Update CLAUDE.md or relevant docs with Cilium handover process
- [ ] Document any lessons learned or gotchas encountered
- [ ] Update architecture.md if any deviations from plan occurred

#### 5.3. Final verification checklist
- [ ] Both clusters (infra + apps) show cilium-core Kustomization Ready
- [ ] Both clusters have Cilium 1.18.2 running
- [ ] Both clusters have kubeProxyReplacement enabled (no kube-proxy pods)
- [ ] Both clusters have WireGuard encryption enabled
- [ ] Both clusters have Gateway API and BGP Control Plane enabled
- [ ] Flux successfully manages Cilium (drift detection works)
- [ ] Health checks are functional
- [ ] No manual Helm releases remain for Cilium

#### 5.4. Story completion
- [ ] All acceptance criteria met (from original story + refined criteria)
- [ ] All tasks marked complete
- [ ] Story status updated to "Done"
- [ ] Next story (STORY-SEC-EXTERNAL-SECRETS-BASE.md) dependencies satisfied

---

## Validation Steps

### Quick Validation Script (run on both clusters)

```bash
#!/bin/bash
CLUSTERS=("infra" "apps")

for CLUSTER in "${CLUSTERS[@]}"; do
  echo "==================================="
  echo "Validating cluster: $CLUSTER"
  echo "==================================="

  # 1. Flux Kustomization Ready
  echo "1. Checking Flux Kustomization status..."
  flux --context=$CLUSTER get kustomization cilium-core

  # 2. HelmRelease Ready
  echo "2. Checking HelmRelease status..."
  kubectl --context=$CLUSTER -n kube-system get helmrelease cilium

  # 3. Cilium DaemonSet healthy
  echo "3. Checking Cilium DaemonSet..."
  kubectl --context=$CLUSTER -n kube-system rollout status ds/cilium --timeout=2m

  # 4. Cilium Operator healthy
  echo "4. Checking Cilium Operator..."
  kubectl --context=$CLUSTER -n kube-system rollout status deploy/cilium-operator --timeout=2m

  # 5. No kube-proxy
  echo "5. Verifying kube-proxy is not running..."
  kubectl --context=$CLUSTER -n kube-system get ds kube-proxy 2>&1 | grep -q "NotFound" && \
    echo "kube-proxy not running" || echo "kube-proxy still running"

  # 6. WireGuard encryption
  echo "6. Checking WireGuard encryption..."
  kubectl --context=$CLUSTER -n kube-system exec ds/cilium -- cilium status | grep Encryption

  # 7. Gateway API enabled
  echo "7. Checking Gateway API availability..."
  kubectl --context=$CLUSTER get crd gateways.gateway.networking.k8s.io && \
    echo "Gateway API CRDs present"

  # 8. BGP Control Plane enabled
  echo "8. Checking BGP Control Plane availability..."
  kubectl --context=$CLUSTER get crd ciliumbgppeeringpolicies.cilium.io && \
    echo "BGP CRDs present"

  # 9. Test pod connectivity
  echo "9. Testing pod connectivity..."
  kubectl --context=$CLUSTER run test-cilium-$CLUSTER --image=nginx --rm --restart=Never -- /bin/sh -c "echo 'Pod networking works'" || \
    echo "Pod networking failed"

  echo ""
done

echo "==================================="
echo "Validation complete!"
echo "==================================="
```

---

## Dev Notes

### Critical Path
1. Bootstrap validation (Phase 1) is **mandatory** - don't skip
2. Handover (Phase 3) is **highest risk** - test on infra first, then apps
3. Cross-cluster consistency (Phase 4.4) is **greenfield advantage** - enforce early

### Common Gotchas
- **CRDs must be skipped in HelmRelease** (crds: Skip) - they're installed in bootstrap Phase 0
- **Cluster-specific vars must use ${VARIABLE}** syntax, not hard-coded values
- **Health checks timeout** should be generous (10m) for initial reconciliation
- **Spegel uses HostPort 29999** - different from Cilium, no conflicts expected

### Troubleshooting
- **Kustomization stuck in "Reconciling"**: Check HelmRelease status, check for missing substitution vars
- **HelmRelease shows "UpgradeFailed"**: Check helm -n kube-system history cilium, check for CRD conflicts
- **Pods restarting during handover**: May indicate reinstall instead of adoption - check strategy
- **Drift detection not working**: Verify helm.toolkit.fluxcd.io/driftDetection annotation present

### Rollback Procedure
If handover fails:
1. Remove Flux Kustomization: `flux delete kustomization cilium-core`
2. Verify bootstrap Helm release still exists: `helm -n kube-system list`
3. If bootstrap removed, reinstall: `helmfile -f bootstrap/helmfile.d/01-core.yaml.gotmpl -e <cluster> sync`

---

## Greenfield-Specific Considerations

### Files Created/Modified by This Story

**Created:**
```
kubernetes/infrastructure/networking/cilium/
├── ocirepository.yaml                    # OCI source for Cilium charts
├── kustomization.yaml                    # Includes ocirepository
└── core/
    ├── helmrelease.yaml                  # Cilium HelmRelease
    ├── kustomization.yaml                # Kustomize resources list
    └── ks.yaml                           # Flux Kustomization
```

**Modified:**
```
kubernetes/clusters/infra/
└── infrastructure.yaml                   # Wire in cilium-core Kustomization

kubernetes/clusters/apps/
└── infrastructure.yaml                   # Wire in cilium-core Kustomization
```

**Not Modified (bootstrap stays as-is):**
```
bootstrap/helmfile.d/
├── 00-crds.yaml                          # CRD installation (unchanged)
└── 01-core.yaml.gotmpl                   # Cilium bootstrap (unchanged)
```

### Risks & Mitigations

| Risk | Mitigation | Validation |
|------|-----------|------------|
| **Flux handover causes pod restarts** | Use Helm adoption strategy; monitor pod ages during handover | Phase 3.2: Watch pod restart counts |
| **Bootstrap values drift from HelmRelease** | Use values.yaml.gotmpl pattern; validate in CI | Phase 2.5: Compare extracted values |
| **Cluster-specific substitutions fail** | Explicit validation in AC-3; test on both clusters | Phase 4.4: Cross-cluster comparison |
| **Health checks too aggressive** | Set 10m timeout; test with simulated failures | Phase 4.3: Scale to 0 test |
| **Spegel conflicts with Cilium** | Different ports; verify no HostPort overlap | Phase 4.5: Port conflict check |
| **WireGuard encryption missing** | Explicit validation in bootstrap and post-handover | Phase 1.2, 4.4: Encryption status |
| **Gateway API/BGP CRDs missing** | Bootstrap Phase 0 installs CRDs first | Phase 1.4: CRD existence check |
| **Manual Helm release left behind** | Explicit cleanup check in Phase 5.1 | Phase 5.3: Final verification |

---

## Dependencies

**Upstream (must complete before this story):**
- STORY-BOOT-TALOS (Talos cluster exists)
- STORY-BOOT-CRD (CRDs installed via Phase 0)
- STORY-BOOT-CORE (Cilium installed via bootstrap helmfile)
- cluster-settings.yaml exists on both clusters

**Downstream (blocked until this story completes):**
- STORY-SEC-EXTERNAL-SECRETS-BASE (next in sequence, needs network)
- STORY-NET-CILIUM-BGP (needs cilium-core as base)
- STORY-NET-CILIUM-GATEWAY (needs cilium-core as base)
- STORY-NET-CILIUM-IPAM (needs cilium-core as base)
- STORY-NET-CILIUM-CLUSTERMESH (needs cilium-core on both clusters)

---

## Success Metrics

**Quantitative:**
- 2/2 clusters with Cilium under Flux control (100%)
- 0 pod disruptions during handover
- 0 manual Helm releases remaining
- 2/2 clusters show Ready status for cilium-core Kustomization
- < 5 minutes from Git commit to Cilium update applied
- 100% health check coverage (DaemonSet + Deployment)

**Qualitative:**
- Handover process documented and repeatable
- Drift detection proven to work
- Team confidence in GitOps management of CNI
- Clear path forward for day-2 networking features (BGP, Gateway API)

---

## Definition of Done

Story is complete when:
1. All 10 Acceptance Criteria met and verified
2. All 5 phases of refined tasks completed
3. Both infra and apps clusters show cilium-core Ready: True
4. Git commit → Cilium config update workflow tested and works
5. Drift detection proven (manual change reverted by Flux)
6. Documentation updated (handover process, rollback, troubleshooting)
7. Next story (STORY-SEC-EXTERNAL-SECRETS-BASE) can proceed
8. No blockers or open issues remain

---

## Design — Core (Story‑Only)

- Install: Bootstrap Cilium, then hand over to Flux HelmRelease. Keep immutable OS defaults; leverage eBPF and kube‑proxy replacement.
- Feature flags: kube‑proxy replacement (strict), Hubble, Gateway API, BGP Control Plane, LB IPAM; enable per cluster as needed.
- Bootstrap alignment: Use values.yaml.gotmpl pattern to ensure bootstrap and Flux HelmRelease values stay synchronized.
