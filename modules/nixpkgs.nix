{ config, pkgs, ... }:

let
  # Pinned to a commit, not to refs/heads/master: a branch tarball moves, but
  # the sha256 below does not, so the pair only agreed on machines that already
  # had the old tarball in their store. Anywhere else — CI, or anyone who forks
  # this repo — evaluation died with "NAR hash mismatch". This rev is the
  # content that was already cached, so nothing about what gets built changes.
  emacsOverlayRev = "9f303ef429e3a6cf0aabedd007e4ea6398a6f67b";
  emacsOverlaySha256 = "11p1c1l04zrn8dd5w8zyzlv172z05dwi9avbckav4d5fk043m754";
in
{

  nixpkgs = {
    config = {
      allowUnfree = true;
      allowBroken = true;
      allowInsecure = false;
      allowUnsupportedSystem = true;
    };

    overlays =
      # Apply each overlay found in the /overlays directory
      let path = ../overlays; in with builtins;
      map (n: import (path + ("/" + n)))
          (filter (n: match ".*\\.nix" n != null ||
                      pathExists (path + ("/" + n + "/default.nix")))
                  (attrNames (readDir path)))

      ++ [(import (builtins.fetchTarball {
               url = "https://github.com/dustinlyons/emacs-overlay/archive/${emacsOverlayRev}.tar.gz";
               sha256 = emacsOverlaySha256;
           }))];
  };

}
