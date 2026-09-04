# Raycast script commands.
#
# Raycast finds script commands by scanning a directory you nominate once in its
# settings ("Script Commands" -> "Add Script Directory") for executable `.sh`
# files carrying `@raycast.*` header comments. That rules out shipping them as
# packages on PATH — the filename and the extension are part of the contract —
# so they are rendered into a stable path in the home directory instead, and
# `nix run .#build-switch` keeps them current.
#
# Point Raycast at ~/.config/raycast/scripts. `quicklinks.json` next to the
# sources still has to be imported by hand; Raycast has no on-disk format for
# quicklinks.
{ config, lib, pkgs, ... }:

let
  user = config.mine.user.name;
  scriptDir = ../../config/raycast/scripts;

  betterdisplay = import ../betterdisplay/scripts.nix { inherit pkgs; };

  # Raycast launches these from the GUI session, whose PATH is not the shell's,
  # so the tools they need are pinned to the store here rather than looked up.
  # `betterdisplaycli` is taken from the betterdisplay package set directly
  # rather than found on PATH at /usr/local/bin, which is what the assertion
  # below is really about: the package resolves either way, but it is a wrapper
  # round an app bundle that is only there if BetterDisplay is installed (#21).
  runtimePath = lib.makeBinPath (
    (with pkgs; [ aerospace jq coreutils gnused ])
    ++ [ betterdisplay.betterdisplaycli ]
  );

  # The sources are stored without a shebang, as the repo does elsewhere for
  # scripts that only ever run with a generated preamble.
  render = name: ''
    #!${pkgs.bash}/bin/bash
    export PATH="${runtimePath}:$PATH"
    ${builtins.readFile (scriptDir + "/${name}")}'';

  # Everything in the directory except the upstream template, which is a
  # starting point to copy rather than a command to install.
  names = lib.filter
    (name: lib.hasSuffix ".sh" name && !(lib.hasInfix ".template." name))
    (lib.attrNames (builtins.readDir scriptDir));
in
{
  config = lib.mkIf config.mine.desktop.raycast.enable {
    # The ultra-wide script commands are 17 calls to `betterdisplaycli` and
    # nothing else would drive the PiP layout they set up, so raycast without
    # betterdisplay is a half-configured machine rather than a smaller one. The
    # flag is the closest thing this repo has to "BetterDisplay is installed";
    # #9 will move the cask itself under the same flag.
    assertions = [
      {
        assertion = config.mine.desktop.betterdisplay.enable;
        message = ''
          mine.desktop.raycast.enable needs mine.desktop.betterdisplay.enable:
          the ultra-wide script commands drive `betterdisplaycli`, which wraps
          an app bundle that betterdisplay is what asks for. Either enable
          betterdisplay too, or turn raycast off.
        '';
      }
    ];

    home-manager.users.${user}.home.file = lib.listToAttrs (map
      (name: lib.nameValuePair ".config/raycast/scripts/${name}" {
        executable = true;
        text = render name;
      })
      names);
  };
}
