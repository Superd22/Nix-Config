# The `mine.*` namespace: everything about this repo that is a property of the
# person or the machine rather than of the software being configured.
#
# It is declared with the module system rather than passed around as
# `specialArgs` on purpose: options get types, error messages that name the
# option that is missing, and a schema that the setup wizard (#5) can read back
# and render as prompts.
#
# Identity has no defaults. A fork that forgets to set `mine.user.name` gets a
# loud "option ... is used but not defined" naming the option, instead of a
# machine quietly configured as david.
{ lib, ... }:

{
  options.mine.user = {
    name = lib.mkOption {
      type = lib.types.str;
      example = "ada";
      description = ''
        Unix account name. Used for the macOS user, the home directory, the
        home-manager user, `system.primaryUser` and the Homebrew owner, so it
        must match the account you actually log in as.
      '';
    };

    fullName = lib.mkOption {
      type = lib.types.str;
      example = "Ada Lovelace";
      description = ''
        Human-readable name, as it should appear in commit authorship.
      '';
    };

    email = lib.mkOption {
      type = lib.types.str;
      example = "ada@example.com";
      description = ''
        Email address used for commit authorship.
      '';
    };
  };

  # Opt-in units (#3). Everything under here is a `mkEnableOption`, so it
  # defaults to `false` and a host has to ask for it by name. That is the point:
  # a fork that copies hosts/example gets a machine with nothing exotic turned
  # on, and turning something off is one line in the host file rather than an
  # edit to a module that upstream also maintains.
  #
  # The modules themselves are always imported by modules/desktop/default.nix
  # and modules/services/default.nix; only their `config` is gated. Import lists
  # stay static so the wizard (#5) never has to rewrite one.
  options.mine.desktop = {
    aerospace.enable = lib.mkEnableOption ''
      the AeroSpace tiling window manager, configured from
      modules/desktop/aerospace/.aerospace.toml. Also installs
      `workspace-to-next-monitor`, which the ctrl-shift-alt-<N> bindings call
    '';

    sketchybar.enable = lib.mkEnableOption ''
      the SketchyBar status bar
    '';

    betterdisplay.enable = lib.mkEnableOption ''
      `betterdisplaycli`, a wrapper round the CLI that the BetterDisplay cask
      hides inside its .app bundle. Needs the cask, which is currently listed
      unconditionally in modules/homebrew.nix (#9 moves that here). Required by
      `raycast.enable` below
    '';

    dock.enable = lib.mkEnableOption ''
      declarative management of the macOS Dock. When on, the Dock is either
      populated from `local.dock.entries` or stripped entirely, depending on
      `local.dock.enable`. When off, this config does not touch the Dock at all,
      which is what you want on a machine whose Dock someone else arranged
    '';

    raycast.enable = lib.mkEnableOption ''
      the Raycast script commands from modules/config/raycast, rendered into
      ~/.config/raycast/scripts. Raycast still has to be pointed at that
      directory by hand, once — see that directory's readme. Requires
      `betterdisplay.enable` above; the ultra-wide scripts are mostly
      `betterdisplaycli` calls, and there is an assertion that says so
    '';
  };

  # Programs, as opposed to the desktop units above: things you run rather than
  # things that arrange your screen. The datasource schema that goes with this
  # flag is declared in modules/programs/datagrip, which is where it is used.
  options.mine.programs = {
    datagrip.enable = lib.mkEnableOption ''
      DataGrip: installs the cask and applies
      `mine.programs.datagrip.datasources` as global datasources, so the same
      connections are in every project on every machine. Off means this config
      does not install DataGrip and never touches its files
    '';
  };

  options.mine.services = {
    # Hyphenated to match the launchd label and the directory it lives in.
    "screen-lock-monitor".enable = lib.mkEnableOption ''
      the screen-lock-monitor launchd agent, a small Swift binary built from
      modules/services/screen-lock-monitor that watches macOS lock/unlock events
      and flips BetterDisplay's main monitor. Requires
      `mine.desktop.betterdisplay.enable`; the store path of `betterdisplaycli`
      is compiled into the binary
    '';
  };

  # Off by default: the secrets module interpolates the `secrets` flake input,
  # which is a private repo. Anything that forces it needs SSH access nobody
  # but its owner has, so a host has to opt in explicitly (#17).
  options.mine.secrets.enable =
    lib.mkEnableOption "agenix-managed secrets from the private `secrets` flake input";
}
