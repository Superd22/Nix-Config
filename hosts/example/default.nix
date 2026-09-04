# A second host that is not David's machine.
#
# It exists so the repo has a non-personal host that still evaluates, which is
# what CI (#10) checks and what the setup wizard (#5) copies.
#
# The identity below is a deliberate placeholder rather than a default on the
# options themselves: `mine.user.*` has no defaults, so a fork that forgets to
# set them fails with an error naming the option instead of silently building
# as david. This host sets obvious junk so `.#example` keeps evaluating —
# `nix flake show`, `nix flake check` and CI all need it to — while being
# visibly wrong to anyone who actually tries to build it.
#
# It is not derived from hosts/David-M3-Pro and is meant to diverge from it as
# the package lists (#9) land.
{ ... }:

{
  mine.user = {
    name = "changeme";
    fullName = "Change Me";
    email = "you@example.com";
  };

  # A plain machine. The flags default to `false`, so this block only has to
  # say what a generic fork should get; anything left out is off.
  mine.desktop = {
    # On. It is the one opinionated thing in this repo that is worth arriving
    # switched on, and it keeps CI evaluating a desktop module in its enabled
    # branch rather than only its disabled one.
    aerospace.enable = true;

    # Off. A status bar is a taste, not a default.
    sketchybar.enable = false;

    # Off. The activation script writes to /usr/local/bin and still hardcodes a
    # /Users/david path (#4); it also only makes sense with the BetterDisplay
    # cask actually installed.
    betterdisplay.enable = false;

    # Off. With `local.dock.enable` false this would strip the Dock bare on
    # first activation, which is not something a fork should discover by
    # surprise.
    dock.enable = false;
  };

  # Off. A launchd agent labelled com.david.* watching lock events is not a
  # generic want.
  mine.services."screen-lock-monitor".enable = false;
}
