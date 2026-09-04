{
  description = "MacOS Compatible Nix";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    agenix.url = "github:ryantm/agenix";
    home-manager.url = "github:nix-community/home-manager";
    darwin = {
      url = "github:LnL7/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-homebrew = {
      url = "github:zhaofengli-wip/nix-homebrew";
    };
    homebrew-bundle = {
      url = "github:homebrew/homebrew-bundle";
      flake = false;
    };
    homebrew-core = {
      url = "github:homebrew/homebrew-core";
      flake = false;
    };
    homebrew-cask = {
      url = "github:homebrew/homebrew-cask";
      flake = false;
    };
    deskflowHomebrewTap = {
      url = "github:deskflow/homebrew-tap";
      flake = false;
    };
    openfgaTap = {
      url = "github:openfga/homebrew-tap";
      flake = false;
    };
    secrets = {
      url = "git+ssh://git@github.com/superd22/nix-secrets?ref=main";
      flake = false;
    };
  };
  outputs = { self, darwin, nix-homebrew, homebrew-bundle, homebrew-core, homebrew-cask, deskflowHomebrewTap, openfgaTap, home-manager, nixpkgs, agenix, secrets } @inputs:
    let
      system = "aarch64-darwin";
      pkgs = nixpkgs.legacyPackages.${system};
      devShell = {
        default = with pkgs; mkShell {
          # gum is here for running apps/init.sh from source (the CI smoke test
          # does, with stubs in front of it on PATH) and for recording it.
          nativeBuildInputs = with pkgs; [ bashInteractive git age age-plugin-yubikey gum ];
          shellHook = with pkgs; ''
            export EDITOR=vim
          '';
        };
      };
      # writeShellApplication runs shellcheck at build time and pins the
      # runtime dependencies, so the scripts are checked rather than just
      # executed out of the source tree.
      #
      # gitMinimal, not git: the full package pulls python3 and with it the
      # Apple SDK, 1.5 GiB of closure that `nix run github:...#init` would
      # download onto a factory Mac. Clone, commit and push over https and
      # ssh are all the scripts ask of it, and gitMinimal has them.
      mkScript = name: extraInputs: pkgs.writeShellApplication {
        inherit name;
        runtimeInputs = with pkgs; [ coreutils gitMinimal ] ++ extraInputs;
        text = builtins.readFile (./apps + "/${name}.sh");
      };
      scripts = rec {
        build = mkScript "build" [ ];
        build-switch = mkScript "build-switch" [ ];
        rollback = mkScript "rollback" [ ];
        # Moves the three irreplaceable keys between machines; see
        # apps/keys.sh and docs/new-machine.md. `nix` itself is deliberately
        # not pinned here: the one on PATH is the Determinate install.
        keys = mkScript "keys" (with pkgs; [ age gnupg gnutar gzip openssh ]);
        # The new-Mac wizard (#5), reached from bootstrap.sh. gum draws the
        # prompts (15 MiB, one dependency); keys and build-switch are the
        # same builds as `nix run .#keys` / `.#build-switch`, not re-evaluated
        # through a second flake call.
        init = mkScript "init" (with pkgs; [ gum findutils openssh keys build-switch ]);
      };
      # Every directory under hosts/ except the shared `common/` is a machine,
      # named after its hostname so `hostname -s` picks the right one.
      hostNames = builtins.attrNames (nixpkgs.lib.filterAttrs
        (name: type: type == "directory" && name != "common")
        (builtins.readDir ./hosts));
      mkHost = hostName: darwin.lib.darwinSystem {
        inherit system;
        specialArgs = inputs;
        modules = [
          home-manager.darwinModules.home-manager
          nix-homebrew.darwinModules.nix-homebrew
          # Homebrew is owned by the machine's user, so this needs the config
          # rather than a flake-level `let` binding.
          ({ config, lib, ... }:
            let
              officialTaps = {
                "homebrew/homebrew-core" = homebrew-core;
                "homebrew/homebrew-cask" = homebrew-cask;
                "homebrew/homebrew-bundle" = homebrew-bundle;
              };
              # Third-party taps. Kept apart from the official ones because
              # Homebrew treats them differently: see `homebrew.taps` below.
              extraTaps = {
                "deskflow/homebrew-deskflow" = deskflowHomebrewTap;
                "openfga/homebrew-openfga" = openfgaTap;
              };
            in
            {
              nix-homebrew = {
                user = config.mine.user.name;
                enable = true;
                taps = officialTaps // extraTaps;
                mutableTaps = false;
                autoMigrate = true;
              };

              # Homebrew 6.0 turned on HOMEBREW_REQUIRE_TAP_TRUST, which refuses
              # to load a formula or cask from a third-party tap until someone
              # has run `brew trust`. During an activation there is nobody to
              # run it, so `brew bundle` aborts:
              #
              #   error: refusing to load formula openfga/openfga/fga from
              #   untrusted tap
              #
              # `trusted = true` puts `trusted: true` on the Brewfile's tap
              # line, which makes `brew bundle` record the trust itself before
              # it loads anything. Trusting the tap covers every formula and
              # cask in it, so `brews = [ "fga" ]` keeps working unqualified.
              #
              # It is the same trust decision that adding the flake input was:
              # mutableTaps = false means these are cloned from the store at the
              # revision flake.lock pins, and nothing changes under us until
              # that lock is bumped. Official taps need none of this.
              homebrew.taps = lib.mapAttrsToList
                (name: _: {
                  # user/homebrew-repo is the directory; brew calls it user/repo.
                  name = builtins.replaceStrings [ "/homebrew-" ] [ "/" ] name;
                  trusted = true;
                })
                extraTaps;
            })
          ./hosts/common/darwin.nix
          (./hosts + "/${hostName}")
        ];
      };
    in
    {
      devShells.${system} = devShell;
      packages.${system} = scripts;
      apps.${system} = nixpkgs.lib.mapAttrs
        (_: drv: { type = "app"; program = nixpkgs.lib.getExe drv; })
        scripts;

      darwinConfigurations = nixpkgs.lib.genAttrs hostNames mkHost;
  };
}
