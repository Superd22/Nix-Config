_:
{
  homebrew = {
    enable = true;
    brews = [
      "nvm"
      "git-secret"
      "deno"
      "openfga"
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
    ];
  };
}
