{ config, lib, ... }:

{
  config = lib.mkIf config.mine.desktop.aerospace.enable {
    services.aerospace = {
      enable = true;
      settings = lib.importTOML ./.aerospace.toml;
    };
  };
}
