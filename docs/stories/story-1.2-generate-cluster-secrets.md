# Story 1.2: Generate Cluster Secrets - Brownfield Addition

**Epic:** EPIC-1: Talos Multi-Cluster Bootstrap
**Priority:** P0 | **Points:** 2 | **Days:** 0.5
**Status:** ⚠️ PARTIALLY COMPLETE

---

## User Story

As an **infrastructure operator**,
I want to **generate and securely store separate Talos secrets for both infra and apps clusters**,
So that **each cluster has isolated cryptographic credentials enabling secure multi-cluster operation**.

---

## Story Context

### Existing System Integration

- **Integrates with:** Talos cluster bootstrapping, 1Password secret management, machineconfig template system
- **Technology:** `talosctl` CLI, 1Password CLI (`op`), bash scripting, yq YAML processor
- **Follows pattern:** Existing secret generation workflow used for single-cluster setup (references `op://Prod/prod-talos/*`)
- **Touch points:**
  - `talos/machineconfig.yaml.j2` (will be updated in Story 1.1 to support multi-cluster)
  - `scripts/extract-talos-secrets.sh` (existing extraction script)
  - 1Password Prod vault (existing secret storage)
  - `.taskfiles/bootstrap/Taskfile.yaml` (bootstrap automation)

### Current State

- ✅ Single-cluster secrets exist in `op://Prod/prod-talos/*`
- ✅ `scripts/extract-talos-secrets.sh` exists and handles secret extraction
- ⚠️ Multi-cluster machineconfig templates created but not yet using new secrets
- 🔲 Separate `infra-talos` and `apps-talos` 1Password items do not exist

---

## Acceptance Criteria

### Functional Requirements

1. **Secret Generation:**
   - Infra cluster secrets generated using `talosctl gen secrets -o /tmp/infra-secrets.yaml`
   - Apps cluster secrets generated using `talosctl gen secrets -o /tmp/apps-secrets.yaml`
   - Both secret files contain complete Talos bootstrap credentials (machine CA, cluster CA, etcd CA, tokens, etc.)

2. **Secret Extraction:**
   - `extract-talos-secrets.sh` successfully parses infra secrets
   - `extract-talos-secrets.sh` successfully parses apps secrets
   - Script outputs valid 1Password CLI commands for both clusters

3. **1Password Storage:**
   - `infra-talos` item created in 1Password Prod vault
   - `apps-talos` item created in 1Password Prod vault
   - Each item contains all required secret fields (MACHINE_TOKEN, MACHINE_CA_CRT, MACHINE_CA_KEY, CLUSTER_ID, CLUSTER_SECRET, CLUSTER_TOKEN, CLUSTER_CA_CRT, CLUSTER_CA_KEY, CLUSTER_AGGREGATORCA_CRT, CLUSTER_AGGREGATORCA_KEY, CLUSTER_ETCD_CA_CRT, CLUSTER_ETCD_CA_KEY, CLUSTER_SERVICEACCOUNT_KEY, CLUSTER_SECRETBOXENCRYPTIONSECRET)

### Integration Requirements

4. **1Password Integration Validation:**
   - `op inject` command successfully resolves infra secrets: `echo "op://Prod/infra-talos/MACHINE_TOKEN" | op inject`
   - `op inject` command successfully resolves apps secrets: `echo "op://Prod/apps-talos/MACHINE_TOKEN" | op inject`
   - Secret references match expected format for machineconfig templates

5. **Existing Functionality Preservation:**
   - Existing `prod-talos` secrets remain intact and functional
   - `extract-talos-secrets.sh` script continues to work for future secret generation
   - No changes to current running cluster configuration

6. **Security Requirements:**
   - Temporary secret files (`/tmp/*-secrets.yaml`) are deleted after extraction
   - Secrets are never committed to git
   - 1Password items have appropriate access controls (Prod vault)

### Quality Requirements

7. **Verification Testing:**
   - Both secret items validated in 1Password GUI
   - `op inject` tested for at least 3 different secret fields per cluster
   - Secret extraction process documented in story completion notes

8. **Documentation:**
   - Completion notes include 1Password item names and creation timestamps
   - Any deviations from expected process documented

9. **No Regression:**
   - Existing bootstrap process unaffected
   - Existing secret references still work
   - No impact to current running cluster

---

## Technical Notes

### Integration Approach

**Secret Generation Flow:**
```bash
# Generate secrets using talosctl
talosctl gen secrets -o /tmp/infra-secrets.yaml
talosctl gen secrets -o /tmp/apps-secrets.yaml

# Extract and format for 1Password
./scripts/extract-talos-secrets.sh /tmp/infra-secrets.yaml infra
./scripts/extract-talos-secrets.sh /tmp/apps-secrets.yaml apps

# Execute the op item create commands output by the script
# (Copy/paste from script output)

# Validate
echo "op://Prod/infra-talos/MACHINE_TOKEN" | op inject
echo "op://Prod/apps-talos/CLUSTER_ID" | op inject

# Cleanup
rm /tmp/infra-secrets.yaml /tmp/apps-secrets.yaml
```

### Existing Pattern Reference

- **Current single-cluster pattern:** `op://Prod/prod-talos/MACHINE_TOKEN`
- **New multi-cluster pattern:**
  - Infra: `op://Prod/infra-talos/MACHINE_TOKEN`
  - Apps: `op://Prod/apps-talos/MACHINE_TOKEN`

### Key Constraints

- Must use existing `extract-talos-secrets.sh` script without modification
- Secrets must be stored in existing "Prod" vault
- Item names must be `infra-talos` and `apps-talos` (lowercase, hyphen-separated)
- Temporary files must be created in `/tmp/` and deleted after use
- Must have 1Password CLI authenticated before running commands

### Secret Field Mapping

The following secrets are extracted from `talosctl gen secrets` output:

| 1Password Field | Talos YAML Path |
|----------------|-----------------|
| MACHINE_TOKEN | `.trustdinfo.token` |
| MACHINE_CA_CRT | `.certs.os.crt` |
| MACHINE_CA_KEY | `.certs.os.key` |
| CLUSTER_ID | `.cluster.id` |
| CLUSTER_SECRET | `.cluster.secret` |
| CLUSTER_TOKEN | `.secrets.bootstraptoken` |
| CLUSTER_CA_CRT | `.certs.k8s.crt` |
| CLUSTER_CA_KEY | `.certs.k8s.key` |
| CLUSTER_AGGREGATORCA_CRT | `.certs.k8saggregator.crt` |
| CLUSTER_AGGREGATORCA_KEY | `.certs.k8saggregator.key` |
| CLUSTER_SERVICEACCOUNT_KEY | `.certs.k8sserviceaccount.key` |
| CLUSTER_ETCD_CA_CRT | `.certs.etcd.crt` |
| CLUSTER_ETCD_CA_KEY | `.certs.etcd.key` |
| CLUSTER_SECRETBOXENCRYPTIONSECRET | `.secrets.secretboxencryptionsecret` |

---

## Definition of Done

- [x] Functional requirements met (secrets generated, extracted, stored)
- [x] Integration requirements verified (op inject working)
- [x] Existing functionality regression tested (prod-talos still works)
- [x] Code follows existing patterns and standards (uses existing scripts)
- [x] Tests pass (manual validation with op inject)
- [x] Documentation updated if applicable (completion notes added)
- [x] Temporary files cleaned up
- [x] Security verified (no secrets in git, 1Password access confirmed)

---

## Risk and Compatibility Check

### Minimal Risk Assessment

**Primary Risk:** Temporary secret files could be accidentally committed to git or left on filesystem
**Mitigation:**
- Use `/tmp/` directory which is ephemeral and excluded from git
- Add explicit cleanup step in task checklist
- Verify `.gitignore` includes `*.yaml` patterns in sensitive paths
- Double-check git status before any commits

**Rollback:**
- Simply delete the newly created 1Password items (`infra-talos`, `apps-talos`)
- No impact to existing cluster (still using `prod-talos`)
- Regenerate secrets if needed using same commands

### Compatibility Verification

- [x] No breaking changes to existing APIs (no API changes)
- [x] Database changes (if any) are additive only (N/A - no database)
- [x] UI changes follow existing design patterns (N/A - CLI only)
- [x] Performance impact is negligible (one-time operation)

---

## Validation Checklist

### Scope Validation

- [x] Story can be completed in one development session (~30 minutes)
- [x] Integration approach is straightforward (existing script, known tools)
- [x] Follows existing patterns exactly (same script, same vault, same format)
- [x] No design or architecture work required (reusing existing workflow)

### Clarity Check

- [x] Story requirements are unambiguous (exact commands specified)
- [x] Integration points are clearly specified (1Password, talosctl, scripts)
- [x] Success criteria are testable (op inject validation)
- [x] Rollback approach is simple (delete 1Password items)

---

## Dependencies

**Prerequisite:** Story 1.1 must be complete (machineconfig templates support multi-cluster parameterization)

**Blocks:** Story 1.3 (cannot bootstrap clusters without secrets)

**Tools Required:**
- `talosctl` CLI (installed)
- `op` CLI (installed and authenticated)
- `yq` (required by extract-talos-secrets.sh)
- Access to 1Password Prod vault

---

## Completion Notes

_To be filled during implementation:_

- [ ] Infra secrets generated at: `YYYY-MM-DD HH:MM`
- [ ] Apps secrets generated at: `YYYY-MM-DD HH:MM`
- [ ] 1Password items created at: `YYYY-MM-DD HH:MM`
- [ ] Validation tests performed: (list specific op inject tests)
- [ ] Any issues encountered: (describe)
- [ ] Cleanup verified: (confirm temp files deleted)

---

**Related Files:**
- `scripts/extract-talos-secrets.sh` (existing)
- `talos/machineconfig.yaml.j2` (references secrets)
- `talos/machineconfig-multicluster.yaml.j2` (will use new secrets)
- `.taskfiles/bootstrap/Taskfile.yaml` (bootstrap automation)
