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

  # Raycast launches these from the GUI session, whose PATH is not the shell's,
  # so the tools they need are pinned to the store here rather than looked up.
  # `/usr/local/bin` is on the end for `betterdisplaycli`, which the ultra-wide
  # scripts drive and which `modules/desktop/betterdisplay` installs there.
  runtimePath = lib.makeBinPath (with pkgs; [ aerospace jq coreutils gnused ]);

  # The sources are stored without a shebang, as the repo does elsewhere for
  # scripts that only ever run with a generated preamble.
  render = name: ''
    #!${pkgs.bash}/bin/bash
    export PATH="${runtimePath}:/usr/local/bin:$PATH"
    ${builtins.readFile (scriptDir + "/${name}")}'';

  # Everything in the directory except the upstream template, which is a
  # starting point to copy rather than a command to install.
  names = lib.filter
    (name: lib.hasSuffix ".sh" name && !(lib.hasInfix ".template." name))
    (lib.attrNames (builtins.readDir scriptDir));
in
{
  config = lib.mkIf config.mine.desktop.raycast.enable {
    home-manager.users.${user}.home.file = lib.listToAttrs (map
      (name: lib.nameValuePair ".config/raycast/scripts/${name}" {
        executable = true;
        text = render name;
      })
      names);
  };
}
