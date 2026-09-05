# Two ways a module can own a file

Almost every module here generates the file it manages: nix owns the content,
renders it, and puts it where the program expects. `modules/programs/claude-code`
does the opposite — the file lives in this repo and `~/.claude` points at it —
and read cold that looks like an inconsistency rather than a decision.

It is a decision. Both shapes are correct, for different files, and which one a
file gets is not a matter of taste. This page is the test.

## Path A — declare and generate

Nix owns the content. The artifact's home is a tree we do not control, or one
that must not be in git, so the repo holds a *declaration* and activation turns
it into the real thing.

Three variants are already in the tree:

| | |
|---|---|
| Store symlink | `modules/desktop/raycast` renders the script commands into `~/.config/raycast/scripts`. Read-only is fine; Raycast only reads them. |
| Copy, writable | `modules/programs/datagrip` copies `dataSources.xml` in with `install`. It cannot symlink: the IDE rewrites that file whenever a datasource changes, and the store is read-only. Drift between switches is the accepted cost, and its header argues this out at length. |
| Intercept the imperative act | `modules/homebrew/nix-brew.sh` (#35). `brew tap` and `brew install` keep working; the wrapper writes the pin into `modules/homebrew/taps.nix` or `hosts/<host>/homebrew-generated.nix`, and `brew drift` lists what escaped. |

The cost is an interception layer, drift detection, and a rebuild before a
change takes effect.

## Path B — adopt in place

The repo holds the real file. Nix only points the program's expected path at it,
with `config.lib.file.mkOutOfStoreSymlink`, and then has no further role.
`modules/programs/claude-code` is the only one today.

The payoff is that drift is structurally impossible, because there is one copy
of the file. A skill written into `~/.claude/skills` is an untracked file in this
repo the moment it is saved. No rebuild, and nothing to remember.

The costs are real and worth knowing before you pick this:

- **`git` moves live configuration.** Checking out an older commit rewrites the
  skills of any Claude Code session running at that moment. `git clean -fdx`
  deletes them.
- **Nix cannot template the file.** No host-specific values, no `mine.user.email`
  interpolated in, and no way to give a fork a different copy. If a file ever
  needs to vary, it moves to Path A.
- **No prompt between typing and versioning.** A credential typed into the file
  is in the working tree immediately. The claude-code module scans for the keys
  that hold one and warns, which is mitigation, not a fix.
- **The path is hardcoded.** `mkOutOfStoreSymlink` bakes in the checkout
  location. Move the repo and the symlinks dangle.

## The test

In order. The first one usually settles it.

**1. Can the artifact live in this repo?**

No means Path A, and it is normally obvious why: a foreign tree
(`/opt/homebrew/Cellar`), a root-owned store symlink (`Taps`), or a file that is
mostly machine state (`~/.claude.json` is 85 KB of caches, telemetry,
`oauthAccount` and per-project history around a few lines of config).

**2. Is there a declaration meaningfully shorter than the artifact that
reproduces it losslessly?**

Yes means Path A pays for itself. `"deskflow"` reproduces an entire Homebrew
install — that asymmetry is the whole return on the generation layer.

No means Path B. The shortest thing that reproduces a `SKILL.md` is the
`SKILL.md`; a generation layer would "declare" the file by storing the file and
then copy it into place, which is ceremony plus a rebuild in exchange for
nothing.

**3. Does the program tolerate a symlink and write through it in place?**

No means Path A, copy variant, and you accept the drift. DataGrip is the
cautionary case. Claude Code was tested and does: it followed the symlink,
preserved it, and merged its write rather than clobbering the file.
`CLAUDE_CONFIG_DIR` points Claude Code at a throwaway config directory, which
makes this cheap to check rather than assume — the equivalent for another
program is worth finding before committing to Path B.

Frequency is not a criterion but it is an amplifier. It decides how much
ceremony Path A can carry before it gets bypassed in practice. `brew install` is
occasional, so `nix-brew` can afford a three-way prompt on every call. Skills get added
most days, often by Claude itself mid-session, so anything per-skill would
simply be skipped — and a drift-control layer that gets skipped is worse than
none, because it looks like it is working.

## One feature, both paths

`modules/programs/claude-code` is the useful example precisely because it needs
each path for a different file, decided by test 1 alone:

- `settings.json`, `skills/`, `CLAUDE.md` — Path B. Ordinary files at a path we
  control.
- MCP servers — Path A. They live only in `~/.claude.json`, which fails test 1,
  so the repo holds `mcp-servers.json`, activation merges it in, and anything
  `claude mcp add` leaves on disk is written back into the repo file so it turns
  up in `git status`.

The boundary is not philosophical. It is decided per file, by where that file
has to live.
