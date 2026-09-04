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
          nativeBuildInputs = with pkgs; [ bashInteractive git age age-plugin-yubikey ];
          shellHook = with pkgs; ''
            export EDITOR=vim
          '';
        };
      };
      # writeShellApplication runs shellcheck at build time and pins the
      # runtime dependencies, so the scripts are checked rather than just
      # executed out of the source tree.
      mkScript = name: extraInputs: pkgs.writeShellApplication {
        inherit name;
        runtimeInputs = with pkgs; [ coreutils git ] ++ extraInputs;
        text = builtins.readFile (./apps + "/${name}.sh");
      };
      scripts = nixpkgs.lib.mapAttrs mkScript {
        build = [ ];
        build-switch = [ ];
        rollback = [ ];
        # Moves the three irreplaceable keys between machines; see
        # apps/keys.sh and docs/new-machine.md. `nix` itself is deliberately
        # not pinned here: the one on PATH is the Determinate install.
        keys = with pkgs; [ age gnupg gnutar gzip openssh ];
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
          ({ config, ... }: {
            nix-homebrew = {
              user = config.mine.user.name;
              enable = true;
              taps = {
                "homebrew/homebrew-core" = homebrew-core;
                "homebrew/homebrew-cask" = homebrew-cask;
                "homebrew/homebrew-bundle" = homebrew-bundle;
                "deskflow/homebrew-deskflow" = deskflowHomebrewTap;
                "openfga/homebrew-openfga" = openfgaTap;
              };
              mutableTaps = false;
              autoMigrate = true;
            };
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
