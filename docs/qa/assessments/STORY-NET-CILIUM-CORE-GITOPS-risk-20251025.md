# Risk Profile: STORY-NET-CILIUM-CORE-GITOPS

**Story:** 02 — STORY-NET-CILIUM-CORE-GITOPS — Put Cilium Core under GitOps Control
**Date:** 2025-10-25
**Reviewer:** Quinn (Test Architect)
**Analysis Mode:** Deep Sequential Thinking (18-step analysis)

---

## Executive Summary

- **Total Risks Identified:** 21
- **Critical Risks (Score 9):** 0
- **High Risks (Score 6):** 3
- **Medium Risks (Score 4):** 5
- **Low Risks (Score 2-3):** 13
- **Overall Risk Score:** 19/100 (HIGH RISK STORY)
- **Gate Decision:** CONCERNS

**Key Finding:** This is a **high-risk story** due to the critical nature of CNI handover. The transition of Cilium management from bootstrap Helm to Flux GitOps involves the foundational networking layer for both clusters. Three HIGH-severity risks require mitigation before execution, particularly around pod disruption, cluster context confusion, and rollback procedures.

**Critical Success Factor:** Phase 3 (Flux Handover) concentrates 7 out of 21 risks and represents the highest-risk phase of the implementation. Maximum preparation and monitoring required.

---

## Critical Risks Requiring Immediate Attention

### 1. TECH-001: Pod Disruption During Handover

**Score: 6 (HIGH RISK)**
**Category:** Technical
**Probability:** Medium (2) - Helm handover strategies (adoption vs reinstall) have inherent risks
**Impact:** High (3) - CNI pod restarts = complete network outage for entire cluster

**Description:**
Despite planning for zero disruption (AC-4), the transition from bootstrap-managed Helm release to Flux HelmRelease could cause Cilium pods to restart. If the "reinstall" strategy is used instead of "adoption," all Cilium DaemonSet pods and the Operator will be recreated, causing a complete network outage.

**Affected Components:**
- Cilium DaemonSet (all nodes)
- Cilium Operator Deployment
- All pod-to-pod networking
- Service connectivity cluster-wide

**Why This Is Critical:**
Cilium is the CNI layer. If these pods restart:
- All new pod creation blocked (no IP allocation)
- Existing connections may drop
- DNS resolution fails
- Cross-node communication interrupted
- Entire cluster effectively offline until Cilium recovers

**Mitigation Strategy:** Preventive + Detective

**Actions Required:**
1. **Explicitly use Flux Helm adoption strategy** with `helm.toolkit.fluxcd.io/driftDetection: enabled` annotation
2. **Pre-handover baseline:** Document current pod UIDs, start times, restart counts
3. **Infra-first testing:** Execute handover on infra cluster first, validate zero disruptions before proceeding to apps
4. **Continuous monitoring:** Use `watch -n 1 'kubectl get pods -n kube-system -l k8s-app=cilium'` during handover
5. **Preserve bootstrap release:** Do NOT delete bootstrap Helm release until Flux adoption confirmed successful
6. **Immediate rollback ready:** Have `flux delete kustomization cilium-core` command prepared

**Testing Requirements:**
- **Pre-test:** Capture baseline metrics (pod UIDs, ages, restart counts, connection count)
- **During test:** Real-time monitoring with 1-second refresh, parallel connectivity test
- **Post-test:** Verify UIDs unchanged, restart counts = 0, no connection drops
- **Success criteria:** Zero pod recreations, all UIDs match pre-handover baseline

**Residual Risk:** Low (with adoption strategy)
**Owner:** Platform Engineering
**Timeline:** Phase 3.1 (strategy decision), Phase 3.2 (execution with monitoring)

---

### 2. TECH-002: Cluster Context Confusion

**Score: 6 (HIGH RISK)**
**Category:** Technical
**Probability:** Medium (2) - Human error during manual operations across two clusters
**Impact:** High (3) - Applying wrong configuration to wrong cluster = networking breakage

**Description:**
The story requires frequent switching between infra and apps clusters using `--context=infra` and `--context=apps` flags. Task 3.2 explicitly warns about this. Risk of applying infra cluster's configuration (POD_CIDR 10.244.0.0/16) to apps cluster (should be 10.246.0.0/16), causing catastrophic routing failures.

**Affected Components:**
- Both infra and apps clusters
- Network routing (CIDR mismatches)
- BGP configuration (ASN conflicts)
- ClusterMesh IPs (IP conflicts)

**Real-World Scenario:**
Operator executes `kubectl --context=infra apply -f cilium-core/ks.yaml` but terminal context is actually set to apps. Apps cluster now has infra's POD_CIDR (10.244.0.0/16) instead of its own (10.246.0.0/16). Result: routing black hole, pod networking fails.

**Why This Is Critical:**
Story line 504 explicitly warns: "Throughout this story you'll switch between infra and apps clusters... Verify your current context... to avoid applying changes to the wrong cluster."

**Mitigation Strategy:** Preventive

**Actions Required:**
1. **Install kubectx tool:** Visual display of current context
2. **Shell prompt modification:** Show current k8s context in PS1 prompt
3. **Mandatory explicit context flags:** Every kubectl/flux command MUST include `--context` flag
4. **Pre-command verification:** Before each phase, run `kubectl config current-context` and verbally confirm
5. **Separate terminals:** Use different terminal windows/tabs for infra vs apps operations (color-coded if possible)
6. **Pre-execution checklist:** Document which cluster each command targets, review before execution

**Testing Requirements:**
- **Practice run:** Execute story tasks in test environment with intentional context switches
- **Checklist validation:** Use Phase 0-5 checklists, add explicit context verification step
- **Post-execution audit:** After each phase, validate changes applied to correct cluster only

**Residual Risk:** Low (with multiple safeguards)
**Owner:** Operator executing story
**Timeline:** Continuous throughout Phases 0-5

---

### 3. OPS-001: Rollback Procedure Untested

**Score: 6 (HIGH RISK)**
**Category:** Operational
**Probability:** Medium (2) - Rollback procedures rarely tested until needed in production
**Impact:** High (3) - If handover fails AND rollback fails, cluster stuck in broken state with no CNI

**Description:**
Story documents rollback procedure in "Rollback Procedure" section (lines 513-517): remove Flux Kustomization, verify bootstrap Helm release exists, potentially reinstall via helmfile. However, this procedure has never been validated. Complex rollback paths are notoriously error-prone under pressure.

**Affected Components:**
- Disaster recovery capability
- Business continuity
- Cluster availability
- Bootstrap helmfile integrity

**Worst-Case Scenario:**
1. Flux handover fails (HelmRelease shows UpgradeFailed)
2. Operator executes rollback: `flux delete kustomization cilium-core`
3. Bootstrap Helm release was inadvertently deleted during handover
4. Cluster now has NO Cilium management (neither Flux nor bootstrap)
5. Network layer collapses
6. No clear recovery path without manual kubectl apply

**Why This Is Critical:**
This is a CNI handover. If rollback fails, the cluster has no functional network layer and is effectively dead. Manual recovery requires:
- Deep knowledge of Cilium manifests
- Access to correct Helm chart version
- Ability to apply manifests without a working network (chicken-and-egg)

**Mitigation Strategy:** Preventive + Corrective

**Actions Required:**
1. **Pre-handover documentation:** Write detailed rollback steps before Phase 3 execution
2. **Dev environment testing:** Test rollback in development/test environment if available
3. **Bootstrap validation:** Verify bootstrap helmfile still works: `helmfile -f bootstrap/helmfile.d/01-core.yaml -e infra diff`
4. **Backup bootstrap metadata:** Export bootstrap Helm release metadata before handover
5. **"Break glass" procedure:** Document manual kubectl apply procedure if both Flux AND bootstrap fail
6. **Recovery time objective:** Document expected time for full rollback (< 10 minutes target)

**Testing Requirements:**
- **Dry-run rollback:** Execute `flux delete kustomization cilium-core --dry-run=client` to preview impact
- **Helmfile validation:** Confirm bootstrap helmfile can still execute against cluster
- **Timed execution:** Measure actual time required for rollback in test environment
- **Success criteria:** Rollback completes < 10 minutes, cluster returns to functional state

**Residual Risk:** Medium (complex rollback, may require manual intervention)
**Owner:** Platform Engineering
**Timeline:** Phase 3.1 (before handover execution)

---

## Medium-Priority Risks (Score 4)

### 4. TECH-005: CRD Management Conflicts

**Score: 4 (MEDIUM)**
**Probability:** Medium (2) | **Impact:** Medium (2)

Bootstrap installs Gateway API CRDs, Cilium BGP CRDs, Cilium IPAM CRDs via Phase 0. Flux HelmRelease uses `install.crds: CreateReplace` and `upgrade.crds: CreateReplace`. If both systems try to manage CRDs simultaneously, conflicts possible.

**Mitigation:**
- Validate CRD ownership annotations before handover: `kubectl get crd -o yaml | grep -A5 metadata.annotations`
- Ensure CreateReplace policy documented and understood
- Monitor HelmRelease for CRD-related errors

**Residual Risk:** Low with proper validation

---

### 5. TECH-007: Cross-Cluster Configuration Drift

**Score: 4 (MEDIUM)**
**Probability:** Medium (2) | **Impact:** Medium (2)

Infra and apps clusters must have identical Cilium configuration except cluster-specific variables (CLUSTER, CLUSTER_ID, CIDRs, IPs, ASN). Risk of unintentional divergence through manual edits, copy-paste errors, or independent modifications.

**Example Drift Scenario:**
- Infra cluster gets kubeProxyReplacement: "true" (correct)
- Apps cluster gets kubeProxyReplacement: "false" (accidental typo)
- Result: Inconsistent behavior, troubleshooting nightmare

**Mitigation:**
- Automated comparison script in Phase 4.4: `helm --kube-context=infra -n kube-system get values cilium > /tmp/infra-values.yaml && helm --kube-context=apps -n kube-system get values cilium > /tmp/apps-values.yaml && diff /tmp/infra-values.yaml /tmp/apps-values.yaml`
- Fail validation if non-cluster-specific differences found
- Enforce templating patterns (single source HelmRelease, cluster-specific substitutions)

**Residual Risk:** Low with automated validation

---

### 6. SEC-004: BGP Peer Authentication Missing

**Score: 4 (MEDIUM)**
**Probability:** Medium (2) | **Impact:** Medium (2)

Story enables BGP Control Plane (line 38: "BGP Control Plane enabled from day 1"). Cluster-settings define BGP peer (CILIUM_BGP_PEER_ASN=64501, CILIUM_BGP_PEER_ADDRESS=10.25.11.1/32). However, BGP peer authentication/authorization not configured in this story, deferred to STORY-NET-CILIUM-BGP.

**Attack Scenario:**
Rogue BGP peer at 10.25.11.1 advertises incorrect routes, hijacks traffic destined for cluster services.

**Mitigation:**
- Document as explicit dependency for STORY-NET-CILIUM-BGP
- Include BGP authentication (MD5 or TCP-AO) in BGP story's security requirements
- Network-level controls: BGP peer IP should be protected by firewall rules

**Residual Risk:** Medium (deferred to future story, requires downstream attention)

---

### 7. OPS-002: Monitoring Gap During Handover

**Score: 4 (MEDIUM)**
**Probability:** Medium (2) | **Impact:** Medium (2)

Phase 3.2 monitors pod status (`watch kubectl get pods`), but doesn't explicitly monitor actual network traffic, connection drops, or Cilium metrics during transition window. Silent failures possible.

**What Could Be Missed:**
- Connection drops (existing flows reset)
- Policy enforcement gaps (brief window where policies unenforced)
- Encryption failures (WireGuard briefly disabled)
- Performance degradation (latency spikes)

**Mitigation:**
- Pre-handover setup: Configure comprehensive monitoring dashboard
- Monitor Cilium metrics: connections count, policy drops, encryption status
- Use Hubble to watch flows: `hubble observe --follow` during handover
- Parallel connectivity test: Keep ping/curl running between test pods throughout

**Residual Risk:** Low with enhanced monitoring

---

### 8. BUS-001: Timeline Dependency Blocking

**Score: 4 (MEDIUM)**
**Probability:** Medium (2) | **Impact:** Medium (2)

Story is #2/41 in sequence, blocks 5 downstream stories (External Secrets, BGP, Gateway, IPAM, ClusterMesh). Estimated 60 minutes for handover per cluster (120 minutes total), but complex handovers often exceed estimates.

**Mitigation:**
- Allocate buffer time in project schedule
- Identify parallel workstreams: If blocked, team can work on documentation/planning for downstream stories
- Greenfield advantage: Flexible schedule, no production pressure

**Residual Risk:** Low (greenfield has schedule flexibility)

---

## Low-Priority Risks (Score 2-3)

### Technical Risks

**TECH-003: Substitution Variable Failures (Score: 3)**
${CLUSTER}, ${CLUSTER_ID}, ${POD_CIDR_STRING} might not resolve. Mitigated by AC-3 explicit validation.

**TECH-004: Dependency Chain Break (Score: 3)**
CoreDNS, cert-manager, Flux depend on Cilium. Mitigated by health checks, AC-9 integration validation.

**TECH-006: OCI Repository Accessibility (Score: 3)**
ghcr.io/home-operations/charts-mirror/cilium unreachable = no updates. Mitigated by internal mirror stability, Task 2.1 verification.

**TECH-008: kubeconform Validation False Negatives (Score: 2)**
kubeconform might miss runtime issues. Mitigated by additional `flux build` validation in Phase 2.5.

**TECH-009: Flux Source Git Access (Score: 3)**
If Flux can't reach Git, GitOps stops. Mitigated by bootstrap validation, flux get sources git check.

**TECH-010: Cluster-Settings ConfigMap Missing (Score: 3)**
If cluster-settings.yaml missing, all substitutions fail. Mitigated by explicit Phase 0 prerequisite tasks.

**TECH-011: ClusterMesh IP Conflicts (Score: 2)**
CLUSTERMESH_IP allocation conflicts. Low risk in greenfield, validated in downstream ClusterMesh story.

### Security Risks

**SEC-001: WireGuard Encryption Failure During Handover (Score: 3)**
Encryption config disrupted during handover. Mitigated by Phase 1.2 and Phase 4 validation.

**SEC-002: Network Policy Enforcement Gap (Score: 3)**
If Cilium pods restart, policies briefly unenforced. Mitigated by zero-disruption handover strategy.

**SEC-003: Secrets Exposure in Git (Score: 2)**
HelmRelease values might contain secrets. Mitigated by External Secrets Operator pattern.

**SEC-005: BGP ASN Conflict (Score: 3)**
Infra ASN 64512, apps ASN 64513 with shared peer ASN 64501. Validated in STORY-NET-CILIUM-BGP.

### Performance Risks

**PERF-001: Flux Reconciliation Storm (Score: 1)**
Both clusters reconciling simultaneously. Self-resolving, Flux designed for this.

**PERF-002: Health Check Timeout Too Aggressive (Score: 2)**
10m timeout might be too short. Mitigated by generous timeout setting.

**PERF-003: Spegel Hostport Conflict (Score: 2)**
Spegel HostPort 29999 vs Cilium ports. Mitigated by different port assignments, Phase 4.5 validation.

**PERF-004: WireGuard Encryption Overhead (Score: 1)**
CPU overhead from encryption. Acceptable trade-off for security.

### Data Risks

**DATA-001: Cilium State Loss During Handover (Score: 3)**
IPAM, identity store, connection tracking could reset. Mitigated by adoption strategy (not reinstall).

**DATA-002: Configuration Drift Accumulation (Score: 2)**
Manual changes persist if drift detection broken. Mitigated by Phase 4.1 explicit drift test.

**DATA-003: Bootstrap Values Not Captured (Score: 2)**
No baseline if Phase 1.5 skipped. Mitigated by explicit Phase 1 task.

**DATA-004: Git History Loss (Score: 1)**
Force-push loses audit trail. Mitigated by standard Git practices.

### Business Risks

**BUS-002: Team Confidence Loss in GitOps (Score: 3)**
Failed handover derails GitOps strategy. Mitigated by well-planned execution, rollback procedure.

**BUS-003: Documentation Inadequacy (Score: 2)**
Incomplete documentation impacts Day-2 ops. Mitigated by AC-10, Phase 5.2 explicit tasks.

### Operational Risks

**OPS-003: Manual Helm Release Left Behind (Score: 2)**
Bootstrap release remains after handover. Mitigated by Phase 5.1 cleanup check.

**OPS-004: Phase 0 Directory Structure Omission (Score: 3)**
Missing directories block resource creation. Mitigated by Phase 0 explicit prerequisite.

**OPS-005: Health Check Simulation Destructive Testing (Score: 3)**
Scaling cilium to 0 could orphan cluster. Mitigated by controlled test, immediate revert.

**OPS-006: Sequential vs Parallel Cluster Handover (Score: 2)**
Infra succeeds, apps fails = inconsistent state. Mitigated by Phase 4.4 validation between clusters.

---

## Risk Distribution

### By Category

| Category | Total | Critical (9) | High (6) | Medium (4) | Low (2-3) |
|----------|-------|--------------|----------|------------|-----------|
| Technical (TECH) | 11 | 0 | 2 | 2 | 7 |
| Security (SEC) | 5 | 0 | 0 | 1 | 4 |
| Performance (PERF) | 4 | 0 | 0 | 0 | 4 |
| Data (DATA) | 4 | 0 | 0 | 0 | 4 |
| Business (BUS) | 3 | 0 | 0 | 1 | 2 |
| Operational (OPS) | 6 | 0 | 1 | 1 | 4 |

**Key Insight:** Technical and Operational categories dominate risk profile, which is expected for infrastructure-layer changes.

### By Component

| Component | Risk Count | High Risks |
|-----------|------------|------------|
| Cilium Core (DaemonSet/Operator) | 8 | TECH-001 |
| Flux GitOps Layer | 6 | TECH-002, OPS-001 |
| Multi-Cluster Coordination | 4 | - |
| Configuration Management | 5 | - |
| Monitoring/Observability | 3 | OPS-002 |
| Integration (Spegel, CoreDNS, etc.) | 3 | - |
| Downstream Dependencies | 2 | - |

### By Phase

| Phase | Description | Risk Count | Critical Risks |
|-------|-------------|------------|----------------|
| Phase 0 | Prerequisites & Directory Structure | 2 | - |
| Phase 1 | Pre-Work & Validation | 3 | - |
| Phase 2 | GitOps Resource Creation | 4 | - |
| **Phase 3** | **Flux Handover** | **7** | **TECH-001, TECH-002, OPS-001** |
| Phase 4 | Post-Handover Validation | 3 | - |
| Phase 5 | Cleanup & Documentation | 2 | - |

**Critical Finding:** Phase 3 (Flux Handover) concentrates 33% of all risks and contains ALL three HIGH-severity risks. This phase requires maximum preparation, monitoring, and execution discipline.

---

## Risk-Based Testing Strategy

### Priority 1: Critical/High Risk Tests (MUST EXECUTE)

#### Test 1: Zero Pod Disruption Test (TECH-001)

**Risk Addressed:** Pod Disruption During Handover
**Priority:** P0 (Blocking)

**Procedure:**
1. **Pre-test:** Record all pod UIDs, start times, restart counts
   ```bash
   kubectl --context=infra -n kube-system get pods -l k8s-app=cilium -o json | jq -r '.items[] | "\(.metadata.name) \(.metadata.uid) \(.status.startTime) \(.status.containerStatuses[0].restartCount)"' > /tmp/cilium-pods-baseline.txt
   ```
2. **During test:** Continuous monitoring with 1-second refresh
   ```bash
   watch -n 1 'kubectl --context=infra -n kube-system get pods -l k8s-app=cilium'
   ```
3. **Post-test:** Compare UIDs, verify restart counts = 0
   ```bash
   kubectl --context=infra -n kube-system get pods -l k8s-app=cilium -o json | jq -r '.items[] | "\(.metadata.name) \(.metadata.uid) \(.status.startTime) \(.status.containerStatuses[0].restartCount)"' > /tmp/cilium-pods-post.txt
   diff /tmp/cilium-pods-baseline.txt /tmp/cilium-pods-post.txt
   ```

**Success Criteria:**
- Zero UIDs changed (no pod recreations)
- All restart counts remain at pre-handover values
- Pod start times unchanged

**Failure Response:** STOP immediately, investigate, execute rollback

---

#### Test 2: Cluster Context Validation Test (TECH-002)

**Risk Addressed:** Cluster Context Confusion
**Priority:** P0 (Blocking)

**Procedure:**
1. Before each phase, verify context:
   ```bash
   echo "Current context: $(kubectl config current-context)"
   read -p "Expected context is 'infra'. Confirm? (yes/no): " confirm
   [[ "$confirm" != "yes" ]] && echo "ABORT" && exit 1
   ```
2. Test intentional context switch (in test environment):
   - Set context to apps
   - Attempt to apply infra configuration
   - Verify detection and prevention

**Success Criteria:**
- Context verification prevents misapplication
- All commands include explicit --context flags
- No accidental cross-cluster configuration

**Failure Response:** Add additional safeguards, implement shell aliases

---

#### Test 3: Rollback Procedure Test (OPS-001)

**Risk Addressed:** Rollback Procedure Untested
**Priority:** P0 (Blocking)

**Procedure:**
1. In test/dev environment, execute full handover
2. Simulate failure: Manually break HelmRelease
3. Execute documented rollback procedure:
   ```bash
   flux delete kustomization cilium-core
   helm -n kube-system list | grep cilium
   helmfile -f bootstrap/helmfile.d/01-core.yaml -e infra sync
   ```
4. Measure time to restoration
5. Validate cluster returns to functional state

**Success Criteria:**
- Rollback completes < 10 minutes
- Cluster networking fully functional post-rollback
- All Cilium features restored (WireGuard, BGP, Gateway API)

**Failure Response:** Refine rollback procedure, add "break glass" manual steps

---

### Priority 2: Medium Risk Tests (SHOULD EXECUTE)

#### Test 4: Cross-Cluster Consistency Test (TECH-007)

**Procedure:**
```bash
helm --kube-context=infra -n kube-system get values cilium > /tmp/infra-values.yaml
helm --kube-context=apps -n kube-system get values cilium > /tmp/apps-values.yaml
diff /tmp/infra-values.yaml /tmp/apps-values.yaml | grep -v "CLUSTER\|CLUSTER_ID\|POD_CIDR\|SERVICE_CIDR\|CLUSTERMESH_IP\|CILIUM_GATEWAY_LB_IP\|BGP_LOCAL_ASN"
```

**Success Criteria:** Only cluster-specific variables differ

---

#### Test 5: Drift Detection Test (DATA-002)

**Procedure:**
```bash
kubectl --context=infra -n kube-system patch helmrelease cilium --type=json -p='[{"op":"add","path":"/spec/values/test","value":"manual-change"}]'
flux --context=infra reconcile helmrelease -n kube-system cilium
# Wait 2 minutes for reconciliation
kubectl --context=infra -n kube-system get helmrelease cilium -o yaml | grep -q "test: manual-change" && echo "FAIL: Drift detection not working" || echo "PASS: Manual change reverted"
```

**Success Criteria:** Manual change removed, Git values restored within reconciliation interval

---

#### Test 6: CRD Lifecycle Test (TECH-005)

**Procedure:**
```bash
kubectl get crd gateways.gateway.networking.k8s.io -o yaml | grep -A10 metadata.annotations
kubectl get crd ciliumbgppeeringpolicies.cilium.io -o yaml | grep -A10 metadata.annotations
# Verify single owner (Flux), no duplicate installations
```

**Success Criteria:** All CRDs show Flux as manager, versions consistent, no conflicts

---

### Priority 3: Integration Tests (SHOULD EXECUTE)

#### Test 7: Network Connectivity Test

**Procedure:**
```bash
# Deploy test pods BEFORE handover
kubectl run test-pod-1 --image=nginx --context=infra
kubectl run test-pod-2 --image=nginx --context=infra
# During handover, continuous connectivity test
while true; do
  kubectl exec test-pod-1 --context=infra -- ping -c 1 test-pod-2 || echo "CONNECTIVITY FAILURE at $(date)"
  sleep 1
done
```

**Success Criteria:** Zero connection failures during handover window

---

#### Test 8: WireGuard Encryption Validation (SEC-001)

**Procedure:**
```bash
# Before handover
kubectl --context=infra -n kube-system exec ds/cilium -- cilium status | grep Encryption
# During handover (repeat every 10 seconds)
# After handover
kubectl --context=infra -n kube-system exec ds/cilium -- cilium status | grep Encryption
```

**Success Criteria:** "Wireguard [NodeEncryption: Disabled]" shown consistently, no encryption downgrade

---

#### Test 9: Health Check Simulation (OPS-005)

**Procedure:**
```bash
# Record initial state
kubectl --context=infra -n kube-system get ds cilium -o jsonpath='{.status.desiredNumberScheduled}' > /tmp/cilium-desired-replicas.txt
# Simulate failure
kubectl --context=infra -n kube-system scale ds cilium --replicas=0
# Monitor Flux detection
flux --context=infra get kustomization cilium-core
# Should show HealthCheckFailed
# Restore
kubectl --context=infra -n kube-system scale ds cilium --replicas=$(cat /tmp/cilium-desired-replicas.txt)
# Verify Flux returns to Ready
flux --context=infra get kustomization cilium-core
```

**Success Criteria:** Flux detects unhealthy state, returns to Ready after restoration

---

### Priority 4: Validation Tests (MUST EXECUTE)

#### Test 10: Substitution Variable Test (TECH-003)

**Procedure:**
```bash
helm --kube-context=infra -n kube-system get values cilium | yq e '.cluster.name'  # Should be "infra"
helm --kube-context=infra -n kube-system get values cilium | yq e '.cluster.id'    # Should be 1
helm --kube-context=infra -n kube-system get values cilium | yq e '.ipv4NativeRoutingCIDR'  # Should be "10.244.0.0/16"

helm --kube-context=apps -n kube-system get values cilium | yq e '.cluster.name'  # Should be "apps"
helm --kube-context=apps -n kube-system get values cilium | yq e '.cluster.id'    # Should be 2
helm --kube-context=apps -n kube-system get values cilium | yq e '.ipv4NativeRoutingCIDR'  # Should be "10.246.0.0/16"
```

**Success Criteria:** All substitutions resolve correctly per cluster-settings

---

#### Test 11: Git Canonicality Test (AC-6)

**Procedure:**
1. Make safe change in Git (add comment to HelmRelease)
2. Commit and push
3. Trigger reconciliation: `flux --context=infra reconcile source git flux-system --with-source`
4. Verify change applied: `kubectl --context=infra -n kube-system get helmrelease cilium -o yaml`
5. Measure time from commit to cluster update

**Success Criteria:** Change applied < 5 minutes, no manual intervention needed

---

## Monitoring Requirements

### Pre-Handover Baseline Metrics

**Capture Before Phase 3 Execution:**

1. **Cilium Pod Inventory:**
   ```bash
   kubectl --context=infra -n kube-system get pods -l k8s-app=cilium -o wide > /tmp/cilium-baseline-infra.txt
   kubectl --context=infra -n kube-system get pods -l k8s-app=cilium -o json | jq -r '.items[] | "\(.metadata.uid)"' > /tmp/cilium-uids-infra.txt
   ```

2. **Connection Count:**
   ```bash
   kubectl --context=infra -n kube-system exec ds/cilium -- cilium bpf ct list global | wc -l > /tmp/cilium-connections-baseline.txt
   ```

3. **IPAM Allocations:**
   ```bash
   kubectl --context=infra -n kube-system exec ds/cilium -- cilium bpf ipam list > /tmp/cilium-ipam-baseline.txt
   ```

4. **Policy Status:**
   ```bash
   kubectl --context=infra -n kube-system exec ds/cilium -- cilium policy get > /tmp/cilium-policy-baseline.txt
   ```

5. **Encryption Status:**
   ```bash
   kubectl --context=infra -n kube-system exec ds/cilium -- cilium status | grep Encryption > /tmp/cilium-encryption-baseline.txt
   ```

6. **Current Helm Release:**
   ```bash
   helm --kube-context=infra -n kube-system list > /tmp/helm-releases-baseline.txt
   ```

---

### During Handover Real-Time Monitoring

**Run Continuously During Phase 3.2:**

1. **Pod Status (Terminal 1):**
   ```bash
   watch -n 1 'kubectl --context=infra -n kube-system get pods -l k8s-app=cilium -o wide'
   ```

2. **Flux Reconciliation (Terminal 2):**
   ```bash
   flux --context=infra get kustomizations -A --watch
   ```

3. **HelmRelease Status (Terminal 3):**
   ```bash
   kubectl --context=infra -n kube-system get helmrelease cilium -w
   ```

4. **Cilium Agent Logs (Terminal 4):**
   ```bash
   kubectl --context=infra -n kube-system logs -f ds/cilium -c cilium-agent
   ```

5. **Connection Monitoring (Terminal 5):**
   ```bash
   # If Hubble available
   hubble observe --follow
   # Or continuous connectivity test
   while true; do kubectl exec test-pod --context=infra -- curl -s test-service && echo "OK" || echo "FAIL at $(date)"; sleep 1; done
   ```

6. **Metrics Watch (Terminal 6):**
   ```bash
   watch -n 5 'kubectl --context=infra -n kube-system exec ds/cilium -- cilium status'
   ```

---

### Post-Handover Validation Metrics

**Capture After Phase 3 Completion:**

1. **Pod Comparison:**
   ```bash
   kubectl --context=infra -n kube-system get pods -l k8s-app=cilium -o json | jq -r '.items[] | "\(.metadata.uid)"' > /tmp/cilium-uids-post.txt
   diff /tmp/cilium-uids-infra.txt /tmp/cilium-uids-post.txt
   # Should be identical
   ```

2. **Connection Count:**
   ```bash
   kubectl --context=infra -n kube-system exec ds/cilium -- cilium bpf ct list global | wc -l > /tmp/cilium-connections-post.txt
   BASELINE=$(cat /tmp/cilium-connections-baseline.txt)
   POST=$(cat /tmp/cilium-connections-post.txt)
   # Allow ±10% variance
   ```

3. **IPAM Allocations (Should Be Identical):**
   ```bash
   kubectl --context=infra -n kube-system exec ds/cilium -- cilium bpf ipam list > /tmp/cilium-ipam-post.txt
   diff /tmp/cilium-ipam-baseline.txt /tmp/cilium-ipam-post.txt
   ```

4. **Flux Status:**
   ```bash
   flux --context=infra get kustomization cilium-core
   # Should show: Ready: True
   ```

5. **Drift Detection:**
   ```bash
   flux --context=infra diff kustomization cilium-core --path ./kubernetes/infrastructure/networking/cilium/core
   # Should show: no differences
   ```

6. **Performance Baseline:**
   ```bash
   # Test pod-to-pod latency
   kubectl exec test-pod-1 --context=infra -- ping -c 100 test-pod-2 | tail -1
   # Compare to pre-handover baseline, should be within 10%
   ```

---

### Ongoing Monitoring (Day 2+)

**Continuous Monitoring Post-Story:**

1. **Flux Reconciliation Health:**
   - Alert: HelmRelease `cilium` shows `Ready: False` for > 5 minutes
   - Alert: Kustomization `cilium-core` shows `HealthCheckFailed`

2. **Cilium Operational Health:**
   - Alert: Cilium DaemonSet not ready on any node
   - Alert: Cilium Operator Deployment not ready
   - Alert: Encryption status changes from "Wireguard"

3. **Configuration Drift Detection:**
   - Daily cron: `flux diff kustomization cilium-core`
   - Alert: Drift detected for > 1 hour

4. **Performance Monitoring:**
   - Track: Network latency (p50, p95, p99)
   - Track: Connection count trends
   - Alert: Latency increase > 20% sustained

5. **Security Monitoring:**
   - Alert: NetworkPolicy violations (Hubble)
   - Alert: Unexpected BGP peer connections
   - Alert: WireGuard encryption failures

---

### Alert Thresholds

| Severity | Condition | Threshold | Response |
|----------|-----------|-----------|----------|
| **Critical** | Cilium pods not ready | Any node missing ready Cilium pod | Immediate investigation, page on-call |
| **Critical** | Network connectivity loss | > 1% packet loss | Immediate investigation, page on-call |
| **High** | Flux reconciliation failing | > 3 failed attempts | Investigation within 30 minutes |
| **High** | Encryption disabled | Encryption status != "Wireguard" | Investigation within 1 hour |
| **Medium** | Configuration drift | Drift detected > 1 hour | Investigation within 4 hours |
| **Medium** | Slow reconciliation | Reconciliation time > 10 minutes | Review at next maintenance window |
| **Low** | Performance degradation | Latency increase > 10% | Review at next team meeting |

---

## Risk Acceptance Criteria

### Must Fix Before Production (Blockers)

**These risks BLOCK story completion if not addressed:**

1. **TECH-001 Mitigation:** Implement Helm adoption strategy (not reinstall) to prevent pod disruption
   - **Validation:** Phase 3.1 strategy decision documented, adoption annotations present
   - **Blocker rationale:** CNI disruption = cluster outage

2. **TECH-002 Mitigation:** Establish context verification safeguards for cluster operations
   - **Validation:** Shell prompt shows context, checklist includes context verification
   - **Blocker rationale:** Wrong cluster configuration = catastrophic failure

3. **OPS-001 Mitigation:** Document and test rollback procedure before handover execution
   - **Validation:** Rollback tested in dev environment OR dry-run documented with expected outcomes
   - **Blocker rationale:** No recovery path = unacceptable risk

4. **OPS-002 Mitigation:** Set up comprehensive monitoring dashboard pre-handover
   - **Validation:** All 6 monitoring terminals ready before Phase 3.2 execution
   - **Blocker rationale:** Blind execution = silent failures undetected

5. **TECH-010 Mitigation:** Validate cluster-settings ConfigMaps exist and are correct
   - **Validation:** Phase 0.4 checklist complete, both cluster-settings.yaml validated
   - **Blocker rationale:** Missing substitutions = complete deployment failure

---

### Can Deploy with Mitigation (Acceptable with Controls)

**These risks are acceptable if mitigations are in place:**

1. **TECH-005 (CRD Conflicts):** Acceptable if CreateReplace policy documented and CRD ownership validated pre-handover

2. **TECH-007 (Configuration Drift):** Acceptable with Phase 4.4 cross-cluster validation passing and automated comparison script operational

3. **SEC-004 (BGP Auth Missing):** Acceptable as out of scope for this story, explicitly addressed in STORY-NET-CILIUM-BGP downstream

4. **BUS-001 (Timeline Delays):** Acceptable in greenfield context with schedule buffer allocated

5. **OPS-006 (Sequential Handover):** Acceptable with validation checkpoint between infra and apps cluster handovers

---

### Accepted Risks (Low Probability × Impact)

**These risks are accepted without additional mitigation:**

1. **PERF-001:** Flux reconciliation storm - Self-resolving, Flux designed for concurrent reconciliation
2. **PERF-004:** WireGuard encryption overhead - Acceptable trade-off for security
3. **DATA-003:** Bootstrap values not captured - Mitigated by explicit Phase 1.5 task
4. **DATA-004:** Git history loss - Standard Git practices sufficient
5. **All remaining Low (score 2-3) and Minimal (score 1) risks** - Probability too low or impact too minor to require specific mitigation beyond existing controls

---

### Waiver Requirements

**Conditions under which waivers may be requested:**

1. **Rollback Testing Waiver (OPS-001):**
   - **If:** No dev/test environment available for rollback testing
   - **Required:** Platform Engineering Lead + SRE Manager sign-off
   - **Compensating controls:** Detailed rollback runbook with step-by-step commands, "break glass" manual recovery procedure, on-call engineer availability during handover

2. **Production Timeline Pressure:**
   - **No waivers recommended** - All HIGH risks (TECH-001, TECH-002, OPS-001) must be mitigated
   - If attempted without mitigation → Gate remains FAIL

**Waiver Authority:**
- HIGH risks: Requires VP Engineering or CTO approval
- MEDIUM risks: Platform Engineering Lead approval sufficient
- LOW risks: No waiver needed (accepted by default)

---

### Sign-Off Requirements

**Required Approvals Before Phase 3 Execution:**

| Role | Responsibility | Approval Required For |
|------|----------------|----------------------|
| **Platform Engineering Lead** | Handover execution strategy | All HIGH risk mitigations |
| **SRE/Operations Lead** | Rollback procedure adequacy | OPS-001 mitigation |
| **Security Lead** | Encryption and network policy validation | SEC-001, SEC-002 mitigation |
| **Project Manager** | Timeline and dependency management | BUS-001 acceptance |

---

## Risk Recommendations

### Must Fix (Before Phase 3 Execution)

1. **Implement Helm Adoption Strategy**
   - Add `helm.toolkit.fluxcd.io/driftDetection: enabled` annotation to HelmRelease
   - Document adoption vs reinstall decision in Phase 3.1
   - Validation: Review HelmRelease manifest before applying

2. **Establish Context Verification Safeguards**
   - Install kubectx/kubens tools: `brew install kubectx` (macOS) or equivalent
   - Modify shell prompt to show current context: Add `export PS1='[\u@\h \W ($(kubectl config current-context))]\$ '` to ~/.bashrc
   - Create pre-phase checklist requiring explicit context confirmation
   - Validation: Test context switch detection in non-prod environment

3. **Document and Test Rollback Procedure**
   - Write detailed rollback runbook in Phase 3.1
   - Validate bootstrap helmfile still executable: `helmfile -f bootstrap/helmfile.d/01-core.yaml -e infra diff`
   - If dev environment available, execute full rollback test
   - If dev unavailable, document expected outcomes for each rollback step
   - Validation: Rollback runbook reviewed by SRE team

4. **Set Up Comprehensive Monitoring**
   - Prepare 6 terminal windows/tmux panes with monitoring commands
   - Test all monitoring commands before Phase 3.2
   - Document what "normal" vs "failure" looks like for each metric
   - Validation: Monitoring dashboard functional before handover

### Should Monitor (During and After Implementation)

1. **Cross-Cluster Configuration Consistency**
   - Execute Phase 4.4 validation after each cluster handover
   - Automate comparison: Create script to diff helm values between clusters
   - Alert on any non-cluster-specific differences
   - Frequency: Daily for first week, weekly thereafter

2. **CRD Management Transitions**
   - Monitor HelmRelease events for CRD-related errors
   - Check CRD ownership annotations post-handover
   - Document CRD versions before and after handover
   - Frequency: Once post-handover, then before Cilium upgrades

3. **Timeline Progress**
   - Track actual time vs estimates for each phase
   - If Phase 3 exceeds 90 minutes (50% over estimate), reassess downstream schedule
   - Maintain buffer time for unexpected issues
   - Frequency: Daily during story execution

4. **Network Performance**
   - Establish baseline latency metrics pre-handover
   - Monitor for performance degradation during handover
   - Compare post-handover metrics to baseline
   - Alert if latency increases > 20%
   - Frequency: Continuous during handover, hourly for 24 hours post-handover

5. **Flux Drift Detection**
   - Run `flux diff kustomization cilium-core` daily
   - Investigate any detected drift immediately
   - Document source of drift (manual change, automation, etc.)
   - Frequency: Daily automated check with alerting

---

## Risk Review Triggers

**Review and update this risk profile when:**

1. **Any Pod Restart Detected During Handover**
   - Trigger: Monitoring detects pod UID change or restart count increase
   - Action: STOP handover immediately, investigate root cause, update risk profile with findings
   - Responsibility: Platform Engineering team lead

2. **Rollback Procedure Needs Execution**
   - Trigger: Phase 3 handover fails, rollback initiated
   - Action: Document actual rollback experience, update OPS-001 mitigation with lessons learned
   - Responsibility: Operator who executed rollback

3. **After Each Cluster Handover**
   - Trigger: Completion of Phase 3 on infra cluster (before proceeding to apps)
   - Action: Validate all HIGH and MEDIUM risks were mitigated as planned, adjust strategy for apps cluster if needed
   - Responsibility: Platform Engineering team lead

4. **Post-Story Completion**
   - Trigger: Phase 5 complete, all acceptance criteria met
   - Action: Update risk profile with actual outcomes, note which risks materialized vs didn't, update probability estimates
   - Responsibility: Test Architect (Quinn)

5. **Architecture Changes Significantly**
   - Trigger: Cilium version upgrade, new feature enablement (BGP, Gateway API, ClusterMesh), or cluster topology changes
   - Action: Re-evaluate all Technical and Security risks, identify new risks
   - Responsibility: Architecture team + Test Architect

6. **New Integrations Added**
   - Trigger: Additional components integrating with Cilium (service mesh, observability agents, network policies)
   - Action: Assess integration risks, update TECH-004 and related risks
   - Responsibility: Platform Engineering + Test Architect

7. **Security Vulnerabilities Discovered**
   - Trigger: CVE published for Cilium, WireGuard, or related components
   - Action: Reassess SEC-001, SEC-002, SEC-004, determine if emergency patching required
   - Responsibility: Security team + Platform Engineering

8. **Performance Issues Reported**
   - Trigger: User complaints, monitoring alerts for latency/throughput degradation
   - Action: Review PERF-001 through PERF-004, assess if WireGuard overhead or other performance risks materialized
   - Responsibility: SRE team + Platform Engineering

9. **Regulatory Requirements Change**
   - Trigger: New compliance requirements (SOC 2, HIPAA, GDPR updates)
   - Action: Reassess all Security and Data risks, validate encryption and audit trail requirements
   - Responsibility: Compliance team + Security team

---

## Conclusion

This is a **HIGH-RISK story** (score 19/100) requiring **CONCERNS gate status** due to the critical nature of CNI handover across two clusters. The story involves transitioning foundational networking infrastructure from imperative bootstrap to declarative GitOps management.

### Key Takeaways

1. **Three HIGH-severity risks (score 6)** require mandatory mitigation before Phase 3 execution:
   - TECH-001: Pod disruption during handover (use adoption strategy)
   - TECH-002: Cluster context confusion (implement verification safeguards)
   - OPS-001: Rollback procedure untested (document and validate)

2. **Phase 3 concentrates 33% of all risks** and contains ALL three HIGH-severity risks. Maximum preparation essential.

3. **Zero-disruption handover is critical** - any Cilium pod restart = cluster-wide network outage. Adoption strategy and continuous monitoring non-negotiable.

4. **Multi-cluster coordination adds complexity** - sequential handover (infra first, then apps) with validation checkpoints required.

5. **Comprehensive monitoring during handover** is essential to detect silent failures. Six concurrent monitoring streams recommended.

6. **Tested rollback procedure** is insurance policy for this high-risk operation. Validates recovery capability before execution.

### Gate Recommendation

**Gate Status: CONCERNS**

**Rationale:**
- 3 HIGH-severity risks (score 6) present
- Per deterministic gate mapping: "Else if any score ≥ 6 → Gate = CONCERNS"
- All HIGH risks have actionable mitigations
- No CRITICAL risks (score 9) that would trigger FAIL

**Conditions for PASS:**
- All HIGH risk mitigations implemented and validated
- Monitoring infrastructure in place
- Rollback procedure documented and tested (or dry-run with sign-off)
- Context verification safeguards operational
- Platform Engineering Lead sign-off obtained

**Path Forward:**
This story can proceed to implementation after HIGH-risk mitigations are in place. The comprehensive task breakdown (70+ subtasks across 6 phases) demonstrates thoughtful planning. Success depends on disciplined execution, particularly in Phase 3.

---

**Risk Profile Document:** `docs/qa/assessments/STORY-NET-CILIUM-CORE-GITOPS-risk-20251025.md`
**Next Review Date:** Post-Phase 3 completion (after handover)
**Document Owner:** Quinn (Test Architect)
