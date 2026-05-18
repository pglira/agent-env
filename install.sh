#!/usr/bin/env bash
# agent-env installer: presents a menu, then hands the selection to `claude`.
set -euo pipefail

REPO_OWNER="pglira"
REPO_NAME="agent-env"
REF="main"
RAW_BASE="https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/${REF}"
MANIFEST_URL="${RAW_BASE}/manifest.json"
INSTALL_MD_URL="${RAW_BASE}/INSTALL.md"

tmp_prompt="$(mktemp -t agent-env.XXXXXX)"
trap 'rm -f "$tmp_prompt"' EXIT

step() { printf '\033[1m[%s]\033[0m %s\n' "$1" "$2"; }
die()  { printf '\033[1;31merror:\033[0m %s\n' "$1" >&2; exit 1; }

step "1/4" "Checking environment..."
command -v apt-get >/dev/null 2>&1 \
  || die "agent-env supports Debian/Ubuntu only (apt-based systems)."
command -v claude >/dev/null 2>&1 \
  || die "Claude Code CLI not found. Install: https://docs.claude.com/claude-code"

need_install=()
command -v jq       >/dev/null 2>&1 || need_install+=(jq)
command -v whiptail >/dev/null 2>&1 || need_install+=(whiptail)
if [ "${#need_install[@]}" -gt 0 ]; then
  step "1/4" "Installing missing packages: ${need_install[*]}"
  sudo apt-get install -y "${need_install[@]}" >/dev/null
fi

step "2/4" "Fetching manifest..."
manifest=$(curl -fsSL "$MANIFEST_URL")
n_items=$(echo "$manifest" | jq -r '.items | length')
if [ "$n_items" -eq 0 ]; then
  echo "No items available to install yet (manifest is empty)."
  exit 0
fi

step "3/4" "Building menu..."
args=()
while IFS=$'\t' read -r type name desc; do
  args+=("${type}:${name}" "$desc" "OFF")
done < <(echo "$manifest" | jq -r '.items[] | [.type, .name, .description] | @tsv')

selected=$(
  whiptail \
    --title "agent-env" \
    --separate-output \
    --checklist "Select items to install (space toggles, enter confirms):" \
    20 78 12 \
    "${args[@]}" \
    3>&1 1>&2 2>&3 </dev/tty
) || { echo "Cancelled."; exit 0; }

if [ -z "$selected" ]; then
  echo "Nothing selected."
  exit 0
fi

step "4/4" "Handing off to claude..."
{
  echo "Install the following items into ~/.claude/ on this machine, following the procedure at:"
  echo "  ${INSTALL_MD_URL}"
  echo
  echo "Items to install (in order):"
  while IFS= read -r tag; do
    type="${tag%%:*}"
    name="${tag#*:}"
    echo "  - ${type}: ${name}"
  done <<< "$selected"
  echo
  echo "Begin by fetching INSTALL.md and following its rules. When done, print a short summary."
} > "$tmp_prompt"

exec </dev/tty
claude "$(cat "$tmp_prompt")"
