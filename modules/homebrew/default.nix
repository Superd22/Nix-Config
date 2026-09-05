# Homebrew: policy and wiring, and no package names.
#
# What lives here is the part every machine shares — Homebrew is on, and how it
# behaves during an activation. *What* gets installed is a property of the
# person or the machine, so it comes from `mine.homebrew.*` (declared in
# modules/options.nix) and is set in hosts/<hostname> (#9).
#
# Modules add to these lists too, for the one case that is not taste: a module
# that shells out to an app bundle needs that cask the way `services.foo.enable`
# needs `pkgs.foo` upstream. `homebrew.casks` is a list option, so those
# contributions merge with whatever the host asked for; see
# modules/desktop/betterdisplay for the shape.
{ config, pkgs, ... }:
let
  scripts = import ./scripts.nix { inherit pkgs; };
  user = config.mine.user.name;
in
{
  homebrew = {
    enable = true;

    onActivation = {
      # Don't run `brew update` on every switch — keeps activations fast and
      # avoids hitting the network when you just want to apply nix changes.
      autoUpdate = false;

      # Don't upgrade already-installed formulae/casks automatically.
      # Upgrade manually with `brew upgrade` when you actually want it.
      upgrade = false;

      # Never try to uninstall packages that aren't in the list during
      # activation. "zap" / "uninstall" will try to delete running apps like
      # Docker and abort the whole activation, which also blocks home-manager
      # from updating your zsh config.
      cleanup = "none";
    };

    inherit (config.mine.homebrew) brews casks taps;
  };

  # The imperative front door (#35). `nix-homebrew.mutableTaps = false` makes
  # /opt/homebrew/Library/Taps a store symlink, so `brew tap` cannot write there;
  # rather than make it writable — which costs HOMEBREW_NO_AUTO_UPDATE and turns
  # a symlink flip into a 75 MiB rsync every activation — `nix-brew` writes the
  # pin into the repo and rebuilds. See modules/homebrew/nix-brew.sh.
  environment.systemPackages = [ scripts.nix-brew ];

  home-manager.users.${user} = { ... }: {
    # Shadowing `brew` is deliberate: the point is that muscle memory keeps
    # working. This only lands in interactive zsh, so scripts that call `brew`
    # non-interactively are unaffected, and `command brew` is the bypass for
    # anyone who wants the real thing.
    programs.zsh.initContent = ''
      brew() {
        case "''${1:-}" in
          tap|untap|install|uninstall|drift) nix-brew "$@" ;;
          *) command brew "$@" ;;
        esac
      }
    '';
  };
}
