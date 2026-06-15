# Comments

Write code comments in an absolute manner: a comment must describe the current
state of the code as it is, not how it changed or what was requested.

- Describe what the code *is* and *does*, never the edit history or the diff.
- Do not reference previous versions, what was removed, or what was added.
- Do not reference the user's request, the task, or the reason for a change.
- A comment must read identically whether the code was just written or has
  existed unchanged for years.

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
