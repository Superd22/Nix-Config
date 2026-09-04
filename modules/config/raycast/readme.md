# Raycast

Dmenu alternative for macOS.

`scripts/` is wired up by [`modules/desktop/raycast`](../../desktop/raycast/default.nix),
which renders each command into `~/.config/raycast/scripts` with a shebang and a
store-pinned `PATH` prepended. The sources here therefore have no shebang of
their own and call `aerospace` / `betterdisplaycli` by bare name.

One manual step remains on a fresh machine: in Raycast, Settings ->
Extensions -> Script Commands -> "Add Script Directory", and pick
`~/.config/raycast/scripts`. `quicklinks.json` also has to be imported by hand —
Raycast exposes no on-disk format for quicklinks.

## Layout
```
.
├── scripts/              # bash script commands, rendered into the home by the nix module
├── quicklinks.json       # Quicklinks to import to raycast
```
