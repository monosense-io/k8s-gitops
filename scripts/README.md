# Helper Scripts

This directory contains automation scripts for managing the multi-cluster Talos deployment.

## Multi-Cluster Conversion Scripts

### convert-to-multicluster.sh

Automates the conversion from a single 6-node cluster to two 3-node clusters.

**What it does:**
- Backs up `talos/machineconfig.yaml.j2`
- Creates `talos/infra/` and `talos/apps/` directories
- Moves node configs from `talos/controlplane/` to cluster-specific directories
- Updates hostnames in each node config:
  - `10.25.11.11-13` → `infra-01`, `infra-02`, `infra-03`
  - `10.25.11.14-16` → `apps-01`, `apps-02`, `apps-03`
- Removes empty `talos/controlplane/` directory

**Usage:**
```bash
./scripts/convert-to-multicluster.sh
```

**Prerequisites:**
- Node configs must exist in `talos/controlplane/` directory
- Must have sed command available

**After running:**
1. Update `talos/machineconfig.yaml.j2` (see docs/talos-multi-cluster-bootstrap.md Step 1)
2. Update `.taskfiles/talos/Taskfile.yaml` (see Step 2)
3. Update `.taskfiles/bootstrap/Taskfile.yaml` (see Step 8)
4. Add DNS records
5. Generate secrets for both clusters

---

### extract-talos-secrets.sh

Extracts secrets from `talosctl gen secrets` output and formats them for 1Password import.

**What it does:**
- Parses Talos secrets YAML file
- Extracts all machine and cluster secrets
- Generates `op` CLI command for creating 1Password item
- Outputs JSON format for manual import

**Usage:**
```bash
# Generate secrets first
talosctl gen secrets -o /tmp/infra-secrets.yaml
talosctl gen secrets -o /tmp/apps-secrets.yaml

# Extract and format for 1Password
./scripts/extract-talos-secrets.sh /tmp/infra-secrets.yaml infra
./scripts/extract-talos-secrets.sh /tmp/apps-secrets.yaml apps
```

**Prerequisites:**
- `yq` command installed (`brew install yq`)
- `talosctl` installed for generating secrets
- Optional: `op` CLI installed for automated 1Password import

**Output:**
1. `op item create` command for automated import
2. JSON format for manual import

**Example Output:**
```bash
# Create 1Password item for infra-talos
op item create \
  --category=login \
  --title="infra-talos" \
  --vault="Prod" \
  "MACHINE_TOKEN[password]=..." \
  "MACHINE_CA_CRT[password]=..." \
  # ... etc
```

---

## Complete Workflow

Follow this sequence for converting to multi-cluster:

### Step 1: Run Conversion Script
```bash
./scripts/convert-to-multicluster.sh
```

### Step 2: Generate Secrets for Both Clusters
```bash
talosctl gen secrets -o /tmp/infra-secrets.yaml
talosctl gen secrets -o /tmp/apps-secrets.yaml
```

### Step 3: Extract and Import to 1Password
```bash
# For infra cluster
./scripts/extract-talos-secrets.sh /tmp/infra-secrets.yaml infra

# Copy the 'op item create' command and run it
# OR manually create the item in 1Password using the JSON output

# For apps cluster
./scripts/extract-talos-secrets.sh /tmp/apps-secrets.yaml apps

# Copy the 'op item create' command and run it
# OR manually create the item in 1Password using the JSON output
```

### Step 4: Update Configuration Files
See **docs/talos-multi-cluster-bootstrap.md** for:
- `machineconfig.yaml.j2` updates
- Taskfile updates
- Bootstrap procedures

### Step 5: Follow Quick Start Guide
See **Quick Start Command Reference** in docs/talos-multi-cluster-bootstrap.md

---

## Troubleshooting

### Error: machineconfig.yaml.j2 not found
- Ensure you're running the script from the repository root
- Check that `talos/machineconfig.yaml.j2` exists

### Error: yq not installed
```bash
brew install yq
```

### Error: Node config files not found
- Verify node configs exist in `talos/controlplane/` directory
- Check file naming: `10.25.11.11.yaml`, `10.25.11.12.yaml`, etc.

### 1Password Import Issues
If automated import fails:
1. Use the JSON output for manual entry
2. Create new Login item in 1Password
3. Name it `infra-talos` or `apps-talos`
4. Add each field from JSON as a password field
5. Save to "Prod" vault

---

## Related Documentation

- **[Talos Multi-Cluster Bootstrap Guide](../docs/talos-multi-cluster-bootstrap.md)** - Complete step-by-step guide
- **[Architecture Decision Record](../docs/architecture-decision-record.md)** - All architectural decisions
- **[Implementation Timeline](../docs/implementation-timeline.md)** - 10-week rollout plan
- **[Technical Deep Dive](../docs/technical-deep-dive.md)** - Production configurations

---

*Helper Scripts Documentation - v1.0*
