{ agenix, config, pkgs, ... }:

let user = "david"; in

{

  imports = [
    ../../modules/secrets.nix
    ../../modules/home-manager.nix
    ../../modules/services
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

  # /etc/zshenv is fought over by two other tools:
  #   - tech.bastion.aiproxy appends its HTTPS_PROXY / NODE_EXTRA_CA_CERTS exports
  #   - the Determinate installer prepends its "set up Nix on SSH" block
  # Either one replaces nix-darwin's symlink with a regular file, and etcChecks
  # then aborts the whole activation with "Unexpected files in /etc".
  #
  # Both tools also write to /etc/zshenv.local, which nix-darwin sources on every
  # shell and never manages, so the copy in /etc/zshenv is pure duplication and
  # nothing is lost by resetting it. Scoped to this one file on purpose — a
  # general /etc auto-heal would silently discard changes that aren't mirrored
  # anywhere. The .drifted copy is kept for inspection.
  #
  # preActivation runs before etcChecks (see nix-darwin's activation-scripts.nix).
  # Belongs in a WeMaintain-specific module once #8 lands, since aiproxy is a
  # work tool rather than something every fork of this repo wants.
  system.activationScripts.preActivation.text = ''
    if [ -e /etc/zshenv ] && [ "$(readlink /etc/zshenv)" != "/etc/static/zshenv" ]; then
      echo "[nix-darwin] /etc/zshenv drifted, moving it to /etc/zshenv.drifted" >&2
      mv -f /etc/zshenv /etc/zshenv.drifted
    fi
  '';

  system = {
    stateVersion = 4;
    primaryUser = user;
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
