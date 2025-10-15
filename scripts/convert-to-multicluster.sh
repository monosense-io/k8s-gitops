#!/usr/bin/env bash

set -euo pipefail

# Talos Multi-Cluster Conversion Script
# Automates the conversion from single 6-node cluster to two 3-node clusters

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
TALOS_DIR="${ROOT_DIR}/talos"

echo "===================================="
echo "Talos Multi-Cluster Conversion"
echo "===================================="
echo ""
echo "This script will convert your single 6-node cluster into:"
echo "  - Infra cluster: 10.25.11.11-13 (infra-01, infra-02, infra-03)"
echo "  - Apps cluster: 10.25.11.14-16 (apps-01, apps-02, apps-03)"
echo ""
read -p "Continue? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

# Step 1: Backup current config
echo ""
echo "Step 1: Backing up machineconfig.yaml.j2..."
if [[ -f "${TALOS_DIR}/machineconfig.yaml.j2" ]]; then
    cp "${TALOS_DIR}/machineconfig.yaml.j2" "${TALOS_DIR}/machineconfig.yaml.j2.backup"
    echo "✓ Backup created: ${TALOS_DIR}/machineconfig.yaml.j2.backup"
else
    echo "✗ Error: machineconfig.yaml.j2 not found!"
    exit 1
fi

# Step 2: Create cluster directories
echo ""
echo "Step 2: Creating cluster directories..."
mkdir -p "${TALOS_DIR}/infra" "${TALOS_DIR}/apps"
echo "✓ Created ${TALOS_DIR}/infra"
echo "✓ Created ${TALOS_DIR}/apps"

# Step 3: Move and update infra nodes (10.25.11.11-13)
echo ""
echo "Step 3: Moving and updating infra nodes..."
if [[ ! -d "${TALOS_DIR}/controlplane" ]]; then
    echo "✗ Error: ${TALOS_DIR}/controlplane directory not found!"
    exit 1
fi

for i in {11..13}; do
    node_file="10.25.11.${i}.yaml"
    src="${TALOS_DIR}/controlplane/${node_file}"
    dst="${TALOS_DIR}/infra/${node_file}"

    if [[ -f "${src}" ]]; then
        mv "${src}" "${dst}"
        echo "✓ Moved ${node_file} to infra/"

        # Update hostname (prod-0X → infra-0X)
        hostname_num=$((i - 10))
        sed -i.bak "s/hostname: prod-0${hostname_num}/hostname: infra-0${hostname_num}/g" "${dst}"
        rm "${dst}.bak"
        echo "  → Updated hostname to infra-0${hostname_num}"
    else
        echo "✗ Warning: ${src} not found, skipping..."
    fi
done

# Step 4: Move and update apps nodes (10.25.11.14-16)
echo ""
echo "Step 4: Moving and updating apps nodes..."
for i in {14..16}; do
    node_file="10.25.11.${i}.yaml"
    src="${TALOS_DIR}/controlplane/${node_file}"
    dst="${TALOS_DIR}/apps/${node_file}"

    if [[ -f "${src}" ]]; then
        mv "${src}" "${dst}"
        echo "✓ Moved ${node_file} to apps/"

        # Update hostname (prod-0X → apps-0X)
        hostname_num=$((i - 13))
        sed -i.bak "s/hostname: prod-0$(printf "%d" $((i - 10)))/hostname: apps-0${hostname_num}/g" "${dst}"
        rm "${dst}.bak"
        echo "  → Updated hostname to apps-0${hostname_num}"
    else
        echo "✗ Warning: ${src} not found, skipping..."
    fi
done

# Step 5: Remove old controlplane directory
echo ""
echo "Step 5: Removing old controlplane directory..."
if [[ -d "${TALOS_DIR}/controlplane" ]]; then
    if [[ -z "$(ls -A ${TALOS_DIR}/controlplane)" ]]; then
        rmdir "${TALOS_DIR}/controlplane"
        echo "✓ Removed empty ${TALOS_DIR}/controlplane directory"
    else
        echo "✗ Warning: ${TALOS_DIR}/controlplane is not empty, not removing"
        echo "  Contents: $(ls ${TALOS_DIR}/controlplane)"
    fi
fi

# Step 6: Summary
echo ""
echo "===================================="
echo "Conversion Complete!"
echo "===================================="
echo ""
echo "Files moved and updated:"
echo "  ${TALOS_DIR}/infra/10.25.11.11.yaml (infra-01)"
echo "  ${TALOS_DIR}/infra/10.25.11.12.yaml (infra-02)"
echo "  ${TALOS_DIR}/infra/10.25.11.13.yaml (infra-03)"
echo "  ${TALOS_DIR}/apps/10.25.11.14.yaml (apps-01)"
echo "  ${TALOS_DIR}/apps/10.25.11.15.yaml (apps-02)"
echo "  ${TALOS_DIR}/apps/10.25.11.16.yaml (apps-03)"
echo ""
echo "Next steps:"
echo "  1. Update machineconfig.yaml.j2 (see docs/talos-multi-cluster-bootstrap.md Step 1)"
echo "  2. Update .taskfiles/talos/Taskfile.yaml (see Step 2)"
echo "  3. Update .taskfiles/bootstrap/Taskfile.yaml (see Step 8)"
echo "  4. Add DNS records:"
echo "     - infra.k8s.monosense.io → 10.25.11.11"
echo "     - apps.k8s.monosense.io → 10.25.11.14"
echo "  5. Generate secrets and create 1Password items"
echo "  6. Follow Quick Start Command Reference in docs/talos-multi-cluster-bootstrap.md"
echo ""
