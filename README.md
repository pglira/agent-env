# agent-env

Bootstrap a project-scoped Claude Code environment (skills, agents, `CLAUDE.md`, `settings.json`) on a Debian/Ubuntu machine via a single command. Items are installed into the **current directory** (`./.claude/...`, `./CLAUDE.md`) — never into `$HOME` or `~/.claude/`.

## Install

> **`cd` into the target project root first.** Both the `curl | bash` line and the printed `claude` command operate on the current directory. Running them from `$HOME` would scaffold project config into your home folder.

```bash
curl -fsSL https://raw.githubusercontent.com/pglira/agent-env/main/install.sh | bash
```

The installer:

1. Checks for `apt-get` and `claude`; auto-installs `jq` and fetches `gum` if missing.
2. Loads `manifest.json` from this repo and shows a `gum` checklist of available items.
3. Builds a prompt referencing [`INSTALL.md`](./INSTALL.md) and writes it to `~/.cache/agent-env/prompt.md`.
4. Prints a `claude` command for you to copy/paste — running it from your project root, Claude Code fetches each selected item and writes it under `./.claude/` (or `./CLAUDE.md`).

## Requirements

- Debian/Ubuntu (other distros are rejected up front)
- [Claude Code CLI](https://docs.claude.com/claude-code) on `$PATH`

## Layout

| Path | Purpose |
|---|---|
| `install.sh` | Bootstrap script (this is what `curl \| bash` runs). |
| `manifest.json` | List of installable items: `{type, name, description}`. |
| `INSTALL.md` | Procedure the agent follows to install each item type. |
| `content/skill-<name>/` | Skill folder → `./.claude/skills/<name>/` (overwrite). |
| `content/agent-<name>.md` | Agent file → `./.claude/agents/<name>.md` (overwrite). |
| `content/claude-<name>.md` | CLAUDE.md variant → concat in selection order, overwrite `./CLAUDE.md`. |
| `content/settings-<name>.json` | settings.json fragment → `jq` deep-merge into `./.claude/settings.json` (repo wins). |
