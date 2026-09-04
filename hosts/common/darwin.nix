{ agenix, config, pkgs, ... }:

{

  imports = [
    ../../modules/options.nix
    ../../modules/secrets.nix
    ../../modules/home-manager.nix
    ../../modules/services
    # Employer-specific units (#8), each behind its own `mine.work.<name>.enable`.
    ../../modules/work
    ../../modules/nixpkgs.nix
     agenix.darwinModules.default
  ];

  # Setup user, packages, programs
  ids.gids.nixbld = 350;
  nix.enable = false; # Managed by determinate
  # nix = {
  #   package = pkgs.nix;
  #   settings = {
  #     trusted-users = [ "@admin" "${user}" ];
  #     substituters = [ "https://nix-community.cachix.org" "https://cache.nixos.org" ];
  #     trusted-public-keys = [ "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=" ];
  #   };

  #   gc = {
  #     automatic = true;
  #     interval = { Weekday = 0; Hour = 2; Minute = 0; };
  #     options = "--delete-older-than 30d";
  #   };

  #   extraOptions = ''
  #     experimental-features = nix-command flakes
  #   '';
  # };

  # Turn off NIX_PATH warnings now that we're using flakes
  system.checks.verifyNixPath = false;

  # Load configuration that is shared across systems
  environment.systemPackages = with pkgs; [
    agenix.packages."${pkgs.stdenv.hostPlatform.system}".default
  ] ++ (import ../../modules/packages.nix { inherit pkgs; });

  # The /etc/zshenv drift fix-up that used to be here moved to
  # modules/work/wemaintain (#8): the tool that causes the drift is a work one.

  system = {
    stateVersion = 4;
    primaryUser = config.mine.user.name;
    defaults = {
      NSGlobalDomain = {
        AppleShowAllExtensions = true;
        ApplePressAndHoldEnabled = false;

        # 120, 90, 60, 30, 12, 6, 2
        KeyRepeat = 2;

        # 120, 94, 68, 35, 25, 15
        InitialKeyRepeat = 15;

        "com.apple.mouse.tapBehavior" = 1;
        "com.apple.sound.beep.volume" = 0.0;
        "com.apple.sound.beep.feedback" = 0;
      };

      dock = {
        autohide = true;
        show-recents = false;
        launchanim = false;
        orientation = "left";
        tilesize = 48;
      };

      finder = {
        _FXShowPosixPathInTitle = false;
      };

      trackpad = {
        Clicking = true;
        TrackpadThreeFingerDrag = false;
      };
    };
  };
}
