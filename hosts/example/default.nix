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
# It is not derived from hosts/David-M3-Pro and diverges from it deliberately:
# the flags below are what a generic fork should get, and the Homebrew lists
# (#9) are a short seed rather than one person's applications.
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

    # Off. `betterdisplaycli` wraps a binary inside the BetterDisplay app
    # bundle, so it means nothing without the cask actually installed.
    betterdisplay.enable = false;

    # Off. With `local.dock.enable` false this would strip the Dock bare on
    # first activation, which is not something a fork should discover by
    # surprise.
    dock.enable = false;

    # Off. The scripts here are for one specific ultra-wide monitor, and wiring
    # them up needs a manual step in Raycast's settings anyway. It would also
    # fail the assertion in modules/desktop/raycast with betterdisplay off,
    # which is the point of that assertion.
    raycast.enable = false;
  };

  # Homebrew (#9). This is the seed a fork copies and edits, so it is a short
  # generic list rather than a copy of hosts/David-M3-Pro — Steam, NordVPN and
  # Autodesk Fusion are exactly the sort of thing that should not arrive with a
  # config someone else wrote. Add what you actually use; `brew search` takes
  # the same names.
  #
  # Casks a module cannot work without are not listed here and never need to be:
  # `mine.desktop.betterdisplay.enable` pulls the betterdisplay cask itself, and
  # `mine.desktop.raycast.enable` pulls raycast.
  mine.homebrew = {
    # Formulae: command-line tools Homebrew has and nixpkgs does not, or does
    # not have working on darwin. Everything else goes in
    # modules/home-packages.nix, which is nix and therefore reproducible.
    brews = [ ];

    # Casks: GUI applications, which macOS mostly does not have in nixpkgs.
    casks = [
      "visual-studio-code"
      "vlc"
    ];
  };

  # Off. A launchd agent watching lock events is not a generic want. The label
  # follows `mine.user.name` now (#4), so on this host it would be
  # com.changeme.screen-lock-monitor rather than com.david.*.
  mine.services."screen-lock-monitor".enable = false;

  # `mine.work.wemaintain.enable` is left at its default (false). It is the
  # one employer-specific unit in the repo (#8): SSO profiles, RDS helpers,
  # gcloud. A fork that does not work there has no use for any of it, and a
  # colleague who does turns it on with one line plus their work email.

  # `mine.secrets.enable` is deliberately left at its default (false): this host
  # must evaluate with no access to the private secrets repo (#17).
}
