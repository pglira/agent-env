#!/usr/bin/env bash
# agent-env installer: presents a menu and prints the claude command to run.
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
  # Resolve the latest tag via github.com's HTTP redirect (api.github.com
  # is unauthenticated-rate-limited to 60/hr per IP).
  gum_tag=$(curl -fsI -o /dev/null -w '%{redirect_url}' \
    https://github.com/charmbracelet/gum/releases/latest | sed 's|.*/||')
  [ -n "$gum_tag" ] || die "could not resolve latest gum version"
  gum_ver="${gum_tag#v}"
  gum_url="https://github.com/charmbracelet/gum/releases/download/${gum_tag}/gum_${gum_ver}_Linux_${gum_arch}.tar.gz"
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

# Ask where the selected items should be installed: into the current project
# (./.claude/, ./CLAUDE.md) or system-wide into the user's home (~/.claude/).
scope_choice=$(
  "$GUM" choose \
    --header "Install scope — where should the selected items go?" \
    "project  current directory (./.claude/, ./CLAUDE.md)" \
    "home     system-wide (~/.claude/)" \
    </dev/tty
) || { echo "Cancelled."; exit 0; }
scope="${scope_choice%% *}"   # leading keyword only: "project" or "home"
[ -n "$scope" ] || { echo "No scope selected."; exit 0; }

# Scope-specific wording for the install prompt.
if [ "$scope" = "home" ]; then
  scope_intro="Install the following items SYSTEM-WIDE into the user's home Claude config under ~/.claude/, NOT into the current working directory. Follow the procedure at:"
  scope_outro="Begin by fetching INSTALL.md and following its rules for the \"home\" scope. All targets are under ~/.claude/ — never inside the current working directory. When done, print a short summary."
else
  scope_intro="Install the following items into the CURRENT WORKING DIRECTORY (project-scoped, NOT into \$HOME or ~/.claude/). Follow the procedure at:"
  scope_outro="Begin by fetching INSTALL.md and following its rules for the \"project\" scope. All targets are under ./.claude/ or ./CLAUDE.md — never under \$HOME. When done, print a short summary."
fi

# Save the prompt to a persistent location the user can reference after this
# script exits (the temp dir is wiped on EXIT).
out_dir="$HOME/.cache/agent-env"
mkdir -p "$out_dir"
prompt_file="$out_dir/prompt.md"
{
  echo "$scope_intro"
  echo "  ${INSTALL_MD_URL}"
  echo
  echo "Install scope: ${scope}"
  echo
  echo "Items to install (in order):"
  while IFS= read -r line; do
    tag="${line%% *}"
    type="${tag%%:*}"
    name="${tag#*:}"
    echo "  - ${type}: ${name}"
  done <<< "$selected"
  echo
  echo "$scope_outro"
} > "$prompt_file"

cmd="claude --permission-mode bypassPermissions \"\$(cat ${prompt_file})\""

step "4/4" "Prompt saved. Run this command to install:"
echo
printf '  \033[1m%s\033[0m\n' "$cmd"
echo

# Best-effort copy to clipboard.
clip_status=""
if [ -n "${WAYLAND_DISPLAY:-}" ] && command -v wl-copy >/dev/null 2>&1; then
  printf '%s' "$cmd" | wl-copy && clip_status="copied to clipboard (wl-copy)"
elif [ -n "${DISPLAY:-}" ] && command -v xclip >/dev/null 2>&1; then
  printf '%s' "$cmd" | xclip -selection clipboard && clip_status="copied to clipboard (xclip)"
elif [ -n "${DISPLAY:-}" ] && command -v xsel >/dev/null 2>&1; then
  printf '%s' "$cmd" | xsel --clipboard --input && clip_status="copied to clipboard (xsel)"
fi

if [ -n "$clip_status" ]; then
  echo "  ($clip_status)"
else
  echo "  (no clipboard tool found; install wl-clipboard or xclip to auto-copy)"
fi
echo
