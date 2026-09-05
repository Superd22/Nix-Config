# Claude Code configuration

These files are not copied or generated. `~/.claude/settings.json`,
`~/.claude/CLAUDE.md` and `~/.claude/skills` are symlinks pointing here, made by
`modules/programs/claude-code` — so the file Claude Code reads and the file git
tracks are the same file, and adding a skill needs no rebuild.

| | |
|---|---|
| `settings.json` | Written by Claude Code itself. Approving a permission or installing a plugin shows up here as a `git diff`. |
| `skills/` | One directory per skill. Anything created in `~/.claude/skills` lands here as an untracked file. |
| `CLAUDE.md` | Global instructions, prepended to every session. Shipped empty. |
| `mcp-servers.json` | The exception: MCP servers live in `~/.claude.json`, which is mostly machine state and cannot be symlinked, so this one *is* merged in at activation. `claude mcp add` still works — the next `build-switch` writes what it added back into this file. |

Two things to know, both explained in `docs/two-paths.md`:

- **`git` moves live configuration.** Checking out an older commit rewrites the
  skills of a running session; `git clean -fdx` deletes them.
- **This is versioned the instant you type it.** Nothing sits between
  `settings.json` and the working tree, so no credential belongs in it. The
  activation warns about `env`, `apiKeyHelper` and `awsAuthRefresh`, and refuses
  to adopt MCP servers carrying `headers` or `env`.

WeMaintain's MCP servers are not here. They are in `modules/work/wemaintain`,
behind `mine.work.wemaintain.enable`, so a fork does not inherit endpoints it
has no account for.
