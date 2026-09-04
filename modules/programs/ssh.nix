{ config, ... }:

{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    includes = [
      "${config.home.homeDirectory}/.ssh/config_external"
    ];
    # Upstream OpenSSH directive names — `matchBlocks` (and its camelCase
    # aliases / `extraOptions` escape hatch) is deprecated.
    settings = {
      "*" = {
        AddKeysToAgent = "yes";
      };
      "github.com" = {
        IdentitiesOnly = true;
        IdentityFile = [
          "${config.home.homeDirectory}/.ssh/id_rsa"
        ];
      };
    };
  };
}
