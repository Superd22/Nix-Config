{lib, ...}: {
  services.aerospace = {
    enable = true;
    settings = lib.importTOML ./.aerospace.toml;
  };
}
