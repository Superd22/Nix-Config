{ pkgs }:

with pkgs;
let
  shared-packages = import ../shared/packages.nix { inherit pkgs; };
  ruby_3_2_0 = pkgs.ruby_3_2.overrideAttrs (old: {
    version = "3.2.0";
    src = pkgs.fetchurl {
      url = "https://cache.ruby-lang.org/pub/ruby/3.2/ruby-3.2.0.tar.gz";
      sha256 = "0wn2mdvvx44hn6vf59pzq0v3l3whmmvvdkpfipwq69qb6vhpians";
    };
  });
in
shared-packages ++ [
  dockutil
  raycast
  aerospace
  xcodes
  ruby_3_2_0
]
