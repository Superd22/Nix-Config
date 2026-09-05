#!/bin/sh
# Renders the aerospace.toml exactly as nix-darwin would, by feeding the
# evaluated settings back through the same pkgs.formats.toml generator.
set -e
cd /Users/david/.config/nixos-config/.claude/worktrees/aerospace-toml-1-1-spike
out=$(nix build --no-link --print-out-paths --impure --expr '
  let
    flake = builtins.getFlake (toString ./.);
    cfg = flake.darwinConfigurations.David-M4-Max;
    pkgs = cfg.pkgs;
    lib = pkgs.lib;
    filterRec = pred: set: lib.listToAttrs (lib.concatMap (name:
      let v = set.${name}; in
      if pred v then [ (lib.nameValuePair name (
        if lib.isAttrs v then filterRec pred v
        else if lib.isList v then map (i: if lib.isAttrs i then filterRec pred i else i) (lib.filter pred v)
        else v)) ] else []) (lib.attrNames set));
  in
    (pkgs.formats.toml {}).generate "aerospace.toml"
      (filterRec (v: v != null) cfg.config.services.aerospace.settings)
')
echo "$out"
echo "--- head ---"
head -30 "$out"
echo "..."
grep -n "on-window-detected" -A6 "$out"
