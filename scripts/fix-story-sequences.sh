#!/bin/bash
# fix-story-sequences.sh
# Fixes story sequence metadata to align with SCHEDULE-V2-GREENFIELD.md
#
# Usage: ./scripts/fix-story-sequences.sh [--dry-run]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SCHEDULE_FILE="${REPO_ROOT}/docs/SCHEDULE-V2-GREENFIELD.md"
STORIES_DIR="${REPO_ROOT}/docs/stories"

DRY_RUN=false
if [ "${1:-}" = "--dry-run" ]; then
  DRY_RUN=true
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

FIXED_COUNT=0
SKIPPED_COUNT=0

echo "======================================"
echo "Story Sequence Fix Script"
echo "======================================"
if [ "$DRY_RUN" = true ]; then
  echo -e "${YELLOW}DRY RUN MODE - No files will be modified${NC}"
fi
echo ""

# Extract canonical sequence from SCHEDULE-V2-GREENFIELD.md
declare -A CANONICAL_SEQUENCE
declare -A STORY_SPRINT
declare -A STORY_LANE

echo "📋 Parsing canonical sequence from ${SCHEDULE_FILE}..."
echo ""

# Parse the sequence from SCHEDULE-V2-GREENFIELD.md
while IFS= read -r line; do
  if [[ $line =~ ^([0-9]+)\.\s+\`(STORY-[A-Z0-9-]+)\` ]]; then
    seq_num="${BASH_REMATCH[1]}"
    story_name="${BASH_REMATCH[2]}"
    CANONICAL_SEQUENCE["$story_name"]="$seq_num"
  fi
done < <(grep -E '^[0-9]+\. `STORY-' "$SCHEDULE_FILE")

echo "✅ Loaded ${#CANONICAL_SEQUENCE[@]} stories from canonical sequence"

# Map stories to sprints and lanes
# Sprint 1 (stories 1-5) - Bare Cluster + Networking Core
STORY_SPRINT["STORY-BOOT-TALOS"]=1
STORY_LANE["STORY-BOOT-TALOS"]="Bootstrap & Platform"

for story in STORY-NET-CILIUM-CORE-GITOPS STORY-NET-CILIUM-IPAM STORY-NET-CILIUM-GATEWAY; do
  STORY_SPRINT["$story"]=1
  STORY_LANE["$story"]="Networking"
done

STORY_SPRINT["STORY-DNS-COREDNS-BASE"]=1
STORY_LANE["STORY-DNS-COREDNS-BASE"]="Networking"

# Sprint 2 (stories 6-9) - Security, DNS & External Secrets
for story in STORY-SEC-CERT-MANAGER-ISSUERS STORY-SEC-EXTERNAL-SECRETS-BASE; do
  STORY_SPRINT["$story"]=2
  STORY_LANE["$story"]="Security"
done

STORY_SPRINT["STORY-OPS-RELOADER-ALL-CLUSTERS"]=2
STORY_LANE["STORY-OPS-RELOADER-ALL-CLUSTERS"]="Operations"

STORY_SPRINT["STORY-DNS-EXTERNALDNS-CF-BIND-TUNNEL"]=2
STORY_LANE["STORY-DNS-EXTERNALDNS-CF-BIND-TUNNEL"]="Networking"

# Sprint 3 (stories 10-15) - Storage & Observability Design
for story in STORY-STO-OPENEBS-BASE STORY-STO-ROOK-CEPH-OPERATOR STORY-STO-ROOK-CEPH-CLUSTER; do
  STORY_SPRINT["$story"]=3
  STORY_LANE["$story"]="Storage"
done

for story in STORY-OBS-VM-STACK STORY-OBS-VICTORIA-LOGS STORY-OBS-FLUENT-BIT; do
  STORY_SPRINT["$story"]=3
  STORY_LANE["$story"]="Observability"
done

# Sprint 4 (stories 16-21) - Observability Implementation & Advanced Networking
for story in STORY-OBS-VM-STACK-IMPLEMENT STORY-OBS-VICTORIA-LOGS-IMPLEMENT STORY-OBS-FLUENT-BIT-IMPLEMENT; do
  STORY_SPRINT["$story"]=4
  STORY_LANE["$story"]="Observability"
done

for story in STORY-NET-CILIUM-BGP STORY-NET-CILIUM-BGP-CP-IMPLEMENT STORY-NET-SPEGEL-REGISTRY-MIRROR; do
  STORY_SPRINT["$story"]=4
  STORY_LANE["$story"]="Networking"
done

# Sprint 5 (stories 22-26) - Databases, Security, IDP
for story in STORY-DB-CNPG-OPERATOR STORY-DB-CNPG-SHARED-CLUSTER STORY-DB-DRAGONFLY-OPERATOR-CLUSTER; do
  STORY_SPRINT["$story"]=5
  STORY_LANE["$story"]="Database"
done

STORY_SPRINT["STORY-SEC-NP-BASELINE"]=5
STORY_LANE["STORY-SEC-NP-BASELINE"]="Security"

STORY_SPRINT["STORY-IDP-KEYCLOAK-OPERATOR"]=5
STORY_LANE["STORY-IDP-KEYCLOAK-OPERATOR"]="Identity"

# Sprint 6 (stories 27-33) - ClusterMesh, SPIRE, Apps Storage, CI/CD
for story in STORY-NET-CILIUM-CLUSTERMESH STORY-NET-CLUSTERMESH-DNS; do
  STORY_SPRINT["$story"]=6
  STORY_LANE["$story"]="Networking"
done

STORY_SPRINT["STORY-SEC-SPIRE-CILIUM-AUTH"]=6
STORY_LANE["STORY-SEC-SPIRE-CILIUM-AUTH"]="Security"

for story in STORY-STO-APPS-OPENEBS-BASE STORY-STO-APPS-ROOK-CEPH-OPERATOR STORY-STO-APPS-ROOK-CEPH-CLUSTER; do
  STORY_SPRINT["$story"]=6
  STORY_LANE["$story"]="Storage"
done

STORY_SPRINT["STORY-CICD-GITHUB-ARC"]=6
STORY_LANE["STORY-CICD-GITHUB-ARC"]="CI/CD"

# Sprint 7 (stories 34-41) - CI/CD, Tenancy, Backup & Bootstrap Validation
for story in STORY-CICD-GITLAB-APPS STORY-APP-HARBOR; do
  STORY_SPRINT["$story"]=7
  STORY_LANE["$story"]="Applications"
done

STORY_SPRINT["STORY-TENANCY-BASELINE"]=7
STORY_LANE["STORY-TENANCY-BASELINE"]="Platform"

STORY_SPRINT["STORY-BACKUP-VOLSYNC-APPS"]=7
STORY_LANE["STORY-BACKUP-VOLSYNC-APPS"]="Backup"

for story in STORY-BOOT-CRDS STORY-GITOPS-SELF-MGMT-FLUX STORY-BOOT-CORE STORY-BOOT-AUTOMATION-ALIGN; do
  STORY_SPRINT["$story"]=7
  STORY_LANE["$story"]="Bootstrap & Platform"
done

# Build prev/next chain
declare -A EXPECTED_PREV
declare -A EXPECTED_NEXT

SORTED_STORIES=($(
  for story in "${!CANONICAL_SEQUENCE[@]}"; do
    echo "${CANONICAL_SEQUENCE[$story]} $story"
  done | sort -n | awk '{print $2}'
))

for i in "${!SORTED_STORIES[@]}"; do
  story="${SORTED_STORIES[$i]}"

  # Set prev
  if [ "$i" -gt 0 ]; then
    prev_story="${SORTED_STORIES[$((i-1))]}"
    EXPECTED_PREV["$story"]="$prev_story"
  fi

  # Set next
  if [ "$i" -lt $((${#SORTED_STORIES[@]} - 1)) ]; then
    next_story="${SORTED_STORIES[$((i+1))]}"
    EXPECTED_NEXT["$story"]="$next_story"
  fi
done

echo ""
echo "======================================"
echo "Fixing Story Files"
echo "======================================"
echo ""

# Fix each story file
for story_file in "${STORIES_DIR}"/STORY-*.md; do
  [ -f "$story_file" ] || continue

  story_basename="$(basename "$story_file" .md)"

  # Skip if not in canonical sequence
  if [ -z "${CANONICAL_SEQUENCE[$story_basename]:-}" ]; then
    echo -e "${YELLOW}⏭  SKIP${NC} $story_basename (not in greenfield schedule)"
    SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
    continue
  fi

  expected_seq="${CANONICAL_SEQUENCE[$story_basename]}"
  expected_prev="${EXPECTED_PREV[$story_basename]:-}"
  expected_next="${EXPECTED_NEXT[$story_basename]:-}"
  expected_sprint="${STORY_SPRINT[$story_basename]:-}"
  expected_lane="${STORY_LANE[$story_basename]:-Platform}"

  # Format sequence line
  sequence_line="Sequence: $(printf "%02d" "$expected_seq")/41"

  if [ -n "$expected_prev" ]; then
    sequence_line="${sequence_line} | Prev: ${expected_prev}.md"
  fi

  if [ -n "$expected_next" ]; then
    sequence_line="${sequence_line} | Next: ${expected_next}.md"
  fi

  # Create temp file
  temp_file=$(mktemp)

  # Process file
  line_num=0
  title_updated=false
  sequence_updated=false
  sprint_updated=false
  global_updated=false

  while IFS= read -r line; do
    line_num=$((line_num + 1))

    # Update title sequence (line 1)
    if [ $line_num -eq 1 ] && [[ $line =~ ^\#\ [0-9]+\ —\  ]]; then
      # Replace title sequence
      updated_line=$(echo "$line" | sed -E "s/^# [0-9]+ —/# $(printf "%02d" "$expected_seq") —/")
      echo "$updated_line" >> "$temp_file"
      title_updated=true
      continue
    fi

    # Update Sequence line (typically line 3)
    if [[ $line =~ ^Sequence: ]]; then
      echo "$sequence_line" >> "$temp_file"
      sequence_updated=true
      continue
    fi

    # Update Sprint line (typically line 4)
    if [[ $line =~ ^Sprint: ]] && [ -n "$expected_sprint" ]; then
      # Preserve lane if it exists
      if [[ $line =~ ^Sprint:\ [0-9]+\ \|\ Lane:\ (.+)$ ]]; then
        echo "Sprint: ${expected_sprint} | Lane: ${expected_lane}" >> "$temp_file"
      else
        echo "Sprint: ${expected_sprint} | Lane: ${expected_lane}" >> "$temp_file"
      fi
      sprint_updated=true
      continue
    fi

    # Update Global Sequence line (typically line 5)
    if [[ $line =~ ^Global\ Sequence: ]]; then
      echo "Global Sequence: ${expected_seq}/41" >> "$temp_file"
      global_updated=true
      continue
    fi

    # Pass through all other lines
    echo "$line" >> "$temp_file"

  done < "$story_file"

  # Apply changes
  if [ "$DRY_RUN" = true ]; then
    echo -e "${BLUE}🔧 DRY-RUN${NC} $story_basename → seq ${expected_seq}/41, sprint ${expected_sprint}"
    rm "$temp_file"
  else
    mv "$temp_file" "$story_file"
    echo -e "${GREEN}✅ FIXED${NC} $story_basename → seq ${expected_seq}/41, sprint ${expected_sprint}"
    FIXED_COUNT=$((FIXED_COUNT + 1))
  fi
done

echo ""
echo "======================================"
echo "Fix Summary"
echo "======================================"
echo -e "${GREEN}Fixed: ${FIXED_COUNT}${NC}"
echo -e "${YELLOW}Skipped: ${SKIPPED_COUNT}${NC}"
echo ""

if [ "$DRY_RUN" = true ]; then
  echo -e "${YELLOW}DRY RUN completed. No files were modified.${NC}"
  echo "Run without --dry-run to apply changes."
else
  echo -e "${GREEN}✅ All story sequences have been fixed!${NC}"
  echo ""
  echo "Next steps:"
  echo "  1. Review changes: git diff docs/stories/"
  echo "  2. Validate: ./scripts/validate-story-sequences.sh"
  echo "  3. Commit: git add docs/stories/ && git commit -m 'fix: align story sequences with greenfield schedule'"
fi
