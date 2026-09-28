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
# It is not a copy of David's hosts and diverges from them deliberately:
# the flags below are what a generic fork should get, and the Homebrew lists
# (#9) are a short seed rather than one person's applications.
{ ... }:

{
  mine.user = {
    name = "changeme";
    fullName = "Change Me";
    email = "you@example.com";
    # Both left at their defaults: github.com is not pinned to a key (git over
    # https through gh works without one), and commits are not signed. The
    # init wizard (#5) asks about both. David's hosts set "id_rsa" and true.
    # githubKey = "id_ed25519";
    # signCommits = true;
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

    # On: the launcher, its Control-D hotkey and a login agent to start it.
    # The ultra-wide script commands are not included; they come only with
    # betterdisplay above, which is off.
    raycast.enable = true;
  };

  # Programs. Both off here, spelled out so this file reads like a real host
  # and like what the init wizard writes.
  mine.programs = {
    # Off. Points ~/.claude into this repo's modules/config/claude, so the
    # settings and skills are David's until changed; see docs/two-paths.md.
    # The wizard explains that before asking.
    claude-code.enable = false;

    # Off. It is at its most useful with the WeMaintain module's datasources,
    # and the wizard preselects it for colleagues.
    datagrip.enable = false;
  };

  # Homebrew (#9). This is the seed a fork copies and edits, and what the init
  # wizard preselects: the development half of hosts/David-M4-Max, without
  # Steam, NordVPN, Autodesk Fusion and the rest that should not arrive with
  # a config someone else wrote. The wizard offers those unselected. Add what
  # you actually use; `brew search` takes the same names.
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
      "docker-desktop"
      "visual-studio-code"
      "warp"
      "google-chrome"
      "claude-code@latest"
      "claude"
    ];
  };

  # Off. A launchd agent watching lock events is not a generic want. The label
  # follows `mine.user.name` now (#4), so on this host it would be
  # com.changeme.screen-lock-monitor rather than com.david.*.
  mine.services."screen-lock-monitor".enable = false;

  # `mine.work.wemaintain.enable` is left at its default (false). It is the
  # one employer-specific unit in the repo (#8): SSO profiles, RDS helpers,
  # the VPN. A fork that does not work there has no use for any of it, and a
  # colleague who does turns it on with one line.

  # `mine.secrets.enable` is deliberately left at its default (false): this host
  # must evaluate with no access to the private secrets repo (#17).
}
