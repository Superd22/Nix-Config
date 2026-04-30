_:
{
  homebrew = {
    enable = true;
    brews = [
      "nvm"
      "git-secret"
      "deno"
      "fga"
      "scrcpy"
      "rust"
    ];
    casks = [
      # Development Tools
      "homebrew/cask/docker"
      "visual-studio-code"
      "httpie"
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
