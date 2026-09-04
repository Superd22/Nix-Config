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
   # A nix-darwin module despite living in modules/programs: it owns both the
   # cask and the datasource file. See its header.
   ./programs/datagrip
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
    # When a module starts managing a file that already exists in the home
    # directory — ~/.aws/config on a machine that had one by hand before #8 —
    # home-manager refuses to clobber it and aborts the whole activation.
    # Moving the original aside instead, under the same suffix the datagrip
    # module uses, keeps a fresh enable from being a manual clean-up first.
    backupFileExtension = "before-nix";
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
