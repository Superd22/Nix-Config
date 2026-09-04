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
    # The app itself, for the same reason modules/desktop/betterdisplay declares
    # its cask: script commands rendered into ~/.config/raycast/scripts do
    # nothing at all without the thing that scans that directory (#9).
    homebrew.casks = [ "raycast" ];

    # The hotkey that opens Raycast, so a rebuilt Mac does not come up on
    # Raycast's default (which collides with Spotlight) and wait to be clicked
    # through the onboarding.
    #
    # `Control-2` is not a typo for the digit: the value is
    # `<modifiers>-<virtual key code>`, and 2 is kVK_ANSI_D. So this reads
    # "Control-D".
    #
    # Raycast keeps its preferences in memory and writes them out when it
    # quits, so an activation while it is running is overwritten the next time
    # it exits. Restart Raycast — or set it once in its own settings — for the
    # value written here to be the one that sticks.
    system.defaults.CustomUserPreferences."com.raycast.macos".raycastGlobalHotkey =
      "Control-2";

    # ...and something to actually start it. The hotkey above is inert while
    # Raycast is not running, and a machine built from this repo has no reason
    # to ever launch it: the cask only drops the bundle in /Applications, and
    # Raycast's own "launch at login" is a login item it writes for itself the
    # first time you open it by hand. Until then Control-D falls through to
    # whatever macOS does with it, which is what a fresh Mac looks like (#9).
    #
    # `open -a` rather than running the binary directly: Raycast is an app
    # bundle and expects to be launched as one, and `open` is a no-op if it is
    # already up. RunAtLoad with no KeepAlive because launchd's job here is to
    # start it once per login, not to supervise it — Raycast restarting itself
    # after an update should not be fought over.
    launchd.user.agents.raycast = {
      serviceConfig = {
        Label = "com.${user}.raycast";
        ProgramArguments = [ "/usr/bin/open" "-a" "Raycast" ];
        RunAtLoad = true;
      };
    };

    # The ultra-wide script commands are 17 calls to `betterdisplaycli` and
    # nothing else would drive the PiP layout they set up, so raycast without
    # betterdisplay is a half-configured machine rather than a smaller one.
    # betterdisplay is what pulls the cask that `betterdisplaycli` wraps.
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
