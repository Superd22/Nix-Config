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

      # Terminal
      "warp"

      # Browsers
      "sigmaos"

      # Networking
      "zerotier-one"
    ];
  };
}
