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
      # Opt-in (#5): without a GPG key for the commit email, signing makes
      # every commit fail.
      commit.gpgsign = osConfig.mine.user.signCommits;

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
