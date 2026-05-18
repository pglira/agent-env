# agent-env

Bootstrap a Claude Code environment (skills, agents, CLAUDE.md, settings.json) on a Debian/Ubuntu machine via a single command.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/pglira/agent-env/main/install.sh | bash
```

The installer:

1. Checks for `apt-get` and `claude`; auto-installs `jq` and fetches `gum` if missing.
2. Loads `manifest.json` from this repo and shows a `gum` checklist of available items.
3. Builds a prompt referencing [`INSTALL.md`](./INSTALL.md) and hands it to `claude -p`.
4. The Claude Code agent fetches each selected item and writes it into `~/.claude/`.

## Requirements

- Debian/Ubuntu (other distros are rejected up front)
- [Claude Code CLI](https://docs.claude.com/claude-code) on `$PATH`

## Layout

| Path | Purpose |
|---|---|
| `install.sh` | Bootstrap script (this is what `curl \| bash` runs). |
| `manifest.json` | List of installable items: `{type, name, description}`. |
| `INSTALL.md` | Procedure the agent follows to install each item type. |
| `content/skill-<name>/` | Skill folder → `~/.claude/skills/<name>/` (overwrite). |
| `content/agent-<name>.md` | Agent file → `~/.claude/agents/<name>.md` (overwrite). |
| `content/claude-<name>.md` | CLAUDE.md variant → concat in selection order, overwrite `~/.claude/CLAUDE.md`. |
| `content/settings-<name>.json` | settings.json fragment → `jq` deep-merge into `~/.claude/settings.json` (repo wins). |
