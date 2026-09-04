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
    # `defaults` below only writes the preferences; it does not tell the
    # running session to re-read them. Most are picked up the next time
    # whatever reads them starts, but the ones WindowServer and the HID stack
    # cache at login — `com.apple.swipescrolldirection` being the one that
    # bites — stay on their old value until you log out. So a freshly built Mac
    # comes up scrolling the wrong way even though the pref on disk is already
    # right.
    #
    # `activateSettings -u` is what System Settings itself calls to broadcast
    # the change, so running it after activation makes `build-switch` take
    # effect the way flipping the switch in the UI would.
    #
    # Activation runs as root, and the settings to broadcast are the login
    # user's, so this drops into their GUI session the same way nix-darwin's
    # own generated `defaults write` lines above it do.
    activationScripts.activateSettings.text = ''
      launchctl asuser "$(id -u -- ${config.mine.user.name})" \
        sudo --user=${config.mine.user.name} -- \
        /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
    '';

    defaults = {
      NSGlobalDomain = {
        AppleShowAllExtensions = true;
        ApplePressAndHoldEnabled = false;

        # 120, 90, 60, 30, 12, 6, 2
        KeyRepeat = 2;

        # 120, 94, 68, 35, 25, 15
        InitialKeyRepeat = 15;

        "com.apple.mouse.tapBehavior" = 1;

        # Classic scrolling: scroll up moves the view up (macOS "Natural" off)
        "com.apple.swipescrolldirection" = false;

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
