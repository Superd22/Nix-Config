# direnv — the piece that makes a devenv activate on `cd` and deactivate on the
# way out. `devenv` itself is in modules/packages.nix; this is only the hook.
#
# Two integrations are enabled side by side, because they cover different files:
#   nix-direnv  -> `use flake` / `use nix`, with the resulting shell pinned as a
#                  gc root so a `nix-collect-garbage` does not force a rebuild
#   devenv      -> `use devenv`, for a repo with a devenv.nix
{ lib, pkgs, ... }:

let
  # `devenv direnvrc` prints the shell that defines `use_devenv`. Baking it into
  # the store beats devenv's documented .envrc preamble, which is a `source_url`
  # of a pinned GitHub raw URL plus its sha256 in *every* repo: that fetches over
  # the network on first load, and the pin rots independently of the devenv here.
  # Generating it from this same pkgs.devenv keeps the two versions in lockstep.
  devenvDirenvrc = pkgs.runCommand "devenv-direnvrc" { } ''
    ${pkgs.devenv}/bin/devenv direnvrc > $out
  '';
in
{
  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;

    # Appended to ~/.config/direnv/direnvrc, which direnv sources before every
    # .envrc. Sourcing it here means a project's .envrc is just `use devenv`.
    stdlib = ''
      source ${devenvDirenvrc}
    '';

    config = {
      global = {
        # direnv prints every exported variable by default, which is a wall of
        # text on a devenv shell. Errors and the load/unload lines still show.
        hide_env_diff = true;
      };
    };
  };
}
