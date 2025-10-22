#!/bin/bash
# validate-story-sequences.sh
# Validates that story sequence metadata aligns with SCHEDULE-V2-GREENFIELD.md
#
# Usage: ./scripts/validate-story-sequences.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SCHEDULE_FILE="${REPO_ROOT}/docs/SCHEDULE-V2-GREENFIELD.md"
STORIES_DIR="${REPO_ROOT}/docs/stories"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
TOTAL_STORIES=0
CORRECT_STORIES=0
INCORRECT_STORIES=0

echo "======================================"
echo "Story Sequence Validation"
echo "======================================"
echo ""

# Extract canonical sequence from SCHEDULE-V2-GREENFIELD.md
declare -A CANONICAL_SEQUENCE
declare -A STORY_SPRINT

echo "📋 Parsing canonical sequence from ${SCHEDULE_FILE}..."
echo ""

# Parse the sequence from SCHEDULE-V2-GREENFIELD.md
# Format: 1. `STORY-BOOT-TALOS` — Description
while IFS= read -r line; do
  if [[ $line =~ ^([0-9]+)\.\s+\`(STORY-[A-Z0-9-]+)\` ]]; then
    seq_num="${BASH_REMATCH[1]}"
    story_name="${BASH_REMATCH[2]}"
    CANONICAL_SEQUENCE["$story_name"]="$seq_num"
  fi
done < <(grep -E '^[0-9]+\. `STORY-' "$SCHEDULE_FILE")

# Map stories to sprints based on SCHEDULE-V2-GREENFIELD.md
# Sprint 1 (stories 1-5)
for story in STORY-BOOT-TALOS STORY-NET-CILIUM-CORE-GITOPS STORY-NET-CILIUM-IPAM STORY-NET-CILIUM-GATEWAY STORY-DNS-COREDNS-BASE; do
  STORY_SPRINT["$story"]=1
done

# Sprint 2 (stories 6-9)
for story in STORY-SEC-CERT-MANAGER-ISSUERS STORY-SEC-EXTERNAL-SECRETS-BASE STORY-OPS-RELOADER-ALL-CLUSTERS STORY-DNS-EXTERNALDNS-CF-BIND-TUNNEL; do
  STORY_SPRINT["$story"]=2
done

# Sprint 3 (stories 10-15)
for story in STORY-STO-OPENEBS-BASE STORY-STO-ROOK-CEPH-OPERATOR STORY-STO-ROOK-CEPH-CLUSTER STORY-OBS-VM-STACK STORY-OBS-VICTORIA-LOGS STORY-OBS-FLUENT-BIT; do
  STORY_SPRINT["$story"]=3
done

# Sprint 4 (stories 16-21)
for story in STORY-OBS-VM-STACK-IMPLEMENT STORY-OBS-VICTORIA-LOGS-IMPLEMENT STORY-OBS-FLUENT-BIT-IMPLEMENT STORY-NET-CILIUM-BGP STORY-NET-CILIUM-BGP-CP-IMPLEMENT STORY-NET-SPEGEL-REGISTRY-MIRROR; do
  STORY_SPRINT["$story"]=4
done

# Sprint 5 (stories 22-26)
for story in STORY-DB-CNPG-OPERATOR STORY-DB-CNPG-SHARED-CLUSTER STORY-DB-DRAGONFLY-OPERATOR-CLUSTER STORY-SEC-NP-BASELINE STORY-IDP-KEYCLOAK-OPERATOR; do
  STORY_SPRINT["$story"]=5
done

# Sprint 6 (stories 27-33)
for story in STORY-NET-CILIUM-CLUSTERMESH STORY-NET-CLUSTERMESH-DNS STORY-SEC-SPIRE-CILIUM-AUTH STORY-STO-APPS-OPENEBS-BASE STORY-STO-APPS-ROOK-CEPH-OPERATOR STORY-STO-APPS-ROOK-CEPH-CLUSTER STORY-CICD-GITHUB-ARC; do
  STORY_SPRINT["$story"]=6
done

# Sprint 7 (stories 34-41)
for story in STORY-CICD-GITLAB-APPS STORY-APP-HARBOR STORY-TENANCY-BASELINE STORY-BACKUP-VOLSYNC-APPS STORY-BOOT-CRDS STORY-GITOPS-SELF-MGMT-FLUX STORY-BOOT-CORE STORY-BOOT-AUTOMATION-ALIGN; do
  STORY_SPRINT["$story"]=7
done

echo "✅ Loaded ${#CANONICAL_SEQUENCE[@]} stories from canonical sequence"
echo ""

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

echo "======================================"
echo "Validating Story Files"
echo "======================================"
echo ""

# Validate each story file
for story_file in "${STORIES_DIR}"/STORY-*.md; do
  [ -f "$story_file" ] || continue

  TOTAL_STORIES=$((TOTAL_STORIES + 1))
  story_basename="$(basename "$story_file" .md)"

  # Skip if not in canonical sequence
  if [ -z "${CANONICAL_SEQUENCE[$story_basename]:-}" ]; then
    echo -e "${YELLOW}⚠️  SKIP${NC} $story_basename (not in greenfield schedule)"
    continue
  fi

  expected_seq="${CANONICAL_SEQUENCE[$story_basename]}"
  expected_prev="${EXPECTED_PREV[$story_basename]:-}"
  expected_next="${EXPECTED_NEXT[$story_basename]:-}"
  expected_sprint="${STORY_SPRINT[$story_basename]:-}"

  # Extract current metadata from story file
  current_title_seq=""
  current_seq=""
  current_prev=""
  current_next=""
  current_sprint=""
  current_global=""

  # Read first 10 lines for metadata
  while IFS= read -r line; do
    # Extract title sequence: # 02 — STORY-...
    if [[ $line =~ ^\#\ ([0-9]+)\ —\ STORY- ]]; then
      current_title_seq="${BASH_REMATCH[1]}"
    fi

    # Extract sequence line: Sequence: 02/41 | Prev: ... | Next: ...
    if [[ $line =~ ^Sequence:\ ([0-9]+)/([0-9]+)\ \|\ Prev:\ ([^|]+)\ \|\ Next:\ (.+)$ ]]; then
      current_seq="${BASH_REMATCH[1]}"
      current_prev="${BASH_REMATCH[3]}"
      current_next="${BASH_REMATCH[4]}"
    fi

    # Handle case with no Next
    if [[ $line =~ ^Sequence:\ ([0-9]+)/([0-9]+)\ \|\ Prev:\ (.+)$ ]] && [[ ! $line =~ Next: ]]; then
      current_seq="${BASH_REMATCH[1]}"
      current_prev="${BASH_REMATCH[3]}"
      current_next="—"
    fi

    # Handle case with no Prev (story 1)
    if [[ $line =~ ^Sequence:\ ([0-9]+)/([0-9]+)\ \|\ Next:\ (.+)$ ]] && [[ ! $line =~ Prev: ]]; then
      current_seq="${BASH_REMATCH[1]}"
      current_prev="—"
      current_next="${BASH_REMATCH[3]}"
    fi

    # Extract sprint
    if [[ $line =~ ^Sprint:\ ([0-9]+) ]]; then
      current_sprint="${BASH_REMATCH[1]}"
    fi

    # Extract global sequence
    if [[ $line =~ ^Global\ Sequence:\ ([0-9]+)/([0-9]+)$ ]]; then
      current_global="${BASH_REMATCH[1]}"
    fi
  done < <(head -10 "$story_file")

  # Validation
  errors=()

  # Title sequence
  if [ "$current_title_seq" != "$expected_seq" ]; then
    errors+=("Title seq: ${current_title_seq} → ${expected_seq}")
  fi

  # Sequence number
  if [ "$current_seq" != "$expected_seq" ]; then
    errors+=("Seq: ${current_seq}/? → ${expected_seq}/41")
  fi

  # Prev
  expected_prev_file="${expected_prev}.md"
  [ -z "$expected_prev" ] && expected_prev_file="—"
  if [ "$current_prev" != "$expected_prev_file" ]; then
    errors+=("Prev: ${current_prev} → ${expected_prev_file}")
  fi

  # Next
  expected_next_file="${expected_next}.md"
  [ -z "$expected_next" ] && expected_next_file="—"
  if [ "$current_next" != "$expected_next_file" ]; then
    errors+=("Next: ${current_next} → ${expected_next_file}")
  fi

  # Sprint
  if [ -n "$expected_sprint" ] && [ "$current_sprint" != "$expected_sprint" ]; then
    errors+=("Sprint: ${current_sprint} → ${expected_sprint}")
  fi

  # Global sequence
  if [ "$current_global" != "$expected_seq" ]; then
    errors+=("Global: ${current_global}/? → ${expected_seq}/41")
  fi

  # Report
  if [ ${#errors[@]} -eq 0 ]; then
    echo -e "${GREEN}✅ PASS${NC} $story_basename (seq ${expected_seq}/41)"
    CORRECT_STORIES=$((CORRECT_STORIES + 1))
  else
    echo -e "${RED}❌ FAIL${NC} $story_basename (seq ${expected_seq}/41)"
    for error in "${errors[@]}"; do
      echo -e "        ${error}"
    done
    INCORRECT_STORIES=$((INCORRECT_STORIES + 1))
  fi
done

echo ""
echo "======================================"
echo "Validation Summary"
echo "======================================"
echo -e "Total stories validated: ${TOTAL_STORIES}"
echo -e "${GREEN}Correct: ${CORRECT_STORIES}${NC}"
echo -e "${RED}Incorrect: ${INCORRECT_STORIES}${NC}"
echo ""

if [ $INCORRECT_STORIES -eq 0 ]; then
  echo -e "${GREEN}🎉 All stories are correctly sequenced!${NC}"
  exit 0
else
  echo -e "${RED}⚠️  ${INCORRECT_STORIES} stories need correction${NC}"
  echo ""
  echo "Run: ./scripts/fix-story-sequences.sh to automatically fix all issues"
  exit 1
fi
