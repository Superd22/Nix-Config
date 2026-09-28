{ config, lib, osConfig, ... }:

let
  githubKey = osConfig.mine.user.githubKey;
in

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
    } // lib.optionalAttrs (githubKey != null) {
      # Pinned, so a private git+ssh:// input is fetched with the key GitHub
      # knows rather than whichever the agent offers first. Which key that is
      # belongs to the person, not this module (#5).
      "github.com" = {
        IdentitiesOnly = true;
        IdentityFile = [
          "${config.home.homeDirectory}/.ssh/${githubKey}"
        ];
      };
    };
  };
}
