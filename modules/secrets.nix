{ config, pkgs, agenix, secrets, ... }:

let
  user = config.mine.user.name;
  home = config.users.users.${user}.home;
in
{
  age.identityPaths = [
    "${home}/.ssh/id_ed25519"
  ];

  age.secrets.GITHUB_NPM_TOKEN = {
    symlink = true;
    path = "${home}/.secrets/GITHUB_TOKEN";
    file = "${secrets}/github-npm-token.age";
    mode = "600";
    owner = user;
    group = "staff";
  };

}
