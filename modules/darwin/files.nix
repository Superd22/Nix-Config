{ user, config, pkgs, ... }:

let
  xdg_home = "${config.users.users.${user}.home}";
  xdg_configHome = "${config.users.users.${user}.home}/.config";
  xdg_dataHome   = "${config.users.users.${user}.home}/.local/share";
  xdg_stateHome  = "${config.users.users.${user}.home}/.local/state";

  in
{

  # todo figureout how to symlink instead of copy
  "${xdg_home}/.aerospace.toml" = {
    source = ./dotfiles/.aerospace.toml;
  };

}
