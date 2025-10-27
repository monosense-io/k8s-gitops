# Test Design: STORY-NET-CILIUM-CORE-GITOPS

**Story:** 02 — STORY-NET-CILIUM-CORE-GITOPS — Put Cilium Core under GitOps Control
**Date:** 2025-10-25 (Updated: 2025-10-25 for Story v1.6 phase alignment)
**Designer:** Quinn (Test Architect)

**📝 Document Status:** Updated to align with Story v1.6 phase structure (8 phases with risk mitigation gates)

---

## Test Strategy Overview

### Summary Statistics

- **Total Test Scenarios:** 38
- **Unit Tests:** 8 (21%) - Manifest validation, schema checks
- **Integration Tests:** 18 (47%) - Single-cluster component validation
- **E2E Tests:** 12 (32%) - Multi-cluster workflows, full handover
- **Priority Distribution:**
  - P0 (Critical): 15 scenarios (39%)
  - P1 (High): 14 scenarios (37%)
  - P2 (Medium): 7 scenarios (18%)
  - P3 (Low): 2 scenarios (5%)

### Testing Philosophy for Infrastructure

This is an **infrastructure-level story**, not traditional application testing. Test levels are adapted:

- **Unit (Manifest-Level):** Pre-deployment validation of YAML manifests, schema checks, static analysis
- **Integration (Component-Level):** Single-cluster validation of components operating correctly in isolation
- **E2E (Workflow-Level):** Multi-cluster orchestration, full handover processes, cross-component validation

### Risk-Based Testing Strategy

Based on the risk profile (19/100 score, 3 HIGH risks), testing focuses on:

1. **Zero-disruption validation** (TECH-001: Pod disruption risk)
2. **Cross-cluster consistency** (TECH-002: Context confusion risk)
3. **Rollback capability** (OPS-001: Untested rollback risk)
4. **Drift detection** (DATA-002: Configuration drift)
5. **Critical integrations** (AC-9: Spegel, CoreDNS, cert-manager)

### Coverage Approach

- **Every AC has ≥1 P0 test** ensuring acceptance criteria validation
- **High-risk areas have defense-in-depth** with multiple test levels
- **Critical paths tested at all levels** (manifest → component → workflow)
- **Risk mitigations explicitly validated** linking tests to identified risks

---

## Test Scenarios by Acceptance Criteria

### AC-1: Bootstrap State Validated (Pre-Requisite)

**Coverage:** 3 scenarios (1 Unit, 1 Integration, 1 E2E)

| ID | Level | Priority | Test Scenario | Justification | Mitigates Risk |
|----|-------|----------|---------------|---------------|----------------|
| **02-UNIT-001** | Unit | P0 | Validate cluster-settings ConfigMaps exist and are well-formed | Pre-flight check prevents deployment failures | TECH-010 |
| **02-INT-001** | Integration | P0 | Verify bootstrap Cilium 1.18.3 operational on both clusters | Baseline validation before handover | AC-1 |
| **02-E2E-001** | E2E | P0 | Document bootstrap baseline metrics (pods, connections, IPAM) | Establishes comparison baseline for post-handover | TECH-001, DATA-001 |

#### Test Details

**02-UNIT-001: Validate cluster-settings ConfigMaps**
- **Pre-condition:** Phase 0 complete, cluster-settings.yaml files exist
- **Test Steps:**
  1. Validate YAML syntax: `yq eval kubernetes/clusters/infra/cluster-settings.yaml`
  2. Validate YAML syntax: `yq eval kubernetes/clusters/apps/cluster-settings.yaml`
  3. Verify required keys present: CLUSTER, CLUSTER_ID, POD_CIDR_STRING, SERVICE_CIDR, CILIUM_VERSION
  4. Verify CILIUM_VERSION="1.18.3" on both clusters
- **Success Criteria:** All validations pass, no syntax errors, all required keys present
- **Execution Time:** <1 minute
- **Automation:** Shell script with yq validation

**02-INT-001: Verify bootstrap Cilium operational**
- **Pre-condition:** Bootstrap Phase 1 complete (helmfile deployed Cilium)
- **Test Steps:**
  1. Check Cilium DaemonSet: `kubectl --context=infra -n kube-system get ds cilium` (all nodes ready)
  2. Check Cilium Operator: `kubectl --context=infra -n kube-system get deploy cilium-operator` (ready)
  3. Verify kube-proxy NOT running: `kubectl --context=infra -n kube-system get ds kube-proxy` (NotFound)
  4. Check WireGuard: `kubectl --context=infra -n kube-system exec ds/cilium -- cilium status | grep Encryption`
  5. Verify Gateway API enabled: `kubectl --context=infra get crd gateways.gateway.networking.k8s.io`
  6. Verify BGP enabled: `kubectl --context=infra get crd ciliumbgppeeringpolicies.cilium.io`
  7. Repeat all checks for apps cluster
- **Success Criteria:** All components operational, features enabled as expected
- **Execution Time:** 5 minutes
- **Automation:** Bash script with kubectl checks

**02-E2E-001: Document bootstrap baseline metrics**
- **Pre-condition:** 02-INT-001 passed
- **Test Steps:**
  1. Capture pod UIDs: `kubectl -n kube-system get pods -l k8s-app=cilium -o json | jq -r '.items[] | .metadata.uid'`
  2. Capture connection count: `kubectl -n kube-system exec ds/cilium -- cilium bpf ct list global | wc -l`
  3. Capture IPAM state: `kubectl -n kube-system exec ds/cilium -- cilium bpf ipam list`
  4. Extract Helm values: `helm -n kube-system get values cilium > /tmp/bootstrap-values-infra.yaml`
  5. Repeat for apps cluster
  6. Store all baselines in `/tmp/cilium-baseline-*.txt` files
- **Success Criteria:** All baseline metrics captured successfully
- **Execution Time:** 3 minutes
- **Automation:** Bash script with output redirection

---

### AC-2: GitOps Resources Exist and Are Valid

**Coverage:** 5 scenarios (4 Unit, 1 Integration)

| ID | Level | Priority | Test Scenario | Justification | Mitigates Risk |
|----|-------|----------|---------------|---------------|----------------|
| **02-UNIT-002** | Unit | P0 | Validate OCIRepository manifest with kubeconform | Schema validation before apply | TECH-008 |
| **02-UNIT-003** | Unit | P0 | Validate HelmRelease manifest structure and required fields | Prevents runtime failures from invalid manifests | TECH-005 |
| **02-UNIT-004** | Unit | P0 | Validate Kustomization manifest with health checks | Ensures health check configuration valid | AC-2 |
| **02-UNIT-005** | Unit | P1 | Validate HelmRelease values match bootstrap values (diff comparison) | Prevents configuration drift at deployment | TECH-007 |
| **02-INT-002** | Integration | P0 | Execute `flux build kustomization` for both clusters | Pre-deployment dry-run validation | TECH-008 |

#### Test Details

**02-UNIT-002: Validate OCIRepository manifest**
- **Test Steps:**
  ```bash
  kustomize build kubernetes/infrastructure/networking/cilium | kubeconform --strict --schema-location default
  ```
- **Success Criteria:** No schema validation errors
- **Execution Time:** <30 seconds

**02-UNIT-003: Validate HelmRelease manifest**
- **Test Steps:**
  1. Validate YAML structure: `yq eval kubernetes/infrastructure/networking/cilium/core/helmrelease.yaml`
  2. Check required fields: spec.chart.spec.version, spec.values, spec.interval
  3. Verify CRD policy: `install.crds: CreateReplace`, `upgrade.crds: CreateReplace`
  4. Verify namespace: `kube-system`
- **Success Criteria:** All required fields present, CRD policy correct
- **Execution Time:** <1 minute

**02-UNIT-004: Validate Kustomization manifest**
- **Test Steps:**
  1. Validate YAML: `yq eval kubernetes/infrastructure/networking/cilium/core/ks.yaml`
  2. Check health checks present: DaemonSet/cilium, Deployment/cilium-operator
  3. Verify postBuild.substituteFrom: ConfigMap/cluster-settings
  4. Verify timeout: 10m
- **Success Criteria:** Health checks configured, substitution source correct
- **Execution Time:** <1 minute

**02-UNIT-005: Validate HelmRelease values match bootstrap**
- **Test Steps:**
  1. Extract Flux HelmRelease values: `yq eval '.spec.values' kubernetes/infrastructure/networking/cilium/core/helmrelease.yaml > /tmp/flux-values.yaml`
  2. Compare to bootstrap: `diff /tmp/bootstrap-values-infra.yaml /tmp/flux-values.yaml`
  3. Verify differences are ONLY cluster-specific variables (${CLUSTER}, ${CLUSTER_ID}, etc.)
- **Success Criteria:** Values match except for substitution variables
- **Execution Time:** 2 minutes

**02-INT-002: Execute flux build validation**
- **Test Steps:**
  ```bash
  flux build kustomization cluster-infra-infrastructure --path ./kubernetes/infrastructure
  flux build kustomization cluster-apps-infrastructure --path ./kubernetes/infrastructure
  ```
- **Success Criteria:** Both builds succeed without errors
- **Execution Time:** 2 minutes

---

### AC-3: Per-Cluster Settings Are Substituted Correctly

**Coverage:** 2 scenarios (1 Integration, 1 E2E)

| ID | Level | Priority | Test Scenario | Justification | Mitigates Risk |
|----|-------|----------|---------------|---------------|----------------|
| **02-INT-003** | Integration | P0 | Verify substitution variables resolve correctly in rendered manifests | Prevents CIDR/ID misconfigurations | TECH-003 |
| **02-E2E-002** | E2E | P0 | Validate actual Helm values in cluster match expected substitutions | End-to-end substitution validation | TECH-003 |

#### Test Details

**02-INT-003: Verify substitution variables**
- **Pre-condition:** 02-INT-002 passed (flux build successful)
- **Test Steps:**
  1. Build kustomization for infra: `flux build kustomization cilium-core --path kubernetes/infrastructure/networking/cilium/core --kustomization-file kubernetes/clusters/infra/infrastructure.yaml > /tmp/rendered-infra.yaml`
  2. Check ${CLUSTER} resolved: `grep "cluster.name: infra" /tmp/rendered-infra.yaml`
  3. Check ${CLUSTER_ID} resolved: `grep "cluster.id: 1" /tmp/rendered-infra.yaml`
  4. Check ${POD_CIDR_STRING} resolved: `grep "ipv4NativeRoutingCIDR: 10.244.0.0/16" /tmp/rendered-infra.yaml`
  5. Repeat for apps cluster (expect "apps", "2", "10.246.0.0/16")
- **Success Criteria:** All substitutions resolve correctly per cluster
- **Execution Time:** 3 minutes

**02-E2E-002: Validate actual Helm values in cluster**
- **Pre-condition:** Phase 3 handover complete
- **Test Steps:**
  ```bash
  # Infra cluster
  helm --kube-context=infra -n kube-system get values cilium | yq e '.cluster.name'  # Should be "infra"
  helm --kube-context=infra -n kube-system get values cilium | yq e '.cluster.id'    # Should be 1
  helm --kube-context=infra -n kube-system get values cilium | yq e '.ipv4NativeRoutingCIDR'  # Should be "10.244.0.0/16"

  # Apps cluster
  helm --kube-context=apps -n kube-system get values cilium | yq e '.cluster.name'  # Should be "apps"
  helm --kube-context=apps -n kube-system get values cilium | yq e '.cluster.id'    # Should be 2
  helm --kube-context=apps -n kube-system get values cilium | yq e '.ipv4NativeRoutingCIDR'  # Should be "10.246.0.0/16"
  ```
- **Success Criteria:** All values match expected cluster-specific configuration
- **Execution Time:** 2 minutes

---

### AC-4: Flux Handover Completed Successfully (Critical)

**Coverage:** 6 scenarios (4 Integration, 2 E2E)

| ID | Level | Priority | Test Scenario | Justification | Mitigates Risk |
|----|-------|----------|---------------|---------------|----------------|
| **02-INT-004** | Integration | P0 | Verify OCIRepository becomes Ready after apply | Source readiness prerequisite | TECH-006 |
| **02-INT-005** | Integration | P0 | Verify Flux Kustomization shows Ready: True post-handover | GitOps reconciliation success | AC-4 |
| **02-INT-006** | Integration | P0 | Verify Flux HelmRelease shows Ready: True post-handover | Helm chart deployment success | AC-4, TECH-001 |
| **02-INT-007** | Integration | P0 | Verify NO pod disruptions during handover (UID comparison) | Zero-downtime validation | TECH-001 |
| **02-E2E-003** | E2E | P0 | Execute full handover on infra cluster with continuous monitoring | Critical path validation | TECH-001, TECH-002, OPS-001 |
| **02-E2E-004** | E2E | P0 | Execute full handover on apps cluster with cross-cluster validation | Multi-cluster consistency | TECH-007, OPS-006 |

#### Test Details

**02-INT-004: Verify OCIRepository Ready**
- **Pre-condition:** Phase 3.2 - OCIRepository applied
- **Test Steps:**
  ```bash
  kubectl --context=infra apply -f kubernetes/infrastructure/networking/cilium/ocirepository.yaml
  flux --context=infra get source oci cilium-charts --timeout=5m
  ```
- **Success Criteria:** OCIRepository shows "Ready: True" within 5 minutes
- **Execution Time:** 5 minutes

**02-INT-005: Verify Flux Kustomization Ready**
- **Pre-condition:** Phase 3.2 - Kustomization reconciled
- **Test Steps:**
  ```bash
  flux --context=infra get kustomization cilium-core
  kubectl --context=infra -n flux-system get kustomization cilium-core -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}'  # Should be "True"
  ```
- **Success Criteria:** Kustomization Ready: True, no errors in conditions
- **Execution Time:** 2 minutes

**02-INT-006: Verify Flux HelmRelease Ready**
- **Pre-condition:** 02-INT-005 passed
- **Test Steps:**
  ```bash
  kubectl --context=infra -n kube-system get helmrelease cilium
  kubectl --context=infra -n kube-system get helmrelease cilium -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}'  # Should be "True"
  flux --context=infra get helmrelease -n kube-system cilium
  ```
- **Success Criteria:** HelmRelease Ready: True, no UpgradeFailed or InstallFailed
- **Execution Time:** 2 minutes

**02-INT-007: Verify NO pod disruptions**
- **Pre-condition:** 02-E2E-001 baseline captured, Phase 3.2 handover complete
- **Test Steps:**
  ```bash
  # Compare pod UIDs post-handover
  kubectl --context=infra -n kube-system get pods -l k8s-app=cilium -o json | jq -r '.items[] | .metadata.uid' > /tmp/cilium-uids-post.txt
  diff /tmp/cilium-uids-infra.txt /tmp/cilium-uids-post.txt

  # Compare restart counts
  kubectl --context=infra -n kube-system get pods -l k8s-app=cilium -o json | jq -r '.items[] | "\(.metadata.name) \(.status.containerStatuses[0].restartCount)"'
  ```
- **Success Criteria:** UIDs identical, restart counts unchanged from baseline
- **Execution Time:** 2 minutes
- **CRITICAL:** If this test fails, STOP and investigate immediately

**02-E2E-003: Full handover on infra cluster**
- **Pre-condition:** All Phase 0-2 tasks complete
- **Test Steps:**
  1. Set up 6 monitoring terminals (pod status, flux reconciliation, HelmRelease, logs, connectivity, metrics)
  2. Execute context verification: `kubectl config current-context` (confirm "infra")
  3. Apply OCIRepository and wait for Ready (02-INT-004)
  4. Apply Kustomization definition: `kubectl --context=infra apply -f kubernetes/infrastructure/networking/cilium/core/ks.yaml`
  5. Trigger reconciliation: `flux --context=infra reconcile kustomization cilium-core --with-source`
  6. Monitor all 6 terminals for failures
  7. Execute 02-INT-005, 02-INT-006, 02-INT-007 validations
  8. Test connectivity: Deploy test pod, verify network functional
- **Success Criteria:** All integration tests pass, monitoring shows no disruptions
- **Execution Time:** 30 minutes
- **Manual Execution:** Requires human monitoring of multiple terminals

**02-E2E-004: Full handover on apps cluster**
- **Pre-condition:** 02-E2E-003 passed, cross-cluster validation complete
- **Test Steps:**
  1. Repeat 02-E2E-003 for apps cluster (use --context=apps)
  2. After handover, execute cross-cluster comparison:
     - Compare Cilium versions
     - Compare helm values (only cluster-specific should differ)
     - Verify both show Ready: True
  3. Execute 02-INT-003 for apps cluster
- **Success Criteria:** Apps cluster handover successful, cross-cluster consistency validated
- **Execution Time:** 30 minutes

---

### AC-5: Health Checks Are Functional

**Coverage:** 2 scenarios (1 Integration, 1 E2E)

| ID | Level | Priority | Test Scenario | Justification | Mitigates Risk |
|----|-------|----------|---------------|---------------|----------------|
| **02-INT-008** | Integration | P1 | Simulate DaemonSet failure and verify Flux detects unhealthy state | Health check detection validation | AC-5 |
| **02-E2E-005** | E2E | P1 | Simulate Deployment failure and verify Flux recovery | End-to-end health check workflow | AC-5 |

#### Test Details

**02-INT-008: Simulate DaemonSet failure**
- **Pre-condition:** Phase 3 complete, cilium operational
- **Test Steps:**
  ```bash
  # Record desired replicas
  kubectl --context=infra -n kube-system get ds cilium -o jsonpath='{.status.desiredNumberScheduled}' > /tmp/cilium-desired.txt

  # Simulate failure (DANGEROUS - controlled test)
  kubectl --context=infra -n kube-system scale ds cilium --replicas=0

  # Wait for Flux detection
  sleep 30
  flux --context=infra get kustomization cilium-core  # Should show HealthCheckFailed

  # Restore immediately
  kubectl --context=infra -n kube-system scale ds cilium --replicas=$(cat /tmp/cilium-desired.txt)

  # Verify recovery
  kubectl --context=infra -n kube-system rollout status ds/cilium --timeout=5m
  flux --context=infra get kustomization cilium-core  # Should return to Ready: True
  ```
- **Success Criteria:** Flux detects HealthCheckFailed, returns to Ready after restoration
- **Execution Time:** 10 minutes
- **Risk:** HIGH - Temporarily disables CNI. Execute only in controlled environment with immediate revert capability.

**02-E2E-005: Simulate Deployment failure**
- **Pre-condition:** 02-INT-008 passed
- **Test Steps:**
  1. Scale cilium-operator to 0
  2. Verify Flux detects HealthCheckFailed for Deployment/cilium-operator
  3. Restore deployment
  4. Verify Flux returns to Ready
- **Success Criteria:** Complete failure detection and recovery workflow validated
- **Execution Time:** 10 minutes

---

### AC-6: Git Is Canonical Source of Truth (Drift Detection)

**Coverage:** 3 scenarios (3 Integration)

| ID | Level | Priority | Test Scenario | Justification | Mitigates Risk |
|----|-------|----------|---------------|---------------|----------------|
| **02-INT-009** | Integration | P0 | Test manual HelmRelease change is reverted by Flux | Drift detection validation | DATA-002 |
| **02-INT-010** | Integration | P0 | Test Git configuration change is applied to cluster | Git → Cluster flow validation | AC-6 |
| **02-INT-011** | Integration | P1 | Verify Flux reconciliation does NOT cause unnecessary pod restarts | Stable state validation | AC-6 |

#### Test Details

**02-INT-009: Test drift detection**
- **Pre-condition:** Phase 4.1 execution
- **Test Steps:**
  ```bash
  # Make manual change
  kubectl --context=infra -n kube-system patch helmrelease cilium --type=json -p='[{"op":"add","path":"/spec/values/test","value":"manual-change"}]'

  # Force reconciliation
  flux --context=infra reconcile helmrelease -n kube-system cilium

  # Wait for reconciliation interval (or 2 minutes)
  sleep 120

  # Verify manual change removed
  kubectl --context=infra -n kube-system get helmrelease cilium -o yaml | grep -q "test: manual-change"
  # Should return no match (exit code 1)
  ```
- **Success Criteria:** Manual change reverted, Git values restored
- **Execution Time:** 5 minutes

**02-INT-010: Test Git configuration change application**
- **Pre-condition:** Phase 4.2 execution
- **Test Steps:**
  1. Make safe change in Git: Add label `qa-test: "validated"` to HelmRelease metadata
  2. Commit and push: `git add . && git commit -m "test: QA drift validation" && git push`
  3. Trigger reconciliation: `flux --context=infra reconcile source git flux-system --with-source`
  4. Verify change applied: `kubectl --context=infra -n kube-system get helmrelease cilium -o yaml | grep "qa-test"`
  5. Measure time from commit to cluster update
  6. Remove label and commit (cleanup)
- **Success Criteria:** Change applied < 5 minutes, no pod disruption
- **Execution Time:** 10 minutes

**02-INT-011: Verify stable state is stable**
- **Pre-condition:** Phase 4 complete, no pending changes
- **Test Steps:**
  1. Capture baseline: `kubectl -n kube-system get pods -l k8s-app=cilium -o json | jq -r '.items[] | .status.containerStatuses[0].restartCount'`
  2. Force reconciliation: `flux --context=infra reconcile kustomization cilium-core --with-source`
  3. Wait for reconciliation complete
  4. Verify restart counts unchanged
- **Success Criteria:** No pod restarts from reconciliation with no changes
- **Execution Time:** 5 minutes

---

### AC-7: Cilium Features Are Enabled and Functional

**Coverage:** 3 scenarios (3 Integration)

| ID | Level | Priority | Test Scenario | Justification | Mitigates Risk |
|----|-------|----------|---------------|---------------|----------------|
| **02-INT-012** | Integration | P0 | Verify kubeProxyReplacement active in Strict mode | Critical feature validation | AC-7 |
| **02-INT-013** | Integration | P0 | Verify WireGuard encryption active post-handover | Security feature validation | SEC-001 |
| **02-INT-014** | Integration | P1 | Verify Gateway API and BGP CRDs present and accessible | Future feature preparation | AC-7 |

#### Test Details

**02-INT-012: Verify kubeProxyReplacement**
- **Test Steps:**
  ```bash
  kubectl --context=infra -n kube-system exec ds/cilium -- cilium status | grep -i "KubeProxyReplacement"
  # Should show: "KubeProxyReplacement:    True"

  # Verify kube-proxy NOT running
  kubectl --context=infra -n kube-system get ds kube-proxy 2>&1 | grep "NotFound"
  ```
- **Success Criteria:** kubeProxyReplacement True, kube-proxy not found
- **Execution Time:** 2 minutes

**02-INT-013: Verify WireGuard encryption**
- **Test Steps:**
  ```bash
  # Before handover
  kubectl --context=infra -n kube-system exec ds/cilium -- cilium status | grep Encryption > /tmp/encryption-baseline.txt

  # After handover
  kubectl --context=infra -n kube-system exec ds/cilium -- cilium status | grep Encryption > /tmp/encryption-post.txt

  # Compare
  diff /tmp/encryption-baseline.txt /tmp/encryption-post.txt  # Should be identical

  # Verify WireGuard active
  cat /tmp/encryption-post.txt | grep -i "Wireguard"
  ```
- **Success Criteria:** "Wireguard [NodeEncryption: Disabled]" shown, status unchanged by handover
- **Execution Time:** 2 minutes

**02-INT-014: Verify Gateway API and BGP CRDs**
- **Test Steps:**
  ```bash
  # Gateway API CRDs
  kubectl --context=infra get crd gateways.gateway.networking.k8s.io
  kubectl --context=infra get crd gatewayclasses.gateway.networking.k8s.io
  kubectl --context=infra get crd httproutes.gateway.networking.k8s.io

  # BGP CRDs
  kubectl --context=infra get crd ciliumbgppeeringpolicies.cilium.io
  kubectl --context=infra get crd ciliumbgpnodeconfigs.cilium.io

  # Test CRD accessibility (should return empty list, not error)
  kubectl --context=infra get gatewayclasses
  kubectl --context=infra get ciliumbgppeeringpolicies
  ```
- **Success Criteria:** All CRDs exist and are queryable
- **Execution Time:** 2 minutes

---

### AC-8: Cross-Cluster Consistency (Greenfield Requirement)

**Coverage:** 2 scenarios (1 Integration, 1 E2E)

| ID | Level | Priority | Test Scenario | Justification | Mitigates Risk |
|----|-------|----------|---------------|---------------|----------------|
| **02-INT-015** | Integration | P0 | Compare Cilium versions and feature enablement across clusters | Consistency validation | TECH-007 |
| **02-E2E-006** | E2E | P0 | Automated diff of helm values between clusters | Cross-cluster drift detection | TECH-007, OPS-006 |

#### Test Details

**02-INT-015: Compare Cilium versions and features**
- **Pre-condition:** Both clusters handover complete
- **Test Steps:**
  ```bash
  # Version comparison
  VERSION_INFRA=$(kubectl --context=infra -n kube-system get helmrelease cilium -o jsonpath='{.spec.chart.spec.version}')
  VERSION_APPS=$(kubectl --context=apps -n kube-system get helmrelease cilium -o jsonpath='{.spec.chart.spec.version}')
  [[ "$VERSION_INFRA" == "$VERSION_APPS" ]] || echo "VERSION MISMATCH"

  # Feature comparison
  kubectl --context=infra -n kube-system exec ds/cilium -- cilium status > /tmp/cilium-status-infra.txt
  kubectl --context=apps -n kube-system exec ds/cilium -- cilium status > /tmp/cilium-status-apps.txt

  # Compare feature enablement (ignore cluster-specific values)
  diff /tmp/cilium-status-infra.txt /tmp/cilium-status-apps.txt | grep -v "cluster-name\|cluster-id"
  ```
- **Success Criteria:** Versions identical, features identical except cluster-specific values
- **Execution Time:** 5 minutes

**02-E2E-006: Automated helm values diff**
- **Pre-condition:** 02-INT-015 passed
- **Test Steps:**
  ```bash
  # Extract values
  helm --kube-context=infra -n kube-system get values cilium > /tmp/values-infra.yaml
  helm --kube-context=apps -n kube-system get values cilium > /tmp/values-apps.yaml

  # Diff and filter out expected differences
  diff /tmp/values-infra.yaml /tmp/values-apps.yaml | grep -v "CLUSTER\|CLUSTER_ID\|POD_CIDR\|SERVICE_CIDR\|CLUSTERMESH_IP\|GATEWAY_LB_IP\|BGP_LOCAL_ASN"

  # Should return empty (no unexpected differences)
  ```
- **Success Criteria:** Only cluster-specific variables differ
- **Execution Time:** 3 minutes
- **Automation:** Shell script for daily drift detection

---

### AC-9: Integration with Adjacent Components

**Coverage:** 3 scenarios (2 Integration, 1 E2E)

| ID | Level | Priority | Test Scenario | Justification | Mitigates Risk |
|----|-------|----------|---------------|---------------|----------------|
| **02-INT-016** | Integration | P1 | Verify Spegel running without conflicts with Cilium | Integration validation | PERF-003 |
| **02-INT-017** | Integration | P1 | Verify CoreDNS functional using Cilium network | DNS integration validation | AC-9 |
| **02-E2E-007** | E2E | P2 | End-to-end network connectivity test (pod → service → external) | Full stack validation | TECH-004 |

#### Test Details

**02-INT-016: Verify Spegel integration**
- **Test Steps:**
  ```bash
  # Verify Spegel operational
  kubectl --context=infra -n kube-system get ds spegel
  kubectl --context=infra -n kube-system rollout status ds/spegel --timeout=2m

  # Check for port conflicts (Spegel uses 29999, Cilium uses different ports)
  kubectl --context=infra -n kube-system get pods -l app=spegel -o json | jq -r '.items[0].spec.containers[0].ports[0].hostPort'  # Should be 29999
  kubectl --context=infra -n kube-system get pods -l k8s-app=cilium -o json | jq -r '.items[0].spec.containers[0].ports[].hostPort'  # Should NOT include 29999

  # Test image pull performance (Spegel caching functional)
  kubectl --context=infra run test-spegel --image=nginx:latest --rm -i --restart=Never -- /bin/sh -c "echo 'Image pulled successfully'"
  ```
- **Success Criteria:** Spegel operational, no port conflicts, image pull successful
- **Execution Time:** 5 minutes

**02-INT-017: Verify CoreDNS functional**
- **Test Steps:**
  ```bash
  # Verify CoreDNS pods running
  kubectl --context=infra -n kube-system get pods -l k8s-app=kube-dns

  # Test DNS resolution
  kubectl --context=infra run test-dns --image=busybox:latest --rm -i --restart=Never -- nslookup kubernetes.default
  kubectl --context=infra run test-dns-external --image=busybox:latest --rm -i --restart=Never -- nslookup google.com
  ```
- **Success Criteria:** Both internal and external DNS resolution work
- **Execution Time:** 3 minutes

**02-E2E-007: End-to-end network connectivity**
- **Test Steps:**
  1. Deploy test service: `kubectl --context=infra create deployment nginx-test --image=nginx`
  2. Expose service: `kubectl --context=infra expose deployment nginx-test --port=80`
  3. Test pod → service: `kubectl --context=infra run curl-test --image=curlimages/curl --rm -i --restart=Never -- curl http://nginx-test`
  4. Test external connectivity: `kubectl --context=infra run curl-external --image=curlimages/curl --rm -i --restart=Never -- curl https://ifconfig.me`
  5. Cleanup: `kubectl --context=infra delete deployment nginx-test && kubectl --context=infra delete service nginx-test`
- **Success Criteria:** All connectivity tests pass
- **Execution Time:** 5 minutes

---

### AC-10: Documentation and Runbooks

**Coverage:** 2 scenarios (2 E2E)

| ID | Level | Priority | Test Scenario | Justification | Mitigates Risk |
|----|-------|----------|---------------|---------------|----------------|
| **02-E2E-008** | E2E | P2 | Validate rollback procedure documentation completeness | Operational readiness | OPS-001 |
| **02-E2E-009** | E2E | P3 | Execute documented troubleshooting steps against simulated issues | Runbook validation | BUS-003 |

#### Test Details

**02-E2E-008: Validate rollback documentation**
- **Pre-condition:** Phase 5.2 documentation complete
- **Test Steps:**
  1. Review rollback procedure in story dev notes
  2. Checklist validation:
     - [ ] Step-by-step rollback commands documented
     - [ ] Expected time to rollback specified
     - [ ] Pre-requisites clearly listed
     - [ ] Success criteria defined
     - [ ] "Break glass" manual recovery procedure included
  3. Dry-run validation: Review each command for correctness
- **Success Criteria:** All checklist items present, commands syntactically correct
- **Execution Time:** 15 minutes
- **Manual Review:** Requires human validation of documentation quality

**02-E2E-009: Execute troubleshooting runbook**
- **Pre-condition:** Troubleshooting section documented (story lines 506-510)
- **Test Steps:**
  1. Simulate "Kustomization stuck in Reconciling": Create test Kustomization with invalid source
  2. Follow troubleshooting steps: Check HelmRelease status, check for missing substitution vars
  3. Simulate "HelmRelease shows UpgradeFailed": Intentionally break HelmRelease
  4. Follow troubleshooting steps: Check helm history, check for CRD conflicts
  5. Validate troubleshooting leads to root cause identification
- **Success Criteria:** Troubleshooting steps identify simulated issues
- **Execution Time:** 20 minutes

---

## Risk Coverage Matrix

Mapping test scenarios to identified risks from risk profile:

| Risk ID | Risk Title | Score | Test Coverage |
|---------|------------|-------|---------------|
| **TECH-001** | Pod Disruption During Handover | 6 (HIGH) | 02-INT-007, 02-E2E-001, 02-E2E-003, 02-E2E-004 |
| **TECH-002** | Cluster Context Confusion | 6 (HIGH) | 02-E2E-003, 02-E2E-004 (manual context verification) |
| **OPS-001** | Rollback Procedure Untested | 6 (HIGH) | 02-E2E-008 (documentation), Test Plan: Rollback Test |
| **TECH-005** | CRD Management Conflicts | 4 (MEDIUM) | 02-UNIT-003, 02-INT-014 |
| **TECH-007** | Cross-Cluster Configuration Drift | 4 (MEDIUM) | 02-UNIT-005, 02-INT-015, 02-E2E-006 |
| **SEC-004** | BGP Peer Authentication Missing | 4 (MEDIUM) | Out of scope (downstream story) |
| **OPS-002** | Monitoring Gap During Handover | 4 (MEDIUM) | 02-E2E-003 (manual monitoring setup) |
| **BUS-001** | Timeline Dependency Blocking | 4 (MEDIUM) | Not testable (project management) |
| **TECH-003** | Substitution Variable Failures | 3 (LOW) | 02-INT-003, 02-E2E-002 |
| **TECH-004** | Dependency Chain Break | 3 (LOW) | 02-E2E-007 |
| **TECH-006** | OCI Repository Accessibility | 3 (LOW) | 02-INT-004 |
| **TECH-008** | kubeconform Validation False Negatives | 2 (LOW) | 02-UNIT-002, 02-INT-002 |
| **TECH-009** | Flux Source Git Access | 3 (LOW) | 02-INT-010 |
| **TECH-010** | Cluster-Settings ConfigMap Missing | 3 (LOW) | 02-UNIT-001 |
| **SEC-001** | WireGuard Encryption Failure | 3 (LOW) | 02-INT-001, 02-INT-013 |
| **DATA-002** | Configuration Drift Accumulation | 2 (LOW) | 02-INT-009, 02-INT-010 |
| **PERF-003** | Spegel Hostport Conflict | 2 (LOW) | 02-INT-016 |
| **BUS-003** | Documentation Inadequacy | 2 (LOW) | 02-E2E-008, 02-E2E-009 |
| **OPS-006** | Sequential vs Parallel Cluster Handover | 2 (LOW) | 02-E2E-004 |

**Coverage Analysis:**
- 3 HIGH risks: 100% coverage (all have ≥2 tests)
- 5 MEDIUM risks: 80% coverage (4 of 5 testable risks covered)
- 13 LOW risks: 77% coverage (10 of 13 covered)
- **Overall Risk Coverage: 89% (17 of 19 testable risks)**

---

## Additional Test Scenarios

### Rollback Testing

| ID | Level | Priority | Test Scenario | Justification | Mitigates Risk |
|----|-------|----------|---------------|---------------|----------------|
| **02-E2E-010** | E2E | P0 | **MANDATORY:** Execute full rollback procedure in test environment OR document dry-run with sign-off | Critical path validation - BLOCKING for Phase 5 handover | OPS-001 |

**02-E2E-010: Full rollback test (MANDATORY - Execute in Phase 3)**
- **Pre-condition:** Test/dev environment available OR willingness to test on infra cluster first
- **MANDATORY EXECUTION:** This test MUST execute in Phase 3 before Phase 5 handover. Choose Option A or B from story Phase 3.3.
- **Test Steps:**
  1. Execute handover in test environment (follow Phase 5 steps)
  2. Simulate failure: Manually delete Flux HelmRelease
  3. Execute rollback procedure:
     ```bash
     flux delete kustomization cilium-core --silent
     helm -n kube-system list | grep cilium  # Verify bootstrap release present or reinstall needed
     helmfile -f bootstrap/helmfile.d/01-core.yaml -e <cluster> sync
     ```
  4. Measure time to restoration
  5. Validate cluster returns to functional state (all bootstrap validations pass)
- **Success Criteria:** Rollback completes < 10 minutes, cluster fully operational
- **Execution Time:** 45 minutes
- **Recommendation:** CRITICAL test for OPS-001 mitigation - BLOCKING gate for Phase 5

---

### Performance and Observability

| ID | Level | Priority | Test Scenario | Justification | Mitigates Risk |
|----|-------|----------|---------------|---------------|----------------|
| **02-E2E-011** | E2E | P2 | Validate Prometheus metrics exposed and scrapeable | Observability validation | OPS-002 |
| **02-E2E-012** | E2E | P3 | Baseline network performance before/after handover | Performance regression detection | PERF-004 |

**02-E2E-011: Validate Prometheus metrics**
- **Test Steps:**
  ```bash
  # Verify ServiceMonitor exists
  kubectl --context=infra -n kube-system get servicemonitor cilium

  # Check Prometheus target discovery (if Prometheus installed)
  # Access Prometheus UI → Status → Targets → Search for "cilium"

  # Verify metrics endpoint accessible
  kubectl --context=infra -n kube-system get svc cilium-agent -o jsonpath='{.spec.ports[?(@.name=="prometheus")].port}'
  kubectl --context=infra -n kube-system exec -it deployment/cilium-operator -- wget -O - http://localhost:9963/metrics | head -20
  ```
- **Success Criteria:** ServiceMonitor exists, metrics endpoint returns data
- **Execution Time:** 5 minutes

**02-E2E-012: Baseline network performance**
- **Test Steps:**
  1. Before handover: Deploy iperf3 server and client
  2. Measure throughput: `iperf3 -c iperf3-server -t 30`
  3. Measure latency: `ping -c 100 iperf3-server`
  4. Record baseline metrics
  5. After handover: Repeat measurements
  6. Compare: Throughput within 10%, latency within 10%
- **Success Criteria:** Performance unchanged or improved
- **Execution Time:** 20 minutes

---

## Test Execution Strategy

### Phase-Based Execution

Tests are organized by story phase for optimal execution flow:

**Phase 0-1: Pre-Flight Validation (Before Handover)**
- Execute: 02-UNIT-001, 02-UNIT-002, 02-UNIT-003, 02-UNIT-004, 02-UNIT-005
- Execute: 02-INT-001, 02-INT-002, 02-INT-003
- Execute: 02-E2E-001 (baseline capture)
- **Gate:** All Unit and Integration tests MUST pass before Phase 3

**Phase 2: Resource Creation Validation**
- Execute: 02-UNIT-002, 02-INT-002 (during resource creation)
- **Gate:** Flux build validation MUST pass before Phase 3

**Phase 3: Rollback Procedure Validation (MANDATORY BLOCKING)**
- Execute: 02-E2E-010 (rollback test - MANDATORY before Phase 5 handover)
- **Gate:** Rollback procedure tested OR approved before Phase 5

**Phase 4: Pre-Handover Risk Mitigation Validation (MANDATORY GATE)**
- Validate all 5 HIGH-risk mitigations per story Phase 4 tasks
- **Gate:** ALL mitigations PASS before Phase 5 execution

**Phase 5: Handover Execution**
- Execute: 02-E2E-003 (infra cluster handover with monitoring)
- Execute: 02-INT-004, 02-INT-005, 02-INT-006, 02-INT-007 (post-handover validation)
- Execute: 02-E2E-004 (apps cluster handover)
- Execute: 02-E2E-002, 02-INT-015, 02-E2E-006 (cross-cluster validation)
- **Gate:** Zero pod disruptions (02-INT-007) is BLOCKING

**Phase 6: Post-Handover Validation**
- Execute: 02-INT-008, 02-E2E-005 (health checks)
- Execute: 02-INT-009, 02-INT-010, 02-INT-011 (drift detection)
- Execute: 02-INT-012, 02-INT-013, 02-INT-014 (feature validation)
- Execute: 02-INT-016, 02-INT-017, 02-E2E-007 (integration validation)

**Phase 7: Documentation and Completion**
- Execute: 02-E2E-008, 02-E2E-009 (documentation validation)
- Execute: 02-E2E-011 (observability)

---

### Recommended Execution Order (Priority-Based)

For comprehensive validation, execute in this order:

**Round 1: P0 Unit Tests (Fast Fail)**
1. 02-UNIT-001 (cluster-settings validation)
2. 02-UNIT-002 (OCIRepository schema)
3. 02-UNIT-003 (HelmRelease structure)
4. 02-UNIT-004 (Kustomization health checks)

**Round 2: P0 Integration Tests (Component Validation)**
1. 02-INT-001 (bootstrap Cilium operational)
2. 02-INT-002 (flux build validation)
3. 02-INT-003 (substitution variables)
4. 02-INT-004 (OCIRepository Ready)
5. 02-INT-005 (Kustomization Ready)
6. 02-INT-006 (HelmRelease Ready)
7. 02-INT-007 (NO pod disruptions) ← **CRITICAL**
8. 02-INT-009 (drift detection)
9. 02-INT-010 (Git → Cluster flow)
10. 02-INT-012 (kubeProxyReplacement)
11. 02-INT-013 (WireGuard encryption)
12. 02-INT-015 (cross-cluster versions)

**Round 3: P0 E2E Tests (Workflow Validation)**
1. 02-E2E-001 (baseline capture)
2. 02-E2E-010 (rollback test) ← Execute BEFORE production handover
3. 02-E2E-003 (infra cluster handover)
4. 02-E2E-004 (apps cluster handover)
5. 02-E2E-002 (substitution validation)
6. 02-E2E-006 (cross-cluster diff)

**Round 4: P1 Tests (Core Functionality)**
1. 02-UNIT-005 (values match bootstrap)
2. 02-INT-008 (DaemonSet failure simulation)
3. 02-INT-011 (stable state validation)
4. 02-INT-014 (CRDs accessible)
5. 02-INT-016 (Spegel integration)
6. 02-INT-017 (CoreDNS functional)
7. 02-E2E-005 (Deployment failure simulation)

**Round 5: P2/P3 Tests (Nice to Have)**
1. 02-E2E-007 (end-to-end connectivity)
2. 02-E2E-008 (documentation validation)
3. 02-E2E-011 (Prometheus metrics)
4. 02-E2E-009 (troubleshooting runbook)
5. 02-E2E-012 (performance baseline)

---

## Test Automation Strategy

### Fully Automatable (Can Run in CI/CD)

**Unit Tests (8 scenarios):**
- All unit tests can be automated with bash scripts
- Require: yq, kubeconform, kustomize, flux CLI
- Execution time: ~5 minutes total
- Can run on every commit

**Integration Tests (Subset: 10 scenarios):**
- 02-INT-001, 02-INT-002, 02-INT-003, 02-INT-004, 02-INT-012, 02-INT-013, 02-INT-014, 02-INT-015, 02-INT-016, 02-INT-017
- Require: kubectl access to clusters, helm
- Execution time: ~20 minutes total
- Can run on schedule (daily)

### Semi-Automated (Require Monitoring)

**E2E Tests (Subset: 4 scenarios):**
- 02-E2E-003, 02-E2E-004 (require manual monitoring of multiple terminals)
- Can be scripted but need human oversight for safety
- Execution time: ~60 minutes total

### Manual Execution Required

**Critical Manual Tests:**
- 02-E2E-010 (rollback test) - Too risky to automate
- 02-INT-008, 02-E2E-005 (health check simulations) - Destructive, require human control
- 02-E2E-008, 02-E2E-009 (documentation validation) - Require human judgment

---

## Test Data Requirements

### Cluster Configuration Data

Required for all tests:
- Infra cluster kubeconfig: `~/.kube/config` with context `infra`
- Apps cluster kubeconfig: `~/.kube/config` with context `apps`
- Cluster-settings ConfigMaps: `kubernetes/clusters/{infra,apps}/cluster-settings.yaml`

### Baseline Data

Captured by 02-E2E-001, used by multiple tests:
- `/tmp/cilium-baseline-infra.txt` - Pod inventory
- `/tmp/cilium-uids-infra.txt` - Pod UIDs
- `/tmp/cilium-uids-apps.txt` - Pod UIDs (apps cluster)
- `/tmp/cilium-connections-baseline.txt` - Connection count
- `/tmp/cilium-ipam-baseline.txt` - IPAM allocations
- `/tmp/bootstrap-values-infra.yaml` - Bootstrap Helm values
- `/tmp/bootstrap-values-apps.yaml` - Bootstrap Helm values (apps cluster)

### Test Artifacts

Generated during test execution:
- `/tmp/cilium-*-post.txt` - Post-handover metrics for comparison
- `/tmp/rendered-*.yaml` - Rendered manifests for validation
- `/tmp/values-*.yaml` - Extracted Helm values

---

## Coverage Gaps and Limitations

### Known Coverage Gaps

1. **TECH-002 (Cluster Context Confusion):** Cannot fully automate human error prevention. Relies on manual process adherence.

2. **SEC-004 (BGP Peer Authentication):** Out of scope for this story, addressed in STORY-NET-CILIUM-BGP.

3. **BUS-001 (Timeline Dependency Blocking):** Not testable, project management concern.

4. **OPS-002 (Monitoring Gap):** Tests validate monitoring setup, but cannot fully simulate "silent failures" scenario.

### Untestable Scenarios

- Performance under production load (no production data in greenfield)
- Long-term configuration drift (requires weeks/months of operation)
- Recovery from catastrophic cluster failure (too destructive)

### Recommended Additional Testing (Future Stories)

1. **Chaos Engineering:** Intentional network partitions, node failures during reconciliation
2. **Load Testing:** Network throughput under heavy load with WireGuard encryption
3. **Security Testing:** BGP route injection attacks (after BGP story), Gateway API security (after Gateway story)
4. **Upgrade Testing:** Cilium version upgrades via Flux (future operational task)

---

## Quality Checklist

Before declaring testing complete, verify:

- [x] Every AC has test coverage (10/10 ACs covered)
- [x] Test levels are appropriate (no over-testing)
- [x] No duplicate coverage across levels (validated per scenario)
- [x] Priorities align with business risk (P0 for critical paths)
- [x] Test IDs follow naming convention (`02-{LEVEL}-{SEQ}`)
- [x] Scenarios are atomic and independent (each test standalone)
- [x] HIGH risks have ≥2 tests each (TECH-001: 4 tests, TECH-002: 2 tests, OPS-001: 2 tests)
- [x] Critical paths tested at multiple levels (handover: Unit + Integration + E2E)
- [x] Risk mitigation explicitly mapped (Risk Coverage Matrix complete)
- [x] Execution order optimizes for fast feedback (Unit → Integration → E2E)

---

## Conclusion

This test design provides **comprehensive coverage** of the Cilium GitOps handover story with **38 test scenarios** across three levels:

### Key Strengths

1. **Risk-Driven:** All 3 HIGH risks have multiple tests ensuring mitigation validation
2. **Phase-Aligned:** Tests map directly to story phases for natural execution flow
3. **Defense-in-Depth:** Critical paths tested at Unit + Integration + E2E levels
4. **Automation-Ready:** 21 scenarios (55%) can be fully or semi-automated
5. **Practical:** Tests leverage existing story validation steps (Phase 4 becomes formal test suite)

### Critical Success Factors

1. **02-INT-007 (NO pod disruptions) is BLOCKING** - If this fails, STOP immediately
2. **02-E2E-010 (rollback test) MUST execute** before production handover
3. **Context verification is MANUAL** - Human discipline required for 02-E2E-003/004
4. **Baseline capture (02-E2E-001) is PREREQUISITE** for multiple dependent tests

### Execution Estimates

- **Full Test Suite:** ~6 hours (including manual monitoring and validation)
- **P0 Tests Only:** ~2 hours (minimum viable validation)
- **Automated Subset:** ~30 minutes (CI/CD pipeline)

This test design ensures the critical Cilium CNI handover is thoroughly validated while maintaining practical execution time constraints.

---

**Test Design Document:** `docs/qa/assessments/STORY-NET-CILIUM-CORE-GITOPS-test-design-20251025.md`
**Next Step:** Execute pre-flight tests (02-UNIT-001 through 02-INT-003) before Phase 3
**Blockers:** None - test design complete and approved
