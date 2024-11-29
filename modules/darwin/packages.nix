{ pkgs }:

with pkgs;
let shared-packages = import ../shared/packages.nix { inherit pkgs; }; in
shared-packages ++ [
  dockutil
  # macos dmenu
  raycast
  # macos i3
  aerospace
]
