# agent-env installation procedure

You are being run by the `agent-env` installer. The user's first message lists items to install and an **install scope** (`project` or `home`). Follow this procedure exactly.

## Repository

- GitHub: `pglira/agent-env`, branch `main`
- Raw base: `https://raw.githubusercontent.com/pglira/agent-env/main/`
- API base: `https://api.github.com/repos/pglira/agent-env/contents/`

## Install scope

The user's message contains a line `Install scope: <scope>`, where `<scope>` is one of:

- `project` — install into the current working directory (treat it as the project root).
- `home` — install system-wide into the user's home Claude config under `~/.claude/`.

Pick the install targets for the active scope from the table below. Never write outside the chosen root: for `project`, do **not** write under `$HOME`; for `home`, do **not** write into the current working directory.

## Path conventions

Each item arrives as `<type>: <name>`. Map to a repo path and the install target for the active scope:

| Type             | Repo path                          | Target (`project`)            | Target (`home`)               |
|------------------|------------------------------------|-------------------------------|-------------------------------|
| `skill`          | `content/skill-<name>/` (folder)   | `./.claude/skills/<name>/`    | `~/.claude/skills/<name>/`    |
| `agent`          | `content/agent-<name>.md`          | `./.claude/agents/<name>.md`  | `~/.claude/agents/<name>.md`  |
| `claude_md`      | `content/claude-<name>.md`         | `./CLAUDE.md`                 | `~/.claude/CLAUDE.md`         |
| `settings_json`  | `content/settings-<name>.json`     | `./.claude/settings.json`     | `~/.claude/settings.json`     |

Create missing target directories with `mkdir -p`.

## Install rules

### `skill: <name>`

1. List the folder via the GitHub contents API: `content/skill-<name>?ref=main`.
2. For each entry, recurse into subdirectories the same way; for files, fetch the `download_url`.
3. Write each file under the `skill` target for the active scope, preserving subpaths.
4. Overwrite any existing files.

### `agent: <name>`

1. Fetch `content/agent-<name>.md` from the raw base.
2. Write to the `agent` target for the active scope, overwriting any existing file.

### `claude_md: <name>` (one or more)

1. Fetch every selected `content/claude-<name>.md` in the order they appear in the user's message.
2. Concatenate the contents in that order, separated by one blank line.
3. Write the result to the `claude_md` target for the active scope, overwriting whatever was there.

### `settings_json: <name>` (one or more)

1. Read the existing `settings_json` target for the active scope (use `{}` if absent or empty).
2. Fetch each selected `content/settings-<name>.json` in the order they appear in the user's message.
3. Deep-merge sequentially with `jq`, existing settings first, then each fetched fragment — later sources override earlier on conflicting keys, so repo fragments win over the user's existing keys, and later fragments win over earlier ones:

   ```bash
   jq -s 'reduce .[] as $x ({}; . * $x)' existing.json frag1.json frag2.json ...
   ```

4. Write the merged JSON (pretty-printed) back to the `settings_json` target for the active scope.

## After install

Print a short summary listing what was installed (one line per item, with its install path). If any fetch failed, list it under a "skipped" section with the reason. Do not commit, push, or modify anything outside the chosen install root (the current working directory for `project`, or `~/.claude/` for `home`).
