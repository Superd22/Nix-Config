# Helper scripts that drive BetterDisplay and AeroSpace together.
#
# They are packages rather than files linked out of the working tree: the store
# path is what `betterdisplaycli.nix` and the AeroSpace keybindings point at, so
# the config no longer depends on the repo being checked out at one particular
# path.
{ pkgs }:

{
  workspace-to-next-monitor = pkgs.writeShellApplication {
    name = "workspace-to-next-monitor";
    runtimeInputs = with pkgs; [ aerospace jq ];
    text = builtins.readFile ./next-monitor-of-workspace.sh;
  };
}
