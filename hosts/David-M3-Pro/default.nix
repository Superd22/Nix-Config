# David's M3 Pro MacBook.
#
# The directory name is the flake attribute name and matches `hostname -s`,
# so `nix run .#build-switch` picks this host with no argument.
#
# hosts/common/darwin.nix is composed in by flake.nix; this file holds only
# what is specific to this machine: the identity that used to be duplicated as
# `let user = "david"` across five module files (#2), and the enable flags that
# used to be hardcoded inside the modules themselves (#3). The package lists
# (#9) move here as that issue lands.
{ ... }:

{
  mine.user = {
    name = "david";
    fullName = "David";
    email = "superd001@gmail.com";
  };

  # Every flag below is spelled out even where it looks obvious. `mkEnableOption`
  # defaults to `false`, so nothing arrives here by default and nothing can drift
  # back in by someone changing a default in modules/. What this machine runs is
  # readable in one screen, which is the whole point.
  mine.desktop = {
    # Tiling window manager. The reason this laptop exists in this shape.
    aerospace.enable = true;

    # Off. It was previously off via `services.sketchybar.enable = false` inside
    # modules/desktop/sketchybar/sketchybar.nix; same end state, expressed here.
    sketchybar.enable = false;

    # The /usr/local/bin shims for the BetterDisplay cask, plus
    # workspace-to-next-monitor, which aerospace binds to.
    betterdisplay.enable = true;

    # On: this config manages the Dock. Which today means stripping it, since
    # `local.dock.enable` is false and the entries list is empty.
    dock.enable = true;
  };

  mine.services."screen-lock-monitor".enable = true;
}
