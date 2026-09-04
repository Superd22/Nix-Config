{ config, pkgs, lib, home-manager, ... }:

let
  user = config.mine.user.name;
  # Define the content of your file as a derivation

  homeFiles = import ./files.nix { inherit config pkgs; };
in
{
  imports = [
   ./homebrew.nix
   ./desktop
  ];

  # It me
  users.users.${user} = {
    name = "${user}";
    home = "/Users/${user}";
    isHidden = false;
    shell = pkgs.zsh;
  };

  # Enable home-manager
  home-manager = {
    useGlobalPkgs = true;
    users.${user} = { pkgs, config, lib, ... }: {
      imports = [ ./programs ];

      home = {
        enableNixpkgsReleaseCheck = false;
        packages = pkgs.callPackage ./home-packages.nix {};
        file = homeFiles;

        stateVersion = "23.11";
      };

      # Marked broken Oct 20, 2022 check later to remove this
      # https://github.com/nix-community/home-manager/issues/3344
      manual.manpages.enable = false;
    };
  };

  # Fully declarative dock using the latest from Nix Store
  local = {
    dock = {
      enable = false;
      entries = [
        # { path = "/Applications/Slack.app/"; }
        # { path = "/System/Applications/Messages.app/"; }
        # { path = "/System/Applications/Facetime.app/"; }
        # { path = "${pkgs.alacritty}/Applications/Alacritty.app/"; }
        # { path = "/System/Applications/Music.app/"; }
        # { path = "/System/Applications/News.app/"; }
        # { path = "/System/Applications/Photos.app/"; }
        # { path = "/System/Applications/Photo Booth.app/"; }
        # { path = "/System/Applications/TV.app/"; }
        # { path = "/System/Applications/Home.app/"; }
        # {
        #   path = toString myEmacsLauncher;
        #   section = "others";
        # }
        # {
        #   path = "${config.users.users.${user}.home}/.local/share/";
        #   section = "others";
        #   options = "--sort name --view grid --display folder";
        # }
        # {
        #   path = "${config.users.users.${user}.home}/.local/share/downloads";
        #   section = "others";
        #   options = "--sort name --view grid --display stack";
        # }
      ];
    };
  };
}
