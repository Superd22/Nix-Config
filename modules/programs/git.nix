{ lib, osConfig, pkgs, ... }:

{
  programs.git = {
    enable = true;
    ignores = [ "*.swp" ];
    signing.format = "openpgp";
    lfs = {
      enable = true;
    };
    settings = {
      user = {
        name = osConfig.mine.user.fullName;
        email = osConfig.mine.user.email;
      };
      init.defaultBranch = "main";
      core = {
	    editor = "vim";
        autocrlf = "input";
      };
      commit.gpgsign = true;

      # `gh auth setup-git` equivalent
      credential."https://github.com".helper = [
        ""
        "!${lib.getExe pkgs.gh} auth git-credential"
      ];
      pull.rebase = true;
      rebase.autoStash = true;
    };
  };
}
