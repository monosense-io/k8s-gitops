# EPIC-1: Talos Multi-Cluster Bootstrap
**Goal:** Split single 6-node cluster into two 3-node clusters
**Status:** ✅ 90% Complete (configs done, deployment pending)

## Story 1.1: Prepare Talos Configuration ✅
**Priority:** P0 | **Points:** 3 | **Days:** 1 | **Status:** ✅ COMPLETE

**Acceptance Criteria:**
- [x] `convert-to-multicluster.sh` script executed successfully
- [x] Node configs moved to `talos/infra/` and `talos/apps/`
- [x] Hostnames updated (infra-01, infra-02, infra-03, apps-01, apps-02, apps-03)
- [x] `machineconfig.yaml.j2` updated with cluster parameterization
- [x] Taskfiles updated with CLUSTER parameter support
- [x] machineconfig.yaml.j2 validated with `talosctl validate`

**Tasks:**
- Run `./scripts/convert-to-multicluster.sh`
- Update `talos/machineconfig.yaml.j2` with cluster variables
- Update `.taskfiles/talos/Taskfile.yaml` apply-node task
- Update `.taskfiles/bootstrap/Taskfile.yaml` bootstrap tasks
- Test config generation: `minijinja-cli ... | op inject | talosctl validate`

**Files Created/Modified:**
- ✅ `talos/infra/10.25.11.11.yaml`
- ✅ `talos/infra/10.25.11.12.yaml`
- ✅ `talos/infra/10.25.11.13.yaml`
- ✅ `talos/apps/10.25.11.14.yaml`
- ✅ `talos/apps/10.25.11.15.yaml`
- ✅ `talos/apps/10.25.11.16.yaml`
- ✅ `talos/machineconfig-multicluster.yaml.j2`
- ✅ `.taskfiles/talos/Taskfile.yaml`
- ✅ `.taskfiles/bootstrap/Taskfile.yaml`

---

## Story 1.2: Generate Cluster Secrets ⚠️
**Priority:** P0 | **Points:** 2 | **Days:** 0.5 | **Status:** ⚠️ PARTIALLY COMPLETE

**Acceptance Criteria:**
- [ ] Secrets generated for infra cluster
- [ ] Secrets generated for apps cluster
- [ ] Secrets imported to 1Password (infra-talos item)
- [ ] Secrets imported to 1Password (apps-talos item)
- [ ] `op inject` tested and working

**Tasks:**
- Run `talosctl gen secrets -o /tmp/infra-secrets.yaml`
- Run `talosctl gen secrets -o /tmp/apps-secrets.yaml`
- Run `./scripts/extract-talos-secrets.sh /tmp/infra-secrets.yaml infra`
- Execute `op item create` command for infra
- Run `./scripts/extract-talos-secrets.sh /tmp/apps-secrets.yaml apps`
- Execute `op item create` command for apps
- Test: `echo "op://Prod/infra-talos/MACHINE_TOKEN" | op inject`

**Files Created:**
- `/tmp/infra-secrets.yaml` (temporary)
- `/tmp/apps-secrets.yaml` (temporary)
- 1Password items: `infra-talos`, `apps-talos`

---

## Story 1.3: Bootstrap Both Clusters
**Priority:** P0 | **Points:** 5 | **Days:** 1.5 | **Status:** 🔲 PENDING

**Acceptance Criteria:**
- [ ] DNS records created (infra-k8s.monosense.io → 10.25.11.11)
- [ ] DNS records created (apps-k8s.monosense.io → 10.25.11.14)
- [ ] Infra cluster deployed (10.25.11.11-13)
- [ ] Apps cluster deployed (10.25.11.14-16)
- [ ] Both clusters bootstrapped and healthy
- [ ] Kubeconfigs generated and merged
- [ ] All 6 nodes in NotReady state (expected - no CNI yet)
- [ ] PodCIDRs verified as non-overlapping

**Tasks:**
- Add DNS A records in Cloudflare (or local DNS)
- Apply configs to infra nodes:
  ```bash
  task talos:apply-node NODE=10.25.11.11 CLUSTER=infra MACHINE_TYPE=controlplane
  task talos:apply-node NODE=10.25.11.12 CLUSTER=infra MACHINE_TYPE=controlplane
  task talos:apply-node NODE=10.25.11.13 CLUSTER=infra MACHINE_TYPE=controlplane
  ```
- Bootstrap infra: `talosctl bootstrap --nodes 10.25.11.11`
- Wait for health: `talosctl health --wait-timeout 10m`
- Generate infra kubeconfig: `talosctl kubeconfig --force`
- Apply configs to apps nodes:
  ```bash
  task talos:apply-node NODE=10.25.11.14 CLUSTER=apps MACHINE_TYPE=controlplane
  task talos:apply-node NODE=10.25.11.15 CLUSTER=apps MACHINE_TYPE=controlplane
  task talos:apply-node NODE=10.25.11.16 CLUSTER=apps MACHINE_TYPE=controlplane
  ```
- Create talosctl context for apps: `talosctl config context apps --nodes 10.25.11.14,10.25.11.15,10.25.11.16`
- Bootstrap apps: `talosctl bootstrap --nodes 10.25.11.14 --context apps`
- Generate apps kubeconfig
- Verify: `kubectl --context infra get nodes` (should show NotReady)
- Verify: `kubectl --context apps get nodes` (should show NotReady)
- Verify PodCIDRs: `kubectl --context infra get nodes -o jsonpath='{.items[*].spec.podCIDR}'`

**Files Created:**
- Kubeconfig contexts: `infra` and `apps`
- DNS records in Cloudflare

---
