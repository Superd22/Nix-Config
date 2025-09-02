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

      # Terminal
      "warp"
      "sf"

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
