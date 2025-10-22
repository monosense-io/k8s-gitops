#!/usr/bin/env python3
"""
resequence_stories.py
Updates story sequence metadata to align with SCHEDULE-V2-GREENFIELD.md

Usage:
    python3 resequence_stories.py [--dry-run] [--validate-only]
"""

import re
import sys
from pathlib import Path
from typing import Dict, List, Tuple, Optional

# ANSI colors
class Colors:
    RED = '\033[0;31m'
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    BLUE = '\033[0;34m'
    NC = '\033[0m'  # No Color

# Canonical sequence from SCHEDULE-V2-GREENFIELD.md
GREENFIELD_SEQUENCE = [
    "STORY-BOOT-TALOS",
    "STORY-NET-CILIUM-CORE-GITOPS",
    "STORY-NET-CILIUM-IPAM",
    "STORY-NET-CILIUM-GATEWAY",
    "STORY-DNS-COREDNS-BASE",
    "STORY-SEC-CERT-MANAGER-ISSUERS",
    "STORY-SEC-EXTERNAL-SECRETS-BASE",
    "STORY-OPS-RELOADER-ALL-CLUSTERS",
    "STORY-DNS-EXTERNALDNS-CF-BIND-TUNNEL",
    "STORY-STO-OPENEBS-BASE",
    "STORY-STO-ROOK-CEPH-OPERATOR",
    "STORY-STO-ROOK-CEPH-CLUSTER",
    "STORY-OBS-VM-STACK",
    "STORY-OBS-VICTORIA-LOGS",
    "STORY-OBS-FLUENT-BIT",
    "STORY-OBS-VM-STACK-IMPLEMENT",
    "STORY-OBS-VICTORIA-LOGS-IMPLEMENT",
    "STORY-OBS-FLUENT-BIT-IMPLEMENT",
    "STORY-NET-CILIUM-BGP",
    "STORY-NET-CILIUM-BGP-CP-IMPLEMENT",
    "STORY-NET-SPEGEL-REGISTRY-MIRROR",
    "STORY-DB-CNPG-OPERATOR",
    "STORY-DB-CNPG-SHARED-CLUSTER",
    "STORY-DB-DRAGONFLY-OPERATOR-CLUSTER",
    "STORY-SEC-NP-BASELINE",
    "STORY-IDP-KEYCLOAK-OPERATOR",
    "STORY-NET-CILIUM-CLUSTERMESH",
    "STORY-NET-CLUSTERMESH-DNS",
    "STORY-SEC-SPIRE-CILIUM-AUTH",
    "STORY-STO-APPS-OPENEBS-BASE",
    "STORY-STO-APPS-ROOK-CEPH-OPERATOR",
    "STORY-STO-APPS-ROOK-CEPH-CLUSTER",
    "STORY-CICD-GITHUB-ARC",
    "STORY-CICD-GITLAB-APPS",
    "STORY-APP-HARBOR",
    "STORY-TENANCY-BASELINE",
    "STORY-BACKUP-VOLSYNC-APPS",
    "STORY-BOOT-CRDS",
    "STORY-GITOPS-SELF-MGMT-FLUX",
    "STORY-BOOT-CORE",
    "STORY-BOOT-AUTOMATION-ALIGN",
]

# Sprint mapping
STORY_SPRINT = {
    # Sprint 1 (stories 1-5)
    "STORY-BOOT-TALOS": 1,
    "STORY-NET-CILIUM-CORE-GITOPS": 1,
    "STORY-NET-CILIUM-IPAM": 1,
    "STORY-NET-CILIUM-GATEWAY": 1,
    "STORY-DNS-COREDNS-BASE": 1,
    # Sprint 2 (stories 6-9)
    "STORY-SEC-CERT-MANAGER-ISSUERS": 2,
    "STORY-SEC-EXTERNAL-SECRETS-BASE": 2,
    "STORY-OPS-RELOADER-ALL-CLUSTERS": 2,
    "STORY-DNS-EXTERNALDNS-CF-BIND-TUNNEL": 2,
    # Sprint 3 (stories 10-15)
    "STORY-STO-OPENEBS-BASE": 3,
    "STORY-STO-ROOK-CEPH-OPERATOR": 3,
    "STORY-STO-ROOK-CEPH-CLUSTER": 3,
    "STORY-OBS-VM-STACK": 3,
    "STORY-OBS-VICTORIA-LOGS": 3,
    "STORY-OBS-FLUENT-BIT": 3,
    # Sprint 4 (stories 16-21)
    "STORY-OBS-VM-STACK-IMPLEMENT": 4,
    "STORY-OBS-VICTORIA-LOGS-IMPLEMENT": 4,
    "STORY-OBS-FLUENT-BIT-IMPLEMENT": 4,
    "STORY-NET-CILIUM-BGP": 4,
    "STORY-NET-CILIUM-BGP-CP-IMPLEMENT": 4,
    "STORY-NET-SPEGEL-REGISTRY-MIRROR": 4,
    # Sprint 5 (stories 22-26)
    "STORY-DB-CNPG-OPERATOR": 5,
    "STORY-DB-CNPG-SHARED-CLUSTER": 5,
    "STORY-DB-DRAGONFLY-OPERATOR-CLUSTER": 5,
    "STORY-SEC-NP-BASELINE": 5,
    "STORY-IDP-KEYCLOAK-OPERATOR": 5,
    # Sprint 6 (stories 27-33)
    "STORY-NET-CILIUM-CLUSTERMESH": 6,
    "STORY-NET-CLUSTERMESH-DNS": 6,
    "STORY-SEC-SPIRE-CILIUM-AUTH": 6,
    "STORY-STO-APPS-OPENEBS-BASE": 6,
    "STORY-STO-APPS-ROOK-CEPH-OPERATOR": 6,
    "STORY-STO-APPS-ROOK-CEPH-CLUSTER": 6,
    "STORY-CICD-GITHUB-ARC": 6,
    # Sprint 7 (stories 34-41)
    "STORY-CICD-GITLAB-APPS": 7,
    "STORY-APP-HARBOR": 7,
    "STORY-TENANCY-BASELINE": 7,
    "STORY-BACKUP-VOLSYNC-APPS": 7,
    "STORY-BOOT-CRDS": 7,
    "STORY-GITOPS-SELF-MGMT-FLUX": 7,
    "STORY-BOOT-CORE": 7,
    "STORY-BOOT-AUTOMATION-ALIGN": 7,
}

# Lane mapping
STORY_LANE = {
    "STORY-BOOT-TALOS": "Bootstrap & Platform",
    "STORY-NET-CILIUM-CORE-GITOPS": "Networking",
    "STORY-NET-CILIUM-IPAM": "Networking",
    "STORY-NET-CILIUM-GATEWAY": "Networking",
    "STORY-DNS-COREDNS-BASE": "Networking",
    "STORY-SEC-CERT-MANAGER-ISSUERS": "Security",
    "STORY-SEC-EXTERNAL-SECRETS-BASE": "Security",
    "STORY-OPS-RELOADER-ALL-CLUSTERS": "Operations",
    "STORY-DNS-EXTERNALDNS-CF-BIND-TUNNEL": "Networking",
    "STORY-STO-OPENEBS-BASE": "Storage",
    "STORY-STO-ROOK-CEPH-OPERATOR": "Storage",
    "STORY-STO-ROOK-CEPH-CLUSTER": "Storage",
    "STORY-OBS-VM-STACK": "Observability",
    "STORY-OBS-VICTORIA-LOGS": "Observability",
    "STORY-OBS-FLUENT-BIT": "Observability",
    "STORY-OBS-VM-STACK-IMPLEMENT": "Observability",
    "STORY-OBS-VICTORIA-LOGS-IMPLEMENT": "Observability",
    "STORY-OBS-FLUENT-BIT-IMPLEMENT": "Observability",
    "STORY-NET-CILIUM-BGP": "Networking",
    "STORY-NET-CILIUM-BGP-CP-IMPLEMENT": "Networking",
    "STORY-NET-SPEGEL-REGISTRY-MIRROR": "Networking",
    "STORY-DB-CNPG-OPERATOR": "Database",
    "STORY-DB-CNPG-SHARED-CLUSTER": "Database",
    "STORY-DB-DRAGONFLY-OPERATOR-CLUSTER": "Database",
    "STORY-SEC-NP-BASELINE": "Security",
    "STORY-IDP-KEYCLOAK-OPERATOR": "Identity",
    "STORY-NET-CILIUM-CLUSTERMESH": "Networking",
    "STORY-NET-CLUSTERMESH-DNS": "Networking",
    "STORY-SEC-SPIRE-CILIUM-AUTH": "Security",
    "STORY-STO-APPS-OPENEBS-BASE": "Storage",
    "STORY-STO-APPS-ROOK-CEPH-OPERATOR": "Storage",
    "STORY-STO-APPS-ROOK-CEPH-CLUSTER": "Storage",
    "STORY-CICD-GITHUB-ARC": "CI/CD",
    "STORY-CICD-GITLAB-APPS": "Applications",
    "STORY-APP-HARBOR": "Applications",
    "STORY-TENANCY-BASELINE": "Platform",
    "STORY-BACKUP-VOLSYNC-APPS": "Backup",
    "STORY-BOOT-CRDS": "Bootstrap & Platform",
    "STORY-GITOPS-SELF-MGMT-FLUX": "Bootstrap & Platform",
    "STORY-BOOT-CORE": "Bootstrap & Platform",
    "STORY-BOOT-AUTOMATION-ALIGN": "Bootstrap & Platform",
}

def get_sequence_mapping() -> Dict[str, int]:
    """Build sequence number mapping"""
    return {story: idx + 1 for idx, story in enumerate(GREENFIELD_SEQUENCE)}

def get_prev_next_mapping() -> Tuple[Dict[str, Optional[str]], Dict[str, Optional[str]]]:
    """Build prev/next story mappings"""
    prev_map = {}
    next_map = {}
    
    for idx, story in enumerate(GREENFIELD_SEQUENCE):
        if idx > 0:
            prev_map[story] = GREENFIELD_SEQUENCE[idx - 1]
        else:
            prev_map[story] = None
            
        if idx < len(GREENFIELD_SEQUENCE) - 1:
            next_map[story] = GREENFIELD_SEQUENCE[idx + 1]
        else:
            next_map[story] = None
    
    return prev_map, next_map

def validate_story(story_file: Path, seq_num: int, prev_story: Optional[str], next_story: Optional[str], sprint: int) -> List[str]:
    """Validate story metadata returns list of errors"""
    errors = []
    
    lines = story_file.read_text().split('\n')[:10]  # Read first 10 lines
    
    # Extract current metadata
    current_title_seq = None
    current_seq = None
    current_prev = None
    current_next = None
    current_sprint = None
    current_global = None
    
    for line in lines:
        # Title: # 02 — STORY-...
        if match := re.match(r'^#\s+(\d+)\s+—\s+STORY-', line):
            current_title_seq = int(match.group(1))
        
        # Sequence: 02/41 | Prev: ... | Next: ...
        if match := re.match(r'^Sequence:\s+(\d+)/(\d+)\s+\|?\s*(Prev:\s+([^|]+))?\s*\|?\s*(Next:\s+(.+))?$', line):
            current_seq = int(match.group(1))
            if match.group(4):
                current_prev = match.group(4).strip()
            if match.group(6):
                current_next = match.group(6).strip()
        
        # Sprint: 1
        if match := re.match(r'^Sprint:\s+(\d+)', line):
            current_sprint = int(match.group(1))
        
        # Global Sequence: 2/41
        if match := re.match(r'^Global\s+Sequence:\s+(\d+)/(\d+)$', line):
            current_global = int(match.group(1))
    
    # Validate
    if current_title_seq != seq_num:
        errors.append(f"Title seq: {current_title_seq} → {seq_num}")
    
    if current_seq != seq_num:
        errors.append(f"Seq: {current_seq}/? → {seq_num}/41")
    
    expected_prev = f"{prev_story}.md" if prev_story else "—"
    if current_prev != expected_prev:
        errors.append(f"Prev: {current_prev} → {expected_prev}")
    
    expected_next = f"{next_story}.md" if next_story else "—"
    if current_next != expected_next:
        errors.append(f"Next: {current_next} → {expected_next}")
    
    if current_sprint != sprint:
        errors.append(f"Sprint: {current_sprint} → {sprint}")
    
    if current_global != seq_num:
        errors.append(f"Global: {current_global}/? → {seq_num}/41")
    
    return errors

def fix_story(story_file: Path, seq_num: int, prev_story: Optional[str], next_story: Optional[str], sprint: int, lane: str, dry_run: bool = False) -> bool:
    """Fix story metadata returns True if fixed"""
    content = story_file.read_text()
    lines = content.split('\n')
    
    new_lines = []
    line_num = 0
    
    for line in lines:
        line_num += 1
        
        # Fix title (line 1)
        if line_num == 1 and re.match(r'^#\s+\d+\s+—\s+', line):
            new_line = re.sub(r'^#\s+\d+\s+—', f'# {seq_num:02d} —', line)
            new_lines.append(new_line)
            continue
        
        # Fix Sequence line
        if line.startswith('Sequence:'):
            seq_parts = [f"Sequence: {seq_num:02d}/41"]
            if prev_story:
                seq_parts.append(f"Prev: {prev_story}.md")
            if next_story:
                seq_parts.append(f"Next: {next_story}.md")
            new_lines.append(" | ".join(seq_parts))
            continue
        
        # Fix Sprint line
        if line.startswith('Sprint:'):
            new_lines.append(f"Sprint: {sprint} | Lane: {lane}")
            continue
        
        # Fix Global Sequence line
        if line.startswith('Global Sequence:'):
            new_lines.append(f"Global Sequence: {seq_num}/41")
            continue
        
        new_lines.append(line)
    
    if not dry_run:
        story_file.write_text('\n'.join(new_lines))
    
    return True

def main():
    dry_run = "--dry-run" in sys.argv
    validate_only = "--validate-only" in sys.argv
    
    repo_root = Path(__file__).parent.parent
    stories_dir = repo_root / "docs" / "stories"
    
    seq_map = get_sequence_mapping()
    prev_map, next_map = get_prev_next_mapping()
    
    print("=" * 60)
    print("Story Sequence Tool")
    print("=" * 60)
    if dry_run:
        print(f"{Colors.YELLOW}DRY RUN MODE - No files will be modified{Colors.NC}")
    if validate_only:
        print(f"{Colors.BLUE}VALIDATION ONLY{Colors.NC}")
    print()
    
    correct_count = 0
    incorrect_count = 0
    fixed_count = 0
    skipped_count = 0
    
    for story_file in sorted(stories_dir.glob("STORY-*.md")):
        story_name = story_file.stem
        
        if story_name not in seq_map:
            print(f"{Colors.YELLOW}⏭  SKIP{Colors.NC} {story_name} (not in greenfield schedule)")
            skipped_count += 1
            continue
        
        seq_num = seq_map[story_name]
        prev_story = prev_map[story_name]
        next_story = next_map[story_name]
        sprint = STORY_SPRINT.get(story_name, 1)
        lane = STORY_LANE.get(story_name, "Platform")
        
        errors = validate_story(story_file, seq_num, prev_story, next_story, sprint)
        
        if not errors:
            print(f"{Colors.GREEN}✅ PASS{Colors.NC} {story_name} (seq {seq_num:02d}/41)")
            correct_count += 1
        else:
            if validate_only:
                print(f"{Colors.RED}❌ FAIL{Colors.NC} {story_name} (seq {seq_num:02d}/41)")
                for error in errors:
                    print(f"        {error}")
                incorrect_count += 1
            else:
                # Fix the story
                if dry_run:
                    print(f"{Colors.BLUE}🔧 DRY-RUN{Colors.NC} {story_name} → seq {seq_num:02d}/41, sprint {sprint}")
                else:
                    fix_story(story_file, seq_num, prev_story, next_story, sprint, lane, dry_run)
                    print(f"{Colors.GREEN}✅ FIXED{Colors.NC} {story_name} → seq {seq_num:02d}/41, sprint {sprint}")
                    fixed_count += 1
    
    print()
    print("=" * 60)
    print("Summary")
    print("=" * 60)
    
    if validate_only:
        print(f"{Colors.GREEN}Correct: {correct_count}{Colors.NC}")
        print(f"{Colors.RED}Incorrect: {incorrect_count}{Colors.NC}")
        print(f"{Colors.YELLOW}Skipped: {skipped_count}{Colors.NC}")
        
        if incorrect_count > 0:
            print()
            print(f"{Colors.RED}⚠️  {incorrect_count} stories need correction{Colors.NC}")
            print("Run: ./scripts/resequence-stories.sh  (without --validate-only)")
            sys.exit(1)
        else:
            print()
            print(f"{Colors.GREEN}🎉 All stories are correctly sequenced!{Colors.NC}")
            sys.exit(0)
    else:
        print(f"{Colors.GREEN}Fixed: {fixed_count}{Colors.NC}")
        print(f"{Colors.YELLOW}Skipped: {skipped_count}{Colors.NC}")
        print(f"{Colors.GREEN}Already correct: {correct_count}{Colors.NC}")
        print()
        
        if dry_run:
            print(f"{Colors.YELLOW}DRY RUN completed. No files were modified.{Colors.NC}")
            print("Run without --dry-run to apply changes.")
        else:
            print(f"{Colors.GREEN}✅ All story sequences have been fixed!{Colors.NC}")
            print()
            print("Next steps:")
            print("  1. Review changes: git diff docs/stories/")
            print("  2. Validate: ./scripts/resequence-stories.sh --validate-only")
            print("  3. Commit: git add docs/stories/ && git commit -m 'fix: align story sequences with greenfield schedule'")

if __name__ == "__main__":
    main()
