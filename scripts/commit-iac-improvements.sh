#!/usr/bin/env bash
# Quick script to commit all IaC improvements from validation
# Generated: 2025-10-14
# Usage: ./scripts/commit-iac-improvements.sh

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}IaC Improvements - Quick Commit Script${NC}"
echo "========================================"
echo ""

# Check if we're in git repo
if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    echo -e "${RED}Error: Not in a git repository${NC}"
    exit 1
fi

# Check for uncommitted changes
if [[ -n $(git status -s) ]]; then
    echo -e "${YELLOW}Warning: You have uncommitted changes${NC}"
    echo "This script will commit the following new files:"
    echo ""
    echo "  .github/workflows/validate-infrastructure.yaml"
    echo "  kubernetes/components/pdb/*.yaml"
    echo "  docs/naming-conventions.md"
    echo "  docs/iac-gap-remediation-guide.md"
    echo "  docs/iac-implementation-summary.md"
    echo "  scripts/commit-iac-improvements.sh"
    echo ""
    read -p "Continue? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 1
    fi
fi

echo ""
echo -e "${GREEN}Step 1: Adding GitHub Actions CI/CD workflow${NC}"
if [[ -f ".github/workflows/validate-infrastructure.yaml" ]]; then
    git add .github/workflows/validate-infrastructure.yaml
    echo "✅ Added CI/CD workflow"
else
    echo -e "${RED}❌ File not found: .github/workflows/validate-infrastructure.yaml${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}Step 2: Adding PodDisruptionBudgets${NC}"
if [[ -d "kubernetes/components/pdb" ]]; then
    git add kubernetes/components/pdb/
    echo "✅ Added PodDisruptionBudgets"
else
    echo -e "${RED}❌ Directory not found: kubernetes/components/pdb/${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}Step 3: Adding documentation${NC}"
git add docs/naming-conventions.md
git add docs/iac-gap-remediation-guide.md
git add docs/iac-implementation-summary.md
git add scripts/commit-iac-improvements.sh
echo "✅ Added documentation files"

echo ""
echo -e "${GREEN}Step 4: Creating commit${NC}"
git commit -m "feat(infra): implement IaC improvements from validation

Implements Infrastructure as Code improvements identified during
infrastructure validation (Section 2):

CI/CD Automation:
- Add GitHub Actions workflow for manifest validation
- Validate Kubernetes manifests with Flux CLI
- Lint YAML files with yamllint
- Validate schemas with kubeconform
- Scan for secrets with Gitleaks
- Scan container images with Trivy (HIGH/CRITICAL only)
- Validate Talos machine config templates

High Availability Protection:
- Add PodDisruptionBudgets for critical services
- Cilium: maxUnavailable=1, ensure 2/3 agents always running
- Rook Ceph MON: minAvailable=2, protect quorum
- Rook Ceph MGR: minAvailable=1, ensure management
- Victoria Metrics: minAvailable=1-2 per component

Documentation:
- Document naming conventions for all resource types
- Create step-by-step remediation guide
- Provide implementation summary with quick start

Addresses:
- IaC Gap #1: No CI/CD automation (HIGH priority)
- IaC Gap #2: Missing PodDisruptionBudgets (HIGH priority)
- IaC Gap #3: Undocumented naming conventions (MEDIUM priority)

Validation Reference: Infrastructure Validation Section 2
Estimated Implementation Time: 3-4 hours
Status: Ready for immediate deployment

Breaking Changes: None
Dependencies: Requires GitHub Actions enabled on repository

Co-authored-by: Alex (DevOps Platform Engineer)
"

echo ""
echo -e "${GREEN}✅ Commit created successfully!${NC}"
echo ""
echo "Next steps:"
echo "1. Review the commit: git show"
echo "2. Push to remote: git push origin main"
echo "3. Check GitHub Actions: gh workflow list"
echo "4. Follow remediation guide: docs/iac-gap-remediation-guide.md"
echo ""
echo -e "${YELLOW}Important:${NC} Enable branch protection after this push!"
echo "See: docs/iac-gap-remediation-guide.md Step 3"
