# Same shape as modules/desktop/betterdisplay/scripts.nix: a module-local
# writeShellApplication, so the script is shellcheck'd at build time and its
# runtime dependencies are pinned rather than assumed to be on PATH.
{ pkgs }:

{
  # `nix` is deliberately absent from runtimeInputs — the one on PATH is the
  # Determinate install, which is the same call apps/*.sh make. `brew` likewise:
  # it is the nix-homebrew wrapper at /opt/homebrew/bin.
  nix-brew = pkgs.writeShellApplication {
    name = "nix-brew";
    runtimeInputs = with pkgs; [ jq gitMinimal coreutils ];
    text = builtins.readFile ./nix-brew.sh;
  };
}
