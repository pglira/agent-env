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

need_pkgs=()
command -v jq     >/dev/null 2>&1 || need_pkgs+=(jq)
command -v script >/dev/null 2>&1 || need_pkgs+=(bsdextrautils)
if [ "${#need_pkgs[@]}" -gt 0 ]; then
  step "1/4" "Installing: ${need_pkgs[*]}"
  sudo apt-get install -y "${need_pkgs[@]}" >/dev/null
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
echo "─── streaming progress ──────────────────────────────"
echo

# Wrap claude in `script -qfc` so it sees a pty for stdout. Without this,
# piping claude's stream-json output into jq triggers full block buffering
# and nothing reaches the user until claude finishes.
cat > "$tmp_dir/run-claude.sh" <<EOF
#!/bin/sh
exec claude -p --output-format stream-json --permission-mode bypassPermissions "\$(cat "$prompt_file")"
EOF
chmod +x "$tmp_dir/run-claude.sh"

exec </dev/tty
script -qfc "$tmp_dir/run-claude.sh" /dev/null \
| jq -r --unbuffered '
    if .type == "system" and .subtype == "init" then "● session started"
    elif .type == "assistant" then
      [(.message.content // [])[] |
        if .type == "text" and (.text | length) > 0 then .text
        elif .type == "tool_use" then "● " + .name
        else empty end
      ] | join("\n")
    elif .type == "user" then
      [(.message.content // [])[]? |
        if .type == "tool_result" then "  ↳ done" else empty end
      ] | join("\n")
    elif .type == "result" then "\n● finished in \((.duration_ms / 1000 | floor))s"
    else empty
    end' 2>/dev/null
