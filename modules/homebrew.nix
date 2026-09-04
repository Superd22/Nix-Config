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
{ config, ... }:
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
}
