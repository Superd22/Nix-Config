# Spike: TOML 1.1.0 vs `.aerospace.toml`, and keeping it neat

Follow-up to #37. Question asked: AeroSpace 0.21.0+ speaks TOML 1.1.0 and its
docs now recommend multi-line inline tables for `on-window-detected` — can we
have that, or something as readable, given `aerospace.nix` parses the file with
`lib.importTOML`?

Everything below was measured on this machine (AeroSpace 0.21.2-Beta,
nix-darwin `4cff07d`). `./run.sh` and the `probe-*.sh` / `render.sh` scripts
reproduce it.

## 1. Nix is TOML 1.0.0, and it fails hard

`builtins.fromTOML` rejects a multi-line inline table outright:

```
[error] toml::parse_table: newline (LF / CRLF) or EOF is expected
 3 | ...  = 'com.apple.iphonesimulator',
   |                                   ^-- here
```

Fixtures `b-multiline.toml` and `c-array-of-multiline.toml` fail; `a-oneline.toml`
passes. This is an eval-time failure, so a mistake here breaks `nix build`
rather than silently breaking the window manager. That is the good outcome.

## 2. …but TOML 1.1.0 buys us nothing here anyway

Two separate things got conflated in #37:

- **TOML 1.1.0** — purely a *formatting* dialect change (newlines inside inline
  tables). Nix can't read it.
- **The modern `on-window-detected` syntax** — `if` becomes a command string
  instead of a table. This is orthogonal, and is the part that actually reads
  better.

And the readability gap 1.1.0 closes can be closed inside 1.0.0. TOML 1.0.0
lets an **array** span newlines; it only forbids an **inline table** from doing
so. So one rule per line inside a multi-line array is legal 1.0.0
(`d-array-oneline-tables.toml`, passes) and is about as neat as what upstream's
docs show.

## 3. The file AeroSpace reads is generated, so source formatting is cosmetic

`render.sh` builds the file nix-darwin actually installs. Whatever shape the
source is in, `pkgs.formats.toml` re-emits it its own way:

```toml
[[on-window-detected]]
run = "layout tiling"

[on-window-detected.if]
app-id = "com.apple.iphonesimulator"
```

So there is no runtime consequence to any of this. "Neat" is only ever about
the hand-edited source file, which is exactly what `aerospace.nix`'s existing
comment says we are optimising for.

## 4. The real blocker is nix-darwin, not TOML

This is the finding that matters. `services.aerospace.settings` is *mostly*
freeform, but `on-window-detected` is explicitly typed
(`modules/services/aerospace/default.nix:98`), and its `if` is a submodule with
exactly five hard-coded keys — `app-id`, `workspace`,
`window-title-regex-substring`, `app-name-regex-substring`,
`during-aerospace-startup`. Feeding it the modern string form gives:

```
error: A definition for option `services.aerospace.settings.on-window-detected."[definition 1-entry 1]"."if"'
       is not of type `submodule'.
       - "test %{app-bundle-id} = com.apple.iphonesimulator"
```

Still true on nix-darwin `master` as of today. So the modern syntax is
unavailable to us for a reason that has nothing to do with TOML versions.

AeroSpace itself is perfectly happy with it — `aerospace test %{app-bundle-id}
= com.apple.iphonesimulator` returns a clean exit 1 (false, nothing matching
focused) rather than a parse error, and that is the same evaluator the modern
`if` uses.

## 5. `config-version` / `persistent-workspaces` are fine

Both are plain scalars/lists and go straight through the freeform part of the
type. Verified in the rendered output:

```toml
config-version = 2
persistent-workspaces = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10"]
```

## Recommendation

Take the #37 migration now, in this shape (already applied to
`.aerospace.toml` on this branch):

- add `config-version = 2` and an explicit `persistent-workspaces`;
- keep the **legacy** `if.app-id` condition — upstream soft-deprecates it but
  says it "probably will remain supported forever", and nix-darwin gives us no
  choice;
- move `on-window-detected` to a top-level multi-line array of single-line
  inline tables. Note it *has* to move to the top of the file: as an array it
  is a top-level assignment, and TOML forbids those after the first `[table]`
  header.

Optional follow-up, small and self-contained: PR nix-darwin to widen that `if`
to `either str (submodule { ... })`. That is the only thing standing between us
and the modern syntax, and it would unblock every other nix-darwin user too.

## Not done here

The generated file was rendered and read, but not parsed by AeroSpace itself —
`aerospace reload-config` only ever reads the store path baked into launchd at
switch time, and there is no `--config` flag to point it elsewhere. Confirming
`reload-config --dry-run --warnings-as-errors` exits zero needs a real
`build-switch`, which is the #37 acceptance check.
