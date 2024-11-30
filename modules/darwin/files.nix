{ user, config, pkgs, ... }:

# Handles copying files (especially dotfiles)
# Through home-manager

let
  xdg_home = "${config.users.users.${user}.home}";
  xdg_configHome = "${config.users.users.${user}.home}/.config";
  xdg_dataHome   = "${config.users.users.${user}.home}/.local/share";
  xdg_stateHome  = "${config.users.users.${user}.home}/.local/state";

  in
{

}
