{ osConfig, ... }:

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
      pull.rebase = true;
      rebase.autoStash = true;
    };
  };
}
