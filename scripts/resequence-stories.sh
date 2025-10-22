#!/bin/bash
# resequence-stories.sh
# Simple wrapper to call the Python resequence script
#
# Usage: ./scripts/resequence-stories.sh [--dry-run] [--validate-only]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check if Python 3 is available
if ! command -v python3 &> /dev/null; then
    echo "Error: python3 is required but not found"
    exit 1
fi

# Run the Python script
exec python3 "${SCRIPT_DIR}/resequence_stories.py" "$@"
