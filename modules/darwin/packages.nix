{ pkgs }:

with pkgs;
let
  shared-packages = import ../shared/packages.nix { inherit pkgs; };
  # Pin Ruby 3.2 from an older nixpkgs where it still exists (24.11)
  pkgs-ruby = import (fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/nixos-24.11.tar.gz";
    sha256 = "1s2gr5rcyqvpr58vxdcb095mdhblij9bfzaximrva2243aal3dgx";
  }) { inherit (pkgs) system; };
  ruby_3_2_0 = pkgs-ruby.ruby_3_2;
in
shared-packages ++ [
  dockutil
  aerospace
  xcodes
  ruby_3_2_0
]
