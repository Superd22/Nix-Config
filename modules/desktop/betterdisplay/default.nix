{ config, lib, ... }:
{
  imports = [
    ./betterdisplaycli.nix
  ];

  # The cask, not as a preference but as this module's implementation: the
  # wrapper in betterdisplaycli.nix runs a binary inside
  # /Applications/BetterDisplay.app, so `mine.desktop.betterdisplay.enable`
  # without the cask is a module that cannot work. It used to sit unconditionally
  # in modules/homebrew.nix (#9).
  config = lib.mkIf config.mine.desktop.betterdisplay.enable {
    homebrew.casks = [ "betterdisplay" ];
  };
}
