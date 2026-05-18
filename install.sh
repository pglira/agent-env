#!/usr/bin/env bash
# agent-env installer: presents a menu, then hands the selection to `claude`.
set -euo pipefail

REPO_OWNER="pglira"
REPO_NAME="agent-env"
REF="main"
RAW_BASE="https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/${REF}"
MANIFEST_URL="${RAW_BASE}/manifest.json"
INSTALL_MD_URL="${RAW_BASE}/INSTALL.md"

tmp_dir="$(mktemp -d -t agent-env.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT

step() { printf '\033[1m[%s]\033[0m %s\n' "$1" "$2"; }
die()  { printf '\033[1;31merror:\033[0m %s\n' "$1" >&2; exit 1; }

step "1/4" "Checking environment..."
command -v apt-get >/dev/null 2>&1 \
  || die "agent-env supports Debian/Ubuntu only (apt-based systems)."
command -v claude >/dev/null 2>&1 \
  || die "Claude Code CLI not found. Install: https://docs.claude.com/claude-code"

if ! command -v jq >/dev/null 2>&1; then
  step "1/4" "Installing jq..."
  sudo apt-get install -y jq >/dev/null
fi

if command -v gum >/dev/null 2>&1; then
  GUM="gum"
else
  step "1/4" "Fetching gum (TUI) for this session..."
  case "$(uname -m)" in
    x86_64)        gum_arch="x86_64" ;;
    aarch64|arm64) gum_arch="arm64" ;;
    *)             die "unsupported architecture: $(uname -m)" ;;
  esac
  gum_url=$(curl -fsSL https://api.github.com/repos/charmbracelet/gum/releases/latest \
    | jq -r --arg a "$gum_arch" '.assets[] | .browser_download_url
        | select(test("_Linux_" + $a + "\\.tar\\.gz$"))')
  [ -n "$gum_url" ] || die "could not resolve gum release asset for Linux_${gum_arch}"
  curl -fsSL "$gum_url" -o "$tmp_dir/gum.tar.gz"
  tar -xzf "$tmp_dir/gum.tar.gz" -C "$tmp_dir"
  GUM="$(find "$tmp_dir" -type f -name gum -executable | head -n1)"
  [ -x "$GUM" ] || die "could not extract gum binary"
fi

step "2/4" "Fetching manifest..."
manifest=$(curl -fsSL "$MANIFEST_URL")
n_items=$(echo "$manifest" | jq -r '.items | length')
[ "$n_items" -gt 0 ] \
  || { echo "No items available to install yet (manifest is empty)."; exit 0; }

step "3/4" "Showing menu..."
options=()
while IFS=$'\t' read -r type name desc; do
  options+=("${type}:${name}  ${desc}")
done < <(echo "$manifest" | jq -r '.items[] | [.type, .name, .description] | @tsv')

selected=$(
  "$GUM" choose --no-limit \
    --header "Select items to install (space toggles, enter confirms):" \
    "${options[@]}" \
    </dev/tty
) || { echo "Cancelled."; exit 0; }

[ -n "$selected" ] || { echo "Nothing selected."; exit 0; }

prompt_file="$tmp_dir/prompt.md"
{
  echo "Install the following items into ~/.claude/ on this machine, following the procedure at:"
  echo "  ${INSTALL_MD_URL}"
  echo
  echo "Items to install (in order):"
  while IFS= read -r line; do
    tag="${line%% *}"
    type="${tag%%:*}"
    name="${tag#*:}"
    echo "  - ${type}: ${name}"
  done <<< "$selected"
  echo
  echo "Begin by fetching INSTALL.md and following its rules. When done, print a short summary."
} > "$prompt_file"

step "4/4" "Prompt for claude:"
echo
sed 's/^/    /' "$prompt_file"
echo
echo "Launching claude..."
echo

exec </dev/tty >/dev/tty 2>&1
exec claude "$(cat "$prompt_file")"
