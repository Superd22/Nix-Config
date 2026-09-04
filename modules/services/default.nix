# Services are imported unconditionally and gated on their `mine.services.*`
# flag, so the wizard (#5) never has to rewrite an import list.
#
# screen-lock-monitor is gated from out here rather than from inside its own
# file, which is the one exception to that shape and is deliberate. Its
# dependency on betterdisplay is passed in from here too, as a store path
# rather than the /usr/local/bin convention it used to assume (#21). Its
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
      # `//` rather than a second module in this list: the assertion adds no
      # `environment.systemPackages`, so merging it into the same attrset keeps
      # the import list one entry long and the ordering above intact.
      config = lib.mkIf config.mine.services."screen-lock-monitor".enable
        ((import ./screen-lock-monitor {
          inherit lib pkgs;
          user = config.mine.user.name;
          betterdisplaycli =
            (import ../desktop/betterdisplay/scripts.nix { inherit pkgs; })
            .betterdisplaycli;
        }) // {
          assertions = [
            {
              assertion = config.mine.desktop.betterdisplay.enable;
              message = ''
                mine.services."screen-lock-monitor".enable needs
                mine.desktop.betterdisplay.enable: the agent exists to flip
                BetterDisplay's main monitor on lock and unlock, and does
                nothing useful without it.
              '';
            }
          ];
        });
    }
  ];
}
