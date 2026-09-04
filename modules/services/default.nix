# Services are imported unconditionally and gated on their `mine.services.*`
# flag, so the wizard (#5) never has to rewrite an import list.
#
# screen-lock-monitor is gated from out here rather than from inside its own
# file, which is the one exception to that shape and is deliberate. Its
# derivation uses `src = ./.`, so every file in
# modules/services/screen-lock-monitor is a build input — the .nix file
# included. Putting `lib.mkIf` in there would change the source hash and force a
# recompile of the Swift binary, and of everything downstream of it, for a
# refactor that changes nothing about what runs.
#
# The gate is an inline module inside `imports` rather than a `config` block on
# this file, and that also matters: module order decides the order in which
# `environment.systemPackages` is concatenated, and system-path hashes that
# order. Sitting in the import list keeps the wrapper exactly where
# ./screen-lock-monitor used to sit, so the closure is unchanged.
{ config, lib, pkgs, ... }:

{
  imports = [
    {
      config = lib.mkIf config.mine.services."screen-lock-monitor".enable
        (import ./screen-lock-monitor { inherit pkgs; });
    }
  ];
}
