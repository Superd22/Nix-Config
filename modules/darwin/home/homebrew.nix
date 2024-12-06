_:
{
  homebrew = {
    enable = true;
    brews = [
      "nvm"
    ];
    casks = [
      # Development Tools
      "homebrew/cask/docker"
      "visual-studio-code"
      "httpie"

      # Communication Tools
      "discord"

      # Entertainment Tools
      "vlc"
      "spotify"
      "jellyfin-media-player"

      # Terminal
      "warp"
      "sf"

      # Browsers
      "sigmaos"

      # Networking
      "zerotier-one"
    ];
  };
}
