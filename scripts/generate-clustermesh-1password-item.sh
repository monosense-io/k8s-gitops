#!/usr/bin/env bash
set -euo pipefail

# Generate or update a 1Password item from a live cilium-clustermesh Secret.
# - Decodes Kubernetes Secret .data (base64) into raw etcd config content
# - Writes each entry as a separate field in a 1Password item
#
# Requirements: kubectl, jq, 1Password CLI v2 (`op`) and signed-in session.
#
# Usage examples:
#   ./scripts/generate-clustermesh-1password-item.sh \
#     -c infra -v "Platform" -t "kubernetes/infra/cilium-clustermesh"
#   ./scripts/generate-clustermesh-1password-item.sh \
#     -c apps  -v "Platform" -t "kubernetes/apps/cilium-clustermesh"

CTX=""
VAULT=""
TITLE=""
NAMESPACE="kube-system"
SECRET_NAME="cilium-clustermesh"

while getopts ":c:v:t:n:s:h" opt; do
  case $opt in
    c) CTX="$OPTARG" ;;
    v) VAULT="$OPTARG" ;;
    t) TITLE="$OPTARG" ;;
    n) NAMESPACE="$OPTARG" ;;
    s) SECRET_NAME="$OPTARG" ;;
    h) echo "Usage: $0 -c <context> -v <vault> -t <title> [-n <ns>=kube-system] [-s <secret>=cilium-clustermesh]"; exit 0 ;;
    *) echo "Invalid option: -$OPTARG" >&2; exit 2 ;;
  esac
done

if [[ -z "$CTX" || -z "$VAULT" || -z "$TITLE" ]]; then
  echo "ERROR: -c <context>, -v <vault>, and -t <title> are required." >&2
  exit 2
fi

command -v kubectl >/dev/null || { echo "kubectl not found" >&2; exit 2; }
command -v jq >/dev/null || { echo "jq not found" >&2; exit 2; }
command -v op >/dev/null || { echo "1Password CLI (op) not found" >&2; exit 2; }

tmpdir="$(mktemp -d)"
cleanup() { rm -rf "$tmpdir"; }
trap cleanup EXIT

echo "Fetching secret ${SECRET_NAME} from context=${CTX}, namespace=${NAMESPACE} ..." >&2
secret_json="$(kubectl --context "$CTX" -n "$NAMESPACE" get secret "$SECRET_NAME" -o json)"

if [[ "$(jq -r '.kind' <<<"$secret_json")" != "Secret" ]]; then
  echo "ERROR: Secret ${SECRET_NAME} not found in ${NAMESPACE} (context=${CTX})." >&2
  exit 3
fi

# Build op CLI args, one file per field (decoded)
mapfile -t keys < <(jq -r '.data | keys[]' <<<"$secret_json")
if [[ ${#keys[@]} -eq 0 ]]; then
  echo "ERROR: Secret has no .data entries." >&2
  exit 3
fi

declare -a args
for key in "${keys[@]}"; do
  value_decoded="$(jq -r --arg k "$key" '.data[$k] | @base64d' <<<"$secret_json")"
  f="$tmpdir/$key"
  # Preserve exact content including newlines
  printf "%s" "$value_decoded" > "$f"
  args+=("$key=@$f")
done

set +e
op item get "$TITLE" --vault "$VAULT" >/dev/null 2>&1
exists=$?
set -e

if [[ $exists -eq 0 ]]; then
  echo "Updating existing 1Password item: vault=$VAULT title=$TITLE" >&2
  op item edit "$TITLE" --vault "$VAULT" "${args[@]}" >/dev/null
else
  echo "Creating new 1Password item: vault=$VAULT title=$TITLE" >&2
  op item create --vault "$VAULT" --category "secure note" --title "$TITLE" "${args[@]}" >/dev/null
fi

echo "Done. Item '$TITLE' in vault '$VAULT' now contains fields: ${keys[*]}" >&2

