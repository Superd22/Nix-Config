_:
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

    brews = [
      "nvm"
      "git-secret"
      "deno"
      "fga"
      "scrcpy"
      "rust"
      "httpie"
      "sf"
    ];
    casks = [
      # Development Tools
      "docker-desktop"
      "visual-studio-code"
      "datagrip"
      "openlens"
      "deskflow"
      "signal"
      "betterdisplay"
      # Communication Tools
      "discord"

      # Entertainment Tools
      "vlc"
      "spotify"
      "jellyfin-media-player"
      "steam"
      "obs"

      # Editors
      "zed"

      # Terminal
      "warp"
      "sf"
      "raycast"

      # Browsers
      "sigmaos"

      # Networking
      "zerotier-one"
      "pritunl"

      # 3D
      "autodesk-fusion"
      "orcaslicer"

      "parsec"
      "nordvpn"

      "camo-studio"
    ];
  };
}
