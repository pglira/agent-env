# Comments

Write code comments in an absolute manner: a comment must describe the code as it
stands — its general behavior — not how it changed, what was requested, or facts
that are only true in one particular environment.

- Describe what the code *is* and *does*, never the edit history or the diff.
- Do not reference previous versions, what was removed, or what was added.
- Do not reference the user's request, the task, or the reason for a change.
- Do not state facts that hold only on one machine or in one setup — who exports a
  variable, where a file lives on this PC, what a value happens to be here.
  Describe the machine-agnostic behavior instead.
- A comment must read identically whether the code was just written or has existed
  unchanged for years, and whether it runs on this machine or any other.

Avoid (relative — describes the change or request):

```
# Now also handle the empty case
# Changed to use a set for performance
# Added retry logic as requested
# Removed the old parser
```

Prefer (absolute — describes the code as it stands):

```
# Handle the empty case
# Use a set for O(1) membership checks
# Retry on transient network errors
```

Avoid (environment-specific — true only here, not elsewhere):

```
# Reads $DIR_BOOKMARKS, exported by the user's shell, outside this repo
# Connects to the staging DB on port 5433
# Path is /data1/Dropbox/... on this machine
```

Prefer (absolute — describes the general behavior):

```
# Reads the file named by $DIR_BOOKMARKS
# Connects to the database at $DB_URL
# Path comes from $DIR_BOOKMARKS
```
