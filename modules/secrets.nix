{ config, pkgs, agenix, secrets, ... }:

let user = "david"; in
{
  age.identityPaths = [
    "/Users/${user}/.ssh/id_ed25519"
  ];

  age.secrets.GITHUB_NPM_TOKEN = {
    symlink = true;
    path = "/Users/${user}/.secrets/GITHUB_TOKEN";
    file = "${secrets}/github-npm-token.age";
    mode = "600";
    owner = "${user}";
    group = "staff";
  };

}
