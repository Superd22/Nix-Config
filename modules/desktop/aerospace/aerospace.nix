{ config, lib, pkgs, ... }:

let
  scripts = import ./scripts.nix { inherit pkgs; };

  raw = lib.importTOML ./.aerospace.toml;

  # The .aerospace.toml is kept editable by hand — it is upstream's example file
  # with edits, and staying diffable against it is worth more than expressing
  # ten keybindings in nix. So it names the script bare and the store path is
  # substituted in here, which is what lets the /usr/local/bin shim go away
  # (#21): `exec-and-forget` inherits AeroSpace's PATH, not a login shell's, so
  # the binding has to carry an absolute path one way or another. Now it is an
  # absolute path into the store, which a rollback takes with it.
  resolve = lib.replaceStrings
    [ "exec-and-forget workspace-to-next-monitor" ]
    [ "exec-and-forget ${lib.getExe scripts.workspace-to-next-monitor}" ];

  settings = lib.recursiveUpdate raw {
    mode.main.binding = lib.mapAttrs (_: resolve) raw.mode.main.binding;
  };
in
{
  config = lib.mkIf config.mine.desktop.aerospace.enable {
    # Also on PATH, so the same thing can be run from a terminal.
    environment.systemPackages = [ scripts.workspace-to-next-monitor ];

    services.aerospace = {
      inherit settings;
      enable = true;
    };
  };
}
