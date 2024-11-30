{ config, pkgs, lib, ... }:

# Original source: https://gist.github.com/antifuchs/10138c4d838a63c0a05e725ccd7bccdd

with lib;
let
  cfg = config.local.dock;
  inherit (pkgs) stdenv dockutil;
in
{
  options = {
    local.dock.enable = mkOption {
      description = "Enable dock";
      default = stdenv.isDarwin;
      example = false;
    };

    local.dock.entries = mkOption
      {
        description = "Entries on the Dock";
        type = with types; listOf (submodule {
          options = {
            path = lib.mkOption { type = str; };
            section = lib.mkOption {
              type = str;
              default = "apps";
            };
            options = lib.mkOption {
              type = str;
              default = "";
            };
          };
        });
        readOnly = true;
      };
  };

  config =
    mkMerge [
      (mkIf (cfg.enable) (
        let
          normalize = path: if hasSuffix ".app" path then path + "/" else path;
          entryURI = path: "file://" + (builtins.replaceStrings
            [" "   "!"   "\""  "#"   "$"   "%"   "&"   "'"   "("   ")"]
            ["%20" "%21" "%22" "%23" "%24" "%25" "%26" "%27" "%28" "%29"]
            (normalize path)
          );
          wantURIs = concatMapStrings
            (entry: "${entryURI entry.path}\n")
            cfg.entries;
          createEntries = concatMapStrings
            (entry: "${dockutil}/bin/dockutil --no-restart --add '${entry.path}' --section ${entry.section} ${entry.options}\n")
            cfg.entries;
        in
        {
          system.activationScripts.postUserActivation.text = ''
            echo >&2 "Setting up the Dock..."
            defaults write com.apple.dock tilesize -float 64 && killall Dock
            defaults write com.apple.dock autohide -bool false && killall Dock
            defaults delete com.apple.dock autohide-delay && killall Dock
            defaults write com.apple.dock no-bouncing -bool FALSE && killall Dock
            haveURIs="$(${dockutil}/bin/dockutil --list | ${pkgs.coreutils}/bin/cut -f2)"
            if ! diff -wu <(echo -n "$haveURIs") <(echo -n '${wantURIs}') >&2 ; then
              echo >&2 "Resetting Dock."
              ${dockutil}/bin/dockutil --no-restart --remove all
              ${createEntries}
              killall Dock
            else
              echo >&2 "Dock setup complete."
            fi
          '';
        }
      ))
      (mkIf (!cfg.enable) {
        system.activationScripts.postUserActivation.text = ''
            echo >&2 "Removing the dock..."
            defaults write com.apple.dock orientation -string "left"
            defaults write com.apple.dock autohide -bool true
            defaults write com.apple.dock autohide-delay -float 1000
            defaults write com.apple.dock no-bouncing -bool TRUE
            killall Dock
            echo >&2 "Dock removed"
        '';
      })
    ];
}
