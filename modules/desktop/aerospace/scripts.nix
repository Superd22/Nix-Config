# Scripts that the keybindings in .aerospace.toml call out to.
#
# A package set rather than a module: aerospace.nix needs the store path to
# substitute into the bindings, and `exec-and-forget` runs with AeroSpace's own
# PATH rather than a login shell's, so a bare name on PATH would not resolve.
{ pkgs }:

{
  workspace-to-next-monitor = pkgs.writeShellApplication {
    name = "workspace-to-next-monitor";
    runtimeInputs = with pkgs; [ aerospace jq ];
    text = builtins.readFile ./next-monitor-of-workspace.sh;
  };
}
