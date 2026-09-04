{ ... }:

{
  programs.starship = {
    enable = true;
    settings = {
      add_newline = false;
      command_timeout = 300;

      character = {
        success_symbol = "[➜](bold green)";
        error_symbol = "[➜](bold red)";
      };

      directory = {
        truncation_length = 5;
        truncate_to_repo = false;
      };

      git_branch = {
        symbol = " ";
        disabled = true;
      };

      git_status = {
        ahead = ''⇡''${count}'';
        diverged = ''⇕⇡''${ahead_count}⇣''${behind_count}'';
        behind = ''⇣''${count}'';
        disabled = true;
      };

      nodejs = {
        symbol = " ";
        disabled = true;
      };
      python = {
        symbol = " ";
        disabled = true;
      };
      rust = {
        symbol = " ";
        disabled = true;
      };
      nix_shell = {
        symbol = " ";
        impure_msg = "[impure](bold red)";
        pure_msg = "[pure](bold green)";
        unknown_msg = "[unknown shell](bold yellow)";
        format = "via [$symbol$state( \\($name\\))](bold blue) ";
        disabled = true;
      };
    };
  };
}
