# agenix-managed secrets, read out of the private `secrets` flake input.
#
# The whole body is behind `mine.secrets.enable` (default false) because
# `${secrets}` is a private `git+ssh://` repo: interpolating it forces the
# fetch, and evaluating *any* host would then require SSH access to it. With
# the option off the interpolation is never reached, so the input is never
# fetched and hosts like `example` evaluate for anyone (#17).
{ config, lib, pkgs, agenix, secrets, ... }:

let
  user = config.mine.user.name;
  home = config.users.users.${user}.home;
in
lib.mkIf config.mine.secrets.enable {
  age.identityPaths = [
    "${home}/.ssh/id_ed25519"
  ];

  # No secrets are declared right now. GITHUB_NPM_TOKEN used to live here,
  # exported as GITHUB_TOKEN by the ~/.secrets loop in modules/programs/zsh.nix
  # and picked up by `gh`; it was dropped in favour of a plain `gh auth login`,
  # whose token `gh` stores in ~/.config/gh/hosts.yml. Add `age.secrets.<NAME>`
  # entries here when there is something to encrypt again.

}
