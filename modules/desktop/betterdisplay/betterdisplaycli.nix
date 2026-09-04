{ config, lib, pkgs, ... }:

let
  scripts = import ./scripts.nix { inherit pkgs; };
in
{
  config = lib.mkIf config.mine.desktop.betterdisplay.enable {
    environment.systemPackages = [ scripts.betterdisplaycli ];
  };
}
